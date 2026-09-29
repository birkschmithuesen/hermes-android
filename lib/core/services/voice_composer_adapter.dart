import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

typedef VoiceStatusCallback = void Function(String status);
typedef VoiceErrorCallback = void Function(String message);
typedef VoiceResultCallback =
    void Function({required String transcript, required bool isFinal});

/// Injectable boundary around speech recognition.
///
/// The composer controller depends only on this contract, so widget and unit
/// tests never initialize the microphone or a platform plugin.
abstract interface class VoiceComposerAdapter {
  Future<bool> get hasPermission;

  Future<bool> initialize({
    required VoiceStatusCallback onStatus,
    required VoiceErrorCallback onError,
  });

  Future<void> listen({
    required VoiceResultCallback onResult,
    String? localeId,
  });

  Future<void> stop();

  Future<void> cancel();

  void dispose();
}

class SpeechToTextVoiceComposerAdapter implements VoiceComposerAdapter {
  final SpeechToText _speechToText;

  SpeechToTextVoiceComposerAdapter({SpeechToText? speechToText})
    : _speechToText = speechToText ?? SpeechToText();

  @override
  Future<bool> get hasPermission => _speechToText.hasPermission;

  @override
  Future<bool> initialize({
    required VoiceStatusCallback onStatus,
    required VoiceErrorCallback onError,
  }) {
    return _speechToText.initialize(
      onStatus: onStatus,
      onError: (SpeechRecognitionError error) => onError(error.errorMsg),
    );
  }

  @override
  Future<void> listen({
    required VoiceResultCallback onResult,
    String? localeId,
  }) async {
    await _speechToText.listen(
      listenOptions: SpeechListenOptions(
        // No pauseFor: speech_to_text's pause timer only counts *changed*
        // results, so with recognizers that deliver no partial results
        // (offline/on-device engines) it ended every dictation 3 s after
        // start. End-of-utterance is left to the recognizer's own VAD;
        // listenFor stays as a hard cap.
        listenFor: const Duration(seconds: 60),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        localeId: localeId,
      ),
      onResult: (SpeechRecognitionResult result) => onResult(
        transcript: result.recognizedWords,
        isFinal: result.finalResult,
      ),
    );
  }

  @override
  Future<void> stop() => _speechToText.stop();

  @override
  Future<void> cancel() => _speechToText.cancel();

  @override
  void dispose() {
    unawaited(_speechToText.cancel());
  }
}
