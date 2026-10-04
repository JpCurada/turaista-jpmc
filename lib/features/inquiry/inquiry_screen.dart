import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:turaista/core/guardrail.dart';
import 'package:turaista/core/host_text.dart';
import 'package:turaista/core/language_id.dart';
import 'package:turaista/core/pipeline.dart';
import 'package:turaista/core/profile.dart';
import 'package:turaista/core/translator.dart';

/// Journey stages 2 and 3: understand a guest message, draft or block a reply.
class InquiryScreen extends StatefulWidget {
  const InquiryScreen({
    super.key,
    required this.profile,
    this.translator = const IdentityTranslator(),
    this.languageIdentifier,
  });

  final FarmProfile profile;
  final Translator translator;

  /// Picks the guest language automatically. Without it, or when it is unsure,
  /// the host picks with the chips. The chips always override it.
  final LanguageIdentifier? languageIdentifier;

  @override
  State<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends State<InquiryScreen> {
  final TextEditingController _controller = TextEditingController();
  String _guestLang = 'en';
  InquiryResult? _result;
  bool _busy = false;

  /// Language the identifier picked for the current message, if any.
  String? _detected;

  /// The identifier was unsure about the current message, so English is used.
  bool _unsure = false;

  /// The message the current result is for.
  String _analyzed = '';

  /// The host tapped a chip for the current message; do not override it.
  bool _hostPicked = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onMessageChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _lastText = '';

  /// A new message gets detected again, even if the host picked a chip before.
  void _onMessageChanged() {
    if (_controller.text == _lastText) return;
    _lastText = _controller.text;
    if (_hostPicked || _detected != null || _unsure) {
      setState(() {
        _hostPicked = false;
        _detected = null;
        _unsure = false;
      });
    }
  }

  void _pickLanguage(String lang) => setState(() {
    _guestLang = lang;
    _hostPicked = true;
    _detected = null;
    _unsure = false;
  });

  /// Sets the guest language from the identifier, unless the host picked one
  /// for this message. When unsure, English: never the last message's language.
  Future<void> _detectLanguage(String text) async {
    final identifier = widget.languageIdentifier;
    if (identifier == null || _hostPicked) return;
    String? lang;
    try {
      lang = await identifier.identify(text);
    } on Object {
      lang = null;
    }
    // The host may have tapped a chip while detection ran: their choice wins.
    if (!mounted || _hostPicked) return;
    final supported = guestLanguageCodes.contains(lang);
    setState(() {
      _guestLang = supported ? lang! : 'en';
      _detected = supported ? lang : null;
      _unsure = !supported;
    });
  }

  Future<void> _analyze() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _detectLanguage(text);
      final result = await handleInquiry(
        message: text,
        guestLang: _guestLang,
        profile: widget.profile,
        translator: widget.translator,
      );
      if (mounted) {
        setState(() {
          _result = result;
          _analyzed = text;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Na-copy! I-paste sa Messenger o SMS.')));
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Mensahe ng bisita')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('inquiry-input'),
                controller: _controller,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'I-paste ang mensahe ng bisita',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Text('Wika ng bisita', style: Theme.of(context).textTheme.labelLarge),
              Wrap(
                spacing: 8,
                children: [
                  for (final lang in guestLanguageCodes)
                    ChoiceChip(
                      label: Text(languageLabels[lang]!),
                      selected: _guestLang == lang,
                      onSelected: (_) => _pickLanguage(lang),
                    ),
                ],
              ),
              if (_detected case final lang?)
                Text(
                  'Mukhang ${languageLabels[lang]} ang wika ng bisita. '
                  'Kung mali, pindutin ang tamang wika sa itaas.',
                  key: const Key('detected-language'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              if (_unsure)
                Text(
                  'Hindi tiyak ng app ang wika ng bisita, kaya English ang sagot. '
                  'Kung mali, pindutin ang tamang wika sa itaas.',
                  key: const Key('language-unsure'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('inquiry-submit'),
                onPressed: _busy ? null : _analyze,
                icon: const Icon(Icons.translate),
                label: const Text('Suriin'),
              ),
              if (result != null) ...[
                const SizedBox(height: 20),
                _ExplanationCard(text: result.hostExplanation),
                if (result.hostTranslation.outcome != TranslationOutcome.notNeeded) ...[
                  const SizedBox(height: 12),
                  _HostTranslationCard(
                    translation: result.hostTranslation,
                    original: _analyzed,
                    host: widget.profile.host,
                  ),
                ],
                if (translationNotice(result.translation, widget.profile.host)
                    case final notice?) ...[
                  const SizedBox(height: 12),
                  _TranslationNotice(text: notice),
                ],
                const SizedBox(height: 12),
                if (result.guardrail.allowed)
                  _DraftCard(result: result, onCopy: _copy)
                else
                  _BlockedCard(result: result, onCopy: _copy),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_outline),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
          ],
        ),
      ),
    );
  }
}

/// The guest's message in the host's language, clearly marked as machine output.
class _HostTranslationCard extends StatelessWidget {
  const _HostTranslationCard({
    required this.translation,
    required this.original,
    required this.host,
  });

  final HostTranslation translation;
  final String original;
  final HostPreferences host;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final note = hostTranslationNote(translation.outcome, host);
    // Lower trust when numbers changed: smaller text, original shown below.
    final flagged = translation.outcome == TranslationOutcome.numbersChanged;
    return Card(
      key: const Key('host-translation'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.g_translate, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(hostTranslationLabel(host), style: textTheme.labelLarge)),
              ],
            ),
            if (translation.text case final text?) ...[
              const SizedBox(height: 8),
              Text(
                text,
                key: const Key('host-translation-text'),
                style: flagged ? textTheme.bodyMedium : textTheme.titleMedium,
              ),
            ],
            if (note != null) ...[
              const SizedBox(height: 8),
              Text(
                note,
                key: const Key('host-translation-note'),
                style: textTheme.bodyMedium?.copyWith(color: colors.error),
              ),
            ],
            if (flagged) ...[
              const SizedBox(height: 8),
              Text('Orihinal na mensahe:', style: textTheme.labelLarge),
              Text(original, key: const Key('host-translation-original')),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shown when the guest reply fell back to English.
class _TranslationNotice extends StatelessWidget {
  const _TranslationNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: const Key('translation-notice'),
      color: colors.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.translate, color: colors.onTertiaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: colors.onTertiaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({required this.result, required this.onCopy});

  final InquiryResult result;
  final Future<void> Function(String text) onCopy;

  @override
  Widget build(BuildContext context) {
    final facts = result.draft?.factsUsed ?? const <String>[];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Draft na sagot (basahin muna bago ipadala):'),
            const SizedBox(height: 8),
            Text(result.guestReply),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final fact in facts)
                  Chip(label: Text(fact), visualDensity: VisualDensity.compact),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('approve-copy'),
              onPressed: () => onCopy(result.guestReply),
              icon: const Icon(Icons.copy),
              label: const Text('Aprubahan at kopyahin'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockedCard extends StatelessWidget {
  const _BlockedCard({required this.result, required this.onCopy});

  final InquiryResult result;
  final Future<void> Function(String text) onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: colors.onErrorContainer),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(hostFallback, style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Hindi gagawa ng sagot ang app para dito.'),
            const SizedBox(height: 12),
            const Text('Pansamantalang sagot sa bisita:'),
            Text(result.guestReply),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => onCopy(result.guestReply),
              icon: const Icon(Icons.copy),
              label: const Text('Kopyahin'),
            ),
          ],
        ),
      ),
    );
  }
}
