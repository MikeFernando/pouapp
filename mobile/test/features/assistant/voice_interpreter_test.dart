import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/assistant/domain/entities/voice_command.dart';
import 'package:pouapp/features/assistant/domain/rules/voice_dates.dart';
import 'package:pouapp/features/assistant/domain/rules/voice_interpreter.dart';

void main() {
  test('reads an add command and a debt question', () {
    final add = interpretVoice('Adicione um quilo de abacaxi para Adriele JP.');
    expect(add.intent, VoiceIntent.addDraftItem);
    expect(add.productQuery, 'abacaxi');
    expect(add.customerQuery, 'adriele jp');
    expect(add.quantity, 1);
    expect(add.unit, VoiceUnit.kilogram);

    final debt = interpretVoice('Quanto a Maria MT me deve?');
    expect(debt.intent, VoiceIntent.consultAccount);
    expect(debt.customerQuery, 'maria mt');
  });

  test('a payment phrase is unsupported and has no fields to run', () {
    final command = interpretVoice('Receba 50 reais da Maria');
    expect(command.intent, VoiceIntent.unsupported);
    expect(command.customerQuery, isNull);
    expect(command.productQuery, isNull);
  });

  test('a spoken price is a new line and a change edits the draft', () {
    final add = interpretVoice('Cliente Adriele, melancia quinze reais.');
    expect(add.intent, VoiceIntent.addDraftItem);
    expect(add.priceCents, 1500);
    expect(add.priceBasis, isNull);
    expect(add.looseText, 'adriele melancia');
    expect(add.quantity, isNull);

    final change = interpretVoice('Mude a melancia para quinze reais');
    expect(change.intent, VoiceIntent.repriceDraftItem);
    expect(change.priceCents, 1500);
    expect(change.looseText, 'melancia');
  });

  test('nesse cliente keeps the product for the open note', () {
    final add = interpretVoice('Adicione um quilo de batata nesse cliente');
    expect(add.intent, VoiceIntent.addDraftItem);
    expect(add.productQuery, 'batata');
    expect(add.customerQuery, isNull);
    expect(add.quantity, 1);
    expect(add.unit, VoiceUnit.kilogram);
  });

  test('e adicione keeps two products for the open customer', () {
    final add = interpretVoice(
      'E adicione um quilo de alho e um quilo de batata',
    );
    expect(add.intent, VoiceIntent.addDraftItem);
    expect(add.customerQuery, isNull);
    expect(add.items, hasLength(2));
    expect(add.items[0].productQuery, 'alho');
    expect(add.items[0].quantity, 1);
    expect(add.items[0].unit, VoiceUnit.kilogram);
    expect(add.items[1].productQuery, 'batata');
    expect(add.items[1].quantity, 1);
    expect(add.items[1].unit, VoiceUnit.kilogram);
  });

  test('connectives and a count without a unit stay in one command', () {
    final also = interpretVoice('Coloca também um quilo de alho');
    expect(also.intent, VoiceIntent.addDraftItem);
    expect(also.productQuery, 'alho');
    expect(also.quantity, 1);

    final more = interpretVoice('Mais um quilo de batata');
    expect(more.productQuery, 'batata');
    expect(more.unit, VoiceUnit.kilogram);

    final him = interpretVoice('Adicione um quilo de alho para ele');
    expect(him.customerQuery, isNull);
    expect(him.productQuery, 'alho');

    final mixed = interpretVoice('Um quilo de alho e duas batatas');
    expect(mixed.items, hasLength(2));
    expect(mixed.items[0].unit, VoiceUnit.kilogram);
    expect(mixed.items[1].productQuery, 'batata');
    expect(mixed.items[1].quantity, 2);
    expect(mixed.items[1].unit, isNull);
  });

  test('a short reply completes the pending item', () {
    final pending = continueVoiceCommand(
      const VoiceCommand(
        intent: VoiceIntent.addDraftItem,
        transcript: 'Um quilo de alho e duas batatas',
        items: [
          VoiceItem(
            productQuery: 'Alho',
            productId: 'alho',
            quantity: 1,
            unit: VoiceUnit.kilogram,
          ),
          VoiceItem(
            productQuery: 'Batata',
            productId: 'batata',
            quantity: 2,
            gap: VoiceGap.unit,
          ),
        ],
        gap: VoiceGap.unit,
      ),
      'dois quilos',
    );
    expect(pending.items.first.productId, 'alho');
    expect(pending.items.last.quantity, 2);
    expect(pending.items.last.unit, VoiceUnit.kilogram);
    expect(pending.items.last.gap, VoiceGap.none);
  });

  test('due dates and payments keep the open customer', () {
    final day = interpretVoice('Ela paga dia quinze.');
    expect(day.intent, VoiceIntent.setDueDate);
    final dated = interpretVoice('Ela paga dia quinze de novembro.');
    expect(dated.intent, VoiceIntent.setDueDate);
    final ahead = interpretVoice('Para daqui a trinta dias.');
    expect(ahead.intent, VoiceIntent.setDueDate);
    final changed = interpretVoice('Mude o vencimento para vinte de novembro.');
    expect(changed.intent, VoiceIntent.setDueDate);

    final credit = interpretVoice('Vai ficar fiado.');
    expect(credit.settlement, 'fiado');
    final cash = interpretVoice('Pagou tudo em dinheiro.');
    expect(cash.settlement, 'cash');
    expect(cash.payAll, isTrue);
    final partial = interpretVoice('Recebi vinte reais em dinheiro.');
    expect(partial.priceCents, 2000);
    expect(partial.settlement, 'cash');
    final pix = interpretVoice('Conferi o Pix de vinte reais.');
    expect(pix.settlement, 'pix');
    expect(pix.priceCents, 2000);
    final promised = interpretVoice('Vou mandar o Pix.');
    expect(promised.settlement, 'promised');

    final today = DateTime(2026, 11, 4);
    final next = resolveSpokenDate(readSpokenDate('dia quinze')!, today);
    expect(next.date, DateTime(2026, 11, 15));
    final passed = resolveSpokenDate(
      readSpokenDate('vinte de novembro')!,
      DateTime(2026, 12, 1),
    );
    expect(passed.date, isNull);
    expect(passed.question, contains('já passou'));
    expect(passed.alternative, DateTime(2027, 11, 20));
  });

  test('an unclear phrase asks instead of guessing', () {
    final command = interpretVoice('Olá');
    expect(command.intent, VoiceIntent.unclear);
    expect(command.reply, contains('nota'));
  });
}
