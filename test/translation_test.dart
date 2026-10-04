import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turaista/app.dart';
import 'package:turaista/core/profile_store.dart';
import 'package:turaista/features/home/home_screen.dart';
import 'package:turaista/features/inquiry/inquiry_screen.dart';
import 'package:turaista/features/setup/language_download_screen.dart';

import 'fakes.dart';
import 'helpers.dart';
import 'onboarding_helpers.dart';

void main() {
  final profile = loadExampleProfile();

  Future<void> askPrice(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('inquiry-input')), 'How much is the tour?');
    await tester.tap(find.text('Korean (한국어)'));
    await tester.tap(find.byKey(const Key('inquiry-submit')));
    await tester.pumpAndSettle();
  }

  group('inquiry', () {
    testWidgets('changed number: host is told and copies the English draft', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
        call,
      ) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: InquiryScreen(profile: profile, translator: const NumberChangingTranslator()),
        ),
      );
      await askPrice(tester);

      expect(find.byKey(const Key('translation-notice')), findsOneWidget);
      expect(find.textContaining('Nag-iba po ang mga numero'), findsOneWidget);
      expect(find.textContaining('530'), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('approve-copy')));
      await tester.tap(find.byKey(const Key('approve-copy')));
      await tester.pump();
      expect(copied, contains('PHP 350'));
      expect(copied, isNot(startsWith('[ko]')));
    });

    testWidgets('faithful translation: no notice', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: InquiryScreen(profile: profile, translator: const TaggingTranslator())),
      );
      await askPrice(tester);
      expect(find.byKey(const Key('translation-notice')), findsNothing);
      expect(find.textContaining('[ko]'), findsOneWidget);
    });

    testWidgets('missing model: host is told to download on Wi-Fi', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: InquiryScreen(profile: profile, translator: const UnavailableTranslator()),
        ),
      );
      await askPrice(tester);
      expect(
        find.descendant(
          of: find.byKey(const Key('translation-notice')),
          matching: find.textContaining('Wi-Fi'),
        ),
        findsOneWidget,
      );
    });
  });

  group('language download', () {
    Widget screen(FakeLanguageModels models, {VoidCallback? onDone}) =>
        MaterialApp(home: LanguageDownloadScreen(models: models, usePo: true, onDone: onDone));

    testWidgets('shows what is already downloaded and downloads the rest', (tester) async {
      useTallScreen(tester);
      final models = FakeLanguageModels(downloaded: {'en'});
      await tester.pumpWidget(screen(models));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('language-en')),
          matching: find.text('Naka-download na'),
        ),
        findsOneWidget,
      );
      expect(find.text('Hindi pa naka-download'), findsNWidgets(4));

      await tester.tap(find.byKey(const Key('download-all')));
      await tester.pumpAndSettle();
      expect(models.downloadCalls, ['tl', 'ko', 'ja', 'zh']);
      expect(find.text('Naka-download na'), findsNWidgets(5));
      expect(find.byKey(const Key('download-all')), findsNothing);
    });

    testWidgets('a failed download says to check Wi-Fi and can be retried', (tester) async {
      useTallScreen(tester);
      final models = FakeLanguageModels(failing: {'ja'});
      await tester.pumpWidget(screen(models));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('download-ja')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('download-error')), findsOneWidget);
      expect(find.text('Hindi natuloy'), findsOneWidget);

      models.failing.clear();
      await tester.tap(find.byKey(const Key('download-ja')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('download-error')), findsNothing);
    });

    testWidgets('home shows the download card only with language models', (tester) async {
      await tester.pumpWidget(MaterialApp(home: HomeScreen(profile: profile)));
      expect(find.text('I-download ang mga wika'), findsNothing);
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(profile: profile, languageModels: FakeLanguageModels())),
      );
      expect(find.text('I-download ang mga wika'), findsOneWidget);
    });

    testWidgets('app offers downloads once, right after onboarding', (tester) async {
      useTallScreen(tester);
      final store = InMemoryProfileStore();
      await tester.pumpWidget(TurAIstaApp(store: store, languageModels: FakeLanguageModels()));
      await answerAll(tester);
      await confirmAll(tester);
      await tester.tap(find.byKey(onboardingSave));
      await tester.pumpAndSettle();

      expect(find.text('I-download ang mga wika'), findsOneWidget);
      await tester.tap(find.byKey(const Key('download-done'))); // "Mamaya na"
      await tester.pumpAndSettle();
      expect(find.text('Magandang araw, Manang Lorna!'), findsOneWidget);
    });

    testWidgets('a returning host goes straight home', (tester) async {
      await tester.pumpWidget(
        TurAIstaApp(
          store: InMemoryProfileStore(profile),
          initialProfile: profile,
          languageModels: FakeLanguageModels(),
        ),
      );
      expect(find.text('Magandang araw, Manang Lorna!'), findsOneWidget);
    });
  });
}
