import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Lance tool/verifier_apk.sh avec de faux `flutter` et `aapt2` en tête du
/// PATH ; [permissions] est la sortie simulée de `aapt2 dump permissions`.
ProcessResult lancer(String permissions, {bool flutterEchoue = false}) {
  final script = File('tool/verifier_apk.sh').absolute.path;
  final dossier = Directory.systemTemp.createTempSync('glyphe_apk_');
  addTearDown(() => dossier.deleteSync(recursive: true));
  final bin = Directory('${dossier.path}/bin')..createSync();
  File('${bin.path}/flutter').writeAsStringSync(
    flutterEchoue
        ? '#!/bin/sh\nexit 1\n'
        : '#!/bin/sh\nmkdir -p build/app/outputs/flutter-apk\n'
              ': > build/app/outputs/flutter-apk/app-release.apk\n',
  );
  File('${bin.path}/aapt2')
      .writeAsStringSync('#!/bin/sh\ncat <<\'EOT\'\n$permissions\nEOT\n');
  Process.runSync('chmod', ['+x', '${bin.path}/flutter', '${bin.path}/aapt2']);
  final projet = Directory('${dossier.path}/projet')..createSync();
  return Process.runSync(
    'bash',
    [script],
    workingDirectory: projet.path,
    environment: {
      'PATH': '${bin.path}:${Platform.environment['PATH']}',
      'ANDROID_HOME': '${dossier.path}/absent',
    },
  );
}

void main() {
  test('REQ026_AC1 réussit si INTERNET est absent', () {
    final r = lancer(
      "package: org.glyphe.caa\nuses-permission: name='android.permission.VIBRATE'",
    );
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
  });

  test('REQ026_AC1 échoue si INTERNET est présent', () {
    final r = lancer("uses-permission: name='android.permission.INTERNET'");
    expect(r.exitCode, isNot(0));
    expect('${r.stdout}${r.stderr}', contains('INTERNET'));
  });

  test('REQ026_AC1 échoue si la build échoue', () {
    final r = lancer('', flutterEchoue: true);
    expect(r.exitCode, isNot(0));
  });
}
