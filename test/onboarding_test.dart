import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turaista/app.dart';
import 'package:turaista/core/profile.dart';
import 'package:turaista/core/profile_store.dart';
import 'package:turaista/features/setup/onboarding_screen.dart';

import 'helpers.dart';
import 'onboarding_helpers.dart';

void main() {
  late InMemoryProfileStore store;
  FarmProfile? saved;

  setUp(() {
    store = InMemoryProfileStore();
    saved = null;
  });

  Widget onboarding() =>
      MaterialApp(home: OnboardingScreen(store: store, onSaved: (p) => saved = p));

  testWidgets('every fact is read back and must be confirmed before saving', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(onboarding());
    await answerAll(tester);

    expect(find.text('Tama po ba lahat?'), findsOneWidget);
    expect(find.text('Tama po ba na PHP 350 bawat tao?'), findsOneWidget);
    expect(find.text('Tama po ba na hanggang 12 bisita lang sa isang grupo?'), findsOneWidget);
    expect(find.textContaining('"Roasting workshop" (PHP 200, 45 minuto)'), findsOneWidget);
    expect(find.textContaining('"Picking walk" (kasama na sa presyo ng tour)'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);

    await tester.tap(find.byKey(const Key('readback-yes-0')));
    await tester.pump();
    expect(saveEnabled(tester), isFalse, reason: 'one confirmed fact is not enough');

    await confirmAll(tester);
    expect(saveEnabled(tester), isTrue);
    await tester.tap(find.byKey(onboardingSave));
    await tester.pumpAndSettle();

    final profile = (await store.load())!;
    expect(saved, same(profile));
    expect(profile.host.preferredAddress, 'Manang Lorna');
    expect(profile.host.usePo, isTrue);
    expect(profile.basePricePhp, 350);
    expect(profile.maxGroupSize, 12);
    expect(profile.activities.map((a) => (a.name, a.pricePhp, a.durationMinutes)), [
      ('Roasting workshop', 200, 45),
      ('Picking walk', 0, null),
    ]);
    expect(profile.safetyRules, ['Closed-toe shoes on the trail']);
  });

  testWidgets('changing a confirmed fact needs a new confirmation', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(onboarding());
    await answerAll(tester);
    await confirmAll(tester);

    await tester.tap(find.byKey(const Key('readback-edit-4'))); // base price
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '350'), findsOneWidget);
    await enterAndNext(tester, 'field-base-price', '400');

    expect(find.text('Tama po ba na PHP 400 bawat tao?'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);
    await tester.tap(find.byKey(const Key('readback-yes-4')));
    await tester.pump();
    expect(saveEnabled(tester), isTrue);
  });

  testWidgets('empty or invalid answers do not move on', (tester) async {
    await tester.pumpWidget(onboarding());
    await tester.tap(find.byKey(onboardingNext));
    await tester.pump();
    expect(find.byKey(const Key('onboarding-error')), findsOneWidget);
    expect(find.text('Paano ka gustong tawagin?'), findsOneWidget);

    await enterAndNext(tester, 'field-address', 'Kuya Ben');
    await tester.tap(find.byKey(onboardingNext)); // no po choice yet
    await tester.pump();
    expect(find.byKey(const Key('onboarding-error')), findsOneWidget);

    await tester.tap(find.byKey(const Key('po-no')));
    await tester.tap(find.byKey(onboardingNext));
    await tester.pumpAndSettle();
    await enterAndNext(tester, 'field-farm-name', 'Ben Farm');
    await enterAndNext(tester, 'field-directions', 'From the church');
    await enterAndNext(tester, 'field-base-price', 'tatlong daan');
    expect(find.byKey(const Key('onboarding-error')), findsOneWidget);
    expect(find.text('Magkano ang tour bawat tao?'), findsOneWidget);
  });

  testWidgets('host who declines "po" is not addressed with it', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(onboarding());
    await answerAll(tester, usePo: false);
    expect(find.text('Tama ba na PHP 350 bawat tao?'), findsOneWidget);
    expect(find.textContaining('po ba'), findsNothing);
  });

  testWidgets('app starts with onboarding when no profile is saved', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(TurAIstaApp(store: store));
    expect(find.text('Paano ka gustong tawagin?'), findsOneWidget);

    await answerAll(tester);
    await confirmAll(tester);
    await tester.tap(find.byKey(onboardingSave));
    await tester.pumpAndSettle();
    expect(find.text('Magandang araw, Manang Lorna!'), findsOneWidget);
  });

  testWidgets('app opens home when a profile is saved', (tester) async {
    final profile = loadExampleProfile();
    await tester.pumpWidget(
      TurAIstaApp(store: InMemoryProfileStore(profile), initialProfile: profile),
    );
    expect(find.text('Magandang araw, Manang Lorna!'), findsOneWidget);
    expect(find.text('Paano ka gustong tawagin?'), findsNothing);
  });

  testWidgets('existing profile opens on the read-back', (tester) async {
    useTallScreen(tester);
    final profile = loadExampleProfile();
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(store: store, initial: profile, onSaved: (p) => saved = p),
      ),
    );
    expect(find.text('Tama po ba lahat?'), findsOneWidget);
    await confirmAll(tester);
    await tester.tap(find.byKey(onboardingSave));
    await tester.pumpAndSettle();
    expect(saved!.toJson(), profile.toJson());
  });
}
