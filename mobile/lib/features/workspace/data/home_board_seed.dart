import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../catalog/data/catalog_seed.dart';
import '../../catalog/domain/entities/catalog.dart';
import '../../customers/domain/entities/customer.dart';
import '../../customers/domain/entities/customer_note.dart';
import '../../customers/domain/repositories/customer_note_repository.dart';
import '../../customers/domain/repositories/customer_repository.dart';
import '../domain/entities/street_ledger.dart';
import '../domain/usecases/home_use_cases.dart';

const homeBoardDuesSeedKey = 'home_board_dues_seeded_v1';

const _overdueCount = 20;
const _upcomingCount = 50;

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
/// Runs on TestFlight/release too so the downloaded build shows Em atrasos
/// and Próximos vencimentos with products, due dates and payment methods.
/// Returns `true` when this call created the seed batch.
Future<bool> seedHomeBoardDuesIfNeeded({
  required CustomerRepository customers,
  required CustomerNoteRepository notes,
  required SharedPreferences prefs,
  CreateHomeNote? createHomeNote,
  DateTime Function()? clock,
}) async {
  if (prefs.getBool(homeBoardDuesSeedKey) == true) return false;

  final now = clock?.call() ?? DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final products = demoCatalogProducts
      .where((product) => product.salePriceCents > 0)
      .toList(growable: false);
  if (products.isEmpty) return false;

  final payments = PaymentMethod.values;
  var created = 0;

  for (var index = 0; index < _overdueCount; index++) {
    final dueOn = today.subtract(Duration(days: index + 1));
    final ok = await _seedOne(
      customers: customers,
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
        customers: customers,
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
  return false;
}

String _nameAt(int index) {
  final first = _firstNames[index % _firstNames.length];
  final last = _lastNames[(index * 3) % _lastNames.length];
  return '$first $last';
}

Future<bool> _seedOne({
  required CustomerRepository customers,
  required CustomerNoteRepository notes,
  required CreateHomeNote? createHomeNote,
  required String name,
  required DateTime dueOn,
  required PaymentMethod payment,
  required List<DemoCatalogProduct> products,
  required int salt,
}) async {
  try {
    final created = await customers.createCustomer(
      CustomerInput(
        type: CustomerType.individual,
        name: name,
        mobilePhone: _phone(salt),
        notes: 'Cliente de demonstração da home.',
      ),
    );
    final customer = created.fold<Customer?>((_) => null, (value) => value);
    if (customer == null) return false;

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
      await createHomeNote(
        customerId: customer.id,
        dueOn: isoDate(saved.dueOn!),
        totalCents: saved.totalCents,
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
