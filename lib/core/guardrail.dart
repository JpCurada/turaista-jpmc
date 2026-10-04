/// Pass/fail guardrail (journey stage 3): block replies outside verified facts.
library;

import 'intents.dart';

const String hostFallback = 'Not sure: ask a local guide/person';
const String guestHoldingReply =
    'Thank you for your message! The host will confirm this with you personally.';

/// Intents the app may never draft a reply for.
const Set<GuestIntent> blockedIntents = {GuestIntent.dietarySafety, GuestIntent.other};

class GuardrailResult {
  const GuardrailResult.allowed() : allowed = true, blocked = const {};

  const GuardrailResult.blocked(this.blocked) : allowed = false;

  final bool allowed;
  final Set<GuestIntent> blocked;
}

/// If ANY intent is blocked, the whole message is blocked.
GuardrailResult checkGuardrail(Set<GuestIntent> intents) {
  final blocked = intents.intersection(blockedIntents);
  return blocked.isEmpty ? const GuardrailResult.allowed() : GuardrailResult.blocked(blocked);
}
