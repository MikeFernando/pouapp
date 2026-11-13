/// Whether [dueOn] is before the local calendar day of [now].
bool noteDueIsOverdue(DateTime? dueOn, [DateTime? now]) {
  if (dueOn == null) return false;
  final clock = now ?? DateTime.now();
  final today = DateTime(clock.year, clock.month, clock.day);
  final due = DateTime(dueOn.year, dueOn.month, dueOn.day);
  return due.isBefore(today);
}
