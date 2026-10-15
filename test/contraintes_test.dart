import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('REQ026_AC1 le manifeste principal supprime la permission INTERNET', () {
    final manifeste = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifeste, contains('xmlns:tools='));
    expect(
      manifeste,
      matches(
        RegExp(
          r'<uses-permission[^>]*android:name="android\.permission\.INTERNET"[^>]*tools:node="remove"',
        ),
      ),
    );
  });

  test('REQ026_AC2 aucune dépendance d\'analytics, pub ou crash-reporting', () {
    final lignes = File('pubspec.yaml').readAsLinesSync();
    final noms = <String>[];
    var section = false;
    for (final l in lignes) {
      if (RegExp(r'^(dependencies|dev_dependencies|dependency_overrides):')
          .hasMatch(l)) {
        section = true;
        continue;
      }
      if (l.isNotEmpty && !l.startsWith(' ') && !l.startsWith('#')) {
        section = false;
      }
      final m = RegExp(r'^  ([a-z0-9_]+):').firstMatch(l);
      if (section && m != null) noms.add(m.group(1)!);
    }
    expect(noms, contains('flutter'));
    const interdits = [
      'firebase', 'analytics', 'crashlytics', 'sentry', 'ads', 'admob', //
    ];
    for (final n in noms) {
      for (final i in interdits) {
        expect(n.contains(i), isFalse, reason: 'dépendance interdite : $n');
      }
    }
  });

  test('REQ035_AC2 aucune couleur en dur dans lib/ui', () {
    final fautes = <String>[];
    for (final f in Directory('lib/ui').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync().replaceAll(RegExp(r'//[^\n]*'), '');
      for (final m in RegExp(r'Colors\.(\w+)').allMatches(src)) {
        if (m.group(1) != 'transparent') {
          fautes.add('${f.path} : ${m.group(0)}');
        }
      }
    }
    expect(fautes, isEmpty);
  });
}
