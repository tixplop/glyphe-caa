import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/banque_pictos.dart';
import 'package:glyphe/domaine/photos.dart';
import 'package:glyphe/ui/app.dart';
import 'package:glyphe/ui/etat_appli.dart';

import '../faux/faux_stockage.dart';
import '../faux/faux_voix.dart';
import '../faux/fausse_horloge.dart';
import '../faux/fausse_source_photo.dart';

Future<void> verifier(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

void main() {
  for (final taille in const [
    Size(360, 640),
    Size(640, 360),
    Size(800, 1280),
    Size(1280, 800),
  ]) {
    testWidgets('REQ028_AC1/AC2/AC4 mode édition, sélecteur compris $taille', (
      tester,
    ) async {
      final h = tester.ensureSemantics();
      tester.view.physicalSize = taille;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final dossier = Directory.systemTemp.createTempSync('glyphe_a11y_');
      addTearDown(() => dossier.deleteSync(recursive: true));
      final json = File('assets/exemples/grilles_exemple.json')
          .readAsStringSync();
      final stockage = FauxStockage();
      final etat = EtatAppli(
        stockage: stockage,
        voix: FauxVoix(),
        horloge: FausseHorloge(),
        jsonExemples: json,
        banque: BanquePictos.depuisJson(
          File('assets/arasaac/index.json').readAsStringSync(),
        ),
        sourcePhoto: FausseSourcePhoto(),
        photos: Photos(Directory('${dossier.path}/photos')),
      );
      await etat.init();
      etat.ouvrirEdition();
      await tester.pumpWidget(GlypheApp(etat: etat));
      await tester.pumpAndSettle();
      await verifier(tester); // grille en édition

      final premiere = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('case-'),
      );
      await tester.tap(premiere.first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ecran-edition-case')), findsOneWidget);
      await verifier(tester); // édition d'une case

      await tester.ensureVisible(find.byKey(const Key('bouton-image')));
      await tester.tap(find.byKey(const Key('bouton-image')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ecran-selecteur-image')), findsOneWidget);
      await verifier(tester); // sélecteur vide

      await tester.enterText(find.byKey(const Key('champ-recherche')), 'chien');
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsWidgets);
      await verifier(tester); // résultats

      await tester.enterText(find.byKey(const Key('champ-recherche')), 'zzzzz');
      await tester.pumpAndSettle();
      expect(find.text('Aucun pictogramme trouvé'), findsOneWidget);
      await verifier(tester); // sans résultat
      h.dispose();
    });
  }
}
