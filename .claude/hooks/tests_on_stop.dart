// Stop: if Dart files changed, run `flutter test` before Claude finishes and
// send failures back so it fixes them.
import 'dart:convert';
import 'dart:io';

import '_common.dart';

Future<void> main() async {
  final event = await readEvent();
  if (event['stop_hook_active'] == true) return; // avoid infinite loops

  final status = await run('git', ['status', '--porcelain', '--', '*.dart']);
  if (status == null || (status.stdout as String).trim().isEmpty) return;

  final tests = await run('flutter', ['test', '--reporter', 'expanded']);
  if (tests == null || tests.exitCode == 0) return;

  final lines = (tests.stdout as String).trim().split('\n');
  final tail = lines.length > 30 ? lines.sublist(lines.length - 30) : lines;
  stdout.writeln(
    jsonEncode({'decision': 'block', 'reason': 'flutter test is failing:\n${tail.join('\n')}'}),
  );
}
