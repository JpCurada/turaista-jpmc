import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const onboardingNext = Key('onboarding-next');
const onboardingSave = Key('onboarding-save');

/// Room for the whole read-back list without scrolling.
void useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> enterAndNext(WidgetTester tester, String field, String text) async {
  await tester.enterText(find.byKey(Key(field)), text);
  await tester.tap(find.byKey(onboardingNext));
  await tester.pumpAndSettle();
}

/// Answers every question; ends on the read-back page.
Future<void> answerAll(WidgetTester tester, {bool usePo = true}) async {
  await enterAndNext(tester, 'field-address', 'Manang Lorna');
  await tester.tap(find.byKey(Key(usePo ? 'po-yes' : 'po-no')));
  await tester.tap(find.byKey(onboardingNext));
  await tester.pumpAndSettle();
  await enterAndNext(tester, 'field-farm-name', "Lorna's Highland Coffee Farm");
  await enterAndNext(tester, 'field-directions', 'From the km 42 marker, turn left.');
  await enterAndNext(tester, 'field-base-price', '350');
  await enterAndNext(tester, 'field-group-size', '12');

  await tester.enterText(find.byKey(const Key('field-activity-name')), 'Roasting workshop');
  await tester.enterText(find.byKey(const Key('field-activity-price')), '200');
  await tester.enterText(find.byKey(const Key('field-activity-minutes')), '45');
  await tester.tap(find.byKey(const Key('activity-add')));
  await tester.pumpAndSettle();
  // Typed but not added: "Susunod" adds it instead of dropping it.
  await tester.enterText(find.byKey(const Key('field-activity-name')), 'Picking walk');
  await enterAndNext(tester, 'field-activity-price', '0');

  await enterAndNext(tester, 'field-rule', 'Closed-toe shoes on the trail');
}

bool saveEnabled(WidgetTester tester) =>
    tester.widget<ButtonStyleButton>(find.byKey(onboardingSave)).enabled;

Future<void> confirmAll(WidgetTester tester) async {
  for (var i = 0; find.byKey(Key('readback-yes-$i')).evaluate().isNotEmpty; i++) {
    await tester.tap(find.byKey(Key('readback-yes-$i')));
    await tester.pump();
  }
}
