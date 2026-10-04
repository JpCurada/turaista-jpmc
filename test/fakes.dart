import 'dart:async';

import 'package:turaista/core/intent_model.dart';
import 'package:turaista/core/language_id.dart';
import 'package:turaista/core/speech.dart';
import 'package:turaista/core/translator.dart';

/// Always answers [lang] (null = unsure).
class FakeLanguageIdentifier implements LanguageIdentifier {
  FakeLanguageIdentifier(this.lang);

  String? lang;

  @override
  Future<String?> identify(String text) async => lang;
}

/// Answers only when the test completes [answer].
class SlowLanguageIdentifier implements LanguageIdentifier {
  final Completer<String?> answer = Completer<String?>();

  @override
  Future<String?> identify(String text) => answer.future;
}

/// Rewrites text for the host's language into something that would change
/// classification and contains a price, to prove it never reaches the reply.
class PoisoningTranslator implements Translator {
  const PoisoningTranslator();

  @override
  Future<String> translate(String text, {required String from, required String to}) async =>
      to == 'tl' ? 'peanut allergy, PHP 999' : '[$to] $text';
}

/// Pretends to translate by tagging the text; keeps every number.
class TaggingTranslator implements Translator {
  const TaggingTranslator();

  @override
  Future<String> translate(String text, {required String from, required String to}) async =>
      '[$to] $text';
}

/// A translation that changes one number, e.g. 350 -> 530.
class NumberChangingTranslator implements Translator {
  const NumberChangingTranslator();

  @override
  Future<String> translate(String text, {required String from, required String to}) async =>
      '[$to] ${text.replaceFirst(RegExp(r'\d+'), '530')}';
}

/// No language model downloaded.
class UnavailableTranslator implements Translator {
  const UnavailableTranslator();

  @override
  Future<String> translate(String text, {required String from, required String to}) =>
      throw const TranslationUnavailable('not downloaded');
}

/// A plugin failure that is not a [TranslationUnavailable].
class CrashingTranslator implements Translator {
  const CrashingTranslator();

  @override
  Future<String> translate(String text, {required String from, required String to}) =>
      throw StateError('plugin crashed');
}

/// In-memory language models; [failing] languages throw on download.
class FakeLanguageModels implements LanguageModels {
  FakeLanguageModels({Set<String>? downloaded, this.failing = const {}})
    : downloaded = downloaded ?? {};

  final Set<String> downloaded;
  final Set<String> failing;
  final List<String> downloadCalls = [];

  @override
  Future<bool> isDownloaded(String lang) async => downloaded.contains(lang);

  @override
  Future<void> download(String lang) async {
    downloadCalls.add(lang);
    if (failing.contains(lang)) throw Exception('no Wi-Fi');
    downloaded.add(lang);
  }
}

/// Returns a fixed model answer, or throws when [answer] is null.
class FakeIntentModel implements IntentModel {
  FakeIntentModel(this.answer);

  final String? answer;
  final List<String> calls = [];

  @override
  Future<String> complete(String guestMessage) async {
    calls.add(guestMessage);
    return answer ?? (throw StateError('model failed'));
  }
}

/// Scripted speech recognition. [available] lists languages that work.
class FakeSpeechInput implements SpeechInput {
  FakeSpeechInput({
    this.available = const {'en', 'ko', 'ja', 'zh', 'tl'},
    this.heard,
    this.throwOnListen = false,
    this.watch,
  });

  final Set<String> available;

  /// What the next [listen] returns; null means nothing was heard.
  String? heard;
  final bool throwOnListen;

  /// When set, [listen] waits for this before it returns.
  Completer<String?>? gate;

  /// Output to watch: [startedWhileSpeaking] records an overlap.
  final FakeSpeechOutput? watch;
  bool startedWhileSpeaking = false;
  bool listening = false;
  final List<String> listenCalls = [];

  @override
  Future<bool> isAvailable(String lang) async => available.contains(lang);

  @override
  Future<String?> listen(String lang, {void Function(String text)? onPartial}) async {
    listenCalls.add(lang);
    if (watch?.speaking ?? false) startedWhileSpeaking = true;
    if (throwOnListen) throw StateError('recognizer failed');
    listening = true;
    onPartial?.call('...');
    final wait = gate;
    final result = wait == null ? heard : await wait.future;
    listening = false;
    return result;
  }

  @override
  Future<void> stop() async {
    final wait = gate;
    if (wait != null && !wait.isCompleted) wait.complete(null);
  }
}

/// Records what would be spoken. [throwOnSpeak] fails every call; [gate] holds
/// the speech until the test completes it or [stop] is called.
class FakeSpeechOutput implements SpeechOutput {
  FakeSpeechOutput({this.voices = const {'en', 'ko', 'ja', 'zh', 'tl'}, this.throwOnSpeak = false});

  final Set<String> voices;
  final bool throwOnSpeak;
  Completer<void>? gate;
  bool speaking = false;
  final List<({String text, String lang})> spoken = [];

  @override
  Future<bool> hasVoice(String lang) async => voices.contains(lang);

  @override
  Future<void> speak(String text, String lang) async {
    if (throwOnSpeak) throw StateError('tts failed');
    speaking = true;
    final wait = gate;
    if (wait != null) await wait.future;
    speaking = false;
    spoken.add((text: text, lang: lang));
  }

  @override
  Future<void> stop() async {
    final wait = gate;
    if (wait != null && !wait.isCompleted) wait.complete();
  }
}
