import 'package:flutter/foundation.dart';

/// The customer screen that is open in front of the voice assistant.
class VoiceVisit {
  const VoiceVisit({
    required this.customerId,
    required this.label,
    required this.onChanged,
  });

  final String customerId;
  final String label;
  final VoidCallback onChanged;
}

class VoiceAttendance {
  static final _stack = <VoiceVisit>[];

  static VoiceVisit? get current => _stack.isEmpty ? null : _stack.last;

  static void mount(VoiceVisit visit) {
    _stack.add(visit);
  }

  static void replace(VoiceVisit previous, VoiceVisit next) {
    final index = _stack.lastIndexOf(previous);
    if (index < 0) {
      _stack.add(next);
      return;
    }
    _stack[index] = next;
  }

  static void unmount(VoiceVisit visit) {
    _stack.remove(visit);
  }
}
