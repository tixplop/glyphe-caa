import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/banque_pictos.dart';
import 'package:glyphe/domaine/photos.dart';
import 'package:glyphe/ui/app.dart';
import 'package:glyphe/ui/ecran_a_propos.dart';
import 'package:glyphe/ui/etat_appli.dart';
import 'package:glyphe/version.dart';

import '../faux/faux_stockage.dart';
import '../faux/faux_voix.dart';
import '../faux/fausse_horloge.dart';
import '../faux/fausse_source_photo.dart';

const attribution =
    'Les symboles pictographiques utilisés sont la propriété du Gouvernement '
    'd\'Aragon et ont été créés par Sergio Palao pour ARASAAC '
    '(http://www.arasaac.org), qui les distribue sous licence Creative '
    'Commons BY-NC-SA.';

void main() {
  test('REQ027_AC2 la constante de version égale celle de pubspec.yaml', () {
    final ligne = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    expect(ligne.substring('version:'.length).trim(), versionAppli);
  });

  testWidgets(
    'REQ027_AC1/AC2 écran À propos : attribution, gratuité, version',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: EcranAPropos()));
      expect(find.text(attribution), findsOneWidget);
      expect(find.textContaining('gratuit'), findsOneWidget);
      expect(find.textContaining('non commercial'), findsOneWidget);
      expect(find.textContaining(versionAppli), findsOneWidget);
    },
  );

  testWidgets('REQ027_AC3 crédite la police Atkinson Hyperlegible', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: EcranAPropos()));
    expect(
      find.text(
        'Police : Atkinson Hyperlegible (Braille Institute), licence SIL '
        'Open Font License 1.1.',
      ),
      findsOneWidget,
    );
  });

  for (final edition in [false, true]) {
    testWidgets('REQ027_AC1 accessible depuis la communication (édition: '
        '$edition)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final dossier = Directory.systemTemp.createTempSync('glyphe_apropos_');
      addTearDown(() => dossier.deleteSync(recursive: true));
      final etat = EtatAppli(
        stockage: FauxStockage(),
        voix: FauxVoix(),
        horloge: FausseHorloge(),
        jsonExemples: File('assets/exemples/grilles_exemple.json')
            .readAsStringSync(),
        banque: BanquePictos.depuisJson(
          File('assets/arasaac/index.json').readAsStringSync(),
        ),
        sourcePhoto: FausseSourcePhoto(),
        photos: Photos(Directory('${dossier.path}/photos')),
      );
      await etat.init();
      if (edition) etat.ouvrirEdition();
      await tester.pumpWidget(GlypheApp(etat: etat));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bouton-a-propos')));
      await tester.pumpAndSettle();
      expect(find.text(attribution), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
