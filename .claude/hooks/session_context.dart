// SessionStart: remind Claude of the non-negotiables and current branch.
import 'dart:io';

import '_common.dart';

const String _rules = '''
TurAIsta rules (full version in CLAUDE.md):
- Facts (prices, group size, activities, directions) come ONLY from FarmProfile.
- DIETARY_SAFETY and OTHER intents never get a draft; the host approves every message.
- lib/core is pure Dart: no Flutter imports, no network.
- Everything runs offline on a budget Android phone.
- Ask hosts for preferences (address, po, voice); never infer from age or gender.''';

Future<void> main() async {
  final branch = await run('git', ['branch', '--show-current']);
  final name = branch == null ? '' : (branch.stdout as String).trim();
  stdout.writeln(name.isEmpty ? _rules : '$_rules\nCurrent branch: $name');
}
