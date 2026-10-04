import 'package:flutter/material.dart';
import 'package:turaista/core/conversation.dart';
import 'package:turaista/core/language_id.dart';
import 'package:turaista/features/interpreter/traveler_strings.dart';

/// Start of every chat. The guest fills it in: language first, then party size
/// and needs. Nothing is guessed; the guest taps everything.
class TravelerCardScreen extends StatefulWidget {
  const TravelerCardScreen({super.key, required this.onStart});

  final ValueChanged<TravelerCard> onStart;

  @override
  State<TravelerCardScreen> createState() => _TravelerCardScreenState();
}

class _TravelerCardScreenState extends State<TravelerCardScreen> {
  static const int _maxParty = 20;

  String? _language;
  int? _partySize;
  final Set<TravelerNeed> _needs = {};

  void _changeParty(int delta) => setState(() {
    final current = _partySize;
    if (current == null) {
      if (delta > 0) _partySize = 1;
      return;
    }
    _partySize = (current + delta).clamp(1, _maxParty);
  });

  @override
  Widget build(BuildContext context) {
    final lang = _language;
    final strings = lang == null ? null : travelerStrings[lang];
    return Scaffold(
      appBar: AppBar(title: const Text('Ibigay ang phone sa bisita')),
      body: SafeArea(child: strings == null ? _picker(context) : _card(context, lang!, strings)),
    );
  }

  Widget _picker(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Language / 언어 / 言語 / 语言',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        for (final code in guestLanguageCodes)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FilledButton.tonal(
              key: Key('traveler-lang-$code'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
              onPressed: () => setState(() => _language = code),
              child: Text(
                languageLabels[code] ?? code,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
      ],
    );
  }

  Widget _card(BuildContext context, String lang, TravelerStrings s) {
    final theme = Theme.of(context);
    final labels = {
      TravelerNeed.food: (Icons.restaurant_outlined, s.food),
      TravelerNeed.health: (Icons.favorite_border, s.health),
      TravelerNeed.children: (Icons.child_care_outlined, s.children),
      TravelerNeed.mobility: (Icons.accessible_forward, s.mobility),
    };
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const Key('traveler-back'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => setState(() => _language = null),
            icon: const Icon(Icons.arrow_back),
            label: Text(s.back),
          ),
        ),
        Text(s.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        Text(s.party, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              key: const Key('traveler-party-minus'),
              iconSize: 32,
              constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
              onPressed: () => _changeParty(-1),
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 80,
              child: Text(
                _partySize?.toString() ?? '-',
                key: const Key('traveler-party-count'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
            ),
            IconButton.filledTonal(
              key: const Key('traveler-party-plus'),
              iconSize: 32,
              constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
              onPressed: () => _changeParty(1),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(s.needs, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final need in TravelerNeed.values)
              FilterChip(
                key: Key('traveler-need-${need.name}'),
                avatar: Icon(labels[need]!.$1),
                label: Text(labels[need]!.$2),
                labelStyle: theme.textTheme.titleSmall,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                selected: _needs.contains(need),
                onSelected:
                    (on) => setState(() {
                      if (on) {
                        _needs.add(need);
                      } else {
                        _needs.remove(need);
                      }
                    }),
              ),
          ],
        ),
        const SizedBox(height: 32),
        FilledButton(
          key: const Key('traveler-start'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
          onPressed:
              () => widget.onStart(
                TravelerCard(language: lang, partySize: _partySize, needs: {..._needs}),
              ),
          child: Text(
            s.start,
            style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onPrimary),
          ),
        ),
      ],
    );
  }
}
