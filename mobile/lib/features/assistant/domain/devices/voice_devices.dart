enum VoiceCaptureProblem { permissionDenied, unavailable, network, failed }

abstract class VoiceCapture {
  /// Prepares the microphone. Does not start listening.
  Future<VoiceCaptureProblem?> prepare();

  /// Listens until [stop], [cancel], or a final transcript.
  /// Must not keep the microphone open after it returns.
  Future<void> listen({
    required void Function(String text, bool isFinal) onText,
    void Function(VoiceCaptureProblem problem)? onProblem,
  });

  Future<void> stop();

  Future<void> cancel();
}

abstract class VoiceSpeaker {
  Future<void> speak(String text);

  Future<void> stop();
}
