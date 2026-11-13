import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../catalog/data/catalog_seed.dart';
import '../../catalog/domain/entities/catalog.dart';
import '../../customers/data/datasources/customer_local_data_source.dart';
import '../../customers/domain/entities/customer.dart';
import '../../customers/domain/entities/customer_note.dart';
import '../../customers/domain/repositories/customer_note_repository.dart';
import '../../customers/domain/repositories/customer_repository.dart';
import '../domain/entities/street_ledger.dart';
import '../domain/usecases/home_use_cases.dart';

const homeBoardDuesSeedKey = 'home_board_dues_seeded_v1';
const homeBoardDuesDedupedKey = 'home_board_dues_deduped_v1';

const _overdueCount = 20;
const _upcomingCount = 50;

/// Prevents parallel home opens from seeding the same batch multiple times.
Future<bool>? _homeSeedGate;

const _firstNames = <String>[
  'Ana',
  'Bruno',
  'Carla',
  'Diego',
  'Elisa',
  'Fábio',
  'Gisele',
  'Hugo',
  'Irene',
  'João',
  'Karen',
  'Lucas',
  'Marta',
  'Nilo',
  'Olívia',
  'Paulo',
  'Quésia',
  'Rafael',
  'Sônia',
  'Tiago',
  'Úrsula',
  'Vitor',
  'Wanda',
  'Xavier',
  'Yara',
  'Zeca',
  'Amanda',
  'Breno',
  'Cíntia',
  'Davi',
  'Elena',
  'Felipe',
  'Gabi',
  'Heitor',
  'Íris',
  'Jonas',
  'Kelly',
  'Leandro',
  'Milena',
  'Nathan',
  'Otávio',
  'Patrícia',
  'Renato',
  'Simone',
  'Tales',
  'Valéria',
  'Wagner',
  'Yasmin',
  'Álvaro',
  'Bárbara',
  'Caio',
  'Denise',
  'Eduardo',
  'Fernanda',
  'Gustavo',
  'Helena',
  'Igor',
  'Júlia',
  'Kevin',
  'Larissa',
  'Marcelo',
  'Natália',
  'Oscar',
  'Priscila',
  'Roberto',
  'Sandra',
  'Tânia',
  'Ubiratan',
  'Vera',
  'William',
];

const _lastNames = <String>[
  'Almeida',
  'Barbosa',
  'Cardoso',
  'Dias',
  'Esteves',
  'Ferreira',
  'Gomes',
  'Henrique',
  'Ibrahim',
  'Jesus',
  'Klein',
  'Lima',
  'Mendes',
  'Nogueira',
  'Oliveira',
  'Pereira',
  'Queiroz',
  'Ribeiro',
  'Santos',
  'Teixeira',
  'Uchoa',
  'Vieira',
  'Wagner',
  'Xavier',
  'Yamamoto',
  'Zanetti',
  'Araújo',
  'Borges',
  'Campos',
  'Duarte',
  'Freitas',
  'Garcia',
  'Hoffmann',
  'Ivo',
  'Junqueira',
  'Kowalski',
  'Lopes',
  'Machado',
  'Neves',
  'Ortiz',
  'Pinto',
  'Ramos',
  'Silva',
  'Tavares',
  'Vargas',
  'Werneck',
];

/// One-time seed: 20 overdue + 50 upcoming clients with full draft notes.
///
/// Also collapses duplicate seed rows from earlier parallel runs.
/// Returns `true` when the home board should reload.
Future<bool> seedHomeBoardDuesIfNeeded({
  required CustomerRepository customers,
  required CustomerLocalDataSource localCustomers,
  required CustomerNoteRepository notes,
  required SharedPreferences prefs,
  CreateHomeNote? createHomeNote,
  ClearHomeNote? clearHomeNote,
  DateTime Function()? clock,
}) {
  final running = _homeSeedGate;
  if (running != null) return running;
  final run = _runHomeBoardSeed(
    customers: customers,
    localCustomers: localCustomers,
    notes: notes,
    prefs: prefs,
    createHomeNote: createHomeNote,
    clearHomeNote: clearHomeNote,
    clock: clock,
  );
  _homeSeedGate = run;
  return run.whenComplete(() {
    if (identical(_homeSeedGate, run)) _homeSeedGate = null;
  });
}

