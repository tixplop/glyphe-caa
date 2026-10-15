import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/banque_pictos.dart';
import 'package:glyphe/domaine/photos.dart';
import 'package:glyphe/ui/app.dart';
import 'package:glyphe/ui/ecran_a_propos.dart';
import 'package:glyphe/ui/etat_appli.dart';
import 'package:glyphe/ui/theme.dart';
import 'package:glyphe/ui/tokens.dart';

import '../faux/faux_stockage.dart';
import '../faux/faux_voix.dart';
import '../faux/fausse_horloge.dart';
import '../faux/fausse_source_photo.dart';

Future<void> verifier(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

Future<EtatAppli> etatPret(WidgetTester tester) async {
  final dossier = Directory.systemTemp.createTempSync('glyphe_a11y_');
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
  return etat;
}

Future<void> depuisMenu(WidgetTester tester, String cle) async {
  await tester.tap(find.byKey(const Key('bouton-plus')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(cle)));
  await tester.pumpAndSettle();
}

Future<void> retour(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).pop();
  await tester.pumpAndSettle();
}

void main() {
  for (final sombre in const [false, true]) {
    for (final taille in const [Size(360, 640), Size(800, 1280)]) {
      testWidgets('REQ028_AC1/AC2/AC4 REQ035_AC2 tous les écrans, thème '
          '${sombre ? 'sombre' : 'clair'} $taille', (tester) async {
        final h = tester.ensureSemantics();
        tester.view.physicalSize = taille;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        if (sombre) {
          tester.platformDispatcher.platformBrightnessTestValue =
              Brightness.dark;
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
        }
        final etat = await etatPret(tester);
        await tester.pumpWidget(GlypheApp(etat: etat));
        await tester.pumpAndSettle();
        final tokens = sombre ? GlypheTokens.sombre : GlypheTokens.clair;
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        expect(
          scaffold.backgroundColor ??
              Theme.of(tester.element(find.byType(Scaffold).first))
                  .scaffoldBackgroundColor,
          tokens.surface100,
        );
        await verifier(tester); // communication

        etat.ouvrirEdition();
        await tester.pumpAndSettle();
        await verifier(tester); // édition

        await depuisMenu(tester, 'bouton-grilles');
        expect(find.byKey(const Key('ecran-grilles')), findsOneWidget);
        await verifier(tester);
        await retour(tester);

        await depuisMenu(tester, 'bouton-reglages');
        expect(find.byKey(const Key('ecran-reglages')), findsOneWidget);
        await verifier(tester);
        await retour(tester);

        await depuisMenu(tester, 'bouton-a-propos');
        expect(find.byType(EcranAPropos), findsOneWidget);
        await verifier(tester);
        await retour(tester);
        h.dispose();
      });
    }
  }

  testWidgets('REQ035_AC5 le thème n\'a pas d\'ondulation', (tester) async {
    for (final l in Brightness.values) {
      expect(themeGlyphe(l).splashFactory, NoSplash.splashFactory);
    }
  });

  testWidgets('REQ035_AC4 réglages : le texte body suit l\'échelle 2', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final etat = await etatPret(tester);
    etat.ouvrirEdition();
    await tester.pumpWidget(GlypheApp(etat: etat));
    await tester.pumpAndSettle();
    await depuisMenu(tester, 'bouton-reglages');
    final ctx = tester.element(find.byKey(const Key('ecran-reglages')));
    final base = GlypheTokens.body.fontSize!;
    expect(MediaQuery.textScalerOf(ctx).scale(base), base * 2);
    final texte = tester.widget<RichText>(
      find
          .descendant(
            of: find.byKey(const Key('ecran-reglages')),
            matching: find.byType(RichText),
          )
          .first,
    );
    expect(texte.textScaler.scale(base), base * 2);
  });
  for (final sombre in const [false, true]) {
    for (final taille in const [
      Size(360, 640),
      Size(640, 360),
      Size(800, 1280),
      Size(1280, 800),
    ]) {
      testWidgets('REQ028_AC1/AC2/AC4 mode édition, sélecteur compris, thème '
          '${sombre ? 'sombre' : 'clair'} $taille', (tester) async {
        if (sombre) {
          tester.platformDispatcher.platformBrightnessTestValue =
              Brightness.dark;
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
        }
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

        await tester.enterText(
          find.byKey(const Key('champ-recherche')),
          'chien',
        );
        await tester.pumpAndSettle();
        expect(find.byType(Image), findsWidgets);
        await verifier(tester); // résultats

        await tester.enterText(
          find.byKey(const Key('champ-recherche')),
          'zzzzz',
        );
        await tester.pumpAndSettle();
        expect(find.text('Aucun pictogramme trouvé'), findsOneWidget);
        await verifier(tester); // sans résultat
        h.dispose();
      });
    }
  }
}
