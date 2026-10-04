/// Inquiry pipeline: classify -> guardrail -> grounded draft -> translate -> number check.
/// Nothing is sent automatically; the host always approves.
library;

import 'guardrail.dart';
import 'host_text.dart';
import 'intents.dart';
import 'number_check.dart';
import 'profile.dart';
import 'reply.dart';
import 'translator.dart';

/// The guest's message machine-translated into the host's language. For the
/// host to read only: never a source of facts and never sent to the guest.
typedef HostTranslation = ({TranslationOutcome outcome, String? text});

const HostTranslation _noHostTranslation = (outcome: TranslationOutcome.notNeeded, text: null);

class InquiryResult {
  const InquiryResult({
    required this.intents,
    required this.guardrail,
    required this.hostExplanation,
    required this.guestReply,
    this.draft,
    this.translation = TranslationOutcome.notNeeded,
    this.hostTranslation = _noHostTranslation,
  });

  final Set<GuestIntent> intents;
  final GuardrailResult guardrail;

  /// What the guest wants, in the host's language.
  final String hostExplanation;

  /// English draft; null when the guardrail blocked the message.
  final Draft? draft;

  /// Text to send the guest, in their language: the draft or the holding reply.
  final String guestReply;

  /// Whether [guestReply] is translated, or English and why.
  final TranslationOutcome translation;

  /// The guest's message in the host's language, machine-translated.
  /// [TranslationOutcome.numbersChanged] still carries the text, with a warning.
  final HostTranslation hostTranslation;

  /// Always true. Kept explicit so tests and reviewers can assert it.
  bool get needsHostApproval => true;
}

Future<InquiryResult> handleInquiry({
  required String message,
  required String guestLang,
  required FarmProfile profile,
  Translator translator = const IdentityTranslator(),
}) async {
  final intents = classifyKeywords(message);
  final verdict = checkGuardrail(intents);
  final explanation = explainForHost(intents, profile.host);
  final forHost = await translateForHost(message, guestLang, profile.host.language, translator);

  if (!verdict.allowed) {
    final (reply, translation) = await toGuestLanguage(guestHoldingReply, guestLang, translator);
    return InquiryResult(
      intents: intents,
      guardrail: verdict,
      hostExplanation: explanation,
      guestReply: reply,
      translation: translation,
      hostTranslation: forHost,
    );
  }

  final draft = draftReply(intents, profile);
  final (reply, translation) = await toGuestLanguage(draft.text, guestLang, translator);
  return InquiryResult(
    intents: intents,
    guardrail: verdict,
    hostExplanation: explanation,
    draft: draft,
    guestReply: reply,
    translation: translation,
    hostTranslation: forHost,
  );
}

/// Translates grounded [english] text for the guest. Falls back to [english]
/// when no offline model is ready or when the translation changed a number.
Future<(String, TranslationOutcome)> toGuestLanguage(
  String english,
  String guestLang,
  Translator translator,
) async {
  if (guestLang == 'en') return (english, TranslationOutcome.notNeeded);
  final String translated;
  try {
    translated = await translator.translate(english, from: 'en', to: guestLang);
  } on Object {
    // Missing model, plugin error, anything: the guest still gets the English
    // draft and the host is told. A failed translation must never mean silence.
    return (english, TranslationOutcome.unavailable);
  }
  if (!numbersMatch(english, translated)) return (english, TranslationOutcome.numbersChanged);
  return (translated, TranslationOutcome.translated);
}

/// Machine-translates the guest's [message] for the host to read. Unlike
/// [toGuestLanguage], a number mismatch keeps the text (the host can compare
/// with the original) but is flagged so the screen can warn.
Future<HostTranslation> translateForHost(
  String message,
  String guestLang,
  String hostLang,
  Translator translator,
) async {
  if (guestLang == hostLang) return _noHostTranslation;
  final String text;
  try {
    text = await translator.translate(message, from: guestLang, to: hostLang);
  } on Object {
    return (outcome: TranslationOutcome.unavailable, text: null);
  }
  final outcome =
      numbersMatch(message, text)
          ? TranslationOutcome.translated
          : TranslationOutcome.numbersChanged;
  return (outcome: outcome, text: text);
}
