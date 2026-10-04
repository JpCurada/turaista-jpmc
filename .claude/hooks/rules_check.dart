// TurAIsta project rules, enforced in three places:
//   * Claude Code PostToolUse hook (reads the event from stdin)
//   * .githooks/pre-commit and CI:  dart run .claude/hooks/rules_check.dart --files a.dart b.dart
//
// Rule 1: no hard-coded prices in lib/ — facts come only from FarmProfile.
// Rule 2: lib/core/ is pure Dart — no Flutter, no network — so it is testable
//         without a device and can never phone home.
import 'dart:io';

import '_common.dart';

final List<RegExp> _pricePatterns = [
  RegExp(r'₱\s*\d'),
  RegExp(r'\bPHP\s*\d', caseSensitive: false),
  RegExp(r'\b(price|rate|fee|cost)\w*\s*[:=]\s*\d', caseSensitive: false),
];

final List<(RegExp, String)> _corePatterns = [
  (RegExp(r'''import\s+['"]package:flutter/'''), 'imports Flutter'),
  (RegExp(r'''import\s+['"]dart:ui['"]'''), 'imports dart:ui'),
  (RegExp(r'''import\s+['"]package:(http|dio)/'''), 'imports a network client'),
  (RegExp(r'\bHttpClient\b'), 'uses HttpClient'),
];

List<String> check(String path) {
  final rel = relativeToProject(path);
  if (!rel.endsWith('.dart') || !rel.startsWith('lib/')) return const [];
  final file = File(absolutePath(path));
  if (!file.existsSync()) return const [];

  final findings = <String>[];
  final lines = file.readAsLinesSync();
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trimLeft().startsWith('//')) continue;
    if (rel != 'lib/core/profile.dart' && _pricePatterns.any((p) => p.hasMatch(line))) {
      findings.add('$rel:${i + 1}: hard-coded price -> read it from FarmProfile: ${line.trim()}');
    }
    if (rel.startsWith('lib/core/')) {
      for (final (pattern, why) in _corePatterns) {
        if (pattern.hasMatch(line)) {
          findings.add('$rel:${i + 1}: lib/core must stay pure Dart, but it $why');
        }
      }
    }
  }
  return findings;
}

Future<void> main(List<String> args) async {
  final fromCli = args.isNotEmpty && args.first == '--files';
  final List<String> paths;
  if (fromCli) {
    paths = args.skip(1).toList();
  } else {
    final path = editedPath(await readEvent());
    paths = path == null ? const [] : [path];
  }

  final findings = [for (final p in paths) ...check(p)];
  if (findings.isNotEmpty) {
    fail(
      'TurAIsta rules violated (see .claude/skills/grounded-replies and '
      '.claude/skills/flutter-architecture):\n${findings.join('\n')}',
      code: fromCli ? 1 : 2,
    );
  }
}
