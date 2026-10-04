import 'dart:async';

import 'package:flutter/material.dart';
import 'package:turaista/core/conversation.dart';
import 'package:turaista/core/guardrail.dart';
import 'package:turaista/core/host_text.dart';
import 'package:turaista/core/intent_model.dart';
import 'package:turaista/core/language_id.dart';
import 'package:turaista/core/profile.dart';
import 'package:turaista/core/speech.dart';
import 'package:turaista/core/translator.dart';
import 'package:turaista/features/interpreter/traveler_strings.dart';

/// Journey stage 4: face-to-face chat on one shared phone, lying flat.
///
/// The top half faces the guest (rotated 180 degrees) and shows the guest's
/// language only. The bottom half faces the host: Tagalog meaning, replies to
/// tap, and the host mic. Tapping a reply speaks it, so that tap is the host's
/// approval. Everything runs offline; typing always works.
class InterpreterScreen extends StatefulWidget {
  const InterpreterScreen({
    super.key,
    required this.profile,
    required this.traveler,
    this.translator = const IdentityTranslator(),
    this.languageModels,
    this.intentModel,
    this.loadIntentModel,
    this.speechInput,
    this.speechOutput,
    this.runGuestTurn = handleGuestTurn,
  });

  /// Runs one guest turn. Tests replace it to prove the failure path.
  @visibleForTesting
  final Future<GuestTurn> Function({
    required String message,
    required TravelerCard traveler,
    required FarmProfile profile,
    Translator translator,
    IntentModel? model,
  })
  runGuestTurn;

  final FarmProfile profile;
  final TravelerCard traveler;
  final Translator translator;

  /// Used only for the hint when the guest language is not on the phone yet.
  final LanguageModels? languageModels;

  /// Null means keyword mode only.
  final IntentModel? intentModel;

  /// Loads [intentModel] when the chat opens. Until it finishes, keywords decide.
  /// Null means the model is ready at once.
  final Future<void> Function()? loadIntentModel;

  /// Null means typing only.
  final SpeechInput? speechInput;
  final SpeechOutput? speechOutput;

  @override
  State<InterpreterScreen> createState() => _InterpreterScreenState();
}

enum _Side { guest, host }

enum _ModelState { none, loading, ready }

class _GuestMsg {
  _GuestMsg(this.text);

  final String text;
  GuestTurn? turn;
  bool failed = false;

  /// Safe replies offered when the turn itself failed (never an answer).
  List<Suggestion> fallback = const [];
}

class _HostMsg {
  _HostMsg({required this.text, required this.forGuest, required this.spoken, this.lang});

  /// What the host said or approved, in the host's language.
  final String text;

  /// What the guest hears; null when it could not be translated safely.
  final String? forGuest;
  bool spoken;

  /// Language it was spoken in; null means the guest's language. English only
  /// after the host confirmed an English fallback.
  final String? lang;
}

/// "a, b at c", like the host explanation text.
String _joinWithAt(List<String> items) =>
    items.length <= 1
        ? items.join()
        : '${items.sublist(0, items.length - 1).join(', ')} at ${items.last}';

const Map<TravelerNeed, String> _needNames = {
  TravelerNeed.food: 'pagkain o allergy',
  TravelerNeed.health: 'kalusugan',
  TravelerNeed.children: 'may kasamang bata',
  TravelerNeed.mobility: 'hirap maglakad',
};

class _InterpreterScreenState extends State<InterpreterScreen> {
  // One text field per side, so host text is never sent as the guest's.
  final _guestInput = TextEditingController();
  final _hostInput = TextEditingController();
  final _scroll = ScrollController();
  final List<Object> _messages = [];

  _GuestMsg? _current;
  final Set<int> _expanded = {};

  /// Replies already said this turn: dimmed, repeated only with Ulitin.
  final Set<Suggestion> _used = {};

  /// An English fallback waiting for the host's yes.
  Suggestion? _confirming;

  /// Which side has the keyboard open; null means both use the mic.
  _Side? _typing;
  _Side? _listening;
  String _partial = '';
  String? _notice;
  bool _speaking = false;
  Suggestion? _speakingSuggestion;

