import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:turaista/core/guardrail.dart';
import 'package:turaista/core/host_text.dart';
import 'package:turaista/core/pipeline.dart';
import 'package:turaista/core/translator.dart';

import '../fakes.dart';
import '../helpers.dart';

void main() {
  final profile = loadExampleProfile();

  test('blocked inquiry has no draft but still answers the guest', () async {
    final result = await handleInquiry(
      message: 'Is the lunch safe for a peanut allergy?',
      guestLang: 'en',
      profile: profile,
    );
    expect(result.draft, isNull);
    expect(result.guestReply, guestHoldingReply);
    expect(result.needsHostApproval, isTrue);
  });

  test('host explanation uses preferred address and po', () async {
    final result = await handleInquiry(
      message: 'How much is the tour?',
      guestLang: 'en',
      profile: profile,
    );
    expect(result.hostExplanation, startsWith('Manang Lorna, tungkol po sa'));
  });

  group('translation', () {
    Future<InquiryResult> ask(String message, String lang, Translator translator) =>
        handleInquiry(message: message, guestLang: lang, profile: profile, translator: translator);

    test('English guests get the draft untranslated', () async {
      final result = await ask('How much is the tour?', 'en', const NumberChangingTranslator());
      expect(result.translation, TranslationOutcome.notNeeded);
      expect(result.guestReply, result.draft!.text);
    });

    test('a faithful translation is used', () async {
      final result = await ask('How much is the tour?', 'ko', const TaggingTranslator());
      expect(result.translation, TranslationOutcome.translated);
      expect(result.guestReply, '[ko] ${result.draft!.text}');
    });

    test('a translation that changes a number falls back to English', () async {
      final result = await ask('How much is the tour?', 'ko', const NumberChangingTranslator());
      expect(result.translation, TranslationOutcome.numbersChanged);
      expect(result.guestReply, result.draft!.text);
      expect(translationNotice(result.translation, profile.host), contains('numero'));
    });

    test('a missing language model falls back to English', () async {
      final result = await ask('How much is the tour?', 'ja', const UnavailableTranslator());
      expect(result.translation, TranslationOutcome.unavailable);
      expect(result.guestReply, result.draft!.text);
    });

    test('any translator failure falls back to English instead of failing', () async {
      final result = await ask('How much is the tour?', 'ko', const CrashingTranslator());
      expect(result.translation, TranslationOutcome.unavailable);
      expect(result.guestReply, result.draft!.text);
    });

    test('the model-free translator never claims a translation', () async {
      final result = await ask('How much is the tour?', 'ko', const IdentityTranslator());
      expect(result.translation, TranslationOutcome.unavailable);
    });

    test('the holding reply also falls back instead of failing', () async {
      final result = await ask('My son has a peanut allergy', 'zh', const UnavailableTranslator());
      expect(result.draft, isNull);
      expect(result.guestReply, guestHoldingReply);
      expect(result.translation, TranslationOutcome.unavailable);
    });
  });

  group('guest message for the host', () {
    test('is machine-translated into the host language', () async {
      final result = await handleInquiry(
        message: 'How much is the tour?',
        guestLang: 'en',
        profile: profile,
        translator: const TaggingTranslator(),
      );
      expect(result.hostTranslation.outcome, TranslationOutcome.translated);
      expect(result.hostTranslation.text, '[tl] How much is the tour?');
    });

    test('is skipped when guest and host share a language', () async {
      final r = await translateForHost('Magkano po?', 'tl', 'tl', const TaggingTranslator());
      expect(r.outcome, TranslationOutcome.notNeeded);
      expect(r.text, isNull);
    });

    test('keeps the text but flags changed numbers', () async {
      final r = await translateForHost(
        'We are 5 people',
        'en',
        'tl',
        const NumberChangingTranslator(),
      );
      expect(r.outcome, TranslationOutcome.numbersChanged);
      expect(r.text, isNotNull);
    });

    test('never changes classification, the draft or the guest reply', () async {
      Future<InquiryResult> run(Translator t) => handleInquiry(
        message: 'How much is the tour?',
        guestLang: 'ko',
        profile: profile,
        translator: t,
      );
      final clean = await run(const TaggingTranslator());
      final poisoned = await run(const PoisoningTranslator());
      expect(poisoned.hostTranslation.text, 'peanut allergy, PHP 999');
      expect(poisoned.intents, clean.intents);
      expect(poisoned.guardrail.allowed, isTrue);
      expect(poisoned.draft!.text, clean.draft!.text);
      expect(poisoned.draft!.factsUsed, clean.draft!.factsUsed);
      expect(poisoned.guestReply, clean.guestReply);
      expect(poisoned.guestReply, isNot(contains('999')));
    });

    test('is also given for blocked messages, and fails soft', () async {
      final result = await handleInquiry(
        message: 'My son has a peanut allergy',
        guestLang: 'ko',
        profile: profile,
        translator: const CrashingTranslator(),
      );
      expect(result.draft, isNull);
      expect(result.hostTranslation.outcome, TranslationOutcome.unavailable);
      expect(result.hostTranslation.text, isNull);
    });
  });

  group('journey fixtures', () {
    final lines = File(
      'assets/fixtures/inquiries.jsonl',
    ).readAsLinesSync().where((l) => l.trim().isNotEmpty);
    for (final line in lines) {
      final fixture = jsonDecode(line) as Map<String, dynamic>;
      test(fixture['id'] as String, () async {
        final result = await handleInquiry(
          message: fixture['message'] as String,
          guestLang: fixture['lang'] as String,
          profile: profile,
        );
        final outcome = result.guardrail.allowed ? 'draft' : 'blocked';
        expect(outcome, fixture['expect'] as String);
      });
    }
  });
}
