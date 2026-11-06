import 'package:sqflite/sqflite.dart';

import '../domain/entities/customer.dart';
import 'customer_demo_policy.dart';
import 'customer_search.dart';

Future<void> insertCustomerDemoData(DatabaseExecutor db, DateTime now) async {
  final existing = await db.query(
    'app_meta',
    where: 'key = ?',
    whereArgs: [demoSeedKey],
  );
  await _renameDemoPeople(db);
  if (existing.isNotEmpty) return;

  final timestamp = now.toIso8601String();
  await _customer(
    db,
    id: 'demo-customer-primavera',
    type: CustomerType.company,
    name: 'Marina Costa',
    tradeName: 'Primavera',
    document: '11222333000181',
    email: 'contato@primavera.example',
    phone: '1133334444',
    mobile: '11988887777',
    notes: 'Cliente fictício de demonstração.',
    externalId: 'demo-ca-primavera',
    externalSource: CustomerSource.contaAzul,
    timestamp: timestamp,
  );
  await _address(
    db,
    id: 'demo-address-primavera',
    customerId: 'demo-customer-primavera',
    label: 'Entrega',
    street: 'Rua das Flores',
    number: '120',
    neighborhood: 'Centro',
    city: 'São Paulo',
    state: 'SP',
    zipCode: '01001000',
  );
  await _contact(
    db,
    id: 'demo-contact-primavera-owner',
    customerId: 'demo-customer-primavera',
    name: 'Marina Costa',
    role: 'Proprietária',
    phone: '11988887777',
    isPrimary: true,
    billing: true,
  );
  await _contact(
    db,
    id: 'demo-contact-primavera-buyer',
    customerId: 'demo-customer-primavera',
    name: 'Paulo Lima',
    role: 'Compras',
    phone: '11977776666',
    isPrimary: false,
  );

  await _customer(
    db,
    id: 'demo-customer-mercado',
    type: CustomerType.company,
    name: 'Ricardo Alves',
    tradeName: 'Mercado Central',
    document: '19100000000191',
    phone: '2133332222',
    mobile: '21988881111',
    externalSource: CustomerSource.local,
    timestamp: timestamp,
  );
  await _customer(
    db,
    id: 'demo-customer-hortifruti',
    type: CustomerType.company,
    name: 'Pedro Almeida',
    tradeName: 'São José',
    document: '33444555000181',
    mobile: '31988882222',
    externalSource: CustomerSource.local,
    timestamp: timestamp,
  );
  await _customer(
    db,
    id: 'demo-customer-padaria',
    type: CustomerType.company,
    name: 'Beatriz Nunes',
    tradeName: 'Bom Sabor',
    document: '55666777000181',
    phone: '4132221111',
    externalSource: CustomerSource.local,
    timestamp: timestamp,
  );
  await _customer(
    db,
    id: 'demo-customer-joao',
    type: CustomerType.individual,
    name: 'João Oliveira',
    document: '52998224725',
    mobile: '21977776666',
    externalSource: CustomerSource.local,
    timestamp: timestamp,
  );

  await db.insert('app_meta', {'key': demoSeedKey, 'value': '1'});
}

Future<void> _renameDemoPeople(DatabaseExecutor db) async {
  const people = [
    ('demo-customer-primavera', 'Restaurante Primavera', 'Marina Costa'),
    ('demo-customer-mercado', 'Mercado Central', 'Ricardo Alves'),
    ('demo-customer-hortifruti', 'Hortifruti São José', 'Pedro Almeida'),
    ('demo-customer-padaria', 'Padaria Bom Sabor', 'Beatriz Nunes'),
  ];
  for (final (id, from, to) in people) {
    await db.update(
      'customers',
      {'name': to, 'search_name': normalizeCustomerText(to)},
      where: 'id = ? AND name = ?',
      whereArgs: [id, from],
    );
  }
}

Future<void> _customer(
  DatabaseExecutor db, {
  required String id,
  required CustomerType type,
  required String name,
  required CustomerSource externalSource,
  required String timestamp,
  String? tradeName,
  String? document,
  String? email,
  String? phone,
  String? mobile,
  String? notes,
  String? externalId,
}) {
  return db.insert('customers', {
    'id': id,
    'type': type.name,
    'name': name,
    'trade_name': tradeName,
    'document': document,
    'email': email,
    'phone': phone,
    'mobile_phone': mobile,
    'status': CustomerStatus.active.name,
    'notes': notes,
    'external_id': externalId,
    'external_source': externalSource.name,
    'search_name': normalizeCustomerText(name),
    'search_trade_name': normalizeCustomerText(tradeName ?? ''),
    'search_phones': '${phone ?? ''}${mobile ?? ''}',
    'search_document': document ?? '',
    'created_at': timestamp,
    'updated_at': timestamp,
  });
}

Future<void> _address(
  DatabaseExecutor db, {
  required String id,
  required String customerId,
  required String label,
  required String street,
  required String number,
  required String neighborhood,
  required String city,
  required String state,
  String? zipCode,
}) {
  return db.insert('customer_addresses', {
    'id': id,
    'customer_id': customerId,
    'label': label,
    'recipient_name': null,
    'zip_code': zipCode,
    'street': street,
    'number': number,
    'complement': null,
    'neighborhood': neighborhood,
    'city': city,
    'state': state,
    'reference_note': null,
    'is_primary': 1,
  });
}

Future<void> _contact(
  DatabaseExecutor db, {
  required String id,
  required String customerId,
  required String name,
  required String phone,
  required bool isPrimary,
  String? role,
  bool billing = false,
}) {
  return db.insert('customer_contacts', {
    'id': id,
    'customer_id': customerId,
    'name': name,
    'role': role,
    'phone': phone,
    'email': null,
    'is_primary': isPrimary ? 1 : 0,
    'can_receive_billing': billing ? 1 : 0,
    'can_receive_delivery': 0,
    'can_receive_whatsapp': 0,
  });
}
