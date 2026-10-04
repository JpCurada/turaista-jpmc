import 'package:flutter_test/flutter_test.dart';
import 'package:turaista/core/onboarding.dart';
import 'package:turaista/core/profile.dart';

import '../helpers.dart';

void main() {
  final profile = loadExampleProfile();

  group('parseWholeNumber', () {
    test('accepts plain, grouped and peso-marked numbers', () {
      expect(parseWholeNumber('350'), 350);
      expect(parseWholeNumber(' 1,200 '), 1200);
      expect(parseWholeNumber('PHP 350'), 350);
      expect(parseWholeNumber('₱350'), 350);
    });

    test('rejects decimals, negatives and words', () {
      expect(parseWholeNumber('350.50'), isNull);
      expect(parseWholeNumber('-5'), isNull);
      expect(parseWholeNumber('tatlong daan'), isNull);
      expect(parseWholeNumber(''), isNull);
    });
  });

  test('validators block empty and invalid answers', () {
    expect(validateRequired('  '), isNotNull);
    expect(validateRequired('Lorna'), isNull);
    expect(validatePrice('0'), isNull);
    expect(validatePrice('abc'), isNotNull);
    expect(validatePositive('0'), isNotNull);
    expect(validatePositive('12'), isNull);
    expect(validateOptionalPositive(''), isNull);
    expect(validateOptionalPositive('0'), isNotNull);
  });

  test('read-back covers every fact in the profile', () {
    final items = readBackItems(profile);
    final questions = items.map((i) => i.question).join('\n');
    expect(questions, contains('Tama po ba na PHP 350 bawat tao?'));
    expect(questions, contains('Manang Lorna'));
    expect(questions, contains(profile.farmName));
    expect(questions, contains(profile.locationHint));
    expect(questions, contains('${profile.maxGroupSize} bisita'));
    for (final a in profile.activities) {
      expect(questions, contains(a.name));
    }
    for (final rule in profile.safetyRules) {
      expect(questions, contains(rule));
    }
    expect(items.map((i) => i.key).toSet(), hasLength(items.length));
  });

  test('validators speak with "po" only when the host chose it', () {
    expect(validateRequired('', usePo: true), contains(' po '));
    expect(validateRequired(''), isNot(contains(' po ')));
    expect(validatePrice('abc', usePo: true), contains(' po'));
    expect(validatePrice('abc'), isNot(contains(' po')));
  });

  test('read-back drops "po" when the host does not want it', () {
    const noPo = FarmProfile(
      farmName: 'Farm',
      locationHint: 'From the church',
      host: HostPreferences(preferredAddress: 'Ben', language: 'tl', usePo: false),
      basePricePhp: 100,
      maxGroupSize: 5,
    );
    final items = readBackItems(noPo);
    expect(items.every((i) => !i.question.contains('po ba')), isTrue);
    // Empty lists are still read back, so the host confirms there are none.
    expect(items.map((i) => i.key), containsAll(['activities-none', 'rules-none']));
  });

  test('profile JSON round-trips', () {
    final again = FarmProfile.fromJsonString(profile.toJsonString());
    expect(again.toJson(), profile.toJson());
  });
}
