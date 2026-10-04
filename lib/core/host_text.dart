/// Host-facing explanations, in the host's language, built from intents.
///
/// Templates (not machine translation) keep these grounded and natural.
/// Tagalog is reviewed; Cebuano and Ilocano need a native speaker before use:
/// run the filipino-localization-reviewer agent and confirm with a local.
library;

import 'intents.dart';
import 'profile.dart';
import 'translator.dart';

const Map<GuestIntent, String> _tagalogTopics = {
  GuestIntent.booking: 'pag-book ng pagbisita',
  GuestIntent.price: 'presyo',
  GuestIntent.directions: 'direksyon papunta sa farm',
  GuestIntent.dietarySafety: 'pagkain, allergy, o kaligtasan',
  GuestIntent.other: 'bagay na wala sa farm profile mo',
};

const Map<GuestIntent, String> _englishTopics = {
  GuestIntent.booking: 'booking a visit',
  GuestIntent.price: 'prices',
  GuestIntent.directions: 'directions to the farm',
  GuestIntent.dietarySafety: 'food, allergies, or safety',
  GuestIntent.other: 'something not in your farm profile',
};

String _joinTopics(List<String> topics, String and) {
  if (topics.length <= 1) return topics.join();
  return '${topics.sublist(0, topics.length - 1).join(', ')} $and ${topics.last}';
}

List<String> _orderedTopics(Set<GuestIntent> intents, Map<GuestIntent, String> labels) => [
  for (final intent in GuestIntent.values)
    if (intents.contains(intent)) labels[intent]!,
];

/// One sentence telling the host what the guest wants.
String explainForHost(Set<GuestIntent> intents, HostPreferences host) {
  if (host.language == 'tl') {
    final po = host.usePo ? ' po' : '';
    final topics = _joinTopics(_orderedTopics(intents, _tagalogTopics), 'at');
    return '${host.preferredAddress}, tungkol$po sa $topics ang tanong ng bisita.';
  }
  // TODO(localization): add 'ceb' and 'ilo' templates written by native speakers.
  final topics = _joinTopics(_orderedTopics(intents, _englishTopics), 'and');
  return '${host.preferredAddress}, the guest is asking about $topics.';
}

/// Tells the host when the guest reply is in English instead of the guest's
/// language, and why. Null when there is nothing to tell.
String? translationNotice(TranslationOutcome outcome, HostPreferences host) {
  final po = host.usePo;
  if (host.language == 'tl') {
    // Instructions stay plain; "po" goes on the sentence addressed to the host.
    const download = 'Pindutin ang "I-download ang mga wika" sa Home kapag may Wi-Fi.';
    return switch (outcome) {
      TranslationOutcome.notNeeded || TranslationOutcome.translated => null,
      TranslationOutcome.numbersChanged =>
        '${po ? 'Nag-iba po' : 'Nag-iba'} ang mga numero nang isalin, kaya English ang sagot. '
            'Para hindi magkamali sa presyo.',
      TranslationOutcome.unavailable =>
        '${po ? 'Wala pa po' : 'Wala pa'} sa phone ang wika ng bisita, kaya English ang sagot. '
            '$download',
    };
  }
  // TODO(localization): add 'ceb' and 'ilo' templates written by native speakers.
  return switch (outcome) {
    TranslationOutcome.notNeeded || TranslationOutcome.translated => null,
    TranslationOutcome.numbersChanged =>
      'The translation changed a number, so the reply is in English to keep prices correct.',
    TranslationOutcome.unavailable =>
      "The guest's language is not on this phone yet, so the reply is in English. "
          'Tap "I-download ang mga wika" on Home when you have Wi-Fi.',
  };
}

/// Label over the guest's message machine-translated into the host language.
String hostTranslationLabel(HostPreferences host) =>
    host.language == 'tl'
        ? 'Isinalin ng app, hindi ng tao. Maaaring may mali.'
        : 'Translated by the app, not a person. It may contain mistakes.';

/// Extra line under that translation when it is missing or its numbers changed.
String? hostTranslationNote(TranslationOutcome outcome, HostPreferences host) {
  final po = host.usePo;
  if (host.language == 'tl') {
    return switch (outcome) {
      TranslationOutcome.notNeeded || TranslationOutcome.translated => null,
      TranslationOutcome.numbersChanged =>
        '${po ? 'Nag-iba po' : 'Nag-iba'} ang mga numero sa salin, kaya baka mali. '
            'Tingnan ang orihinal na mensahe.',
      TranslationOutcome.unavailable =>
        '${po ? 'Hindi po maisalin' : 'Hindi maisalin'} ang mensahe. '
            'Wala pa sa phone ang wikang ito. '
            'Pindutin ang "I-download ang mga wika" sa Home kapag may Wi-Fi.',
    };
  }
  // TODO(localization): add 'ceb' and 'ilo' templates written by native speakers.
  return switch (outcome) {
    TranslationOutcome.notNeeded || TranslationOutcome.translated => null,
    TranslationOutcome.numbersChanged =>
      'Numbers changed in this translation. Check the numbers in the original message.',
    TranslationOutcome.unavailable =>
      'This message cannot be translated yet because the language is not on this phone.',
  };
}

const Map<String, String> _slotLabelsEn = {
  'party_size': 'number of people',
  'date': 'date',
  'time': 'time',
  'place': 'place',
  'item': 'about',
  'allergen': 'allergy',
};

const Map<String, String> _slotLabelsTl = {
  'party_size': 'ilang tao',
  'date': 'petsa',
  'time': 'oras',
  'place': 'lugar',
  'item': 'tungkol sa',
  'allergen': 'allergy',
};

/// What the small AI picked out of the guest's message, as quotes for the
/// host: "Nabanggit ng bisita: petsa "Saturday", ilang tao "4"". The values are
/// the guest's own words, never facts the app states. Null when there are none.
String? mentionedForHost(Map<String, String> slots, HostPreferences host) {
  if (slots.isEmpty) return null;
  final tl = host.language == 'tl';
  final labels = tl ? _slotLabelsTl : _slotLabelsEn;
  final parts = [
    for (final MapEntry(:key, :value) in slots.entries)
      if (labels[key] case final label?) '$label "$value"',
  ];
  if (parts.isEmpty) return null;
  return '${tl ? 'Nabanggit ng bisita' : 'The guest mentioned'}: ${parts.join(', ')}';
}
