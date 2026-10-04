import 'package:flutter/material.dart';
import 'package:turaista/core/intent_model.dart';
import 'package:turaista/core/language_id.dart';
import 'package:turaista/core/profile.dart';
import 'package:turaista/core/profile_store.dart';
import 'package:turaista/core/speech.dart';
import 'package:turaista/core/translator.dart';
import 'package:turaista/features/inquiry/inquiry_screen.dart';
import 'package:turaista/features/interpreter/interpreter_screen.dart';
import 'package:turaista/features/interpreter/traveler_card_screen.dart';
import 'package:turaista/features/setup/language_download_screen.dart';
import 'package:turaista/features/setup/onboarding_screen.dart';

/// Session picker: the host chooses what is happening right now instead of
/// facing a blank prompt box.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.profile,
    this.store,
    this.onProfileSaved,
    this.translator = const IdentityTranslator(),
    this.languageModels,
    this.languageIdentifier,
    this.intentModel,
    this.loadIntentModel,
    this.speechInput,
    this.speechOutput,
  });

  final FarmProfile profile;

  /// Where a re-checked profile is saved. Without it the farm profile card is hidden.
  final ProfileStore? store;
  final ValueChanged<FarmProfile>? onProfileSaved;

  /// Puts draft replies into the guest's language.
  final Translator translator;

  /// Offline language models. Without it the download card is hidden.
  final LanguageModels? languageModels;

  /// Detects the guest language on the inquiry screen; null means chips only.
  final LanguageIdentifier? languageIdentifier;

  /// Live Interpreter: intent model (null = keywords only), its loader, and speech
  /// (null = typing only).
  final IntentModel? intentModel;
  final Future<void> Function()? loadIntentModel;
  final SpeechInput? speechInput;
  final SpeechOutput? speechOutput;

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('TurAIsta')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Magandang araw, ${profile.host.preferredAddress}!',
              style: textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text('Ano ang nangyayari ngayon?', style: textTheme.bodyLarge),
            const SizedBox(height: 16),
            _SessionCard(
              icon: Icons.mark_email_unread_outlined,
              title: 'May mensahe ang bisita',
              subtitle: 'Intindihin ang tanong at gumawa ng sagot',
              onTap:
                  () => _open(
                    context,
                    InquiryScreen(
                      profile: profile,
                      translator: translator,
                      languageIdentifier: languageIdentifier,
                    ),
                  ),
            ),
            _SessionCard(
              icon: Icons.record_voice_over_outlined,
              title: 'Live Interpreter',
              subtitle: 'May bisita sa farm ngayon',
              onTap:
                  () => _open(
                    context,
                    TravelerCardScreen(
                      onStart:
                          (traveler) => Navigator.of(context).pushReplacement(
                            MaterialPageRoute<void>(
                              builder:
                                  (_) => InterpreterScreen(
                                    profile: profile,
                                    traveler: traveler,
                                    translator: translator,
                                    languageModels: languageModels,
                                    intentModel: intentModel,
                                    loadIntentModel: loadIntentModel,
                                    speechInput: speechInput,
                                    speechOutput: speechOutput,
                                  ),
                            ),
                          ),
                    ),
                  ),
            ),
            if (languageModels case final models?)
              _SessionCard(
                icon: Icons.download_for_offline_outlined,
                title: 'I-download ang mga wika',
                subtitle: 'Para masagot ang bisita sa wika niya. Kailangan ng Wi-Fi.',
                onTap:
                    () => _open(
                      context,
                      LanguageDownloadScreen(models: models, usePo: profile.host.usePo),
                    ),
              ),
            if (store case final store?)
              _SessionCard(
                icon: Icons.agriculture_outlined,
                title: 'Tungkol sa farm',
                subtitle: 'Tingnan at itama ang presyo at mga bilin',
                onTap:
                    () => _open(
                      context,
                      OnboardingScreen(
                        store: store,
                        initial: profile,
                        onSaved: (saved) {
                          Navigator.of(context).pop();
                          onProfileSaved?.call(saved);
                        },
                      ),
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        minVerticalPadding: 16,
        leading: Icon(icon, size: 36),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
