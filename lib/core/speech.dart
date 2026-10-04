/// Offline speech in and out for the face-to-face chat. Implementations live in
/// lib/services; tests use fakes. Typing always works when speech does not.
library;

abstract interface class SpeechInput {
  /// True when on-device recognition for [lang] can be used.
  Future<bool> isAvailable(String lang);

  /// Listens once and returns what was said, or null when nothing was heard.
  /// [onPartial] gets live text while the person speaks.
  Future<String?> listen(String lang, {void Function(String text)? onPartial});

  Future<void> stop();
}

abstract interface class SpeechOutput {
  /// True when an offline voice for [lang] is installed.
  Future<bool> hasVoice(String lang);

  /// Reads [text] aloud and completes when finished.
  Future<void> speak(String text, String lang);

  Future<void> stop();
}

/// Platform locale for an app language code.
const Map<String, String> speechLocales = {
  'en': 'en-US',
  'ko': 'ko-KR',
  'ja': 'ja-JP',
  'zh': 'zh-CN',
  'tl': 'fil-PH',
};
