import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_address.dart';
import '../../domain/entities/customer_contact.dart';
import '../../domain/validation/customer_validators.dart';
import '../customer_demo_data.dart';
import '../customer_demo_policy.dart';
import '../customer_search.dart';
import '../exceptions/customer_exceptions.dart';
import '../models/customer_address_model.dart';
import '../models/customer_contact_model.dart';
import '../models/customer_model.dart';

abstract class CustomerLocalDataSource {
  Future<CustomerPage> getCustomers(CustomerQuery query);

  Future<Customer> getCustomerById(String id);

  Future<Customer> createCustomer(CustomerInput input);

  Future<Customer> updateCustomer({
    required String id,
    required CustomerInput input,
  });

  Future<Customer> changeStatus({
    required String id,
    required CustomerStatus status,
  });

  Future<List<CustomerAddress>> getAddresses(String customerId);

  Future<CustomerAddress> addAddress(AddressInput input);

  Future<CustomerAddress> updateAddress({
    required String id,
    required AddressInput input,
  });

  Future<void> deleteAddress({
    required String customerId,
    required String addressId,
  });

  Future<void> setPrimaryAddress({
    required String customerId,
    required String addressId,
  });

  Future<List<CustomerContact>> getContacts(String customerId);

  Future<CustomerContact> addContact(ContactInput input);

  Future<CustomerContact> updateContact({
    required String id,
    required ContactInput input,
  });

  Future<void> deleteContact({
    required String customerId,
    required String contactId,
  });

  Future<void> close();

  /// Shared connection used by the customer draft. Callers must not close it.
  Future<Database> database();
}

const customerDatabaseVersion = 3;

/// Local development database.
///
/// This file is not a multi-company boundary. It has no tenant column.
/// Real isolation between companies will be enforced by the future backend.
class CustomerLocalDataSourceImpl implements CustomerLocalDataSource {
  CustomerLocalDataSourceImpl({
    this.databasePath,
    bool? seedDemo,
    DateTime Function()? clock,
    String Function()? newId,
  }) : _seedDemo = seedDemo ?? true,
       _clock = clock ?? DateTime.now,
       _newId = newId ?? generateEntityId;

  final String? databasePath;
  final bool _seedDemo;
  final DateTime Function() _clock;
  final String Function() _newId;
  Database? _database;

  @override
  Future<CustomerPage> getCustomers(CustomerQuery query) async {
    final db = await _databaseOrOpen();
    final pageSize = query.pageSize.clamp(1, 100);
    final page = query.page < 0 ? 0 : query.page;
    final where = <String>[];
    final args = <Object?>[];
    if (query.status != null) {
      where.add('status = ?');
      args.add(query.status!.name);
    }
    final text = normalizeCustomerText(query.search);
    final digits = onlyDigits(query.search);
    final searchParts = <String>[];
    if (text.isNotEmpty) {
      searchParts.add("search_name LIKE ? ESCAPE '\\'");
      searchParts.add("search_trade_name LIKE ? ESCAPE '\\'");
      final pattern = '%${escapeLike(text)}%';
      args.add(pattern);
      args.add(pattern);
    }
    if (digits.isNotEmpty) {
      searchParts.add('search_phones LIKE ?');
      searchParts.add('search_document LIKE ?');
      final pattern = '%$digits%';
      args.add(pattern);
      args.add(pattern);
    }
    if (searchParts.isNotEmpty) {
      where.add('(${searchParts.join(' OR ')})');
    }
    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final total =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM customers $whereSql', args),
        ) ??
        0;
    final rows = await db.rawQuery(
      '''
      SELECT * FROM customers
      $whereSql
      ORDER BY search_name ASC, name ASC
      LIMIT ? OFFSET ?
      ''',
      [...args, pageSize, page * pageSize],
    );
    return CustomerPage(
      items: rows.map(CustomerModel.fromMap).toList(),
      total: total,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<Customer> getCustomerById(String id) async {
    final db = await _databaseOrOpen();
    final rows = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw CustomerNotFoundException();
    return CustomerModel.fromMap(rows.first);
  }

  @override
  Future<Customer> createCustomer(CustomerInput input) async {
    final db = await _databaseOrOpen();
    final now = _clock();
    final customer = _modelFromInput(
      id: _newId(),
      input: input,
      createdAt: now,
      updatedAt: now,
    );
    try {
      await db.insert('customers', _customerMap(customer));
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw DuplicateExternalCustomerException();
      }
      throw CacheException();
    }
    return customer;
  }

