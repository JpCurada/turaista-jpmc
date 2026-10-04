import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:turaista/core/profile.dart';
import 'package:turaista/core/profile_store.dart';

/// Saves the profile as JSON in the app's private documents folder. Offline only.
class FileProfileStore implements ProfileStore {
  /// [directory] defaults to the app documents folder; tests pass a temp folder.
  FileProfileStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;

  static const String fileName = 'farm_profile.json';

  final Future<Directory> Function() _directory;

  Future<File> _file() async => File('${(await _directory()).path}/$fileName');

  @override
  Future<FarmProfile?> load() async {
    final file = await _file();
    if (!await file.exists()) return null;
    try {
      return FarmProfile.fromJsonString(await file.readAsString());
    } on TypeError catch (e) {
      // A missing or wrongly typed field fails a cast in fromJson.
      throw FormatException('Saved farm profile is incomplete: $e');
    }
  }

  @override
  Future<void> save(FarmProfile profile) async {
    final file = await _file();
    // Write a temp file first so a crash mid-write never leaves a half-saved profile.
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(profile.toJsonString(), flush: true);
    await temp.rename(file.path);
  }
}
