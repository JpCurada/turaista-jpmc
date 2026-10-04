/// What a suggested reply means, in the host's language, so the host knows
/// exactly what the phone will say before tapping it.
///
/// Built from the same FarmProfile facts as the English draft with fixed
/// templates, not machine translation. A test checks that the numbers match
/// the English draft. Tagalog only; other host languages see the English.
/// TODO(localization): add 'ceb' and 'ilo' templates written by native speakers.
library;

import 'intents.dart';
import 'profile.dart';
import 'reply.dart';

/// Tagalog meaning of [draftReply] for the same [intents], [profile] and
/// [partySize]. Null when the host language has no templates yet.
String? draftMeaningForHost(Set<GuestIntent> intents, FarmProfile profile, {int? partySize}) {
  if (profile.host.language != 'tl') return null;
  final lines = ['Salamat sa pag-message sa ${profile.farmName}!'];
  if (intents.contains(GuestIntent.price)) {
    lines.add('${formatPhp(profile.basePricePhp)} kada tao ang farm tour.');
    for (final a in profile.activities) {
      lines.add('- ${a.name}: ${a.pricePhp == 0 ? 'kasama na' : formatPhp(a.pricePhp)}');
    }
  }
  if (intents.contains(GuestIntent.booking)) {
    final limit = 'Hanggang ${profile.maxGroupSize} tao kada grupo.';
    if (partySize == null || partySize < 1) {
      lines.addAll([limit, 'Pakisabi ang gustong petsa at ilang tao.']);
    } else {
      lines.addAll([
        if (partySize <= profile.maxGroupSize) '$limit Pasok ang grupo ng $partySize.',
        if (partySize > profile.maxGroupSize)
          '$limit Para sa grupo ng $partySize, kausapin muna kami.',
        'Pakisabi ang gustong petsa.',
      ]);
    }
  }
  if (intents.contains(GuestIntent.directions)) lines.add(profile.locationHint);
  lines.add('Hihintayin namin kayo!');
  return lines.join('\n');
}

/// Tagalog meaning of the fixed phrases (holding reply, one moment, thanks).
/// No "po": these are said to the guest, not to the host.
const String holdingMeaning = 'Salamat sa mensahe! Kami mismo ang magkukumpirma nito.';
const String momentMeaning = 'Sandali lang.';
const String thanksMeaning = 'Salamat! Mag-enjoy sa pagbisita.';