Future<bool> _runHomeBoardSeed({
  required CustomerRepository customers,
  required CustomerLocalDataSource localCustomers,
  required CustomerNoteRepository notes,
  required SharedPreferences prefs,
  CreateHomeNote? createHomeNote,
  ClearHomeNote? clearHomeNote,
  DateTime Function()? clock,
}) async {
  final deduped = await _dedupeSeedCustomers(
    customers: customers,
    localCustomers: localCustomers,
    notes: notes,
    prefs: prefs,
    clearHomeNote: clearHomeNote,
  );
  if (prefs.getBool(homeBoardDuesSeedKey) == true) return deduped;

  final now = clock?.call() ?? DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final products = demoCatalogProducts
      .where((product) => product.salePriceCents > 0)
      .toList(growable: false);
  if (products.isEmpty) return deduped;

  final payments = PaymentMethod.values;
  var created = 0;

  for (var index = 0; index < _overdueCount; index++) {
    final dueOn = today.subtract(Duration(days: index + 1));
    final ok = await _seedOne(
      localCustomers: localCustomers,
      notes: notes,
      createHomeNote: createHomeNote,
      name: _nameAt(index),
      dueOn: dueOn,
      payment: payments[index % payments.length],
      products: products,
      salt: index,
    );
    if (ok) created++;
  }

  final lastDay = DateTime(today.year, today.month + 1, 0);
  final firstUpcoming = today.add(const Duration(days: 1));
  final upcomingSpan = lastDay.difference(firstUpcoming).inDays;
  if (upcomingSpan < 0) {
    debugPrint('home seed: no remaining days this month for upcoming dues');
  } else {
    for (var index = 0; index < _upcomingCount; index++) {
      final offset = upcomingSpan == 0 ? 0 : index % (upcomingSpan + 1);
      final dueOn = firstUpcoming.add(Duration(days: offset));
      final ok = await _seedOne(
        localCustomers: localCustomers,
        notes: notes,
        createHomeNote: createHomeNote,
        name: _nameAt(_overdueCount + index),
        dueOn: dueOn,
        payment: payments[(_overdueCount + index) % payments.length],
        products: products,
        salt: _overdueCount + index,
      );
      if (ok) created++;
    }
  }

  if (created >= _overdueCount + _upcomingCount - 5) {
    await prefs.setBool(homeBoardDuesSeedKey, true);
    debugPrint('home seed: created $created customers with notes');
    return true;
  }
  debugPrint('home seed: incomplete ($created); will retry next launch');
  return deduped;
}

Set<String> _seedNames() => {
  for (var index = 0; index < _overdueCount + _upcomingCount; index++)
    _nameAt(index),
};

/// Keeps the oldest customer per seeded name; deletes the rest.
///
/// Reads/writes SQLite only so dedupe never hangs the device offline.
Future<bool> _dedupeSeedCustomers({
  required CustomerRepository customers,
  required CustomerLocalDataSource localCustomers,
  required CustomerNoteRepository notes,
  required SharedPreferences prefs,
  ClearHomeNote? clearHomeNote,
}) async {
  if (prefs.getBool(homeBoardDuesDedupedKey) == true) return false;

  final items = await _loadAllLocalCustomers(localCustomers);
  if (items.isEmpty) {
    await prefs.setBool(homeBoardDuesDedupedKey, true);
    return false;
  }

  final seedNames = _seedNames();
  final byName = <String, List<Customer>>{};
  for (final customer in items) {
    if (!seedNames.contains(customer.name)) continue;
    byName.putIfAbsent(customer.name, () => <Customer>[]).add(customer);
  }

  var removed = 0;
  for (final group in byName.values) {
    if (group.length <= 1) continue;
    group.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (final extra in group.skip(1)) {
      // Best-effort remote cleanup — never block on network.
      if (clearHomeNote != null) {
        unawaited(clearHomeNote(customerId: extra.id));
      }
      final draft = await notes.currentNote(extra.id);
      final note = draft.fold<CustomerNote?>((_) => null, (value) => value);
      if (note != null && note.status == NoteStatus.draft) {
        await notes.deleteNote(note.id);
      }
      await localCustomers.deleteCustomer(extra.id);
      unawaited(customers.deleteCustomer(extra.id));
      removed++;
    }
  }

  await prefs.setBool(homeBoardDuesDedupedKey, true);
  debugPrint('home seed: removed $removed duplicate customers');
  return removed > 0;
}

