import 'package:google_mlkit_language_id/google_mlkit_language_id.dart' as mlkit;
import 'package:turaista/core/language_id.dart';

/// Offline guest-language detection with ML Kit. The model ships in the APK,
/// so nothing is downloaded. The decision rule is [pickConfidentLanguage].
class MlKitLanguageIdentifier implements LanguageIdentifier {
  MlKitLanguageIdentifier({required this.supported});

  /// App codes the inquiry screen can use, e.g. {'en', 'ko', 'ja', 'zh'}.
  final Set<String> supported;

  // ML Kit's default threshold; pickConfidentLanguage applies stricter rules.
  final mlkit.LanguageIdentifier _identifier = mlkit.LanguageIdentifier(confidenceThreshold: 0.5);

  @override
  Future<String?> identify(String text) async {
    final cleaned = textForDetection(text);
    if (cleaned.length < 3) return null;
    final guesses = await _identifier.identifyPossibleLanguages(cleaned);
    return pickConfidentLanguage([
      for (final g in guesses) (tag: g.languageTag, confidence: g.confidence),
    ], supported);
  }

  Future<void> close() => _identifier.close();
}