  bool _speechChecked = false;
  final Map<_Side, bool> _micOk = {_Side.guest: false, _Side.host: false};
  bool _voiceOk = false;
  bool _enVoiceOk = false;
  bool _needsDownload = false;
  late _ModelState _model =
      widget.intentModel == null
          ? _ModelState.none
          : (widget.loadIntentModel == null ? _ModelState.ready : _ModelState.loading);

  String get _guestLang => widget.traveler.language;
  HostPreferences get _host => widget.profile.host;
  TravelerStrings get _gs => travelerStrings[_guestLang] ?? travelerStrings['en']!;

  @override
  void initState() {
    super.initState();
    _guestInput.addListener(() => setState(() {}));
    _hostInput.addListener(() => setState(() {}));
    unawaited(_checkSpeech());
    unawaited(_loadModel());
    unawaited(_checkDownloads());
  }

  @override
  void dispose() {
    unawaited(_quiet(() => widget.speechInput?.stop()));
    unawaited(_quiet(() => widget.speechOutput?.stop()));
    _guestInput.dispose();
    _hostInput.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _checkSpeech() async {
    final input = widget.speechInput;
    final output = widget.speechOutput;
    Future<bool> safe(Future<bool>? Function() f) async {
      try {
        return await f() ?? false;
      } on Object {
        return false;
      }
    }

    final guest = await safe(() => input?.isAvailable(_guestLang));
    final host = await safe(() => input?.isAvailable(_host.language));
    final voice = await safe(() => output?.hasVoice(_guestLang));
    final enVoice = await safe(() => output?.hasVoice('en'));
    if (!mounted) return;
    setState(() {
      _micOk[_Side.guest] = guest;
      _micOk[_Side.host] = host;
      _voiceOk = voice;
      _enVoiceOk = enVoice;
      _speechChecked = true;
      // No mic on a side: open its keyboard so typing is ready.
      if (_typing == null && (!host || !guest)) _typing = !host ? _Side.host : _Side.guest;
    });
  }

  Future<void> _loadModel() async {
    final load = widget.loadIntentModel;
    if (widget.intentModel == null || load == null) return;
    try {
      await load();
      if (mounted) setState(() => _model = _ModelState.ready);
    } on Object {
      if (mounted) setState(() => _model = _ModelState.none);
    }
  }

  Future<void> _checkDownloads() async {
    final models = widget.languageModels;
    if (models == null) return;
    try {
      final missing = !await models.isDownloaded(_guestLang) || !await models.isDownloaded('tl');
      if (mounted) setState(() => _needsDownload = missing);
    } on Object {
      // The hint is optional; stay quiet.
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  // Speaking and listening.

  /// Runs a plugin call and ignores its errors.
  Future<void> _quiet(Future<void>? Function() call) async {
    try {
      await call();
    } on Object {
      // Speech plugin errors never reach the host.
    }
  }

  bool _interrupted = false;

  /// Speaks [text] unless the phone is listening or has no voice. True only if
  /// it was really spoken: no error and not cut off by the mic or stop button.
  Future<bool> _speak(String text, {String? lang}) async {
    final output = widget.speechOutput;
    final speakLang = lang ?? _guestLang;
    final hasVoice = speakLang == _guestLang ? _voiceOk : _enVoiceOk;
    if (output == null || !hasVoice || _listening != null) return false;
    _interrupted = false;
    setState(() => _speaking = true);
    var ok = true;
    try {
      await output.speak(text, speakLang);
    } on Object {
      ok = false; // The text stays on screen for the guest to read.
    }
    if (mounted) {
      setState(() {
        _speaking = false;
        _speakingSuggestion = null;
      });
    }
    return ok && !_interrupted;
  }

  /// Speaks [text] and marks [msg] as heard only if it really was.
  Future<void> _speakFor(_HostMsg msg, String text) async {
    final ok = await _speak(text, lang: msg.lang);
    if (ok && mounted) setState(() => msg.spoken = true);
  }

  Future<void> _stopSpeaking() async {
    _interrupted = true;
    await _quiet(() => widget.speechOutput?.stop());
  }

  Future<void> _toggleMic(_Side side) async {
    final input = widget.speechInput;
    if (input == null || _micOk[side] != true) return;
    if (_listening == side) {
      await _quiet(input.stop);
      return;
    }
    if (_listening != null) return;
    // Listening is set first, so no speech can start from here on.
    setState(() {
      _interrupted = _speaking;
      _listening = side;
      _partial = '';
      _notice = null;
      _speaking = false;
      _speakingSuggestion = null;
    });
    await _quiet(() => widget.speechOutput?.stop());
    if (!mounted) return;
    String? heard;
    try {
      heard = await input.listen(
        side == _Side.guest ? _guestLang : _host.language,
        onPartial: (text) {
          if (mounted) setState(() => _partial = text);
        },
      );
    } on Object {
      heard = null;
    }
    if (!mounted) return;
    setState(() {
      _listening = null;
      _partial = '';
    });
    final text = heard?.trim() ?? '';
    if (text.isEmpty) {
      setState(
        () => _notice = '${_host.usePo ? 'Wala pong' : 'Walang'} narinig ang phone. Subukan ulit.',
      );
    } else if (side == _Side.guest) {
      _onGuest(text);
    } else {
      await _onHost(text);
    }
  }

  /// Opens the host mic, or the host keyboard when there is no mic.
  void _hostAnswers() {
    if (_micOk[_Side.host] == true) {
      unawaited(_toggleMic(_Side.host));
    } else {
      setState(() => _typing = _Side.host);
    }
  }

  // Turns.

  void _sendTyped(_Side side) {
    final controller = side == _Side.guest ? _guestInput : _hostInput;
    final text = controller.text.trim();
    if (text.isEmpty) return;
    controller.clear();
    if (side == _Side.guest) {
      _onGuest(text);
    } else {
      unawaited(_onHost(text));
    }
  }

  void _onGuest(String text) {
    unawaited(_quiet(() => widget.speechOutput?.stop()));
    final msg = _GuestMsg(text);
    setState(() {
      _messages.add(msg);
      _current = msg;
      _expanded.clear();
      _used.clear();
      _confirming = null;
      _notice = null;
    });
    _scrollToEnd();
    unawaited(_runGuest(msg));
  }

  Future<void> _runGuest(_GuestMsg msg) async {
    try {
      final turn = await widget.runGuestTurn(
        message: msg.text,
        traveler: widget.traveler,
        profile: widget.profile,
        translator: widget.translator,
        model: _model == _ModelState.ready ? widget.intentModel : null,
      );
      if (!mounted) return;
      setState(() => msg.turn = turn);
    } on Object {
      // Still offer the fixed replies, never an answer.
      final fixed = await Future.wait([
        for (final kind in [SuggestionKind.holding, SuggestionKind.moment, SuggestionKind.thanks])
          fixedSuggestion(
            kind,
            traveler: widget.traveler,
            profile: widget.profile,
            translator: widget.translator,
          ),
      ]);
      if (!mounted) return;
      setState(() {
        msg.fallback = fixed;
        msg.failed = true;
      });
    }
    _scrollToEnd();
  }

  Future<void> _onHost(String text) async {
    unawaited(_quiet(() => widget.speechOutput?.stop()));
    final HostTurn turn;
    try {
      turn = await handleHostTurn(
        text: text,
        traveler: widget.traveler,
        profile: widget.profile,
        translator: widget.translator,
      );
    } on Object {
      if (!mounted) return;
      setState(() {
        _messages.add(_HostMsg(text: text, forGuest: null, spoken: false));
        _notice = _sayAgain;
      });
      return;
    }
    if (!mounted) return;
    final forGuest = turn.forGuest;
    final msg = _HostMsg(text: text, forGuest: forGuest, spoken: false);
    setState(() {
      _messages.add(msg);
      _notice = forGuest == null ? _sayAgain : null;
    });
    _scrollToEnd();
    if (forGuest != null) await _speakFor(msg, forGuest);
  }

  /// Replies the guest would hear in English, not in their language.
  /// Exhaustive on purpose: a new outcome must decide here whether it needs
  /// the host's extra confirm.
  bool _isFallback(Suggestion s) => switch (s.translation) {
    TranslationOutcome.notNeeded || TranslationOutcome.translated => false,
    TranslationOutcome.unavailable || TranslationOutcome.numbersChanged => true,
  };

  /// Tapping a reply is the host's approval: it is spoken at once. An English
  /// fallback first asks the host to confirm.
  Future<void> _say(Suggestion s, {bool confirmed = false}) async {
    if (_listening != null || _speaking || _used.contains(s)) return;
    if (_isFallback(s) && !confirmed) {
      setState(() => _confirming = s);
      return;
    }
    final msg = _HostMsg(
      text: s.forHost,
      forGuest: s.forGuest,
      spoken: false,
      lang: _isFallback(s) ? 'en' : null,
    );
    setState(() {
      _messages.add(msg);
      _used.add(s);
      _confirming = null;
      _speakingSuggestion = s;
      _notice = null;
    });
    _scrollToEnd();
    await _speakFor(msg, s.forGuest);
  }

  Future<void> _repeat(_HostMsg msg) async {
    final text = msg.forGuest;
    if (text == null || _listening != null || _speaking) return;
    await _speakFor(msg, text);
  }

  String get _sayAgain =>
      '${_host.usePo ? 'Hindi po' : 'Hindi'} maisalin nang tama. '
      'Sabihin ulit sa ibang paraan, o pumili ng sagot sa ibaba.';

  // Build.

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    // While one side types, the other half shrinks to its mic button.
    final guestCompact = keyboard && _typing != null && _typing != _Side.guest;
    final hostCompact = keyboard && _typing != null && _typing != _Side.host;
    Widget sized(Widget child, {required bool compact, required int flex}) =>
        compact
            ? SizedBox(height: 80, child: child)
            : Expanded(flex: keyboard ? 1 : flex, child: child);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            sized(
              RotatedBox(quarterTurns: 2, child: _guestHalf(context, compact: guestCompact)),
              compact: guestCompact,
              flex: 2,
            ),
            const Divider(height: 3, thickness: 3),
            sized(_hostHalf(context, compact: hostCompact), compact: hostCompact, flex: 3),
          ],
        ),
      ),
    );
  }

  // Guest half: guest language only.

  Widget _guestHalf(BuildContext context, {required bool compact}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final recent = _messages.length > 2 ? _messages.sublist(_messages.length - 2) : _messages;
    final lines = <Widget>[];
    for (final m in recent) {
      if (m is _GuestMsg) {
        lines.add(_line(context, m.text, mine: true, color: scheme.surfaceContainerHighest));
      } else if (m is _HostMsg && m.forGuest != null) {
        lines.add(_line(context, m.forGuest!, mine: false, color: scheme.primaryContainer));
      }
    }
    final micMissing = _speechChecked && _micOk[_Side.guest] != true;
    return Container(
      key: const Key('guest-half'),
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          if (!compact) ...[
            Expanded(child: SingleChildScrollView(reverse: true, child: Column(children: lines))),
            if (micMissing) Text(_gs.noMic, style: theme.textTheme.bodyMedium),
          ],
          _controls(
            context,
            _Side.guest,
            micLabel: _gs.tapToSpeak,
            listeningLabel: _gs.listening,
            hint: _gs.typeHint,
            sendLabel: _gs.send,
            compact: compact || MediaQuery.viewInsetsOf(context).bottom > 0,
          ),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, String text, {required bool mine, required Color color}) {
    return Align(
      alignment: mine ? Alignment.centerLeft : Alignment.centerRight,
      child: Card(
        color: color,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(text, style: Theme.of(context).textTheme.titleMedium),
        ),
      ),
    );
  }

  // Host half.

  Widget _hostHalf(BuildContext context, {required bool compact}) {
    final theme = Theme.of(context);
    final notes = <String>[
      if (_speechChecked && _micOk[_Side.guest] != true)
        'Walang mic para sa wika ng bisita. Mag-type na lang.',
      if (_speechChecked && _micOk[_Side.host] != true)
        'Walang mic para sa ${languageLabels[_host.language] ?? 'wika mo'}. Mag-type na lang.',
      if (_notice case final n?) n,
    ];
    final lastHost = _messages.whereType<_HostMsg>().lastOrNull;
    if (compact) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: _controls(
          context,
          _Side.host,
          micLabel: 'Magsalita',
          listeningLabel: 'Itigil',
          hint: 'Mag-type dito',
          sendLabel: 'Sabihin sa bisita',
          compact: true,
        ),
      );
    }
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Column(
      children: [
        if (!keyboard) _topBar(context),
        if (widget.traveler.hasCareNeeds) _careBanner(context),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            children: [
              for (final m in _messages) _bubble(context, m, isLastHost: identical(m, lastHost)),
              if (_current != null) _panel(context, _current!),
            ],
          ),
        ),
        Material(
          elevation: 4,
          color: theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Only the newest note, and none while the keyboard is open.
                if (notes.isNotEmpty && !keyboard)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      notes.last,
                      key: const Key('chat-note'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                _controls(
                  context,
                  _Side.host,
                  micLabel: 'Magsalita',
                  listeningLabel: 'Itigil',
                  hint: 'Mag-type dito',
                  sendLabel: 'Sabihin sa bisita',
                  compact: keyboard,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _topBar(BuildContext context) {
    final theme = Theme.of(context);
    final (key, label) = switch (_model) {
      _ModelState.ready => (const Key('chat-ai-ready'), 'AI: handa'),
      _ModelState.loading => (const Key('chat-status'), 'AI: hinahanda'),
      _ModelState.none => (const Key('chat-status'), 'AI: wala'),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('chat-back'),
                tooltip: 'Bumalik',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Chip(
                    key: key,
                    avatar: const Icon(Icons.auto_awesome, size: 16),
                    label: Text(label, style: theme.textTheme.labelMedium),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ),
          if (_needsDownload)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: Text(
                'Wala pa sa phone ang wika ng bisita. '
                'Pindutin ang "I-download ang mga wika" sa Home kapag may Wi-Fi.',
                key: const Key('chat-download-hint'),
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  Widget _careBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final needs = [
      for (final n in TravelerNeed.values)
        if (widget.traveler.needs.contains(n)) _needNames[n]!,
    ];
    return Container(
      key: const Key('care-banner'),
      width: double.infinity,
      color: scheme.tertiaryContainer,
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: scheme.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Paalala tungkol sa bisita: ${_joinWithAt(needs)}.',
              style: TextStyle(color: scheme.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(BuildContext context, Object msg, {required bool isLastHost}) {
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width * 0.9;
    final isGuest = msg is _GuestMsg;
    return Align(
      alignment: isGuest ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Card(
          color: isGuest ? scheme.surfaceContainerHighest : scheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: switch (msg) {
              _GuestMsg() => _guestBubble(context, msg),
              _HostMsg() => _hostBubble(context, msg, isLastHost),
              _ => const SizedBox.shrink(),
            },
          ),
        ),
      ),
    );
  }

  Widget _guestBubble(BuildContext context, _GuestMsg msg) {
    final theme = Theme.of(context);
    final turn = msg.turn;
    final children = <Widget>[
      Text(msg.text, key: const Key('guest-bubble'), style: theme.textTheme.titleMedium),
    ];
    if (turn == null && !msg.failed) {
      children.add(Text('Isinasalin...', style: theme.textTheme.bodySmall));
    } else if (turn != null) {
      final translated = turn.hostTranslation.text;
      final note = hostTranslationNote(turn.hostTranslation.outcome, _host);
      children
        ..add(const Divider())
        ..addAll([
          if (translated != null) ...[
            Text(translated, key: const Key('guest-translation'), style: theme.textTheme.bodyLarge),
            Text(hostTranslationLabel(_host), style: theme.textTheme.bodySmall),
          ],
          if (note != null)
            Text(note, key: const Key('guest-translation-note'), style: theme.textTheme.bodySmall),
        ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _hostBubble(BuildContext context, _HostMsg msg, bool isLast) {
    final theme = Theme.of(context);
    final heard = msg.forGuest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(msg.text, key: const Key('host-bubble'), style: theme.textTheme.titleMedium),
        const Divider(),
        if (heard != null) ...[
          Text(heard, key: const Key('host-heard'), style: theme.textTheme.bodyMedium),
          Text(
            msg.spoken ? 'Narinig ng bisita' : 'Ipinakita sa bisita',
            style: theme.textTheme.bodySmall,
          ),
          if (isLast)
            TextButton.icon(
              key: const Key('chat-repeat'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: _listening != null || _speaking ? null : () => _repeat(msg),
              icon: const Icon(Icons.replay),
              label: const Text('Ulitin'),
            ),
        ] else
          Text(
            'Hindi nasabi sa bisita.',
            key: const Key('host-not-said'),
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }

  /// Explanation, what the small AI picked out, and replies to tap.
  Widget _panel(BuildContext context, _GuestMsg msg) {
    final theme = Theme.of(context);
    final turn = msg.turn;
    if (turn == null && !msg.failed) return const SizedBox.shrink();
    final blocked = turn == null || !turn.guardrail.allowed;
    final suggestions = [
      for (final s in turn?.suggestions ?? msg.fallback)
        if (!blocked || s.kind != SuggestionKind.answer) s,
    ];
    final mentioned = turn == null ? null : mentionedForHost(turn.classification.slots, _host);
    final busy = _listening != null || _speaking;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        if (turn != null && !blocked)
          Text(
            turn.hostExplanation,
            key: const Key('chat-explanation'),
            style: theme.textTheme.bodyLarge,
          ),
        if (mentioned != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              mentioned,
              key: const Key('chat-mentioned'),
              style: theme.textTheme.bodySmall,
            ),
          ),
        if (blocked) _blockedCard(context, turn, turn == null ? 'chat-failed' : 'chat-blocked'),
        for (var i = 0; i < suggestions.length; i++) _tile(context, i, suggestions[i]),
        if (blocked)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: FilledButton.icon(
              key: const Key('chat-answer-self'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
              onPressed: busy ? null : _hostAnswers,
              icon: const Icon(Icons.mic),
              label: const Text('Ako na ang sasagot'),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _blockedCard(BuildContext context, GuestTurn? turn, String key) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final translated = turn?.hostTranslation.text;
    final asked = translated ?? turn?.hostExplanation;
    return Card(
      key: Key(key),
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.front_hand_outlined, color: scheme.onErrorContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hostFallback,
                    style: theme.textTheme.titleMedium?.copyWith(color: scheme.onErrorContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Hindi sigurado: magtanong sa local guide o taga-roon.',
              key: const Key('chat-blocked-tl'),
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onErrorContainer),
            ),
            if (asked != null) ...[
              const SizedBox(height: 8),
              Text(
                translated != null ? 'Tanong ng bisita: $asked' : asked,
                key: const Key('chat-blocked-asked'),
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onErrorContainer),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _kindIcon(SuggestionKind kind) => switch (kind) {
    SuggestionKind.answer => Icons.chat_bubble_outline,
    SuggestionKind.holding => Icons.pause_circle_outline,
    SuggestionKind.moment => Icons.hourglass_empty,
    SuggestionKind.thanks => Icons.favorite_border,
  };

  /// A reply in the host's language. One tap speaks it for the guest, once.
  Widget _tile(BuildContext context, int i, Suggestion s) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final speakingThis = identical(_speakingSuggestion, s);
    final busy = _listening != null || _speaking;
    final used = _used.contains(s);
    final open = _expanded.contains(i);
    final notice = translationNotice(s.translation, _host);
    final willSpeak = widget.speechOutput != null && _voiceOk;
    final fallback = _isFallback(s);
    final badge = switch (s.translation) {
      TranslationOutcome.unavailable => 'Sa English masasabi, wala pa ang wika ng bisita',
      TranslationOutcome.numbersChanged => 'Sa English masasabi, nag-iba ang numero sa salin',
      TranslationOutcome.translated => 'Isasalin ng app',
      TranslationOutcome.notNeeded => null,
    };
    return Card(
      color: used ? scheme.surfaceContainerHighest : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            key: Key('suggestion-$i'),
            minVerticalPadding: 14,
            leading: Icon(used ? Icons.check_circle : _kindIcon(s.kind), size: 28),
            title: Text(
              s.forHost,
              style: theme.textTheme.titleMedium?.copyWith(
                color: used ? scheme.onSurfaceVariant : null,
              ),
            ),
            trailing:
                speakingThis
                    ? IconButton.filled(
                      key: const Key('suggestion-stop'),
                      tooltip: 'Itigil',
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      onPressed: _stopSpeaking,
                      icon: const Icon(Icons.stop),
                    )
                    : (used ? null : const Icon(Icons.volume_up)),
            onTap: busy || used ? null : () => _say(s),
          ),
          if (badge != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: DecoratedBox(
                key: Key('suggestion-badge-$i'),
                decoration: BoxDecoration(
                  color: fallback ? scheme.tertiaryContainer : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    badge,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: fallback ? scheme.onTertiaryContainer : null,
                    ),
                  ),
                ),
              ),
            ),
          if (_confirming == s)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('English lang ito. Sabihin pa rin?', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          key: const Key('suggestion-confirm'),
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                          onPressed: busy ? null : () => _say(s, confirmed: true),
                          child: const Text('Oo'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('suggestion-cancel'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                          onPressed: () => setState(() => _confirming = null),
                          child: const Text('Huwag'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: TextButton(
              key: Key('suggestion-more-$i'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed:
                  () => setState(() {
                    if (!_expanded.remove(i)) _expanded.add(i);
                  }),
              child: Text(open ? 'Itago' : 'Tingnan'),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    willSpeak && !fallback ? 'Maririnig ng bisita' : 'Ipapakita sa bisita',
                    style: theme.textTheme.labelMedium,
                  ),
                  Text(
                    s.forGuest,
                    key: Key('suggestion-guest-text-$i'),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(s.english, style: theme.textTheme.bodySmall),
                  if (notice != null)
                    Text(
                      notice,
                      key: Key('suggestion-notice-$i'),
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Mic and keyboard controls for one side.

  Widget _controls(
    BuildContext context,
    _Side side, {
    required String micLabel,
    required String listeningLabel,
    required String hint,
    required String sendLabel,
    bool compact = false,
  }) {
    final theme = Theme.of(context);
    final name = side.name;
    final controller = side == _Side.guest ? _guestInput : _hostInput;
    final listeningHere = _listening == side;
    final micEnabled = _micOk[side] == true && (_listening == null || listeningHere);
    final typing = _typing == side;
    final canSend = controller.text.trim().isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (listeningHere && !compact)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              _partial.isEmpty ? '...' : _partial,
              key: Key('chat-partial-$name'),
              style: theme.textTheme.titleMedium,
            ),
          ),
        if (typing)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('chat-input'),
                    controller: controller,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  key: Key('chat-send-$name'),
                  tooltip: sendLabel,
                  iconSize: 28,
                  constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
                  onPressed: canSend ? () => _sendTyped(side) : null,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: Key('chat-mic-$name'),
                style: FilledButton.styleFrom(minimumSize: Size.fromHeight(compact ? 56 : 64)),
                onPressed: micEnabled ? () => _toggleMic(side) : null,
                icon: Icon(listeningHere ? Icons.stop : Icons.mic, size: 32),
                label: Text(
                  listeningHere ? listeningLabel : micLabel,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: micEnabled ? theme.colorScheme.onPrimary : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              key: Key('chat-kbd-$name'),
              tooltip: 'Keyboard',
              constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
              onPressed: () => setState(() => _typing = typing ? null : side),
              icon: Icon(typing ? Icons.keyboard_hide_outlined : Icons.keyboard_outlined),
            ),
          ],
        ),
      ],
    );
  }
}
