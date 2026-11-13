import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/workspace/data/day_checklist_store.dart';
import 'package:pouapp/features/workspace/domain/rules/month_board.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('persists and restores served ids for the day', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = DayChecklistStore(sharedPreferences: prefs);
    final day = DateTime(2026, 11, 12);

    expect(store.loadServed(day), isEmpty);

    await store.saveServed(day, {'c1', 'c2'});
    expect(store.loadServed(day), {'c1', 'c2'});

    await store.saveServed(day, {});
    expect(store.loadServed(day), isEmpty);
  });

  test('persists frozen checklist values after note deletion', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = DayChecklistStore(sharedPreferences: prefs);
    final day = DateTime(2026, 11, 12);

    await store.saveFrozen(day, {
      'c1': const DayChecklistFrozen(
        receivedCents: 2500,
        productCents: {'Alho 1 kg': 2500},
      ),
    });
    final frozen = store.loadFrozen(day);
    expect(frozen['c1']?.receivedCents, 2500);
    expect(frozen['c1']?.productCents['Alho 1 kg'], 2500);

    await store.saveFrozen(day, {});
    expect(store.loadFrozen(day), isEmpty);
  });

  test('committed receipts sum the same product from two notes', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = DayChecklistStore(sharedPreferences: prefs);

    await store.commitReceipt(
      noteId: 'note-a',
      entry: const DayChecklistFrozen(
        receivedCents: 890,
        productCents: {'Abacate': 890},
      ),
    );
    await store.commitReceipt(
      noteId: 'note-b',
      entry: const DayChecklistFrozen(
        receivedCents: 890,
        productCents: {'Abacate': 890},
      ),
    );

    final total = store.committedTotal();
    expect(total.receivedCents, 1780);
    expect(total.productCents['Abacate'], 1780);
  });
}
