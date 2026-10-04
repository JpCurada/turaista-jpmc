import 'package:flutter_test/flutter_test.dart';
import 'package:turaista/core/conversation.dart';
import 'package:turaista/core/host_meaning.dart';
import 'package:turaista/core/host_text.dart';
import 'package:turaista/core/intents.dart';
import 'package:turaista/core/number_check.dart';
import 'package:turaista/core/profile.dart';
import 'package:turaista/core/reply.dart';

import '../fakes.dart';
import '../helpers.dart';

void main() {
  final profile = loadExampleProfile();
  const allowed = [GuestIntent.price, GuestIntent.booking, GuestIntent.directions];

  test('the Tagalog meaning states exactly the numbers of the English draft', () {
    for (var mask = 1; mask < 8; mask++) {
      final intents = {
        for (var i = 0; i < allowed.length; i++)
          if (mask & (1 << i) != 0) allowed[i],
      };
      for (final size in [null, 0, 4, profile.maxGroupSize + 5]) {
        final english = draftReply(intents, profile, partySize: size).text;
        final tagalog = draftMeaningForHost(intents, profile, partySize: size)!;
        expect(numbersMatch(english, tagalog), isTrue, reason: '$intents, size $size');
      }
    }
  });

  test('the Tagalog meaning names the same activities and inclusions as the English', () {
    final intents = {GuestIntent.price};
    final english = draftReply(intents, profile).text;
    final tagalog = draftMeaningForHost(intents, profile)!;
    for (final a in profile.activities) {
      expect(tagalog, contains(a.name));
    }
    expect('kasama na'.allMatches(tagalog).length, 'included'.allMatches(english).length);
  });

  test('no Tagalog templates for other host languages yet', () {
    final cebuano = FarmProfile(
      farmName: profile.farmName,
      locationHint: profile.locationHint,
      host: const HostPreferences(preferredAddress: 'Nang Inday', language: 'ceb'),
      basePricePhp: profile.basePricePhp,
      maxGroupSize: profile.maxGroupSize,
    );
    expect(draftMeaningForHost({GuestIntent.price}, cebuano), isNull);
  });

  test('a host without templates reads the English, never an empty tile', () async {
    for (final lang in ['ceb', 'ilo']) {
      final host = FarmProfile(
        farmName: profile.farmName,
        locationHint: profile.locationHint,
        host: HostPreferences(preferredAddress: 'Host', language: lang),
        basePricePhp: profile.basePricePhp,
        maxGroupSize: profile.maxGroupSize,
      );
      final turn = await handleGuestTurn(
        message: 'How much is the tour?',
        traveler: const TravelerCard(language: 'en'),
        profile: host,
      );
      for (final s in turn.suggestions) {
        expect(s.forHost, s.english, reason: '$lang ${s.kind}');
      }
    }
  });

  test('every suggestion carries what it means for the host', () async {
    final turn = await handleGuestTurn(
      message: 'How much is the tour?',
      traveler: const TravelerCard(language: 'ko'),
      profile: profile,
      translator: const TaggingTranslator(),
    );
    final answer = turn.suggestions.first;
    expect(answer.forHost, contains('kada tao'));
    expect(answer.forGuest, startsWith('[ko]'));
    expect(turn.suggestions.map((s) => s.forHost), containsAll([momentMeaning, thanksMeaning]));
  });

  test('a fixed holding reply is always available, never an answer', () async {
    final s = await fixedSuggestion(
      SuggestionKind.holding,
      traveler: const TravelerCard(language: 'ja'),
      profile: profile,
      translator: const UnavailableTranslator(),
    );
    expect(s.kind, SuggestionKind.holding);
    expect(s.forHost, holdingMeaning);
    expect(s.forGuest, s.english, reason: 'English when no model');
  });

  test('model slots are shown to the host as quotes of the guest', () {
    final note = mentionedForHost({'date': 'Saturday', 'party_size': '4'}, profile.host)!;
    expect(note, 'Nabanggit ng bisita: petsa "Saturday", ilang tao "4"');
    expect(mentionedForHost({}, profile.host), isNull);
  });
}
