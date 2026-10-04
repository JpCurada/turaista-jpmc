/// Grounded reply drafting (journey stage 2).
///
/// Every fact in a reply is read from [FarmProfile]. A model may later
/// translate the draft, but it never supplies numbers.
/// See .claude/skills/grounded-replies.
library;

import 'intents.dart';
import 'profile.dart';

class Draft {
  const Draft({required this.text, required this.factsUsed});

  final String text;

  /// Profile field paths used, so the host can see where each fact came from.
  final List<String> factsUsed;
}

typedef _SectionBuilder = List<String> Function(FarmProfile p, List<String> facts, int? partySize);

String formatPhp(int amount) {
  final digits = amount.toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return 'PHP $out';
}

List<String> _priceLines(FarmProfile p, List<String> facts, int? _) {
  facts.add('base_price_php');
  final lines = ['The farm tour is ${formatPhp(p.basePricePhp)} per person.'];
  for (final a in p.activities) {
    facts.add('activities[${a.name}].price_php');
    final cost = a.pricePhp == 0 ? 'included' : formatPhp(a.pricePhp);
    lines.add('- ${a.name}: $cost');
  }
  return lines;
}

List<String> _bookingLines(FarmProfile p, List<String> facts, int? partySize) {
  facts.add('max_group_size');
  final limit = 'We welcome groups of up to ${p.maxGroupSize} people.';
  if (partySize == null || partySize < 1) {
    return [limit, 'Please tell us your preferred date and number of guests.'];
  }
  // The party size is what the guest entered on the traveler card, not a
  // profile fact; only its comparison with the profile limit is stated.
  facts.add('traveler.party_size (guest-entered)');
  return [
    if (partySize <= p.maxGroupSize) '$limit A group of $partySize is within this limit.',
    if (partySize > p.maxGroupSize) '$limit For a group of $partySize, please talk with us first.',
    'Please tell us your preferred date.',
  ];
}

List<String> _directionLines(FarmProfile p, List<String> facts, int? _) {
  facts.add('location_hint');
  return [p.locationHint];
}

/// Stable order of sections in a reply.
const List<(GuestIntent, _SectionBuilder)> _sections = [
  (GuestIntent.price, _priceLines),
  (GuestIntent.booking, _bookingLines),
  (GuestIntent.directions, _directionLines),
];

/// Builds an English draft. Callers must run checkGuardrail() first.
/// [partySize] comes from the guest's traveler card, when there is one.
Draft draftReply(Set<GuestIntent> intents, FarmProfile profile, {int? partySize}) {
  final facts = <String>['farm_name'];
  final lines = ['Hello, and thank you for contacting ${profile.farmName}!'];
  for (final (intent, build) in _sections) {
    if (intents.contains(intent)) lines.addAll(build(profile, facts, partySize));
  }
  lines.add('We look forward to your visit.');
  return Draft(text: lines.join('\n'), factsUsed: facts);
}
