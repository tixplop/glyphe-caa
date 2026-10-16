import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/ui/app.dart';

import 'ui/accessibilite_edition_test.dart' show depuisMenu, etatPret, retour;

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

  test('REQ036_AC5 pas de FittedBox dans les barres ni l\'édition de case', () {
    final fichiers = [
      ...Directory('lib/ui/widgets').listSync().whereType<File>().where(
        (f) => RegExp(r'(barre_|bouton_barre)[^/]*\.dart$').hasMatch(f.path),
      ),
      File('lib/ui/ecran_edition_case.dart'),
    ];
    expect(fichiers.length, greaterThanOrEqualTo(4));
    for (final f in fichiers) {
      final src = f.readAsStringSync().replaceAll(RegExp(r'//[^\n]*'), '');
      expect(src.contains('FittedBox'), isFalse, reason: f.path);
    }
  });

  for (final sombre in const [false, true]) {
    testWidgets('REQ036_AC5 tout texte rendu sous un bouton fait au moins 15 '
        '(${sombre ? 'sombre' : 'clair'})', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      if (sombre) {
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      }
      final etat = await etatPret(tester);
      await tester.pumpWidget(GlypheApp(etat: etat));
      await tester.pumpAndSettle();

      final boutons = find.byWidgetPredicate(
        (w) => w is ButtonStyleButton || w is IconButton,
      );
      void verifier(String ecran) {
        final fautes = <String>[];
        final textes = find.descendant(
          of: boutons,
          matching: find.byType(RichText),
        );
        for (final w in tester.widgetList<RichText>(textes)) {
          final taille = w.text.style?.fontSize;
          if (taille == null || taille < 15) {
            fautes.add('${w.text.toPlainText()} : $taille');
          }
        }
        expect(fautes, isEmpty, reason: ecran);
      }

      Future<void> fermerPopup() async {
        await tester.tapAt(const Offset(2, 2));
        await tester.pumpAndSettle();
      }

      verifier('communication');
      etat.ouvrirEdition();
      await tester.pumpAndSettle();
      verifier('édition');

      for (final cle in const [
        'bouton-grilles',
        'bouton-reglages',
        'bouton-a-propos',
      ]) {
        await depuisMenu(tester, cle);
        verifier(cle);
        await retour(tester);
      }

      await tester.tap(
        find
            .byWidgetPredicate(
              (w) =>
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>).value.startsWith('case-'),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ecran-edition-case')), findsOneWidget);
      verifier('édition de case');

      await tester.ensureVisible(find.byKey(const Key('bouton-image')));
      await tester.tap(find.byKey(const Key('bouton-image')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ecran-selecteur-image')), findsOneWidget);
      verifier('sélecteur d\'image');
      await retour(tester);

      await tester.ensureVisible(find.byKey(const Key('bouton-supprimer')));
      await tester.tap(find.byKey(const Key('bouton-supprimer')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('confirmation-suppression')), findsOneWidget);
      verifier('confirmation de suppression');
      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('bouton-echanger')));
      await tester.tap(find.byKey(const Key('bouton-echanger')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(OutlinedButton), findsWidgets);
      verifier('choix d\'emplacement');
      await fermerPopup();
    });
  }

  test('REQ028_AC5 tout AppBar de lib/ui a un titre TitreBarre', () {
    for (final f in Directory('lib/ui').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync().replaceAll(RegExp(r'//[^\n]*'), '');
      final n = 'AppBar('.allMatches(src).length;
      final t = RegExp(r'title:\s*(const\s+)?TitreBarre\(').allMatches(src);
      expect(t.length, n, reason: f.path);
    }
  });

  test('REQ038_AC5 tout AlertDialog de lib/ui défile avec marges réduites', () {
    for (final f in Directory('lib/ui').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      final n = RegExp(r'(Alert|Simple)Dialog\(').allMatches(src).length;
      final ins = 'insetPadding'.allMatches(src).length;
      expect(ins, n, reason: f.path);
      final alertes = 'AlertDialog('.allMatches(src).length;
      expect(
        'scrollable: true'.allMatches(src).length,
        alertes,
        reason: f.path,
      );
    }
  });

  test('REQ031 REQ037 plus de barre de navigation ni d\'onglets dans lib/', () {
    final noms = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .toList();
    expect(noms, isNot(contains('barre_navigation.dart')));
    expect(noms, isNot(contains('onglets.dart')));
  });

  test('REQ034 la barre de phrase n\'a ni bouton Parler, ni onglet, ni '
      'appui long', () {
    final src = File('lib/ui/widgets/barre_phrase.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r'//[^\n]*'), '');
    for (final interdit in const ['bouton-parler', 'onglet-', 'onLongPress']) {
      expect(src.contains(interdit), isFalse, reason: interdit);
    }
  });

  test('REQ038_AC1 main appelle fixerOrientation avant le premier runApp', () {
    final src = File('lib/main.dart').readAsStringSync();
    final a = src.indexOf('fixerOrientation()');
    expect(a, isNonNegative);
    expect(a, lessThan(src.indexOf('runApp(')));
  });

  test('REQ038_AC2 activité principale en sensorLandscape', () {
    final m = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(
      m,
      matches(
        RegExp(
          r'<activity[^>]*android:name="\.MainActivity"[^>]*'
          r'android:screenOrientation="sensorLandscape"',
        ),
      ),
    );
  });

  test('REQ038_AC3 Info.plist paysage seulement, plein écran requis', () {
    final p = File('ios/Runner/Info.plist').readAsStringSync();
    expect(p, isNot(contains('Portrait')));
    expect(p, contains('LandscapeLeft'));
    expect(p, contains('LandscapeRight'));
    expect(p, matches(RegExp(r'<key>UIRequiresFullScreen</key>\s*<true/>')));
  });
}
