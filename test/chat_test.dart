import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turaista/core/conversation.dart';
import 'package:turaista/core/guardrail.dart';
import 'package:turaista/core/translator.dart';
import 'package:turaista/features/home/home_screen.dart';
import 'package:turaista/features/interpreter/interpreter_screen.dart';

import 'fakes.dart';
import 'helpers.dart';
import 'onboarding_helpers.dart';

void main() {
  final profile = loadExampleProfile();

  Future<void> pumpChat(
    WidgetTester tester, {
    Translator translator = const TaggingTranslator(),
    Set<TravelerNeed> needs = const {},
    FakeSpeechInput? input,
    FakeSpeechOutput? output,
    FakeIntentModel? model,
    Future<void> Function()? load,
    bool failTurns = false,
  }) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: InterpreterScreen(
          runGuestTurn:
              failTurns
                  ? ({
                    required message,
                    required traveler,
                    required profile,
                    translator = const IdentityTranslator(),
                    model,
                  }) => throw StateError('turn failed')
                  : handleGuestTurn,
          profile: profile,
          traveler: TravelerCard(language: 'ko', partySize: 2, needs: needs),
          translator: translator,
          speechInput: input,
          speechOutput: output,
          intentModel: model,
          loadIntentModel: load,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Types as [side], opening that side's keyboard first when needed.
  Future<void> typeAs(WidgetTester tester, String side, String text) async {
    if (find.byKey(Key('chat-send-$side')).evaluate().isEmpty) {
      await tester.tap(find.byKey(Key('chat-kbd-$side')));
      await tester.pump();
    }
    await tester.enterText(find.byKey(const Key('chat-input')), text);
    await tester.pump();
    await tester.tap(find.byKey(Key('chat-send-$side')));
    await tester.pumpAndSettle();
  }

  Future<void> guestTypes(WidgetTester tester, String text) => typeAs(tester, 'guest', text);
  Future<void> hostTypes(WidgetTester tester, String text) => typeAs(tester, 'host', text);

  Future<void> tapTile(WidgetTester tester, int i) async {
    await tester.tap(find.byKey(Key('suggestion-$i')));
    await tester.pumpAndSettle();
  }

  Finder inGuestHalf(Finder finder) =>
      find.descendant(of: find.byKey(const Key('guest-half')), matching: finder);

  bool tileEnabled(WidgetTester tester, int i) =>
      tester.widget<ListTile>(find.byKey(Key('suggestion-$i'))).onTap != null;

  bool buttonEnabled(WidgetTester tester, String key) =>
      tester.widget<ButtonStyleButton>(find.byKey(Key(key))).onPressed != null;

  testWidgets('traveler card leads to the chat', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(MaterialApp(home: HomeScreen(profile: profile)));
    await tester.tap(find.text('Live Interpreter'));
    await tester.pumpAndSettle();
    expect(find.text('Ibigay ang phone sa bisita'), findsOneWidget);
    expect(find.byKey(const Key('traveler-start')), findsNothing);

    await tester.tap(find.byKey(const Key('traveler-lang-ko')));
    await tester.pumpAndSettle();
    expect(find.text('몇 분이세요?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('traveler-party-plus')));
    await tester.tap(find.byKey(const Key('traveler-party-plus')));
    await tester.tap(find.byKey(const Key('traveler-need-food')));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('traveler-start')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('guest-half')), findsOneWidget);
    expect(find.byKey(const Key('chat-mic-host')), findsOneWidget);
    expect(find.byKey(const Key('care-banner')), findsOneWidget);
    expect(find.textContaining('pagkain o allergy'), findsOneWidget);
  });

  testWidgets('party size stays unset until the guest taps', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(MaterialApp(home: HomeScreen(profile: profile)));
    await tester.tap(find.text('Live Interpreter'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('traveler-lang-en')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('traveler-party-minus')));
    await tester.pump();
    expect(find.text('-'), findsOneWidget);
  });

  testWidgets('traveler needs are not preselected', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(MaterialApp(home: HomeScreen(profile: profile)));
    await tester.tap(find.text('Live Interpreter'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('traveler-lang-en')));
    await tester.pumpAndSettle();
    for (final need in TravelerNeed.values) {
      final chip = tester.widget<FilterChip>(find.byKey(Key('traveler-need-${need.name}')));
      expect(chip.selected, isFalse);
    }
    await tester.tap(find.byKey(const Key('traveler-start')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('care-banner')), findsNothing);
  });

  testWidgets('price question shows translation, explanation and a Tagalog reply tile', (
    tester,
  ) async {
    await pumpChat(tester);
    await guestTypes(tester, 'How much is the tour?');

    expect(find.text('[tl] How much is the tour?'), findsOneWidget);
    expect(find.textContaining('hindi ng tao'), findsOneWidget);
    expect(find.byKey(const Key('chat-explanation')), findsOneWidget);
    expect(find.textContaining('presyo'), findsWidgets);
    final tile = find.byKey(const Key('suggestion-0'));
    expect(tile, findsOneWidget);
    // The host reads the Tagalog meaning, not English or the guest language.
    expect(find.descendant(of: tile, matching: find.textContaining('350')), findsOneWidget);
    expect(find.descendant(of: tile, matching: find.textContaining('[ko]')), findsNothing);
    expect(find.descendant(of: tile, matching: find.textContaining('The tour')), findsNothing);
    expect(find.byKey(const Key('chat-blocked')), findsNothing);
    expect(find.byKey(const Key('care-banner')), findsNothing);
  });

  testWidgets('guest half is rotated and shows only the guest language', (tester) async {
    await pumpChat(tester);
    await guestTypes(tester, 'How much is the tour?');
    final rotated = find.ancestor(
      of: find.byKey(const Key('guest-half')),
      matching: find.byType(RotatedBox),
    );
    expect(tester.widget<RotatedBox>(rotated).quarterTurns, 2);

    expect(inGuestHalf(find.text('How much is the tour?')), findsOneWidget);
    expect(inGuestHalf(find.textContaining('[tl]')), findsNothing);
    expect(inGuestHalf(find.byKey(const Key('chat-explanation'))), findsNothing);
    expect(inGuestHalf(find.textContaining('350')), findsNothing);

    await tapTile(tester, 0);
    expect(inGuestHalf(find.textContaining('[ko] ')), findsOneWidget);
    // Tagalog never appears on the guest side.
    expect(inGuestHalf(find.textContaining('Ang ')), findsNothing);
    expect(inGuestHalf(find.textContaining('Narinig')), findsNothing);
  });

  testWidgets('one tap on a reply speaks it in the guest language', (tester) async {
    final output = FakeSpeechOutput();
    await pumpChat(tester, output: output, input: FakeSpeechInput());
    await guestTypes(tester, 'How much is the tour?');
    expect(output.spoken, isEmpty);

    await tapTile(tester, 0);
    expect(output.spoken, hasLength(1));
    expect(output.spoken.single.lang, 'ko');
    expect(output.spoken.single.text, startsWith('[ko] '));
    expect(find.byKey(const Key('host-bubble')), findsOneWidget);
    expect(find.text('Narinig ng bisita'), findsOneWidget);
  });

  testWidgets('Ulitin repeats the last reply', (tester) async {
    final output = FakeSpeechOutput();
    await pumpChat(tester, output: output, input: FakeSpeechInput());
    await guestTypes(tester, 'How much is the tour?');
    await tapTile(tester, 0);
    await tester.ensureVisible(find.byKey(const Key('chat-repeat')));
    await tester.tap(find.byKey(const Key('chat-repeat')));
    await tester.pumpAndSettle();
    expect(output.spoken, hasLength(2));
    expect(output.spoken.first, output.spoken.last);
  });

  testWidgets('stop button cuts the speech and it is not reported as heard', (tester) async {
    final output = FakeSpeechOutput();
    await pumpChat(tester, output: output, input: FakeSpeechInput());
    await guestTypes(tester, 'How much is the tour?');
    output.gate = Completer<void>();
    await tester.tap(find.byKey(const Key('suggestion-0')));
    await tester.pump();
    expect(output.speaking, isTrue);
    expect(find.byKey(const Key('suggestion-stop')), findsOneWidget);
    expect(tileEnabled(tester, 1), isFalse);

    await tester.tap(find.byKey(const Key('suggestion-stop')));
    await tester.pumpAndSettle();
    expect(output.speaking, isFalse);
    expect(find.byKey(const Key('suggestion-stop')), findsNothing);
    expect(find.text('Narinig ng bisita'), findsNothing);
    expect(tileEnabled(tester, 1), isTrue);
  });

  testWidgets('guest text and English sit behind Tingnan, with the fallback notice', (
    tester,
  ) async {
    await pumpChat(tester, translator: const UnavailableTranslator());
    await guestTypes(tester, 'How much is the tour?');
    expect(find.byKey(const Key('suggestion-notice-0')), findsNothing);
    expect(find.byKey(const Key('suggestion-badge-0')), findsOneWidget);
    await tester.tap(find.byKey(const Key('suggestion-more-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('suggestion-guest-text-0')), findsOneWidget);
    expect(find.byKey(const Key('suggestion-notice-0')), findsOneWidget);
    expect(find.byKey(const Key('guest-translation-note')), findsOneWidget);
  });

  testWidgets('safety question is blocked, with a holding tile and no answer', (tester) async {
    final output = FakeSpeechOutput();
    await pumpChat(tester, output: output, input: FakeSpeechInput());
    await guestTypes(tester, 'I have a peanut allergy, is the lunch safe?');

    final blocked = find.byKey(const Key('chat-blocked'));
    expect(blocked, findsOneWidget);
    expect(find.descendant(of: blocked, matching: find.text(hostFallback)), findsOneWidget);
    expect(find.byKey(const Key('chat-blocked-asked')), findsOneWidget);
    expect(
      tester.widget<Card>(blocked).color,
      Theme.of(tester.element(blocked)).colorScheme.errorContainer,
    );
    expect(find.byKey(const Key('suggestion-0')), findsOneWidget);
    expect(find.byKey(const Key('suggestion-2')), findsOneWidget);
    expect(find.byKey(const Key('suggestion-3')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('suggestion-0')),
        matching: find.textContaining('magkukumpirma'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('350'), findsNothing);

    await tapTile(tester, 0);
    expect(output.spoken, hasLength(1));
    expect(output.spoken.single.lang, 'ko');
  });

  testWidgets('Ikaw na ang sumagot opens the host mic after a blocked turn', (tester) async {
    final input = FakeSpeechInput(heard: 'Magtatanong po ako sa guide.');
    final output = FakeSpeechOutput();
    await pumpChat(tester, input: input, output: output);
    await guestTypes(tester, 'I have a peanut allergy, is the lunch safe?');
    await tester.ensureVisible(find.byKey(const Key('chat-answer-self')));
    await tester.tap(find.byKey(const Key('chat-answer-self')));
    await tester.pumpAndSettle();
    expect(input.listenCalls, ['tl']);
    expect(find.text('Magtatanong po ako sa guide.'), findsWidgets);
    expect(output.spoken.single.lang, 'ko');
  });

  testWidgets('a blocked turn after an answer leaves no answer to tap', (tester) async {
    final output = FakeSpeechOutput();
    await pumpChat(tester, output: output, input: FakeSpeechInput());
    await guestTypes(tester, 'How much is the tour?');
    expect(find.textContaining('350'), findsWidgets);

    await guestTypes(tester, 'I have a peanut allergy, is the lunch safe?');
    expect(find.byKey(const Key('chat-blocked')), findsOneWidget);
    expect(find.byKey(const Key('suggestion-3')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('suggestion-0')),
        matching: find.textContaining('350'),
      ),
      findsNothing,
    );
    expect(output.spoken, isEmpty);
  });

  testWidgets('care banner shows only when a need was picked', (tester) async {
    await pumpChat(tester, needs: {TravelerNeed.mobility, TravelerNeed.children});
    expect(find.byKey(const Key('care-banner')), findsOneWidget);
    expect(find.textContaining('hirap maglakad'), findsOneWidget);
    expect(find.textContaining('bata'), findsOneWidget);
  });

  testWidgets('host turn with a changed number is not spoken', (tester) async {
    final output = FakeSpeechOutput();
    await pumpChat(
      tester,
      translator: const NumberChangingTranslator(),
      output: output,
      input: FakeSpeechInput(),
    );
    await hostTypes(tester, 'Ang presyo ay 350 pesos.');
    expect(output.spoken, isEmpty);
    expect(find.byKey(const Key('host-not-said')), findsOneWidget);
    expect(find.textContaining('pumili ng sagot'), findsOneWidget);
    expect(inGuestHalf(find.textContaining('350')), findsNothing);
  });

  testWidgets('host turn is spoken in the guest language', (tester) async {
    final output = FakeSpeechOutput();
    await pumpChat(tester, output: output, input: FakeSpeechInput());
    await hostTypes(tester, 'Magandang umaga po.');
    expect(output.spoken.single.lang, 'ko');
    expect(find.text('Narinig ng bisita'), findsOneWidget);
  });

  for (final translator in <Translator>[
    const UnavailableTranslator(),
    const CrashingTranslator(),
  ]) {
    testWidgets('host turn is not spoken with ${translator.runtimeType}', (tester) async {
      final output = FakeSpeechOutput();
      await pumpChat(tester, translator: translator, output: output, input: FakeSpeechInput());
      await hostTypes(tester, 'Magandang umaga po.');
      expect(output.spoken, isEmpty);
      expect(find.byKey(const Key('host-not-said')), findsOneWidget);
    });
  }

  testWidgets('mic is disabled when speech is unavailable, typing still works', (tester) async {
    await pumpChat(tester, input: FakeSpeechInput(available: {'tl'}), output: FakeSpeechOutput());
    expect(buttonEnabled(tester, 'chat-mic-guest'), isFalse);
    expect(buttonEnabled(tester, 'chat-mic-host'), isTrue);
    expect(find.textContaining('Mag-type na lang'), findsOneWidget);
    expect(inGuestHalf(find.text('메시지를 입력해 주세요.')), findsOneWidget);
    await guestTypes(tester, 'How much is the tour?');
    expect(find.byKey(const Key('suggestion-0')), findsOneWidget);
  });

  testWidgets('no speech at all means typing only', (tester) async {
    await pumpChat(tester);
    expect(buttonEnabled(tester, 'chat-mic-guest'), isFalse);
    expect(buttonEnabled(tester, 'chat-mic-host'), isFalse);
    expect(find.byKey(const Key('chat-input')), findsOneWidget);
  });

  testWidgets('guest mic listens in the guest language and runs the turn', (tester) async {
    final input = FakeSpeechInput(heard: 'How much is the tour?');
    final output = FakeSpeechOutput();
    await pumpChat(tester, input: input, output: output);
    await tester.tap(find.byKey(const Key('chat-mic-guest')));
    await tester.pumpAndSettle();
    expect(input.listenCalls, ['ko']);
    expect(find.byKey(const Key('guest-bubble')), findsOneWidget);
    expect(find.byKey(const Key('suggestion-0')), findsOneWidget);
    expect(output.spoken, isEmpty);
  });

  testWidgets('a failing recognizer degrades to typing', (tester) async {
    final input = FakeSpeechInput(throwOnListen: true);
    await pumpChat(tester, input: input, output: FakeSpeechOutput());
    await tester.tap(find.byKey(const Key('chat-mic-guest')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Subukan ulit'), findsOneWidget);
    expect(find.byKey(const Key('chat-partial-guest')), findsNothing);
    await guestTypes(tester, 'How much is the tour?');
    expect(find.byKey(const Key('suggestion-0')), findsOneWidget);
  });

  testWidgets('speaking and listening never overlap', (tester) async {
    final output = FakeSpeechOutput();
    final input = FakeSpeechInput(watch: output)..gate = Completer<String?>();
    await pumpChat(tester, output: output, input: input);
    await guestTypes(tester, 'How much is the tour?');
    output.gate = Completer<void>();
    await tester.tap(find.byKey(const Key('suggestion-0')));
    await tester.pump();
    expect(output.speaking, isTrue);
    expect(tileEnabled(tester, 1), isFalse);

    await tester.tap(find.byKey(const Key('chat-mic-guest')));
    await tester.pump();
    await tester.pump();
    expect(output.speaking, isFalse);
    expect(input.startedWhileSpeaking, isFalse);
    expect(input.listening, isTrue);
    expect(tileEnabled(tester, 1), isFalse);
    expect(find.byKey(const Key('chat-partial-guest')), findsOneWidget);
    expect(find.text('Narinig ng bisita'), findsNothing);

    input.gate!.complete(null);
    await tester.pumpAndSettle();
    expect(tileEnabled(tester, 1), isTrue);
  });

  testWidgets('a failed guest turn still offers fixed replies, never an answer', (tester) async {
    await pumpChat(tester, failTurns: true);
    await guestTypes(tester, 'How much is the tour?');
    expect(find.byKey(const Key('chat-failed')), findsOneWidget);
    expect(find.byKey(const Key('suggestion-0')), findsOneWidget);
    expect(find.byKey(const Key('suggestion-3')), findsNothing);
    expect(find.textContaining('350'), findsNothing);
    await tapTile(tester, 0);
    expect(inGuestHalf(find.textContaining('[ko] ')), findsOneWidget);
  });

  testWidgets('AI chip: keyword mode, loading, ready', (tester) async {
    await pumpChat(tester);
    expect(find.text('AI: wala'), findsOneWidget);
    expect(find.byKey(const Key('chat-status')), findsOneWidget);
  });

  testWidgets('AI chip says hinahanda while the model loads, then handa', (tester) async {
    final done = Completer<void>();
    await pumpChat(tester, model: FakeIntentModel(null), load: () => done.future);
    expect(find.text('AI: hinahanda'), findsOneWidget);
    done.complete();
    await tester.pumpAndSettle();
    expect(find.text('AI: handa'), findsOneWidget);
    expect(find.byKey(const Key('chat-status')), findsNothing);
    await guestTypes(tester, 'How much is the tour?');
    expect(find.byKey(const Key('suggestion-0')), findsOneWidget);
  });

  testWidgets('a failed model load shows keyword mode', (tester) async {
    await pumpChat(
      tester,
      model: FakeIntentModel('{}'),
      load: () async => throw StateError('load failed'),
    );
    expect(find.byKey(const Key('chat-status')), findsOneWidget);
    expect(find.text('AI: wala'), findsOneWidget);
    await guestTypes(tester, 'How much is the tour?');
    expect(find.byKey(const Key('suggestion-0')), findsOneWidget);
  });

  testWidgets('what the small AI picked out is shown as a quoted note', (tester) async {
    await pumpChat(
      tester,
      model: FakeIntentModel('{"intent":"BOOKING","slots":{"date":"Saturday"}}'),
      load: () async {},
    );
    await guestTypes(tester, 'Can we book for Saturday?');
    final note = find.byKey(const Key('chat-mentioned'));
    expect(note, findsOneWidget);
    expect(tester.widget<Text>(note).data, contains('"Saturday"'));
    expect(inGuestHalf(note), findsNothing);
    expect(inGuestHalf(find.textContaining('Nabanggit')), findsNothing);
    expect(find.textContaining('Nabanggit ng bisita'), findsOneWidget);
  });

  testWidgets('without a voice the text is shown and nothing is spoken', (tester) async {
    final output = FakeSpeechOutput(voices: {});
    await pumpChat(tester, output: output, input: FakeSpeechInput());
    await guestTypes(tester, 'How much is the tour?');
    await tester.tap(find.byKey(const Key('suggestion-more-0')));
    await tester.pumpAndSettle();
    expect(find.text('Ipapakita sa bisita'), findsOneWidget);
    expect(find.byKey(const Key('suggestion-guest-text-0')), findsOneWidget);
    await tapTile(tester, 0);
    expect(output.spoken, isEmpty);
    expect(find.text('Ipinakita sa bisita'), findsOneWidget);
    expect(find.text('Narinig ng bisita'), findsNothing);
    expect(inGuestHalf(find.textContaining('[ko] ')), findsOneWidget);
  });

  testWidgets('speech output that throws is not reported as heard', (tester) async {
    final output = FakeSpeechOutput(throwOnSpeak: true);
    await pumpChat(tester, output: output, input: FakeSpeechInput());
    await guestTypes(tester, 'How much is the tour?');
    await tapTile(tester, 0);
    expect(find.byKey(const Key('host-bubble')), findsOneWidget);
    expect(find.text('Narinig ng bisita'), findsNothing);
    expect(find.text('Ipinakita sa bisita'), findsOneWidget);
    await hostTypes(tester, 'Magandang umaga po.');
    expect(find.text('Narinig ng bisita'), findsNothing);
  });

  testWidgets('fits a small phone at large font without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(
      MaterialApp(
        home: InterpreterScreen(
          profile: profile,
          traveler: const TravelerCard(language: 'ko', partySize: 2),
          translator: const TaggingTranslator(),
          speechInput: FakeSpeechInput(),
          speechOutput: FakeSpeechOutput(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat-kbd-guest')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('chat-input')), 'How much is the tour?');
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat-send-guest')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('chat-mic-host')), findsOneWidget);
  });

  testWidgets('fallback tiles show a badge on the tile itself', (tester) async {
    await pumpChat(tester, translator: const UnavailableTranslator());
    await guestTypes(tester, 'How much is the tour?');
    final badge = find.byKey(const Key('suggestion-badge-0'));
    expect(
      find.descendant(of: badge, matching: find.textContaining('wala pa ang wika ng bisita')),
      findsOneWidget,
    );
  });

  testWidgets('a changed number is flagged on the tile', (tester) async {
    await pumpChat(tester, translator: const NumberChangingTranslator());
    await guestTypes(tester, 'How much is the tour?');
    final badge = find.byKey(const Key('suggestion-badge-0'));
    expect(
      find.descendant(of: badge, matching: find.textContaining('nag-iba ang numero')),
      findsOneWidget,
    );
  });

  testWidgets('a translated tile says the app will translate it', (tester) async {
    await pumpChat(tester);
    await guestTypes(tester, 'How much is the tour?');
    final badge = find.byKey(const Key('suggestion-badge-0'));
    expect(find.descendant(of: badge, matching: find.text('Isasalin ng app')), findsOneWidget);
  });

  testWidgets('an English fallback needs a yes and is spoken in English', (tester) async {
    final output = FakeSpeechOutput();
    await pumpChat(
      tester,
      translator: const UnavailableTranslator(),
      output: output,
      input: FakeSpeechInput(),
    );
    await guestTypes(tester, 'How much is the tour?');
    await tester.tap(find.byKey(const Key('suggestion-0')));
    await tester.pumpAndSettle();
    expect(find.text('English lang ito. Sabihin pa rin?'), findsOneWidget);
    expect(output.spoken, isEmpty);
    expect(find.byKey(const Key('host-bubble')), findsNothing);
    expect(inGuestHalf(find.textContaining('350')), findsNothing);

    await tester.tap(find.byKey(const Key('suggestion-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('English lang ito. Sabihin pa rin?'), findsNothing);
    expect(output.spoken, isEmpty);

    await tester.tap(find.byKey(const Key('suggestion-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('suggestion-confirm')));
    await tester.pumpAndSettle();
    expect(output.spoken, hasLength(1));
    expect(output.spoken.single.lang, 'en');
    expect(inGuestHalf(find.textContaining('350')), findsOneWidget);
  });

  testWidgets('a said reply is marked used and is not spoken again on tap', (tester) async {
    final output = FakeSpeechOutput();
    await pumpChat(tester, output: output, input: FakeSpeechInput());
    await guestTypes(tester, 'How much is the tour?');
    await tapTile(tester, 0);
    expect(output.spoken, hasLength(1));
    expect(tileEnabled(tester, 0), isFalse);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    await tester.tap(find.byKey(const Key('suggestion-0')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(output.spoken, hasLength(1));
    // Ulitin still repeats it.
    await tester.ensureVisible(find.byKey(const Key('chat-repeat')));
    await tester.tap(find.byKey(const Key('chat-repeat')));
    await tester.pumpAndSettle();
    expect(output.spoken, hasLength(2));
  });

  testWidgets('no tile can be tapped while speaking', (tester) async {
    final output = FakeSpeechOutput();
    await pumpChat(tester, output: output, input: FakeSpeechInput());
    await guestTypes(tester, 'How much is the tour?');
    output.gate = Completer<void>();
    await tester.tap(find.byKey(const Key('suggestion-0')));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      expect(tileEnabled(tester, i), isFalse);
    }
    output.gate!.complete();
    await tester.pumpAndSettle();
    expect(tileEnabled(tester, 1), isTrue);
  });

  testWidgets('a failed turn offers the holding reply first', (tester) async {
    await pumpChat(tester, failTurns: true);
    await guestTypes(tester, 'How much is the tour?');
    expect(
      find.descendant(
        of: find.byKey(const Key('suggestion-0')),
        matching: find.textContaining('Kami mismo'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('chat-blocked-tl')), findsOneWidget);
  });

  testWidgets('each side has its own text field', (tester) async {
    await pumpChat(tester, input: FakeSpeechInput(), output: FakeSpeechOutput());
    await tester.tap(find.byKey(const Key('chat-kbd-guest')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('chat-input')), 'How much is the tour?');
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat-kbd-host')));
    await tester.pump();
    expect(tester.widget<TextField>(find.byKey(const Key('chat-input'))).controller!.text, isEmpty);
    expect(find.byKey(const Key('chat-send-host')), findsOneWidget);
    expect(tester.widget<IconButton>(find.byKey(const Key('chat-send-host'))).onPressed, isNull);
    expect(find.byKey(const Key('guest-bubble')), findsNothing);
  });

  testWidgets('fits 360x640 with the keyboard open on either side', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: InterpreterScreen(
          profile: profile,
          traveler: const TravelerCard(
            language: 'ko',
            partySize: 2,
            needs: {TravelerNeed.food, TravelerNeed.mobility},
          ),
          translator: const TaggingTranslator(),
          speechInput: FakeSpeechInput(),
          speechOutput: FakeSpeechOutput(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final side in ['host', 'guest']) {
      await tester.tap(find.byKey(Key('chat-kbd-$side')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$side typing');
      expect(find.byKey(const Key('chat-input')), findsOneWidget);
      await tester.tap(find.byKey(Key('chat-kbd-$side')));
      await tester.pumpAndSettle();
    }
  });
}
