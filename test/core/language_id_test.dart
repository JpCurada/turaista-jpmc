import 'package:flutter_test/flutter_test.dart';
import 'package:turaista/core/language_id.dart';

void main() {
  const supported = {'en', 'ko', 'ja', 'zh'};

  test('a clear, supported top guess is picked', () {
    expect(pickConfidentLanguage([(tag: 'ko', confidence: 0.95)], supported), 'ko');
    expect(
      pickConfidentLanguage([
        (tag: 'en', confidence: 0.1),
        (tag: 'ja', confidence: 0.85),
      ], supported),
      'ja',
      reason: 'guesses are ranked, not taken in order',
    );
  });

  test('low confidence or a close runner-up is unsure', () {
    expect(pickConfidentLanguage([(tag: 'en', confidence: 0.6)], supported), isNull);
    expect(
      pickConfidentLanguage([
        (tag: 'en', confidence: 0.75),
        (tag: 'tl', confidence: 0.6),
      ], supported),
      isNull,
      reason: 'Taglish: English barely ahead of Tagalog',
    );
  });

  test('unsupported, romanized or undetermined tags are unsure', () {
    for (final tag in ['tl', 'ceb', 'ja-Latn', 'zh-Latn', 'und', 'fr']) {
      expect(pickConfidentLanguage([(tag: tag, confidence: 0.99)], supported), isNull, reason: tag);
    }
    expect(pickConfidentLanguage([], supported), isNull);
  });

  test('links are removed before detection', () {
    expect(textForDetection('See https://example.com/tour and www.x.ph ok'), 'See   and   ok');
    expect(textForDetection('  https://example.com  '), isEmpty);
  });

  test('every guest language has a label the host can read', () {
    for (final lang in guestLanguageCodes) {
      expect(languageLabels[lang], matches(RegExp('^[A-Z][a-z]+')), reason: lang);
    }
  });
}
