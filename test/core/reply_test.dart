import 'package:flutter_test/flutter_test.dart';
import 'package:turaista/core/intents.dart';
import 'package:turaista/core/reply.dart';

import '../helpers.dart';

void main() {
  final profile = loadExampleProfile();

  test('every number in a draft comes from the profile', () {
    final draft = draftReply({GuestIntent.price, GuestIntent.booking}, profile);
    final allowed = {
      profile.basePricePhp,
      profile.maxGroupSize,
      for (final a in profile.activities) a.pricePhp,
    };
    final numbers =
        RegExp(
          r'\d[\d,]*',
        ).allMatches(draft.text).map((m) => int.parse(m.group(0)!.replaceAll(',', ''))).toSet();
    expect(numbers.difference(allowed), isEmpty, reason: 'invented numbers in:\n${draft.text}');
  });

  test('facts are traceable to profile fields', () {
    final draft = draftReply({GuestIntent.price}, profile);
    expect(draft.factsUsed, contains('base_price_php'));
  });

  test('formatPhp groups thousands', () {
    expect(formatPhp(1200), 'PHP 1,200');
    expect(formatPhp(350), 'PHP 350');
  });
}