  @override
  Future<Customer> updateCustomer({
    required String id,
    required CustomerInput input,
  }) async {
    final current = await getCustomerById(id);
    final customer = _modelFromInput(
      id: id,
      input: input,
      createdAt: current.createdAt,
      updatedAt: _clock(),
      externalId: current.externalId,
      externalSource: current.externalSource,
    );
    final db = await _databaseOrOpen();
    try {
      await db.update(
        'customers',
        _customerMap(customer),
        where: 'id = ?',
        whereArgs: [id],
      );
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw DuplicateExternalCustomerException();
      }
      throw CacheException();
    }
    return customer;
  }

  @override
  Future<Customer> changeStatus({
    required String id,
    required CustomerStatus status,
  }) async {
    final current = await getCustomerById(id);
    final db = await _databaseOrOpen();
    final updated = CustomerModel(
      id: current.id,
      type: current.type,
      name: current.name,
      tradeName: current.tradeName,
      document: current.document,
      email: current.email,
      phone: current.phone,
      mobilePhone: current.mobilePhone,
      status: status,
      notes: current.notes,
      externalId: current.externalId,
      externalSource: current.externalSource,
      createdAt: current.createdAt,
      updatedAt: _clock(),
    );
    await db.update(
      'customers',
      _customerMap(updated),
      where: 'id = ?',
      whereArgs: [id],
    );
    return updated;
  }

  @override
  Future<List<CustomerAddress>> getAddresses(String customerId) async {
    await getCustomerById(customerId);
    final db = await _databaseOrOpen();
    final rows = await db.query(
      'customer_addresses',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'is_primary DESC, label COLLATE NOCASE ASC',
    );
    return rows.map(CustomerAddressModel.fromMap).toList();
  }

  @override
  Future<CustomerAddress> addAddress(AddressInput input) async {
    await getCustomerById(input.customerId);
    final db = await _databaseOrOpen();
    final id = _newId();
    late CustomerAddressModel saved;
    await db.transaction((txn) async {
      final count =
          Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM customer_addresses WHERE customer_id = ?',
              [input.customerId],
            ),
          ) ??
          0;
      final primary = input.isPrimary || count == 0;
      if (primary) {
        await txn.update(
          'customer_addresses',
          {'is_primary': 0},
          where: 'customer_id = ?',
          whereArgs: [input.customerId],
        );
      }
      saved = _addressModel(id: id, input: input, isPrimary: primary);
      await txn.insert('customer_addresses', saved.toMap());
    });
    return saved;
  }

  @override
  Future<CustomerAddress> updateAddress({
    required String id,
    required AddressInput input,
  }) async {
    final db = await _databaseOrOpen();
    late CustomerAddressModel saved;
    await db.transaction((txn) async {
      await _addressRow(txn, customerId: input.customerId, addressId: id);
      final othersPrimary =
          Sqflite.firstIntValue(
            await txn.rawQuery(
              '''
              SELECT COUNT(*) FROM customer_addresses
              WHERE customer_id = ? AND id != ? AND is_primary = 1
              ''',
              [input.customerId, id],
            ),
          ) ??
          0;
      final primary = input.isPrimary || othersPrimary == 0;
      if (primary) {
        await txn.update(
          'customer_addresses',
          {'is_primary': 0},
          where: 'customer_id = ?',
          whereArgs: [input.customerId],
        );
      }
      saved = _addressModel(id: id, input: input, isPrimary: primary);
      await txn.update(
        'customer_addresses',
        saved.toMap(),
        where: 'id = ? AND customer_id = ?',
        whereArgs: [id, input.customerId],
      );
    });
    return saved;
  }

  @override
  Future<void> deleteAddress({
    required String customerId,
    required String addressId,
  }) async {
    final db = await _databaseOrOpen();
    await db.transaction((txn) async {
      final rows = await _addressRow(
        txn,
        customerId: customerId,
        addressId: addressId,
      );
      final wasPrimary = (rows.first['is_primary'] as int) == 1;
      await txn.delete(
        'customer_addresses',
        where: 'id = ? AND customer_id = ?',
        whereArgs: [addressId, customerId],
      );
      if (!wasPrimary) return;
      final remaining = await txn.query(
        'customer_addresses',
        columns: ['id'],
        where: 'customer_id = ?',
        whereArgs: [customerId],
        orderBy: 'label COLLATE NOCASE ASC',
        limit: 1,
      );
      if (remaining.isEmpty) return;
      await txn.update(
        'customer_addresses',
        {'is_primary': 1},
        where: 'id = ?',
        whereArgs: [remaining.first['id']],
      );
    });
  }

  @override
  Future<void> setPrimaryAddress({
    required String customerId,
    required String addressId,
  }) async {
    final db = await _databaseOrOpen();
    await db.transaction((txn) async {
      await _addressRow(txn, customerId: customerId, addressId: addressId);
      await txn.update(
        'customer_addresses',
        {'is_primary': 0},
        where: 'customer_id = ?',
        whereArgs: [customerId],
      );
      await txn.update(
        'customer_addresses',
        {'is_primary': 1},
        where: 'id = ? AND customer_id = ?',
        whereArgs: [addressId, customerId],
      );
    });
  }

  @override
  Future<List<CustomerContact>> getContacts(String customerId) async {
    await getCustomerById(customerId);
    final db = await _databaseOrOpen();
    final rows = await db.query(
      'customer_contacts',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'is_primary DESC, name COLLATE NOCASE ASC',
    );
    return rows.map(CustomerContactModel.fromMap).toList();
  }

  @override
  Future<CustomerContact> addContact(ContactInput input) async {
    await getCustomerById(input.customerId);
    final db = await _databaseOrOpen();
    final id = _newId();
    late CustomerContactModel saved;
    await db.transaction((txn) async {
      final count =
          Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM customer_contacts WHERE customer_id = ?',
              [input.customerId],
            ),
          ) ??
          0;
      final primary = input.isPrimary || count == 0;
      if (primary) await _clearPrimaryContact(txn, input.customerId);
      saved = _contactModel(id: id, input: input, isPrimary: primary);
      await txn.insert('customer_contacts', saved.toMap());
    });
    return saved;
  }

  @override
  Future<CustomerContact> updateContact({
    required String id,
    required ContactInput input,
  }) async {
    final db = await _databaseOrOpen();
    late CustomerContactModel saved;
    await db.transaction((txn) async {
      await _contactRow(txn, customerId: input.customerId, contactId: id);
      final othersPrimary =
          Sqflite.firstIntValue(
            await txn.rawQuery(
              '''
              SELECT COUNT(*) FROM customer_contacts
              WHERE customer_id = ? AND id != ? AND is_primary = 1
              ''',
              [input.customerId, id],
            ),
          ) ??
          0;
      final primary = input.isPrimary || othersPrimary == 0;
      if (primary) await _clearPrimaryContact(txn, input.customerId);
      saved = _contactModel(id: id, input: input, isPrimary: primary);
      await txn.update(
        'customer_contacts',
        saved.toMap(),
        where: 'id = ? AND customer_id = ?',
        whereArgs: [id, input.customerId],
      );
    });
    return saved;
  }

  @override
  Future<void> deleteContact({
    required String customerId,
    required String contactId,
  }) async {
    final db = await _databaseOrOpen();
    await db.transaction((txn) async {
      final rows = await _contactRow(
        txn,
        customerId: customerId,
        contactId: contactId,
      );
      final wasPrimary = (rows.first['is_primary'] as int) == 1;
      await txn.delete(
        'customer_contacts',
        where: 'id = ? AND customer_id = ?',
        whereArgs: [contactId, customerId],
      );
      if (!wasPrimary) return;
      final remaining = await txn.query(
        'customer_contacts',
        columns: ['id'],
        where: 'customer_id = ?',
        whereArgs: [customerId],
        orderBy: 'name COLLATE NOCASE ASC',
        limit: 1,
      );
      if (remaining.isEmpty) return;
      await txn.update(
        'customer_contacts',
        {'is_primary': 1},
        where: 'id = ?',
        whereArgs: [remaining.first['id']],
      );
    });
  }

  @override
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  @override
  Future<Database> database() => _databaseOrOpen();

  Future<Database> _databaseOrOpen() async {
    final current = _database;
    if (current != null) return current;
    final path =
        databasePath ?? '${await getDatabasesPath()}/pouapp_customers.db';
    final database = await openDatabase(
      path,
      version: customerDatabaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await createCustomerTables(db);
        await createCustomerNoteTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await createCustomerNoteTables(db);
        if (oldVersion < 3) await upgradeCustomerNotePrices(db);
      },
    );
    if (customerDemoAllowed && _seedDemo) {
      await database.transaction(
        (txn) => insertCustomerDemoData(txn, _clock()),
      );
    }
    _database = database;
    return database;
  }

  CustomerModel _modelFromInput({
    required String id,
    required CustomerInput input,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? externalId,
    CustomerSource? externalSource,
  }) {
    return CustomerModel(
      id: id,
      type: input.type,
      name: input.name.trim(),
      tradeName: _blank(input.tradeName),
      document: _digitsOrNull(input.document),
      email: _blank(input.email),
      phone: _digitsOrNull(input.phone),
      mobilePhone: _digitsOrNull(input.mobilePhone),
      status: input.status,
      notes: _blank(input.notes),
      externalId: externalId ?? _blank(input.externalId),
      externalSource: externalSource ?? input.externalSource,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, Object?> _customerMap(CustomerModel customer) {
    return customer.toMap(
      searchName: normalizeCustomerText(customer.name),
      searchTradeName: normalizeCustomerText(customer.tradeName ?? ''),
      searchPhones: '${customer.phone ?? ''}${customer.mobilePhone ?? ''}',
      searchDocument: customer.document ?? '',
    );
  }

  CustomerAddressModel _addressModel({
    required String id,
    required AddressInput input,
    required bool isPrimary,
  }) {
    return CustomerAddressModel(
      id: id,
      customerId: input.customerId,
      label: input.label.trim(),
      recipientName: _blank(input.recipientName),
      zipCode: _digitsOrNull(input.zipCode),
      street: input.street.trim(),
      number: input.number.trim(),
      complement: _blank(input.complement),
      neighborhood: input.neighborhood.trim(),
      city: input.city.trim(),
      state: input.state.trim().toUpperCase(),
      reference: _blank(input.reference),
      isPrimary: isPrimary,
    );
  }

  CustomerContactModel _contactModel({
    required String id,
    required ContactInput input,
    required bool isPrimary,
  }) {
    return CustomerContactModel(
      id: id,
      customerId: input.customerId,
      name: input.name.trim(),
      role: _blank(input.role),
      phone: _digitsOrNull(input.phone),
      email: _blank(input.email),
      isPrimary: isPrimary,
      canReceiveBilling: input.canReceiveBilling,
      canReceiveDelivery: input.canReceiveDelivery,
      canReceiveWhatsApp: input.canReceiveWhatsApp,
    );
  }

  Future<List<Map<String, Object?>>> _addressRow(
    DatabaseExecutor txn, {
    required String customerId,
    required String addressId,
  }) async {
    final rows = await txn.query(
      'customer_addresses',
      where: 'id = ? AND customer_id = ?',
      whereArgs: [addressId, customerId],
      limit: 1,
    );
    if (rows.isEmpty) throw AddressNotFoundException();
    return rows;
  }

  Future<List<Map<String, Object?>>> _contactRow(
    DatabaseExecutor txn, {
    required String customerId,
    required String contactId,
  }) async {
    final rows = await txn.query(
      'customer_contacts',
      where: 'id = ? AND customer_id = ?',
      whereArgs: [contactId, customerId],
      limit: 1,
    );
    if (rows.isEmpty) throw ContactNotFoundException();
    return rows;
  }

  Future<void> _clearPrimaryContact(DatabaseExecutor txn, String customerId) {
    return txn.update(
      'customer_contacts',
      {'is_primary': 0},
      where: 'customer_id = ?',
      whereArgs: [customerId],
    );
  }
}

String? _blank(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty ? null : text;
}

String? _digitsOrNull(String? value) {
  final digits = onlyDigits(value);
  return digits.isEmpty ? null : digits;
}

Future<void> createCustomerTables(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE customers (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      name TEXT NOT NULL,
      trade_name TEXT,
      document TEXT,
      email TEXT,
      phone TEXT,
      mobile_phone TEXT,
      status TEXT NOT NULL,
      notes TEXT,
      external_id TEXT,
      external_source TEXT NOT NULL,
      search_name TEXT NOT NULL,
      search_trade_name TEXT NOT NULL,
      search_phones TEXT NOT NULL,
      search_document TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''');
  await db.execute('''
    CREATE UNIQUE INDEX idx_customers_external
    ON customers(external_source, external_id)
    WHERE external_id IS NOT NULL AND external_id != ''
    ''');
  await db.execute(
    'CREATE INDEX idx_customers_search_name ON customers(search_name)',
  );
  await db.execute('''
    CREATE TABLE customer_addresses (
      id TEXT PRIMARY KEY,
      customer_id TEXT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
      label TEXT NOT NULL,
      recipient_name TEXT,
      zip_code TEXT,
      street TEXT NOT NULL,
      number TEXT NOT NULL,
      complement TEXT,
      neighborhood TEXT NOT NULL,
      city TEXT NOT NULL,
      state TEXT NOT NULL,
      reference_note TEXT,
      is_primary INTEGER NOT NULL
    )
    ''');
  await db.execute('''
    CREATE TABLE customer_contacts (
      id TEXT PRIMARY KEY,
      customer_id TEXT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      role TEXT,
      phone TEXT,
      email TEXT,
      is_primary INTEGER NOT NULL,
      can_receive_billing INTEGER NOT NULL,
      can_receive_delivery INTEGER NOT NULL,
      can_receive_whatsapp INTEGER NOT NULL
    )
    ''');
  await db.execute('''
    CREATE TABLE app_meta (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
    ''');
}

/// Draft notes live in the customer database so a note and its lines share
/// one transaction. This does not record stock, debt or payment.
Future<void> createCustomerNoteTables(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE customer_notes (
      id TEXT PRIMARY KEY,
      customer_id TEXT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
      status TEXT NOT NULL,
      due_on TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''');
  await db.execute('''
    CREATE UNIQUE INDEX idx_customer_notes_one_draft
    ON customer_notes(customer_id)
    WHERE status = 'draft'
    ''');
  await db.execute('''
    CREATE TABLE customer_note_lines (
      id TEXT PRIMARY KEY,
      note_id TEXT NOT NULL REFERENCES customer_notes(id) ON DELETE CASCADE,
      position INTEGER NOT NULL,
      product_id TEXT,
      name TEXT NOT NULL,
      unit TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      unit_price_cents INTEGER NOT NULL,
      reference_price_cents INTEGER
    )
    ''');
  await db.execute(
    'CREATE INDEX idx_customer_note_lines_note '
    'ON customer_note_lines(note_id, position)',
  );
}

Future<void> upgradeCustomerNotePrices(Database db) async {
  final tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'customer_note_lines'",
  );
  if (tables.isEmpty) return;
  final columns = await db.rawQuery('PRAGMA table_info(customer_note_lines)');
  final names = {for (final row in columns) row['name'] as String};
  if (names.contains('reference_price_cents')) return;
  await db.execute(
    'ALTER TABLE customer_note_lines ADD COLUMN reference_price_cents INTEGER',
  );
  await db.execute('''
    UPDATE customer_note_lines
    SET reference_price_cents = unit_price_cents
    WHERE reference_price_cents IS NULL
    ''');
}

String generateEntityId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
