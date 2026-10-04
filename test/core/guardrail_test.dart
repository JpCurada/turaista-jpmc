import 'package:flutter_test/flutter_test.dart';
import 'package:turaista/core/guardrail.dart';
import 'package:turaista/core/intents.dart';

void main() {
  test('exactly DIETARY_SAFETY and OTHER are blocked', () {
    expect(blockedIntents, {GuestIntent.dietarySafety, GuestIntent.other});
    // A new intent must be decided explicitly here before this test passes.
    for (final intent in GuestIntent.values) {
      final expected = intent == GuestIntent.dietarySafety || intent == GuestIntent.other;
      expect(checkGuardrail({intent}).allowed, !expected, reason: intent.code);
    }
  });

  test('safety is blocked even when mixed with an allowed intent', () {
    final result = checkGuardrail({GuestIntent.price, GuestIntent.dietarySafety});
    expect(result.allowed, isFalse);
    expect(result.blocked, {GuestIntent.dietarySafety});
  });

  test('OTHER is blocked', () {
    expect(checkGuardrail({GuestIntent.other}).allowed, isFalse);
  });

  test('price, booking and directions are allowed', () {
    final result = checkGuardrail({GuestIntent.price, GuestIntent.booking, GuestIntent.directions});
    expect(result.allowed, isTrue);
  });
}
