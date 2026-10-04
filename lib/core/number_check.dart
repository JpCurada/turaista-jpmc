/// Number check for machine translation: a translated reply must state exactly
/// the numbers of the grounded English draft (prices, group size, minutes,
/// km markers). Anything else falls back to English.
library;

final RegExp _number = RegExp(r'\d+(?:[,\u00A0\u202F]\d{3})*');
final RegExp _separators = RegExp(r'[,\u00A0\u202F]');

/// Full-width digits (common in Japanese and Chinese output) as ASCII.
String _asciiDigits(String text) => text.replaceAllMapped(
  RegExp('[０-９]'),
  (m) => String.fromCharCode(m[0]!.codeUnitAt(0) - 0xFF10 + 0x30),
);

final RegExp _leadingZeros = RegExp(r'^0+(?=\d)');

/// Every number in [text], in order, as plain digits: "1,200" is "1200".
/// Kept as strings so a run of digits of any length is safe to compare.
List<String> numbersIn(String text) => [
  for (final m in _number.allMatches(_asciiDigits(text)))
    m[0]!.replaceAll(_separators, '').replaceFirst(_leadingZeros, ''),
];

/// True when [translated] has the same numbers as [original], in any order.
///
/// Numbers written as words (e.g. 三百五十) do not count, so they fail the
/// check: falling back to English is the safe side.
bool numbersMatch(String original, String translated) {
  final a = numbersIn(original)..sort();
  final b = numbersIn(translated)..sort();
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
