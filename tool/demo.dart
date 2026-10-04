// Terminal demo of the journey: `dart run tool/demo.dart [fixtures.jsonl]`.
// Uses only the pure-Dart core, so no device or emulator is needed.
import 'dart:convert';
import 'dart:io';

import 'package:turaista/core/guardrail.dart';
import 'package:turaista/core/pipeline.dart';
import 'package:turaista/core/profile.dart';

Future<void> main(List<String> args) async {
  final fixturesPath = args.isNotEmpty ? args.first : 'assets/fixtures/inquiries.jsonl';
  final profile = FarmProfile.fromJsonString(
    File('assets/profiles/example_farm.json').readAsStringSync(),
  );

  var failures = 0;
  for (final line in File(fixturesPath).readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    final fixture = jsonDecode(line) as Map<String, dynamic>;
    final result = await handleInquiry(
      message: fixture['message'] as String,
      guestLang: fixture['lang'] as String,
      profile: profile,
    );
    final outcome = result.guardrail.allowed ? 'draft' : 'blocked';
    final ok = fixture['expect'] == null || fixture['expect'] == outcome;
    if (!ok) failures++;

    stdout
      ..writeln('\n=== ${fixture['id']} [${fixture['lang']}] ${ok ? 'OK' : 'MISMATCH'} ===')
      ..writeln('guest:   ${fixture['message']}')
      ..writeln('intents: ${result.intents.map((i) => i.code).join(', ')}')
      ..writeln('host:    ${result.hostExplanation}');
    final draft = result.draft;
    if (draft != null) {
      stdout
        ..writeln('draft (needs approval):\n${draft.text}')
        ..writeln('facts:   ${draft.factsUsed.join(', ')}');
    } else {
      stdout
        ..writeln('BLOCKED: $hostFallback')
        ..writeln('guest holding reply: ${result.guestReply}');
    }
  }
  if (failures > 0) {
    stderr.writeln('\n$failures fixture(s) did not match "expect".');
    exitCode = 1;
  }
}
