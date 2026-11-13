import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/workspace/data/day_checklist_store.dart';
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
}
