/// On-device small language model (SLM) for guest intent, with structured
/// JSON output. The keyword classifier always runs too: if either one finds a
/// blocked intent, the message is blocked (see .claude/skills/intent-taxonomy).
library;

import 'dart:async';
import 'dart:convert';

import 'guardrail.dart';
import 'intents.dart';

/// System prompt the GGUF model was fine-tuned with. Keep in sync with training.
const String intentSystemPrompt =
    'You classify messages from guests of a Philippine farm tour. Reply with JSON only: '
    '{"intent": one of BOOKING, PRICE, DIRECTIONS, DIETARY_SAFETY, OTHER, "slots": {...}}. '
    'Slots may include party_size, date, time, place, item, allergen, copied exactly from the '
    'message. Anything about food, allergies, health, children, accessibility, or weather risk '
    'is DIETARY_SAFETY.';

/// GBNF grammar that forces the model's output into the JSON shape above, so
/// decoding stops early and parsing never fails on stray text.
const String intentGrammar = r'''
root   ::= "{" ws "\"intent\":" ws intent "," ws "\"slots\":" ws slots ws "}"
intent ::= "\"BOOKING\"" | "\"PRICE\"" | "\"DIRECTIONS\"" | "\"DIETARY_SAFETY\"" | "\"OTHER\""
slots  ::= "{" ws ( pair ( "," ws pair )* )? "}"
pair   ::= key ws ":" ws str
key    ::= "\"party_size\"" | "\"date\"" | "\"time\"" | "\"place\"" | "\"item\"" | "\"allergen\""
str    ::= "\"" ( [^"\\] | "\\" ["\\/bfnrt] )* "\""
ws     ::= [ ]?
''';

/// Slot names the model may fill.
const Set<String> intentSlotNames = {'party_size', 'date', 'time', 'place', 'item', 'allergen'};

/// Runs the model on one guest message and returns its raw text output.
abstract interface class IntentModel {
  Future<String> complete(String guestMessage);
}

typedef IntentPrediction = ({GuestIntent intent, Map<String, String> slots});

final RegExp _jsonObject = RegExp(r'\{.*\}', dotAll: true);

/// Parses the model output. Null when it is not the expected JSON, which makes
/// the caller fall back to keywords. Slots not copied exactly from [message]
/// are dropped: the model may point at words, never invent them.
IntentPrediction? parseIntentOutput(String raw, String message) {
  final match = _jsonObject.firstMatch(raw);
  if (match == null) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(match[0]!);
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, dynamic>) return null;
  final code = decoded['intent'];
  final intent = GuestIntent.values.where((i) => i.code == code).firstOrNull;
  if (intent == null) return null;
  final slots = <String, String>{};
  if (decoded['slots'] case final Map<String, dynamic> raw) {
    for (final MapEntry(:key, :value) in raw.entries) {
      if (intentSlotNames.contains(key) && value is String && value.isNotEmpty) {
        if (message.toLowerCase().contains(value.toLowerCase())) slots[key] = value;
      }
    }
  }
  return (intent: intent, slots: slots);
}

/// Who decided the intents of a message.
enum IntentSource { model, keywords, both }

typedef Classification =
    ({Set<GuestIntent> intents, Map<String, String> slots, IntentSource source});

/// Classifies [message] with the model and the keywords together.
///
/// - Any keyword match (including safety and out-of-profile words) is kept,
///   and the model's intent is added: a blocked intent from either one blocks.
/// - When keywords matched nothing at all, the model can only make the message
///   stricter (a safety label); it never unlocks a draft on its own.
/// - Otherwise a question no keyword could place still adds OTHER.
/// - If the model is missing, slow (over [timeout]) or returns bad JSON, the
///   keywords alone decide.
Future<Classification> classifyGuestMessage(
  String message, {
  IntentModel? model,
  Duration timeout = const Duration(seconds: 3),
}) async {
  const noSlots = <String, String>{};
  final keywordsOnly = (
    intents: classifyKeywords(message),
    slots: noSlots,
    source: IntentSource.keywords,
  );
  if (model == null) return keywordsOnly;
  IntentPrediction? prediction;
  try {
    prediction = parseIntentOutput(await model.complete(message).timeout(timeout), message);
  } on Object {
    prediction = null;
  }
  if (prediction == null) return keywordsOnly;

  final signals = keywordSignals(message);
  if (signals.matched.isEmpty) {
    // Keywords found nothing. The model may make this stricter (a safety
    // label) but never unlock a draft on its own: when in doubt, block.
    return (
      intents: {
        GuestIntent.other,
        if (blockedIntents.contains(prediction.intent)) prediction.intent,
      },
      slots: prediction.slots,
      source: IntentSource.both,
    );
  }
  return (
    intents: {
      prediction.intent,
      ...signals.matched,
      if (signals.unplacedQuestion) GuestIntent.other,
    },
    slots: prediction.slots,
    source: IntentSource.both,
  );
}
