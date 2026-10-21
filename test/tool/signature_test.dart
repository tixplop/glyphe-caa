import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String lire(String chemin) => File(chemin).readAsStringSync();

void main() {
  test('REQ039_AC1 build.gradle.kts définit la signature release', () {
    final gradle = lire('android/app/build.gradle.kts');
    for (final motif in [
      'key.properties',
      'create("release")',
      'storeFile',
      'storePassword',
      'keyAlias',
      'keyPassword',
    ]) {
      expect(gradle, contains(motif));
    }
  });

  test('REQ039_AC2 le TODO de signature est retiré', () {
    expect(
      lire('android/app/build.gradle.kts'),
      isNot(contains('TODO: Add your own signing config')),
    );
  });

  test('REQ039_AC3 les secrets de signature sont ignorés et non suivis', () {
    final ignore = lire('android/.gitignore');
    for (final motif in ['key.properties', '**/*.keystore', '**/*.jks']) {
      expect(ignore, contains(motif));
    }
    final r = Process.runSync('git', ['ls-files']);
    if (r.exitCode == 0) {
      final suivis = (r.stdout as String)
          .split('\n')
          .where(
            (f) =>
                f.endsWith('key.properties') ||
                f.endsWith('.jks') ||
                f.endsWith('.keystore'),
          );
      expect(suivis, isEmpty);
    }
  });

  test('REQ039_AC4 le script vérifie la signature', () {
    final script = lire('tool/verifier_apk.sh');
    expect(script, contains('apksigner'));
    expect(script, contains('CN=Android Debug'));
  });

  test('REQ039_AC5 le README documente la signature', () {
    expect(lire('README.md'), contains("## Signature de l'APK"));
  });
}
