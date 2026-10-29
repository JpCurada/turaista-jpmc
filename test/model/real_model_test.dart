// Runs the real GGUF intent model with llama.cpp on this machine.
// Off by default (it loads a 531 MB model). Run with:
//   TURAISTA_MODEL_TEST=1 flutter test test/model/real_model_test.dart
// PowerShell: $env:TURAISTA_MODEL_TEST = '1'; flutter test test/model/real_model_test.dart
// Desktop speed is not phone speed: expect a budget phone to be several times slower.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:turaista/core/guardrail.dart';
import 'package:turaista/core/intent_model.dart';
import 'package:turaista/services/llama_intent_model.dart';

void main() {
  final enabled = Platform.environment['TURAISTA_MODEL_TEST'] == '1';
  final path =
      File(
        Platform.environment['TURAISTA_MODEL'] ?? 'models/${LlamaIntentModel.fileName}',
      ).absolute.path;

  test(
    'real model: valid JSON, fixture outcomes and speed',
    () async {
      // TURAISTA_GRAMMAR=intent-only measures the faster grammar without slots.
      final intentOnly = Platform.environment['TURAISTA_GRAMMAR'] == 'intent-only';
      final model = LlamaIntentModel(path, grammar: intentOnly ? intentOnlyGrammar : intentGrammar);
      final load = Stopwatch()..start();
      await model.load();
      load.stop();

      final fixtures = [
        for (final line in File('assets/fixtures/inquiries.jsonl').readAsLinesSync())
          if (line.trim().isNotEmpty) jsonDecode(line) as Map<String, dynamic>,
      ];

      // Warm-up, so the first timed message does not include one-time setup.
      await model.complete('Hello');

      var validJson = 0;
      var outcomesOk = 0;
      final times = <int>[];
      final report = StringBuffer();
      for (final f in fixtures) {
        final message = f['message'] as String;
        final sw = Stopwatch()..start();
        final raw = await model.complete(message);
        sw.stop();
        times.add(sw.elapsedMilliseconds);

        final parsed = parseIntentOutput(raw, message);
        if (parsed != null) validJson++;
        final c = await classifyGuestMessage(
          message,
          model: _Fixed(raw),
          timeout: const Duration(seconds: 30),
        );
        final outcome = checkGuardrail(c.intents).allowed ? 'draft' : 'blocked';
        final ok = outcome == f['expect'];
        if (ok) outcomesOk++;
        report.writeln(
          '${ok ? 'OK  ' : 'MISS'} ${sw.elapsedMilliseconds.toString().padLeft(5)} ms '
          '${f['id']}: model=${parsed?.intent.code ?? 'INVALID'} '
          'slots=${parsed?.slots ?? {}} final=$outcome expect=${f['expect']}',
        );
      }

      times.sort();
      final avg = times.reduce((a, b) => a + b) ~/ times.length;
      final p90 = times[(times.length * 0.9).floor().clamp(0, times.length - 1)];
      // ignore: avoid_print
      print(
        '\n$report\n'
        'model: $path\n'
        'grammar: ${intentOnly ? 'intent only' : 'intent and slots'}\n'
        'load: ${load.elapsedMilliseconds} ms\n'
        'per message: avg $avg ms, p90 $p90 ms, max ${times.last} ms\n'
        'valid JSON: $validJson/${fixtures.length}\n'
        'final outcome matches fixture: $outcomesOk/${fixtures.length}\n',
      );

      expect(validJson, fixtures.length, reason: 'the grammar must always give valid JSON');
      expect(outcomesOk, fixtures.length, reason: 'model + keywords must match every fixture');
      await model.dispose();
    },
    skip: enabled ? false : 'set TURAISTA_MODEL_TEST=1 to run the real model',
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

/// Replays one model output, so the merge rules run on the real answer.
class _Fixed implements IntentModel {
  const _Fixed(this.output);

  final String output;

  @override
  Future<String> complete(String guestMessage) async => output;
}
