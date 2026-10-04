/// Language names and offline guest-language detection rules.
/// The host can always override a detected language.
library;

/// How every screen names a language: the name the host can read first, then
/// the guest's own script so it can be matched against the message.
const Map<String, String> languageLabels = {
  'en': 'English',
  'tl': 'Tagalog',
  'ko': 'Korean (한국어)',
  'ja': 'Japanese (日本語)',
  'zh': 'Chinese (中文)',
};

/// Guest languages offered in the MVP (all covered by ML Kit offline translation).
const List<String> guestLanguageCodes = ['en', 'ko', 'ja', 'zh'];

abstract interface class LanguageIdentifier {
  /// The app language code of [text] (e.g. 'ko'), or null when unsure.
  Future<String?> identify(String text);
}

/// One guess from a language detector: a BCP-47 tag and its confidence (0-1).
typedef LanguageGuess = ({String tag, double confidence});

final RegExp _urls = RegExp(r'https?://\S+|www\.\S+');

/// [text] without links, which say nothing about the guest's language.
String textForDetection(String text) => text.replaceAll(_urls, ' ').trim();

/// The guessed language only when the detector is clearly sure: the top guess
/// is one of [supported], reaches [minConfidence] and beats the runner-up by
/// [minMargin]. Otherwise null, and the host picks.
///
/// Tags like 'ja-Latn' (romanized) or 'und' (undetermined) are never in
/// [supported], so they count as unsure.
String? pickConfidentLanguage(
  List<LanguageGuess> guesses,
  Set<String> supported, {
  double minConfidence = 0.7,
  double minMargin = 0.2,
}) {
  if (guesses.isEmpty) return null;
  final ranked = [...guesses]..sort((a, b) => b.confidence.compareTo(a.confidence));
  final top = ranked.first;
  final runnerUp = ranked.length > 1 ? ranked[1].confidence : 0.0;
  if (!supported.contains(top.tag)) return null;
  if (top.confidence < minConfidence || top.confidence - runnerUp < minMargin) return null;
  return top.tag;
}
