import 'package:flutter_test/flutter_test.dart';
import 'package:turaista/core/conversation.dart';
import 'package:turaista/core/guardrail.dart';
import 'package:turaista/core/translator.dart';

import '../fakes.dart';
import '../helpers.dart';

void main() {
  final profile = loadExampleProfile();
  const korean = TravelerCard(language: 'ko', partySize: 4);

  test('an allowed question gets a grounded answer first, in the guest language', () async {
    final turn = await handleGuestTurn(
      message: 'How much is the tour?',
      traveler: korean,
      profile: profile,
      translator: const TaggingTranslator(),
    );
    expect(turn.guardrail.allowed, isTrue);
    final answer = turn.suggestions.first;
    expect(answer.kind, SuggestionKind.answer);
    expect(answer.english, contains('PHP 350'));
    expect(answer.forGuest, startsWith('[ko] '));
    expect(answer.factsUsed, contains('base_price_php'));
    expect(turn.hostTranslation.text, '[tl] How much is the tour?');
  });

  test('a blocked question only offers the holding reply, never an answer', () async {
    final turn = await handleGuestTurn(
      message: 'Is the lunch safe for my peanut allergy?',
      traveler: korean,
      profile: profile,
      translator: const TaggingTranslator(),
    );
    expect(turn.guardrail.allowed, isFalse);
    expect(turn.suggestions.map((s) => s.kind), isNot(contains(SuggestionKind.answer)));
    expect(turn.suggestions.first.english, guestHoldingReply);
  });

  test('the party size from the traveler card is checked against the profile', () async {
    Future<String> bookingFor(int? size) async =>
        (await handleGuestTurn(
          message: 'Can we book for Saturday?',
          traveler: TravelerCard(language: 'en', partySize: size),
          profile: profile,
        )).suggestions.first.english;

    expect(await bookingFor(4), contains('A group of 4 is within this limit'));
    expect(await bookingFor(0), contains('number of guests'), reason: 'invalid size ignored');
    expect(await bookingFor(profile.maxGroupSize + 3), contains('please talk with us first'));
    expect(await bookingFor(null), contains('number of guests'));
  });

  test('a changed number in a suggestion falls back to English', () async {
    final turn = await handleGuestTurn(
      message: 'How much is the tour?',
      traveler: korean,
      profile: profile,
      translator: const NumberChangingTranslator(),
    );
    final answer = turn.suggestions.first;
    expect(answer.translation, TranslationOutcome.numbersChanged);
    expect(answer.forGuest, answer.english);
  });

  group('host turn', () {
    test('is translated for the guest', () async {
      final turn = await handleHostTurn(
        text: 'Opo, pwede po.',
        traveler: korean,
        profile: profile,
        translator: const TaggingTranslator(),
      );
      expect(turn.forGuest, '[ko] Opo, pwede po.');
    });

    test('is not spoken when a number changed or no model is ready', () async {
      for (final t in [const NumberChangingTranslator(), const UnavailableTranslator()]) {
        final turn = await handleHostTurn(
          text: '350 po bawat tao.',
          traveler: korean,
          profile: profile,
          translator: t,
        );
        expect(turn.forGuest, isNull);
      }
    });
  });

  test('care needs are recorded only when the guest picks them', () {
    expect(korean.hasCareNeeds, isFalse);
    expect(const TravelerCard(language: 'ja', needs: {TravelerNeed.food}).hasCareNeeds, isTrue);
  });
}
