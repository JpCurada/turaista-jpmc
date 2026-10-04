// Named widget_test.dart on purpose: `flutter create .` skips existing files,
// so it will not generate its default counter test here.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turaista/core/guardrail.dart';
import 'package:turaista/features/home/home_screen.dart';
import 'package:turaista/features/inquiry/inquiry_screen.dart';

import 'helpers.dart';

void main() {
  final profile = loadExampleProfile();

  testWidgets('home greets the host by preferred address', (tester) async {
    await tester.pumpWidget(MaterialApp(home: HomeScreen(profile: profile)));
    expect(find.text('Magandang araw, Manang Lorna!'), findsOneWidget);
  });

  testWidgets('allergy question is blocked with the fallback', (tester) async {
    await tester.pumpWidget(MaterialApp(home: InquiryScreen(profile: profile)));
    await tester.enterText(find.byKey(const Key('inquiry-input')), 'My son has a peanut allergy');
    await tester.tap(find.byKey(const Key('inquiry-submit')));
    await tester.pumpAndSettle();
    expect(find.text(hostFallback), findsOneWidget);
    expect(find.byKey(const Key('approve-copy')), findsNothing);
  });

  testWidgets('price question shows a draft to approve', (tester) async {
    await tester.pumpWidget(MaterialApp(home: InquiryScreen(profile: profile)));
    await tester.enterText(find.byKey(const Key('inquiry-input')), 'How much is the tour?');
    await tester.tap(find.byKey(const Key('inquiry-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('approve-copy')), findsOneWidget);
    expect(find.text(hostFallback), findsNothing);
  });
}