Future<List<Customer>> _loadAllLocalCustomers(
  CustomerLocalDataSource localCustomers,
) async {
  const pageSize = 100;
  final all = <Customer>[];
  var page = 0;
  while (true) {
    final batch = await localCustomers.getCustomers(
      CustomerQuery(page: page, pageSize: pageSize),
    );
    all.addAll(batch.items);
    if (!batch.hasMore || batch.items.isEmpty) break;
    page++;
  }
  return all;
}

String _nameAt(int index) {
  final first = _firstNames[index % _firstNames.length];
  final last = _lastNames[(index * 3) % _lastNames.length];
  return '$first $last';
}

Future<bool> _seedOne({
  required CustomerLocalDataSource localCustomers,
  required CustomerNoteRepository notes,
  required CreateHomeNote? createHomeNote,
  required String name,
  required DateTime dueOn,
  required PaymentMethod payment,
  required List<DemoCatalogProduct> products,
  required int salt,
}) async {
  try {
    // Local SQLite only — home must work in neighborhoods without signal.
    final customer = await localCustomers.createCustomer(
      CustomerInput(
        type: CustomerType.individual,
        name: name,
        mobilePhone: _phone(salt),
        notes: 'Cliente de demonstração da home.',
      ),
    );

    final draft = await notes.activeDraft(customer.id);
    final note = draft.fold<CustomerNote?>((_) => null, (value) => value);
    if (note == null) return false;

    final lines = _linesFor(products, salt);
    final withLines = await notes.saveLines(noteId: note.id, lines: lines);
    final savedLines = withLines.fold<CustomerNote?>(
      (_) => null,
      (value) => value,
    );
    if (savedLines == null) return false;

    final withDue = await notes.setDueOn(noteId: note.id, dueOn: dueOn);
    final savedDue = withDue.fold<CustomerNote?>(
      (_) => null,
      (value) => value,
    );
    if (savedDue == null) return false;

    final withPay = await notes.setPaymentMethod(
      noteId: note.id,
      paymentMethod: payment,
    );
    final saved = withPay.fold<CustomerNote?>(
      (_) => null,
      (value) => value,
    );
    if (saved == null || saved.totalCents <= 0 || saved.dueOn == null) {
      return false;
    }

    if (createHomeNote != null) {
      unawaited(
        createHomeNote(
          customerId: customer.id,
          dueOn: isoDate(saved.dueOn!),
          totalCents: saved.totalCents,
        ),
      );
    }
    return true;
  } catch (error, stack) {
    debugPrint('home seed item failed: $error\n$stack');
    return false;
  }
}

List<NoteLineDraft> _linesFor(List<DemoCatalogProduct> products, int salt) {
  final count = 2 + (salt % 3);
  final lines = <NoteLineDraft>[];
  for (var i = 0; i < count; i++) {
    final product = products[(salt + i * 5) % products.length];
    lines.add(
      NoteLineDraft(
        productId: product.id,
        name: product.name,
        unit: product.unit,
        quantity: _qty(product.unit, salt + i),
        unitPriceCents: product.salePriceCents,
        referencePriceCents: product.salePriceCents,
      ),
    );
  }
  return lines;
}

int _qty(CatalogUnit unit, int salt) {
  switch (unit) {
    case CatalogUnit.kilogram:
      return 1000 + (salt % 4) * 500;
    case CatalogUnit.dozen:
      return 1 + (salt % 2);
    case CatalogUnit.box:
      return 1 + (salt % 2);
    case CatalogUnit.bunch:
    case CatalogUnit.piece:
      return 1 + (salt % 4);
  }
}

String _phone(int salt) {
  final suffix = (90000000 + (salt * 137) % 9999999).toString().padLeft(8, '0');
  return '11$suffix';
}
