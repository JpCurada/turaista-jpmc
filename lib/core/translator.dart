/// Offline translation interface.
///
/// MVP backend: Google ML Kit on-device translation for guest languages
/// (en, ko, ja, zh). Stretch: NLLB-200 ONNX for Cebuano/Ilocano.
/// See .claude/skills/offline-translation.
library;

abstract interface class Translator {
  /// [from] and [to] are BCP-47 codes, e.g. 'en', 'ko', 'tl'.
  Future<String> translate(String text, {required String from, required String to});
}

/// Model-free backend for tests and demos: it cannot translate, so any real
/// language change is reported as unavailable and the reply stays English.
class IdentityTranslator implements Translator {
  const IdentityTranslator();

  @override
  Future<String> translate(String text, {required String from, required String to}) async {
    if (from == to) return text;
    throw TranslationUnavailable('IdentityTranslator cannot translate $from to $to');
  }
}

/// Thrown when text cannot be translated on this phone yet, e.g. the language
/// model is not downloaded or the language is not supported offline.
class TranslationUnavailable implements Exception {
  const TranslationUnavailable(this.message);

  final String message;

  @override
  String toString() => 'TranslationUnavailable: $message';
}

/// What happened when the English reply was put into the guest's language.
enum TranslationOutcome {
  /// The guest reads English; nothing to translate.
  notNeeded,

  /// Translated, and every number matches the English draft.
  translated,

  /// The translation changed, dropped or added a number. English is used instead.
  numbersChanged,

  /// No offline model for this language yet. English is used instead.
  unavailable,
}

/// Offline language models: check and download, Wi-Fi only.
abstract interface class LanguageModels {
  Future<bool> isDownloaded(String lang);

  /// Downloads the model for [lang] over Wi-Fi only. Throws when it fails.
  Future<void> download(String lang);
}
