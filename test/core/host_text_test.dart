import 'package:flutter_test/flutter_test.dart';
import 'package:turaista/core/host_text.dart';
import 'package:turaista/core/profile.dart';
import 'package:turaista/core/translator.dart';

void main() {
  const withPo = HostPreferences(preferredAddress: 'Manang Lorna', language: 'tl');
  const plain = HostPreferences(preferredAddress: 'Ben', language: 'tl', usePo: false);

  test('no notice when the reply is in the guest language', () {
    expect(translationNotice(TranslationOutcome.translated, withPo), isNull);
    expect(translationNotice(TranslationOutcome.notNeeded, withPo), isNull);
  });

  test('English fallback is explained, with "po" only when the host chose it', () {
    for (final outcome in [TranslationOutcome.numbersChanged, TranslationOutcome.unavailable]) {
      expect(translationNotice(outcome, withPo), allOf(contains('English'), contains(' po')));
      expect(translationNotice(outcome, plain), isNot(contains(' po')));
    }
  });
}
