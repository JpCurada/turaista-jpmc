import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:turaista/services/file_profile_store.dart';

import '../helpers.dart';

void main() {
  late Directory dir;
  late FileProfileStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('turaista_profile_');
    store = FileProfileStore(directory: () async => dir);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('load returns null before onboarding', () async {
    expect(await store.load(), isNull);
  });

  test('saved profile loads back unchanged, replacing the old one', () async {
    final profile = loadExampleProfile();
    await store.save(profile);
    await store.save(profile);
    expect((await store.load())!.toJson(), profile.toJson());
    expect(dir.listSync().map((f) => f.uri.pathSegments.last), [FileProfileStore.fileName]);
  });

  test('unreadable or incomplete profile is a FormatException', () async {
    final file = File('${dir.path}/${FileProfileStore.fileName}');
    file.writeAsStringSync('{not json');
    await expectLater(store.load(), throwsFormatException);
    file.writeAsStringSync('{"farm_name": "Farm"}');
    await expectLater(store.load(), throwsFormatException);
  });
}
