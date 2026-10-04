import 'package:flutter/material.dart';
import 'package:turaista/core/language_id.dart';
import 'package:turaista/core/onboarding.dart';
import 'package:turaista/core/translator.dart';

/// Models needed: English (ML Kit pivots through it), Tagalog (guest messages
/// for the host) and the MVP guest languages.
const List<String> downloadLanguages = ['en', 'tl', 'ko', 'ja', 'zh'];

enum _Status { checking, missing, downloading, ready, failed }

/// Journey stage 1, one time: download offline language models over Wi-Fi.
///
/// TODO(localization): Tagalog only; add 'ceb' and 'ilo' text written by native speakers.
class LanguageDownloadScreen extends StatefulWidget {
  const LanguageDownloadScreen({super.key, required this.models, required this.usePo, this.onDone});

  final LanguageModels models;
  final bool usePo;

  /// Shown as a "Tapos na" / "Mamaya na" button when this screen is part of
  /// first-time setup. Without it the app bar back button is used.
  final VoidCallback? onDone;

  @override
  State<LanguageDownloadScreen> createState() => _LanguageDownloadScreenState();
}

class _LanguageDownloadScreenState extends State<LanguageDownloadScreen> {
  final Map<String, _Status> _status = {
    for (final lang in downloadLanguages) lang: _Status.checking,
  };

  String _p(String plain, String po) => withPo(widget.usePo, plain, po);

  bool get _busy => _status.values.contains(_Status.downloading);
  bool get _allReady => _status.values.every((s) => s == _Status.ready);

  @override
  void initState() {
    super.initState();
    for (final lang in downloadLanguages) {
      _check(lang);
    }
  }

  Future<void> _check(String lang) async {
    var ready = false;
    try {
      ready = await widget.models.isDownloaded(lang);
    } on Exception {
      ready = false;
    }
    if (!mounted) return;
    setState(() => _status[lang] = ready ? _Status.ready : _Status.missing);
  }

  Future<void> _download(String lang) async {
    setState(() => _status[lang] = _Status.downloading);
    try {
      await widget.models.download(lang);
      if (!mounted) return;
      setState(() => _status[lang] = _Status.ready);
    } on Object {
      if (!mounted) return;
      setState(() => _status[lang] = _Status.failed);
    }
  }

  Future<void> _downloadAll() async {
    for (final lang in downloadLanguages) {
      if (_status[lang] != _Status.ready) await _download(lang);
    }
  }

  String _statusText(_Status status) => switch (status) {
    _Status.checking => 'Tinitingnan…',
    _Status.missing => 'Hindi pa naka-download',
    _Status.downloading => 'Dina-download…',
    _Status.ready => 'Naka-download na',
    _Status.failed => 'Hindi natuloy',
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final failed = _status.values.contains(_Status.failed);
    return Scaffold(
      appBar: AppBar(
        title: const Text('I-download ang mga wika'),
        automaticallyImplyLeading: widget.onDone == null,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Kailangan ito para masagot ang bisita sa sarili niyang wika.',
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gawin ito kapag may Wi-Fi. Isang beses lang ito. '
                    'Pagkatapos, gumagana na kahit walang signal.',
                    style: textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 12),
                  for (final lang in downloadLanguages)
                    Card(
                      key: Key('language-$lang'),
                      child: ListTile(
                        minVerticalPadding: 16,
                        title: Text(languageLabels[lang]!, style: textTheme.titleMedium),
                        subtitle: Text(_statusText(_status[lang]!)),
                        trailing: switch (_status[lang]!) {
                          _Status.ready => const Icon(Icons.check_circle, size: 32),
                          _Status.checking || _Status.downloading => const SizedBox.square(
                            dimension: 28,
                            child: CircularProgressIndicator(),
                          ),
                          _Status.missing || _Status.failed => IconButton(
                            key: Key('download-$lang'),
                            tooltip: 'I-download',
                            iconSize: 32,
                            onPressed: _busy ? null : () => _download(lang),
                            icon: const Icon(Icons.download),
                          ),
                        },
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (failed) ...[
                    Text(
                      _p(
                        'Hindi natapos ang download. Tiyaking naka-Wi-Fi ka, tapos subukan ulit.',
                        'Hindi po natapos ang download. Pakitiyak na naka-Wi-Fi kayo, tapos subukan ulit.',
                      ),
                      key: const Key('download-error'),
                      style: textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (!_allReady)
                    FilledButton.icon(
                      key: const Key('download-all'),
                      style: _bigButton,
                      onPressed: _busy ? null : _downloadAll,
                      icon: const Icon(Icons.download),
                      label: const Text('I-download lahat'),
                    ),
                  if (widget.onDone case final onDone?) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      key: const Key('download-done'),
                      style: _bigButton,
                      onPressed: _busy ? null : onDone,
                      child: Text(_allReady ? 'Tapos na' : 'Mamaya na'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static final ButtonStyle _bigButton = ButtonStyle(
    minimumSize: WidgetStateProperty.all(const Size.fromHeight(56)),
  );
}
