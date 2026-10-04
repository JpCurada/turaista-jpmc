import 'package:flutter/material.dart';
import 'package:turaista/core/intent_model.dart';
import 'package:turaista/core/language_id.dart';
import 'package:turaista/core/profile.dart';
import 'package:turaista/core/profile_store.dart';
import 'package:turaista/core/speech.dart';
import 'package:turaista/core/translator.dart';
import 'package:turaista/features/home/home_screen.dart';
import 'package:turaista/features/setup/language_download_screen.dart';
import 'package:turaista/features/setup/onboarding_screen.dart';

/// Shows onboarding until a verified profile is saved, then (once) the language
/// download screen, then the home screen.
class TurAIstaApp extends StatefulWidget {
  const TurAIstaApp({
    super.key,
    required this.store,
    this.initialProfile,
    this.translator = const IdentityTranslator(),
    this.languageModels,
    this.languageIdentifier,
    this.intentModel,
    this.loadIntentModel,
    this.speechInput,
    this.speechOutput,
  });

  final ProfileStore store;

  /// The profile loaded at startup, or null to start onboarding.
  final FarmProfile? initialProfile;

  final Translator translator;

  /// Offline language models; null skips the download step (tests, demos).
  final LanguageModels? languageModels;

  final LanguageIdentifier? languageIdentifier;

  /// Live Interpreter: null model means keywords only, null speech means typing only.
  final IntentModel? intentModel;
  final Future<void> Function()? loadIntentModel;
  final SpeechInput? speechInput;
  final SpeechOutput? speechOutput;

  @override
  State<TurAIstaApp> createState() => _TurAIstaAppState();
}

class _TurAIstaAppState extends State<TurAIstaApp> {
  late FarmProfile? _profile = widget.initialProfile;

  /// True right after first-time onboarding, until the host leaves the download step.
  bool _offerDownloads = false;

  void _onOnboarded(FarmProfile profile) => setState(() {
    _profile = profile;
    _offerDownloads = widget.languageModels != null;
  });

  void _onSaved(FarmProfile profile) => setState(() => _profile = profile);

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return MaterialApp(
      title: 'TurAIsta',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D32),
        useMaterial3: true,
        visualDensity: VisualDensity.comfortable,
      ),
      home: switch ((profile, widget.languageModels)) {
        (null, _) => OnboardingScreen(store: widget.store, onSaved: _onOnboarded),
        (_, final models?) when _offerDownloads => LanguageDownloadScreen(
          models: models,
          usePo: profile!.host.usePo,
          onDone: () => setState(() => _offerDownloads = false),
        ),
        (final profile?, _) => HomeScreen(
          profile: profile,
          store: widget.store,
          onProfileSaved: _onSaved,
          translator: widget.translator,
          languageModels: widget.languageModels,
          languageIdentifier: widget.languageIdentifier,
          intentModel: widget.intentModel,
          loadIntentModel: widget.loadIntentModel,
          speechInput: widget.speechInput,
          speechOutput: widget.speechOutput,
        ),
      },
    );
  }
}
