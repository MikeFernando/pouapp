import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../domain/devices/voice_devices.dart';

/// Device speech recognition for one short phrase.
///
/// Android often uses a remote recognizer and needs internet unless a
/// Portuguese pack is installed. iOS on-device recognition fails when the
/// offline model is missing. This class does not store the audio.
class DeviceVoiceCapture implements VoiceCapture {
  final SpeechToText _speech = SpeechToText();
  var _usingDevice = true;
  var _retried = false;
  var _delivered = false;
  var _attempt = 0;
  void Function(String text, bool isFinal)? _onText;
  void Function(VoiceCaptureProblem problem)? _onProblem;

  @override
  Future<VoiceCaptureProblem?> prepare() async {
    try {
      final ready = await _speech.initialize(onError: _error, onStatus: (_) {});
      if (ready) return null;
      final allowed = await _speech.hasPermission;
      return allowed
          ? VoiceCaptureProblem.unavailable
          : VoiceCaptureProblem.permissionDenied;
    } catch (_) {
      return VoiceCaptureProblem.unavailable;
    }
  }

  @override
  Future<void> listen({
    required void Function(String text, bool isFinal) onText,
    void Function(VoiceCaptureProblem problem)? onProblem,
  }) async {
    _onText = onText;
    _onProblem = onProblem;
    _delivered = false;
    _retried = false;
    _usingDevice = true;
    _attempt = 0;
    await _start(onDevice: true);
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() async {
    _onText = null;
    _onProblem = null;
    await _speech.cancel();
  }

  Future<void> _start({required bool onDevice}) async {
    final attempt = ++_attempt;
    _usingDevice = onDevice;
    try {
      await _speech.listen(
        onResult: (result) {
          if (attempt != _attempt) return;
          final text = result.recognizedWords.trim();
          if (text.isEmpty) return;
          _delivered = result.finalResult;
          _onText?.call(text, result.finalResult);
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          onDevice: onDevice,
          listenMode: ListenMode.confirmation,
          cancelOnError: true,
          localeId: 'pt_BR',
          listenFor: const Duration(seconds: 12),
          pauseFor: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      _reject(attempt, 'error_listen_failed');
    }
  }

  void _error(SpeechRecognitionError error) {
    _reject(_attempt, error.errorMsg);
  }

  void _reject(int attempt, String code) {
    if (attempt != _attempt || (_onProblem == null && _onText == null)) {
      return;
    }
    final normalized = code.toLowerCase();
    final deviceRejected =
        _usingDevice &&
        !_delivered &&
        (normalized.contains('network') ||
            normalized.contains('language') ||
            normalized.contains('unavailable') ||
            normalized.contains('service') ||
            normalized.contains('ondevice') ||
            normalized.contains('listen_failed') ||
            normalized.contains('not supported'));
    if (deviceRejected) {
      if (_retried) return;
      _retried = true;
      _speech.cancel().whenComplete(() {
        if (_onText == null) return;
        _start(onDevice: false);
      });
      return;
    }
    if (_retried && _usingDevice) return;
    _onProblem?.call(_problem(normalized));
  }

  VoiceCaptureProblem _problem(String code) {
    if (code.contains('permission') || code.contains('denied')) {
      return VoiceCaptureProblem.permissionDenied;
    }
    if (code.contains('network') || code.contains('offline')) {
      return VoiceCaptureProblem.network;
    }
    if (code.contains('unavailable') || code.contains('service')) {
      return VoiceCaptureProblem.unavailable;
    }
    return VoiceCaptureProblem.failed;
  }
}

/// Reads the answer with the voice already installed on the phone.
/// Speaking never starts the microphone.
class DeviceVoiceSpeaker implements VoiceSpeaker {
  FlutterTts? _tts;

  Future<FlutterTts> _ready() async {
    final tts = _tts ??= FlutterTts();
    await tts.setLanguage('pt-BR');
    await tts.awaitSpeakCompletion(true);
    return tts;
  }

  @override
  Future<void> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    try {
      final tts = await _ready();
      await tts.stop();
      await tts.speak(trimmed);
    } catch (_) {
      // The written answer stays on the screen when the voice is missing.
    }
  }

  @override
  Future<void> stop() async {
    await _tts?.stop();
  }
}
