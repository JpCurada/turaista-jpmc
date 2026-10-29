import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:llamadart/llamadart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:turaista/core/intent_model.dart';

/// The fine-tuned Qwen2.5-0.5B intent model (GGUF), run offline with llama.cpp.
///
/// Speed settings: small context, CPU threads = performance cores, greedy
/// decoding, a grammar that forces the short JSON shape, and a fixed system
/// prompt first so llama.cpp can reuse its cache between messages.
class LlamaIntentModel implements IntentModel {
  LlamaIntentModel(this.path, {Future<bool> Function()? prepare, this.grammar = intentGrammar})
    : _prepare = prepare;

  /// GBNF output grammar: [intentGrammar] (intent and slots) or the faster
  /// [intentOnlyGrammar].
  final String grammar;

  static const String fileName = 'turaista-intent-v2-q8_0.gguf';

  static const MethodChannel _channel = MethodChannel('turaista/model');

  /// Finds the model, fast, without blocking app start:
  /// 1. a file pushed with `adb push` to
  ///    `/sdcard/Android/data/ph.turaista.turaista/files/models/` + [fileName];
  /// 2. otherwise the copy of the model bundled in the APK, in app support
  ///    storage. If it is not copied yet, [load] copies it first (once).
  /// Without either, loading fails and the app uses keywords only.
  static Future<LlamaIntentModel?> find() async {
    final external = await getExternalStorageDirectory();
    if (external != null) {
      final pushed = File('${external.path}/models/$fileName');
      if (await pushed.exists()) return LlamaIntentModel(pushed.path);
    }
    final support = await getApplicationSupportDirectory();
    final bundled = '${support.path}/models/$fileName';
    return LlamaIntentModel(
      bundled,
      prepare:
          () async =>
              await _channel.invokeMethod<bool>('copyBundledModel', {
                'name': fileName,
                'dest': bundled,
              }) ??
              false,
    );
  }

  final String path;

  /// Copies the bundled model to [path] when needed; false if not bundled.
  final Future<bool> Function()? _prepare;
  LlamaEngine? _engine;
  Future<LlamaEngine>? _loading;

  /// Last request in flight; requests run one at a time.
  Future<void> _queue = Future.value();

  /// Loads the model once. Call early (e.g. when the chat opens) so the first
  /// guest message does not wait for it.
  /// A failed load is not remembered: the next call tries again.
  Future<LlamaEngine> load() =>
      _loading ??= () async {
        try {
          // First launch with the APK-bundled model: copy it to a file once.
          if (_prepare case final prepare? when !await File(path).exists()) {
            if (!await prepare()) throw StateError('Intent model is not bundled or copy failed');
          }
          final engine = LlamaEngine(LlamaBackend());
          await engine.loadModel(
            path,
            modelParams: const ModelParams(
              contextSize: 512,
              gpuLayers: 0,
              preferredBackend: GpuBackend.cpu,
              numberOfThreads: 4,
              numberOfThreadsBatch: 4,
            ),
          );
          return _engine = engine;
        } on Object {
          _loading = null;
          rethrow;
        }
      }();

  static String _prompt(String message) =>
      '<|im_start|>system\n$intentSystemPrompt<|im_end|>\n'
      '<|im_start|>user\n$message<|im_end|>\n'
      '<|im_start|>assistant\n';

  @override
  Future<String> complete(String guestMessage) {
    final result = _queue.then((_) async {
      final engine = await load();
      final out = StringBuffer();
      await for (final chunk in engine.generate(
        _prompt(guestMessage),
        params: GenerationParams(
          maxTokens: 80,
          temp: 0,
          topK: 1,
          penalty: 1.0,
          grammar: grammar,
          stopSequences: ['<|im_end|>'],
          reusePromptPrefix: true,
        ),
      )) {
        out.write(chunk);
      }
      return out.toString();
    });
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<void> dispose() async {
    final engine = _engine;
    _engine = null;
    _loading = null;
    await engine?.dispose();
  }
}
