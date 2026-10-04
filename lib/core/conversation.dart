/// Face-to-face chat between the host and a guest on one shared phone
/// (journey stage 4). Each guest turn is classified, guarded and answered
/// with grounded suggestions; nothing is said to the guest until the host
/// picks a suggestion or speaks.
library;

import 'guardrail.dart';
import 'host_meaning.dart';
import 'host_text.dart';
import 'intent_model.dart';
import 'number_check.dart';
import 'pipeline.dart';
import 'profile.dart';
import 'reply.dart';
import 'translator.dart';

/// Needs the guest tells the host about at the start of a chat. Asked, never
/// guessed: the guest taps them on the traveler card.
enum TravelerNeed { food, health, children, mobility }

/// Who the guest is, from the traveler card filled in by the guest.
class TravelerCard {
  const TravelerCard({required this.language, this.partySize, this.needs = const {}});

  /// App language code, e.g. 'ko'.
  final String language;

  /// How many people, as the guest entered it.
  final int? partySize;
  final Set<TravelerNeed> needs;

  /// The guest told the host about food, health, children or mobility needs;
  /// the chat keeps a reminder on screen for the host.
  bool get hasCareNeeds => needs.isNotEmpty;
}

/// A reply the host can choose. [english] is grounded; [forGuest] is what the
/// guest will hear and read; [forHost] is what it means in the host's language
/// (fixed templates from the same facts, never machine translation).
typedef Suggestion =
    ({
      SuggestionKind kind,
      String english,
      String forGuest,
      String forHost,
      TranslationOutcome translation,
      List<String> factsUsed,
    });

enum SuggestionKind { answer, holding, moment, thanks }

class GuestTurn {
  const GuestTurn({
    required this.message,
    required this.classification,
    required this.guardrail,
    required this.hostExplanation,
    required this.hostTranslation,
    required this.suggestions,
  });

  final String message;
  final Classification classification;
  final GuardrailResult guardrail;
  final String hostExplanation;
  final HostTranslation hostTranslation;

  /// Grounded answer first when allowed; the holding reply when blocked.
  final List<Suggestion> suggestions;
}

const String _moment = 'One moment, please.';
const String _thanks = 'Thank you! Enjoy your visit.';

/// A fixed phrase (holding reply, one moment, thanks) ready for [traveler].
/// Also used when a guest turn fails, so the host always has a reply to tap.
Future<Suggestion> fixedSuggestion(
  SuggestionKind kind, {
  required TravelerCard traveler,
  required FarmProfile profile,
  Translator translator = const IdentityTranslator(),
}) async {
  assert(kind != SuggestionKind.answer, 'answers come from draftReply');
  final (english, meaning) = switch (kind) {
    SuggestionKind.holding => (guestHoldingReply, holdingMeaning),
    SuggestionKind.moment => (_moment, momentMeaning),
    _ => (_thanks, thanksMeaning),
  };
  final (text, outcome) = await toGuestLanguage(english, traveler.language, translator);
  return (
    kind: kind,
    english: english,
    forGuest: text,
    forHost: profile.host.language == 'tl' ? meaning : english,
    translation: outcome,
    factsUsed: const <String>[],
  );
}

/// Handles one guest message: understand it for the host and prepare replies.
Future<GuestTurn> handleGuestTurn({
  required String message,
  required TravelerCard traveler,
  required FarmProfile profile,
  Translator translator = const IdentityTranslator(),
  IntentModel? model,
}) async {
  final lang = traveler.language;
  final classification = await classifyGuestMessage(message, model: model);
  final verdict = checkGuardrail(classification.intents);
  final forHost = translateForHost(message, lang, profile.host.language, translator);

  Future<Suggestion> answer(Draft draft) async {
    final (text, outcome) = await toGuestLanguage(draft.text, lang, translator);
    final meaning = draftMeaningForHost(
      classification.intents,
      profile,
      partySize: traveler.partySize,
    );
    return (
      kind: SuggestionKind.answer,
      english: draft.text,
      forGuest: text,
      forHost: meaning ?? draft.text,
      translation: outcome,
      factsUsed: draft.factsUsed,
    );
  }

  Future<Suggestion> fixed(SuggestionKind kind) =>
      fixedSuggestion(kind, traveler: traveler, profile: profile, translator: translator);

  final draft =
      verdict.allowed
          ? draftReply(classification.intents, profile, partySize: traveler.partySize)
          : null;
  final suggestions = await Future.wait([
    if (draft != null) answer(draft) else fixed(SuggestionKind.holding),
    fixed(SuggestionKind.moment),
    fixed(SuggestionKind.thanks),
  ]);
  return GuestTurn(
    message: message,
    classification: classification,
    guardrail: verdict,
    hostExplanation: explainForHost(classification.intents, profile.host),
    hostTranslation: await forHost,
    suggestions: suggestions,
  );
}

/// What the host said, ready for the guest.
typedef HostTurn = ({String text, String? forGuest, TranslationOutcome translation});

/// Translates the host's own words for the guest. If a number changed or no
/// model is ready, [HostTurn.forGuest] is null: the app does not speak it,
/// and the host is told to say it again or use a suggestion.
Future<HostTurn> handleHostTurn({
  required String text,
  required TravelerCard traveler,
  required FarmProfile profile,
  Translator translator = const IdentityTranslator(),
}) async {
  final from = profile.host.language;
  final to = traveler.language;
  if (from == to) return (text: text, forGuest: text, translation: TranslationOutcome.notNeeded);
  final String translated;
  try {
    translated = await translator.translate(text, from: from, to: to);
  } on Object {
    return (text: text, forGuest: null, translation: TranslationOutcome.unavailable);
  }
  if (!numbersMatch(text, translated)) {
    return (text: text, forGuest: null, translation: TranslationOutcome.numbersChanged);
  }
  return (text: text, forGuest: translated, translation: TranslationOutcome.translated);
}
