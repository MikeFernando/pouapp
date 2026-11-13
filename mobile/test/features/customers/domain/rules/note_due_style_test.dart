import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/customers/domain/rules/note_due_style.dart';

void main() {
  test('noteDueIsOverdue is true only before today', () {
    final now = DateTime(2026, 11, 12, 15);
    expect(noteDueIsOverdue(null, now), isFalse);
    expect(noteDueIsOverdue(DateTime(2026, 11, 12), now), isFalse);
    expect(noteDueIsOverdue(DateTime(2026, 11, 13), now), isFalse);
    expect(noteDueIsOverdue(DateTime(2026, 11, 11), now), isTrue);
    expect(noteDueIsOverdue(DateTime(2026, 5, 1), now), isTrue);
  });
}
