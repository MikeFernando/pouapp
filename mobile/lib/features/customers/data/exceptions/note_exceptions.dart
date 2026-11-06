class NoteRuleException implements Exception {
  const NoteRuleException(this.message);

  final String message;
}

class NoteNotFoundException implements Exception {
  const NoteNotFoundException();
}
