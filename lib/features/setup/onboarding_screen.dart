import 'package:flutter/material.dart';
import 'package:turaista/core/onboarding.dart';
import 'package:turaista/core/profile.dart';
import 'package:turaista/core/profile_store.dart';
import 'package:turaista/core/reply.dart';

/// Journey stage 1: one question per page, then a "Tama ba?" read-back of
/// every fact. Nothing is saved until the host confirms each fact.
///
/// With [initial], the screen opens on the read-back so the host can check
/// and change an existing profile.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.store, required this.onSaved, this.initial});

  final ProfileStore store;
  final ValueChanged<FarmProfile> onSaved;
  final FarmProfile? initial;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static final int _reviewPage = OnboardingStep.values.length;

  final _address = TextEditingController();
  final _farmName = TextEditingController();
  final _directions = TextEditingController();
  final _basePrice = TextEditingController();
  final _groupSize = TextEditingController();
  final _activityName = TextEditingController();
  final _activityPrice = TextEditingController();
  final _activityMinutes = TextEditingController();
  final _rule = TextEditingController();

  bool? _usePo;
  final List<Activity> _activities = [];
  final List<String> _rules = [];

  int _page = 0;
  bool _backToReview = false;
  String? _error;
  bool _saving = false;

  /// Fact key -> the exact question the host confirmed. A fact edited after
  /// confirming gets a new question, so it must be confirmed again.
  final Map<String, String> _confirmed = {};

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial == null) return;
    _address.text = initial.host.preferredAddress;
    _usePo = initial.host.usePo;
    _farmName.text = initial.farmName;
    _directions.text = initial.locationHint;
    _basePrice.text = '${initial.basePricePhp}';
    _groupSize.text = '${initial.maxGroupSize}';
    _activities.addAll(initial.activities);
    _rules.addAll(initial.safetyRules);
    _page = _reviewPage;
  }

  @override
  void dispose() {
    for (final c in [
      _address,
      _farmName,
      _directions,
      _basePrice,
      _groupSize,
      _activityName,
      _activityPrice,
      _activityMinutes,
      _rule,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  OnboardingStep get _step => OnboardingStep.values[_page];

  /// True once the host chose "po". Before that choice, text stays plain.
  bool get _po => _usePo ?? false;

  String _p(String plain, String po) => withPo(_po, plain, po);

  /// Adds the activity being typed. Returns an error, or null when added or blank.
  String? _addActivity() {
    if (_activityName.text.trim().isEmpty) {
      final typedSomething = _activityPrice.text.trim().isNotEmpty;
      return typedSomething
          ? _p('Pakisulat ang pangalan ng activity.', 'Pakisulat po muna ang pangalan ng activity.')
          : null;
    }
    final error =
        validatePrice(_activityPrice.text, usePo: _po) ??
        validateOptionalPositive(_activityMinutes.text, usePo: _po);
    if (error != null) return error;
    final minutes = _activityMinutes.text.trim();
    _activities.add(
      Activity(
        name: _activityName.text.trim(),
        pricePhp: parseWholeNumber(_activityPrice.text)!,
        durationMinutes: minutes.isEmpty ? null : parseWholeNumber(minutes),
      ),
    );
    _activityName.clear();
    _activityPrice.clear();
    _activityMinutes.clear();
    return null;
  }

  /// Adds the rule being typed, if any. Never an error: rules are optional.
  String? _addRule() {
    final rule = _rule.text.trim();
    if (rule.isEmpty) return null;
    _rules.add(rule);
    _rule.clear();
    return null;
  }

  String? _validateStep() => switch (_step) {
    OnboardingStep.address => validateRequired(_address.text, usePo: _po),
    OnboardingStep.po => _usePo == null ? 'Pindutin ang isa sa dalawa.' : null,
    OnboardingStep.farmName => validateRequired(_farmName.text, usePo: _po),
    OnboardingStep.directions => validateRequired(_directions.text, usePo: _po),
    OnboardingStep.basePrice => validatePrice(_basePrice.text, usePo: _po),
    OnboardingStep.groupSize => validatePositive(_groupSize.text, usePo: _po),
    OnboardingStep.activities => _addActivity(),
    OnboardingStep.safetyRules => _addRule(),
  };

  void _next() {
    final error = _validateStep();
    setState(() {
      _error = error;
      if (error != null) return;
      final last = _page == OnboardingStep.values.length - 1;
      _page = _backToReview || last ? _reviewPage : _page + 1;
      if (_page == _reviewPage) _backToReview = false;
    });
  }

  void _back() {
    setState(() {
      _error = null;
      if (_backToReview) {
        _backToReview = false;
        _page = _reviewPage;
      } else if (_page > 0) {
        _page--;
      }
    });
  }

  void _edit(OnboardingStep step) {
    setState(() {
      _error = null;
      _backToReview = true;
      _page = step.index;
    });
  }

  /// The profile as answered so far. Only valid once every step passed.
  FarmProfile _draft() => FarmProfile(
    farmName: _farmName.text.trim(),
    locationHint: _directions.text.trim(),
    host: HostPreferences(
      preferredAddress: _address.text.trim(),
      // Only Tagalog host text exists so far; keep an existing choice when editing.
      language: widget.initial?.host.language ?? 'tl',
      usePo: _usePo!,
      voice: widget.initial?.host.voice,
      simpleExplanations: widget.initial?.host.simpleExplanations ?? false,
    ),
    basePricePhp: parseWholeNumber(_basePrice.text)!,
    maxGroupSize: parseWholeNumber(_groupSize.text)!,
    activities: List.unmodifiable(_activities),
    safetyRules: List.unmodifiable(_rules),
  );

  Future<void> _save(FarmProfile profile) async {
    setState(() => _saving = true);
    try {
      await widget.store.save(profile);
    } on Exception {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _p(
              'Hindi na-save ang impormasyon ng farm. Pakisubukan ulit.',
              'Hindi po na-save ang impormasyon ng farm. Pakisubukan ulit.',
            ),
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved(profile);
  }

  @override
  Widget build(BuildContext context) {
    final total = OnboardingStep.values.length + 1;
    return Scaffold(
      appBar: AppBar(
        title: Text('Tungkol sa farm (${_page + 1} sa $total)'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: (_page + 1) / total),
        ),
      ),
      body: SafeArea(child: _page == _reviewPage ? _buildReview(context) : _buildStep(context)),
    );
  }

  Widget _buildStep(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (question, help) = _questionFor(_step);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(question, style: textTheme.headlineSmall),
              if (help != null) ...[
                const SizedBox(height: 8),
                Text(help, style: textTheme.bodyLarge),
              ],
              const SizedBox(height: 16),
              ..._inputsFor(_step),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  key: const Key('onboarding-error'),
                  style: textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (_page > 0 || _backToReview)
                Expanded(
                  child: OutlinedButton(
                    key: const Key('onboarding-back'),
                    style: _bigButton,
                    onPressed: _back,
                    child: const Text('Bumalik'),
                  ),
                ),
              if (_page > 0 || _backToReview) const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('onboarding-next'),
                  style: _bigButton,
                  onPressed: _next,
                  child: const Text('Susunod'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static final ButtonStyle _bigButton = ButtonStyle(
    minimumSize: WidgetStateProperty.all(const Size.fromHeight(56)),
  );

  (String, String?) _questionFor(OnboardingStep step) => switch (step) {
    OnboardingStep.address => (
      'Paano ka gustong tawagin?',
      'Ito ang itatawag sa iyo ng app. Halimbawa: "Manang Lorna", "Kuya Ben", o pangalan lang.',
    ),
    OnboardingStep.po => ('Gusto mo bang may "po" kapag kinakausap ka ng app?', null),
    OnboardingStep.farmName => (
      _p('Ano ang pangalan ng farm mo?', 'Ano po ang pangalan ng farm ninyo?'),
      null,
    ),
    OnboardingStep.directions => (
      _p('Paano pumunta sa farm?', 'Paano po pumunta sa farm?'),
      'Magsimula sa lugar na kilala ng lahat, gaya ng palengke o simbahan.',
    ),
    OnboardingStep.basePrice => (
      _p('Magkano ang tour bawat tao?', 'Magkano po ang tour bawat tao?'),
      'Piso ang ilagay. Numero lang.',
    ),
    OnboardingStep.groupSize => (
      _p(
        'Ilan ang pinakamaraming bisita sa isang grupo?',
        'Ilan po ang pinakamaraming bisita sa isang grupo?',
      ),
      _p(
        'Ilang tao ang kaya mong samahan nang sabay-sabay?',
        'Ilang tao po ang kaya ninyong samahan nang sabay-sabay?',
      ),
    ),
    OnboardingStep.activities => (
      _p('Ano-ano ang mga activity sa farm?', 'Ano-ano po ang mga activity sa farm?'),
      'Halimbawa: pamimitas ng kape, pagluluto. Puwedeng wala. '
          'Pindutin ang "Idagdag" sa bawat isa.',
    ),
    OnboardingStep.safetyRules => (
      _p(
        'Ano ang mga bilin mo sa bisita para sa kaligtasan?',
        'Ano po ang mga bilin ninyo sa bisita para sa kaligtasan?',
      ),
      'Halimbawa: sapatos sa trail, bantay sa mga bata, walang tour kapag malakas ang ulan.',
    ),
  };

  List<Widget> _inputsFor(OnboardingStep step) => switch (step) {
    OnboardingStep.address => [_field(const Key('field-address'), _address, 'Tawag sa iyo')],
    OnboardingStep.po => [
      _choice(const Key('po-yes'), 'Oo, may "po"', _usePo == true, () => _usePo = true),
      const SizedBox(height: 12),
      _choice(const Key('po-no'), 'Hindi na kailangan', _usePo == false, () => _usePo = false),
    ],
    OnboardingStep.farmName => [
      _field(const Key('field-farm-name'), _farmName, 'Pangalan ng farm'),
    ],
    OnboardingStep.directions => [
      _field(const Key('field-directions'), _directions, 'Direksyon', lines: 5),
    ],
    OnboardingStep.basePrice => [
      _field(const Key('field-base-price'), _basePrice, 'Presyo bawat tao', number: true),
    ],
    OnboardingStep.groupSize => [
      _field(const Key('field-group-size'), _groupSize, 'Pinakamaraming bisita', number: true),
    ],
    OnboardingStep.activities => [
      for (final (i, a) in _activities.indexed)
        _addedRow(
          Key('activity-row-$i'),
          a.name,
          a.pricePhp == 0 ? 'kasama na' : formatPhp(a.pricePhp),
          () => setState(() => _activities.removeAt(i)),
        ),
      _field(const Key('field-activity-name'), _activityName, 'Pangalan ng activity'),
      const SizedBox(height: 12),
      _field(
        const Key('field-activity-price'),
        _activityPrice,
        'Dagdag na bayad',
        helper: 'Isulat ang 0 kung kasama na sa presyo ng tour.',
        number: true,
      ),
      const SizedBox(height: 12),
      _field(
        const Key('field-activity-minutes'),
        _activityMinutes,
        'Ilang minuto (puwedeng iwanang blangko)',
        number: true,
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        key: const Key('activity-add'),
        style: _bigButton,
        onPressed: () => setState(() => _error = _addActivity()),
        icon: const Icon(Icons.add),
        label: const Text('Idagdag'),
      ),
    ],
    OnboardingStep.safetyRules => [
      for (final (i, rule) in _rules.indexed)
        _addedRow(Key('rule-row-$i'), rule, null, () => setState(() => _rules.removeAt(i))),
      _field(const Key('field-rule'), _rule, 'Bilin', lines: 2),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        key: const Key('rule-add'),
        style: _bigButton,
        onPressed: () => setState(() => _addRule()),
        icon: const Icon(Icons.add),
        label: const Text('Idagdag'),
      ),
    ],
  };

  Widget _field(
    Key key,
    TextEditingController controller,
    String label, {
    int lines = 1,
    bool number = false,
    String? helper,
  }) {
    return TextField(
      key: key,
      controller: controller,
      minLines: lines,
      maxLines: lines,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      textCapitalization: number ? TextCapitalization.none : TextCapitalization.sentences,
      style: Theme.of(context).textTheme.titleMedium,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 2,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _choice(Key key, String label, bool selected, VoidCallback select) {
    void onPressed() => setState(() {
      select();
      _error = null;
    });
    final child = Text(label);
    return selected
        ? FilledButton.icon(
          key: key,
          style: _bigButton,
          onPressed: onPressed,
          icon: const Icon(Icons.check),
          label: child,
        )
        : OutlinedButton(key: key, style: _bigButton, onPressed: onPressed, child: child);
  }

  Widget _addedRow(Key key, String title, String? subtitle, VoidCallback remove) {
    return Card(
      key: key,
      child: ListTile(
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: IconButton(
          tooltip: 'Alisin',
          icon: const Icon(Icons.delete_outline),
          onPressed: remove,
        ),
      ),
    );
  }

  Widget _buildReview(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final profile = _draft();
    final items = readBackItems(profile);
    bool isConfirmed(ReadBackItem item) => _confirmed[item.key] == item.question;
    final allConfirmed = items.every(isConfirmed);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(_p('Tama ba lahat?', 'Tama po ba lahat?'), style: textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Basahin ang bawat isa. Pindutin ang "Oo, tama" o "Baguhin".',
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              for (final (i, item) in items.indexed)
                Card(
                  key: Key('readback-$i'),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(item.label, style: textTheme.labelLarge),
                        const SizedBox(height: 4),
                        Text(item.question, style: textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child:
                                  isConfirmed(item)
                                      ? FilledButton.icon(
                                        key: Key('readback-yes-$i'),
                                        style: _bigButton,
                                        onPressed: null,
                                        icon: const Icon(Icons.check),
                                        label: const Text('Tama'),
                                      )
                                      : FilledButton.tonal(
                                        key: Key('readback-yes-$i'),
                                        style: _bigButton,
                                        onPressed:
                                            () => setState(
                                              () => _confirmed[item.key] = item.question,
                                            ),
                                        child: const Text('Oo, tama'),
                                      ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                key: Key('readback-edit-$i'),
                                style: _bigButton,
                                onPressed: () => _edit(item.step),
                                child: const Text('Baguhin'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
              if (!allConfirmed) ...[
                Text(
                  'Tapos na: ${items.where(isConfirmed).length} sa ${items.length}',
                  key: const Key('readback-progress'),
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
              ],
              FilledButton.icon(
                key: const Key('onboarding-save'),
                style: _bigButton,
                onPressed: allConfirmed && !_saving ? () => _save(profile) : null,
                icon: const Icon(Icons.save_outlined),
                label: const Text('I-save na'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
