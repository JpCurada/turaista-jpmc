// PreToolUse: block edits to secrets, model weights, lockfiles, signing
// files, and real host profiles.
import '_common.dart';

const Set<String> _allowed = {
  '.env.example',
  'assets/profiles/example_farm.json',
  'models/.gitkeep',
};

final List<(RegExp, String)> _rules = [
  (RegExp(r'(^|/)\.env(\..+)?$'), 'secrets live in .env; edit .env.example instead'),
  (RegExp(r'^models/'), 'model weights are exported by model_tools/, never hand-edited'),
  (RegExp(r'\.(tflite|onnx|gguf|bin|safetensors)$'), 'model weights are never hand-edited'),
  (RegExp(r'(^|/)pubspec\.lock$'), 'change Dart deps with `flutter pub add/remove`'),
  (RegExp(r'(^|/)uv\.lock$'), 'change Python deps with `uv add/remove`'),
  (RegExp(r'^\.git/'), 'never edit git internals'),
  (
    RegExp(r'(key\.properties|google-services\.json|GoogleService-Info\.plist|\.jks|\.keystore)$'),
    'signing keys and Firebase configs are private',
  ),
];

Future<void> main() async {
  final path = editedPath(await readEvent());
  if (path == null) return;
  final rel = relativeToProject(path);
  if (_allowed.contains(rel)) return;

  if (rel.startsWith('assets/profiles/')) {
    fail('Blocked edit to $rel: real host profiles are private. Use example_farm.json.');
    return;
  }
  for (final (pattern, why) in _rules) {
    if (pattern.hasMatch(rel)) {
      fail('Blocked edit to $rel: $why.');
      return;
    }
  }
}
