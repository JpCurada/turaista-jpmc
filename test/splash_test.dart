import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turaista/features/home/splash_screen.dart';

void main() {
  testWidgets('splash stays until its animation plays, then shows the app', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(SplashGate(load: () async => const MaterialApp(home: Text('ready'))));

    // The name fades in first; at opacity 0 it is not yet in the semantics tree.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.bySemanticsLabel('turAIsta'), findsOneWidget);
    expect(find.text('ready'), findsNothing);

    await tester.pump(SplashScreen.duration);
    await tester.pumpAndSettle();
    expect(find.text('ready'), findsOneWidget);
    expect(find.text('a small AI for travelers'), findsNothing);
    semantics.dispose();
  });

  testWidgets('reduced motion shows the finished name at once', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: SplashScreen()),
      ),
    );
    await tester.pump();
    final tagline = tester.widget<Opacity>(
      find.ancestor(of: find.text('a small AI for travelers'), matching: find.byType(Opacity)),
    );
    expect(tagline.opacity, 1);
  });
}
