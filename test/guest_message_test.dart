import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turaista/core/translator.dart';
import 'package:turaista/features/inquiry/inquiry_screen.dart';

import 'fakes.dart';
import 'helpers.dart';
import 'onboarding_helpers.dart';

void main() {
  final profile = loadExampleProfile();

  Future<void> pumpInquiry(
    WidgetTester tester, {
    Translator translator = const TaggingTranslator(),
    FakeLanguageIdentifier? identifier,
  }) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: InquiryScreen(
          profile: profile,
          translator: translator,
          languageIdentifier: identifier,
        ),
      ),
    );
  }

  Future<void> ask(WidgetTester tester, String message) async {
    await tester.enterText(find.byKey(const Key('inquiry-input')), message);
    await tester.tap(find.byKey(const Key('inquiry-submit')));
    await tester.pumpAndSettle();
  }

  bool chipSelected(WidgetTester tester, String label) =>
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label)).selected;

  group('guest message in Tagalog', () {
    testWidgets('appears under the explanation, labeled as machine translation', (tester) async {
      await pumpInquiry(tester);
      await ask(tester, 'How much is the tour?');

      final card = find.byKey(const Key('host-translation'));
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.textContaining('hindi ng tao')),
        findsOneWidget,
      );
      expect(find.text('[tl] How much is the tour?'), findsOneWidget);
      final explanation = find.textContaining('Manang Lorna, tungkol po sa');
      expect(tester.getTopLeft(explanation).dy, lessThan(tester.getTopLeft(card).dy));
    });

    testWidgets('warns when the translation changed a number', (tester) async {
      await pumpInquiry(tester, translator: const NumberChangingTranslator());
      await ask(tester, 'Can 5 of us book for Saturday?');
      expect(find.byKey(const Key('host-translation-text')), findsOneWidget);
      expect(find.byKey(const Key('host-translation-note')), findsOneWidget);
      expect(find.textContaining('orihinal na mensahe'), findsOneWidget);
      // The original is shown next to the doubtful translation.
      expect(
        tester.widget<Text>(find.byKey(const Key('host-translation-original'))).data,
        'Can 5 of us book for Saturday?',
      );
    });

    testWidgets('a trusted translation does not repeat the original', (tester) async {
      await pumpInquiry(tester);
      await ask(tester, 'Can 5 of us book for Saturday?');
      expect(find.byKey(const Key('host-translation-original')), findsNothing);
    });

    testWidgets('says why when the language is not on the phone', (tester) async {
      await pumpInquiry(tester, translator: const UnavailableTranslator());
      await ask(tester, 'How much is the tour?');
      expect(find.byKey(const Key('host-translation-text')), findsNothing);
      expect(find.textContaining('Hindi po maisalin'), findsOneWidget);
    });
  });

  group('guest language detection', () {
    testWidgets('selects the detected language and says so', (tester) async {
      await pumpInquiry(tester, identifier: FakeLanguageIdentifier('ko'));
      await ask(tester, '투어 가격이 얼마예요?');

      expect(chipSelected(tester, 'Korean (한국어)'), isTrue);
      expect(find.byKey(const Key('detected-language')), findsOneWidget);
      expect(find.textContaining('[ko]'), findsOneWidget); // reply in Korean
    });

    testWidgets('unsure or unsupported: English, never the last language', (tester) async {
      final identifier = FakeLanguageIdentifier('ko');
      await pumpInquiry(tester, identifier: identifier);
      await ask(tester, '투어 가격이 얼마예요?');
      expect(chipSelected(tester, 'Korean (한국어)'), isTrue);

      for (final unsure in [null, 'fr']) {
        identifier.lang = unsure;
        await ask(tester, 'Pila ang bayad? $unsure'); // e.g. Cebuano
        expect(chipSelected(tester, 'English'), isTrue);
        expect(find.byKey(const Key('language-unsure')), findsOneWidget);
        expect(find.byKey(const Key('detected-language')), findsNothing);
      }
    });

    testWidgets('a chip picked for this message is kept', (tester) async {
      final identifier = FakeLanguageIdentifier('ja');
      await pumpInquiry(tester, identifier: identifier);
      await tester.enterText(find.byKey(const Key('inquiry-input')), 'How much is the tour?');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Korean (한국어)'));
      await tester.tap(find.byKey(const Key('inquiry-submit')));
      await tester.pumpAndSettle();
      expect(chipSelected(tester, 'Korean (한국어)'), isTrue);
      expect(find.byKey(const Key('language-unsure')), findsNothing);
    });

    testWidgets('a chip tapped while detection runs wins', (tester) async {
      final identifier = SlowLanguageIdentifier();
      useTallScreen(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: InquiryScreen(
            profile: profile,
            translator: const TaggingTranslator(),
            languageIdentifier: identifier,
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('inquiry-input')), 'How much is the tour?');
      await tester.tap(find.byKey(const Key('inquiry-submit')));
      await tester.pump(); // detection is now waiting
      await tester.tap(find.widgetWithText(ChoiceChip, 'Chinese (中文)'));
      identifier.answer.complete('ja');
      await tester.pumpAndSettle();
      expect(chipSelected(tester, 'Chinese (中文)'), isTrue);
      expect(find.textContaining('[zh]'), findsOneWidget);
    });

    testWidgets('the host can override it, until a new message is pasted', (tester) async {
      await pumpInquiry(tester, identifier: FakeLanguageIdentifier('ja'));
      await ask(tester, 'How much is the tour?');
      expect(chipSelected(tester, 'Japanese (日本語)'), isTrue);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Chinese (中文)'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('inquiry-submit')));
      await tester.pumpAndSettle();
      expect(chipSelected(tester, 'Chinese (中文)'), isTrue, reason: 'host choice wins');
      expect(find.textContaining('[zh]'), findsOneWidget);

      await ask(tester, 'Can we book for Saturday?');
      expect(chipSelected(tester, 'Japanese (日本語)'), isTrue, reason: 'new message, detected again');
    });

    testWidgets('without an identifier the chips are used', (tester) async {
      await pumpInquiry(tester);
      await ask(tester, '투어 가격이 얼마예요?');
      expect(chipSelected(tester, 'English'), isTrue);
      expect(find.byKey(const Key('detected-language')), findsNothing);
    });
  });
}
