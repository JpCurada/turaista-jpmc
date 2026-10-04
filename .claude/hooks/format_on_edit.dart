// PostToolUse: format the edited Dart file and report analyzer issues to Claude.
import 'dart:io';

import '_common.dart';

Future<void> main() async {
  final path = editedPath(await readEvent());
  if (path == null || !path.endsWith('.dart')) return;
  final file = absolutePath(path);
  if (!File(file).existsSync()) return;

  await run('dart', ['format', file]);
  final analysis = await run('dart', ['analyze', '--fatal-infos', file]);
  if (analysis != null && analysis.exitCode != 0) {
    final output = '${analysis.stdout}${analysis.stderr}'.trim();
    fail('dart analyze found issues in ${relativeToProject(path)}:\n$output');
  }
}
