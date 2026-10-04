// Shared helpers for TurAIsta's Claude Code hooks. dart:io only, so hooks
// run with plain `dart run` and need no packages.
import 'dart:convert';
import 'dart:io';

String get projectDir => Platform.environment['CLAUDE_PROJECT_DIR'] ?? Directory.current.path;

bool get onWindows => Platform.isWindows;

/// Reads the hook event JSON from stdin. Returns an empty map on bad input.
Future<Map<String, dynamic>> readEvent() async {
  try {
    final raw = await stdin.transform(utf8.decoder).join();
    if (raw.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  } on FormatException {
    return <String, dynamic>{};
  }
}

/// `tool_input.file_path` from Edit/MultiEdit/Write events, if any.
String? editedPath(Map<String, dynamic> event) {
  final input = event['tool_input'];
  if (input is! Map<String, dynamic>) return null;
  final raw = input['file_path'];
  return raw is String && raw.isNotEmpty ? raw : null;
}

String _normalize(String path) =>
    path.replaceAll(r'\', '/').replaceAll(RegExp(r'/+$'), '').replaceAll('/./', '/');

/// Absolute path for a possibly-relative tool path.
String absolutePath(String path) => File(path).isAbsolute ? path : '$projectDir/$path';

/// Path relative to the project root, with forward slashes.
String relativeToProject(String path) {
  final root = _normalize(projectDir);
  final full = _normalize(absolutePath(path));
  return full.startsWith('$root/') ? full.substring(root.length + 1) : full;
}

/// Exit code 2: PreToolUse blocks the call; PostToolUse feeds stderr back to Claude.
void fail(String message, {int code = 2}) {
  stderr.writeln(message);
  exitCode = code;
}

/// Runs a command in the project dir. Returns null if the executable is missing.
Future<ProcessResult?> run(String executable, List<String> args) async {
  try {
    return await Process.run(executable, args, workingDirectory: projectDir, runInShell: onWindows);
  } on ProcessException {
    return null;
  }
}
