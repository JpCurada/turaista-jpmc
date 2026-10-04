import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:turaista/core/speech.dart';

String _locale(String lang) => speechLocales[lang] ?? lang;

/// Android's on-device speech recognizer. Offline only works for languages
/// whose offline pack is installed on the phone; check [isAvailable].
class DeviceSpeechInput implements SpeechInput {
  final SpeechToText _stt = SpeechToText();
  bool _ready = false;
  Completer<String?>? _active;
  String _lastWords = '';

  /// Only a successful start is remembered, so a later try (for example after
  /// the microphone permission is granted) can work.
  Future<bool> _init() async {
    if (_ready) return true;
    try {
      _ready = await _stt.initialize(
        onError: (_) => _finish(),
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') _finish();
        },
      );
    } on Object {
      _ready = false;
    }
    return _ready;
  }

  /// Ends the current listen with what was heard so far, or null.
  void _finish() {
    final active = _active;
    if (active == null || active.isCompleted) return;
    final words = _lastWords.trim();
    active.complete(words.isEmpty ? null : words);
  }

  @override
  Future<bool> isAvailable(String lang) async {
    if (!await _init()) return false;
    final want = _locale(lang).replaceAll('-', '_').toLowerCase();
    final locales = await _stt.locales();
    return locales.any((l) => l.localeId.replaceAll('-', '_').toLowerCase() == want);
  }

  @override
  Future<String?> listen(String lang, {void Function(String text)? onPartial}) async {
    if (!await _init()) return null;
    final done = _active = Completer<String?>();
    _lastWords = '';
    await _stt.listen(
      listenOptions: SpeechListenOptions(
        localeId: _locale(lang).replaceAll('-', '_'),
        onDevice: true,
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
      onResult: (r) {
        _lastWords = r.recognizedWords;
        onPartial?.call(r.recognizedWords);
        if (r.finalResult && !done.isCompleted) {
          done.complete(r.recognizedWords.trim().isEmpty ? null : r.recognizedWords);
        }
      },
    );
    return done.future
        .timeout(const Duration(seconds: 30), onTimeout: () => null)
        .whenComplete(() => _active = null);
  }

  @override
  Future<void> stop() => _stt.stop();
}

/// Android text-to-speech with installed (offline) voices only.
class DeviceSpeechOutput implements SpeechOutput {
  DeviceSpeechOutput() {
    unawaited(_tts.awaitSpeakCompletion(true));
  }

  final FlutterTts _tts = FlutterTts();

  @override
  Future<bool> hasVoice(String lang) async {
    final installed = await _tts.isLanguageInstalled(_locale(lang));
    return installed == true;
  }

  /// Throws when the voice cannot be set, so the screen shows "not spoken".
  @override
  Future<void> speak(String text, String lang) async {
    final set = await _tts.setLanguage(_locale(lang));
    if (set != 1) throw StateError('Voice for "$lang" could not be set');
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }
}
