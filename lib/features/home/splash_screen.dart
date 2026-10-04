import 'package:flutter/material.dart';

/// Shows [SplashScreen] while [load] builds the app, then fades to it. The
/// splash stays until its animation has played once, so it never flickers.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.load});

  final Future<Widget> Function() load;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  Widget? _app;
  final Future<void> _played = Future<void>.delayed(SplashScreen.duration);

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final app = await widget.load();
    await _played;
    if (mounted) setState(() => _app = app);
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 400),
    child: _app ?? const MaterialApp(debugShowCheckedModeBanner: false, home: SplashScreen()),
  );
}

/// The name plays on "turista", Filipino for tourist: an A slides in and the
/// i stands up, so "turista" becomes "turAIsta".
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const duration = Duration(milliseconds: 2200);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: SplashScreen.duration,
  );

  late final Animation<double> _word = _step(0, 0.25, Curves.easeOut);
  late final Animation<double> _a = _step(0.35, 0.6, Curves.easeOutBack);
  late final Animation<double> _i = _step(0.45, 0.65, Curves.easeInOut);
  late final Animation<double> _tagline = _step(0.7, 0.95, Curves.easeOut);

  Animation<double> _step(double begin, double end, Curve curve) =>
      CurvedAnimation(parent: _c, curve: Interval(begin, end, curve: curve));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32));
    final base = Theme.of(context).textTheme.displayMedium!.copyWith(
      color: scheme.onPrimary,
      fontWeight: FontWeight.w300,
      letterSpacing: 1,
    );
    final ai = base.copyWith(color: scheme.primaryFixedDim, fontWeight: FontWeight.w700);

    return Scaffold(
      backgroundColor: scheme.primary,
      body: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder:
              (context, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: _word.value,
                    child: Transform.translate(
                      offset: Offset(0, 16 * (1 - _word.value)),
                      child: Semantics(
                        label: 'turAIsta',
                        excludeSemantics: true,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text('tur', style: base),
                            ClipRect(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                widthFactor: _a.value.clamp(0, 1),
                                child: Transform.translate(
                                  offset: Offset(0, -24 * (1 - _a.value)),
                                  child: Opacity(
                                    opacity: _a.value.clamp(0, 1),
                                    child: Text('A', style: ai),
                                  ),
                                ),
                              ),
                            ),
                            Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                Opacity(opacity: 1 - _i.value, child: Text('i', style: base)),
                                Opacity(opacity: _i.value, child: Text('I', style: ai)),
                              ],
                            ),
                            Text('sta', style: base),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Opacity(
                    opacity: _tagline.value,
                    child: Text(
                      'a small AI for travelers',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: scheme.onPrimary.withAlpha(220)),
                    ),
                  ),
                ],
              ),
        ),
      ),
    );
  }
}
