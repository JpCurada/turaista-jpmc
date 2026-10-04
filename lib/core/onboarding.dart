/// Rules for the one-time offline onboarding (journey stage 1).
///
/// The screens collect answers; this file parses them and builds the
/// "Tama ba?" read-back. Only facts the host confirms in the read-back are
/// saved, which is what "verified" means for a [FarmProfile].
/// See .claude/skills/host-onboarding.
library;

import 'profile.dart';
import 'reply.dart';

/// Onboarding questions, in the order the host answers them.
enum OnboardingStep {
  address,
  po,
  farmName,
  directions,
  basePrice,
  groupSize,
  activities,
  safetyRules,
}

/// One fact read back to the host. [key] is stable per fact so a confirmation
/// can be tied to it; [step] is where the host goes to change it.
typedef ReadBackItem = ({String key, OnboardingStep step, String label, String question});

final RegExp _numberNoise = RegExp(r'(php|₱|[\s,])', caseSensitive: false);
final RegExp _digitsOnly = RegExp(r'^\d+$');

/// Parses a whole number typed by the host: "350", "1,200", "PHP 350".
/// Returns null when it is not a whole number.
int? parseWholeNumber(String input) {
  final cleaned = input.replaceAll(_numberNoise, '');
  if (!_digitsOnly.hasMatch(cleaned) || cleaned.length > 7) return null;
  return int.parse(cleaned);
}

/// Picks the "po" or plain form of host-facing text.
String withPo(bool usePo, String plain, String po) => usePo ? po : plain;

/// Error shown under a required text field, or null when it is filled in.
String? validateRequired(String input, {bool usePo = false}) =>
    input.trim().isEmpty ? withPo(usePo, 'Pakisulat muna.', 'Pakisulat po muna.') : null;

/// Error for a price (0 allowed), or null when valid.
String? validatePrice(String input, {bool usePo = false}) {
  if (input.trim().isEmpty) {
    return withPo(usePo, 'Pakisulat ang presyo.', 'Pakisulat po ang presyo.');
  }
  return parseWholeNumber(input) == null
      ? withPo(usePo, 'Numero lang, halimbawa 350.', 'Numero lang po, halimbawa 350.')
      : null;
}

/// Error for a count that must be at least 1 (group size, minutes), or null when valid.
String? validatePositive(String input, {bool usePo = false}) {
  if (input.trim().isEmpty) {
    return withPo(usePo, 'Pakisulat ang numero.', 'Pakisulat po ang numero.');
  }
  final value = parseWholeNumber(input);
  if (value == null) return withPo(usePo, 'Numero lang.', 'Numero lang po.');
  return value < 1 ? withPo(usePo, 'Isa o higit pa.', 'Dapat po, isa o higit pa.') : null;
}

/// Error for an optional count, e.g. activity minutes, or null when blank or valid.
String? validateOptionalPositive(String input, {bool usePo = false}) =>
    input.trim().isEmpty ? null : validatePositive(input, usePo: usePo);

String _price(int amount) => amount == 0 ? 'kasama na sa presyo ng tour' : formatPhp(amount);

String _activityFacts(Activity a) {
  final minutes = a.durationMinutes;
  return [
    _price(a.pricePhp),
    if (minutes != null) '$minutes minuto',
    if (a.description.isNotEmpty) a.description,
  ].join(', ');
}

/// Every fact in [profile], phrased as a yes/no question for the host.
List<ReadBackItem> readBackItems(FarmProfile profile) {
  final host = profile.host;
  final tamaBa = host.usePo ? 'Tama po ba' : 'Tama ba';
  return [
    (
      key: 'address',
      step: OnboardingStep.address,
      label: 'Itatawag sa iyo',
      question:
          host.usePo
              ? '$tamaBa na "${host.preferredAddress}" ang itatawag sa inyo ng app?'
              : '$tamaBa na "${host.preferredAddress}" ang itatawag sa iyo ng app?',
    ),
    (
      key: 'po',
      step: OnboardingStep.po,
      label: 'Po',
      question:
          host.usePo
              ? '$tamaBa na may "po" kapag kinakausap kayo ng app?'
              : '$tamaBa na hindi na kailangan ng "po" kapag kinakausap ka ng app?',
    ),
    (
      key: 'farm_name',
      step: OnboardingStep.farmName,
      label: 'Pangalan ng farm',
      question: '$tamaBa na "${profile.farmName}" ang pangalan ng farm?',
    ),
    (
      key: 'directions',
      step: OnboardingStep.directions,
      label: 'Paano pumunta',
      question: '$tamaBa ang direksyon na ito: "${profile.locationHint}"?',
    ),
    (
      key: 'base_price',
      step: OnboardingStep.basePrice,
      label: 'Presyo bawat tao',
      question: '$tamaBa na ${formatPhp(profile.basePricePhp)} bawat tao?',
    ),
    (
      key: 'group_size',
      step: OnboardingStep.groupSize,
      label: 'Pinakamaraming bisita',
      question: '$tamaBa na hanggang ${profile.maxGroupSize} bisita lang sa isang grupo?',
    ),
    if (profile.activities.isEmpty)
      (
        key: 'activities-none',
        step: OnboardingStep.activities,
        label: 'Mga activity',
        question: '$tamaBa na walang ibang activity sa farm?',
      ),
    for (final (i, a) in profile.activities.indexed)
      (
        key: 'activity-$i',
        step: OnboardingStep.activities,
        label: 'Activity',
        question: '$tamaBa ang activity na "${a.name}" (${_activityFacts(a)})?',
      ),
    if (profile.safetyRules.isEmpty)
      (
        key: 'rules-none',
        step: OnboardingStep.safetyRules,
        label: 'Mga bilin',
        question: '$tamaBa na walang bilin para sa kaligtasan ng bisita?',
      ),
    for (final (i, rule) in profile.safetyRules.indexed)
      (
        key: 'rule-$i',
        step: OnboardingStep.safetyRules,
        label: 'Bilin sa bisita',
        question: '$tamaBa ang bilin na "$rule"?',
      ),
  ];
}
