import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Lance tool/verifier_apk.sh avec de faux `flutter` et `aapt2` en tête du
/// PATH ; [permissions] est la sortie simulée de `aapt2 dump permissions`.
ProcessResult lancer(
  String permissions, {
  bool flutterEchoue = false,
  String certificat = 'Signer #1 certificate DN: CN=Glyphe',
  bool avecApksigner = true,
}) {
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
  final aChmoder = ['${bin.path}/flutter', '${bin.path}/aapt2'];
  if (avecApksigner) {
    File('${bin.path}/apksigner')
        .writeAsStringSync('#!/bin/sh\ncat <<\'EOT\'\n$certificat\nEOT\n');
    aChmoder.add('${bin.path}/apksigner');
  }
  Process.runSync('chmod', ['+x', ...aChmoder]);
  // PATH minimal : seuls les outils nécessaires, pour qu'un vrai apksigner de
  // la machine ne soit jamais trouvé.
  final outils = Directory('${dossier.path}/outils')..createSync();
  for (final o in [
    'bash',
    'grep',
    'mkdir',
    'sort',
    'tail',
    'ls',
    'cat',
    'env',
  ]) {
    final r = Process.runSync('sh', ['-c', 'command -v $o']);
    final chemin = (r.stdout as String).trim();
    if (chemin.isNotEmpty) Link('${outils.path}/$o').createSync(chemin);
  }
  final projet = Directory('${dossier.path}/projet')..createSync();
  return Process.runSync(
    'bash',
    [script],
    workingDirectory: projet.path,
    environment: {
      'PATH': '${bin.path}:${outils.path}',
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

  test('REQ039_AC4 échoue avec la clé de debug', () {
    final r = lancer(
      "uses-permission: name='android.permission.VIBRATE'",
      certificat: 'Signer #1 certificate DN: CN=Android Debug, O=Android, C=US',
    );
    expect(r.exitCode, 1);
    expect('${r.stderr}', contains('ECHEC : APK signé avec la clé de debug'));
  });

  test('REQ039_AC4 réussit avec une clé dédiée et affiche le DN', () {
    final r = lancer("uses-permission: name='android.permission.VIBRATE'");
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    expect('${r.stdout}', contains('Signer #1 certificate DN: CN=Glyphe'));
    expect('${r.stdout}', contains('OK : APK signé avec une clé dédiée.'));
  });

  test('REQ039_AC4 échoue si INTERNET présent malgré une clé dédiée', () {
    final r = lancer("uses-permission: name='android.permission.INTERNET'");
    expect(r.exitCode, 1);
  });

  test('REQ039_AC4 code 2 si apksigner est introuvable', () {
    final r = lancer(
      "uses-permission: name='android.permission.VIBRATE'",
      avecApksigner: false,
    );
    expect(r.exitCode, 2, reason: '${r.stdout}${r.stderr}');
    expect('${r.stderr}', contains('apksigner'));
  });
}
