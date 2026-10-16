import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/banque_pictos.dart';
import 'package:glyphe/domaine/modeles.dart';
import 'package:glyphe/domaine/photos.dart';
import 'package:glyphe/ui/app.dart';
import 'package:glyphe/ui/etat_appli.dart';

import '../faux/faux_stockage.dart';
import '../faux/faux_voix.dart';
import '../faux/fausse_horloge.dart';
import '../faux/fausse_source_photo.dart';

const String jsonBanque =
    '[{"id":2517,"motsCles":["chien"]},'
    '{"id":7202,"motsCles":["chien de berger"]},'
    '{"id":2617,"motsCles":["je","moi"]}]';

Donnees donnees({String? photo}) => Donnees(
  accueilId: 'acc',
  grilles: [
    Grille(
      id: 'acc',
      nom: 'Accueil',
      lignes: 2,
      colonnes: 2,
      cases: [
        Case(
          id: 'm1',
          ligne: 0,
          colonne: 0,
          type: TypeCase.mot,
          libelle: 'maman',
          image: photo == null ? const ImageAucune() : ImagePhoto(photo),
        ),
        const Case(
          id: 'vide',
          ligne: 0,
          colonne: 1,
          type: TypeCase.mot,
          libelle: '',
          image: ImageArasaac(2617),
        ),
      ],
    ),
  ],
);

class Env {
  Env(this.etat, this.stockage, this.source, this.dossier, this.photos);
  final EtatAppli etat;
  final FauxStockage stockage;
  final FausseSourcePhoto source;
  final Directory dossier;
  final Photos photos;

  Case cas(String id) => etat.session.donnees
      .grillePar('acc')!
      .cases
      .firstWhere((c) => c.id == id);
}

/// Les E/S réelles se terminent hors de l'horloge simulée : alterne attente
/// réelle et pompage pour laisser avancer les chaînes d'`await`.
Future<void> io(WidgetTester t, {bool Function()? jusqua}) async {
  // Attend la condition [jusqua] (au plus ~5 s) ; sans condition, attend que
  // l'état du dossier photos soit stable sur 5 tours consécutifs.
  var precedent = '';
  var stable = 0;
  for (var i = 0; i < 500; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await t.pumpAndSettle();
    if (jusqua != null) {
      if (jusqua()) return;
      continue;
    }
    final etat = envCourant == null ? '' : fichiers(envCourant!).join('|');
    stable = etat == precedent ? stable + 1 : 0;
    precedent = etat;
    if (stable >= 5) return;
  }
}

Env? envCourant;

Future<Env> lance(
  WidgetTester tester, {
  String? photo,
  Size taille = const Size(915, 412),
}) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final dossier = Directory.systemTemp.createTempSync('glyphe_sel_');
  addTearDown(() => dossier.deleteSync(recursive: true));
  final photos = Photos(Directory('${dossier.path}/photos'));
  if (photo != null) {
    Directory('${dossier.path}/photos').createSync();
    File('${dossier.path}/photos/$photo').writeAsBytesSync([1]);
  }
  final src = File('${dossier.path}/source.jpg')..writeAsBytesSync([9, 9]);
  final source = FausseSourcePhoto(
    cheminCamera: src.path,
    cheminGalerie: src.path,
  );
  final stockage = FauxStockage(donnees(photo: photo));
  final etat = EtatAppli(
    stockage: stockage,
    voix: FauxVoix(),
    horloge: FausseHorloge(),
    jsonExemples: '{}',
    banque: BanquePictos.depuisJson(jsonBanque),
    sourcePhoto: source,
    photos: photos,
  );
  await etat.init();
  etat.ouvrirEdition();
  await tester.pumpWidget(GlypheApp(etat: etat));
  await tester.pumpAndSettle();
  return envCourant = Env(etat, stockage, source, dossier, photos);
}

Future<void> toucher(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> ouvrirSelecteur(WidgetTester tester, String idCase) async {
  await toucher(tester, find.byKey(Key('case-$idCase')));
  await toucher(tester, find.byKey(const Key('bouton-image')));
  expect(find.byKey(const Key('ecran-selecteur-image')), findsOneWidget);
}

List<String> fichiers(Env e) {
  final d = Directory('${e.dossier.path}/photos');
  if (!d.existsSync()) return [];
  return [for (final f in d.listSync()) f.uri.pathSegments.last];
}

void main() {
  testWidgets('REQ019_AC1 la recherche chien propose des pictos', (
    tester,
  ) async {
    await lance(tester);
    await ouvrirSelecteur(tester, 'm1');
    await tester.enterText(find.byKey(const Key('champ-recherche')), 'chien');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('picto-2517')), findsOneWidget);
    expect(find.byKey(const Key('picto-7202')), findsOneWidget);
    expect(find.byKey(const Key('picto-2617')), findsNothing);
  });

  testWidgets('REQ019_AC3 sans résultat : message et bouton photo', (
    tester,
  ) async {
    await lance(tester);
    await ouvrirSelecteur(tester, 'm1');
    await tester.enterText(find.byKey(const Key('champ-recherche')), 'zzzz');
    await tester.pumpAndSettle();
    expect(find.text('Aucun pictogramme trouvé'), findsOneWidget);
    expect(find.text('Prendre une photo'), findsOneWidget);
  });

  testWidgets('REQ019 choisir un picto remplit l\'image et le libellé vide', (
    tester,
  ) async {
    final e = await lance(tester);
    await toucher(tester, find.byKey(const Key('case-vide')));
    await toucher(tester, find.byKey(const Key('bouton-image')));
    await tester.enterText(find.byKey(const Key('champ-recherche')), 'chien');
    await tester.pumpAndSettle();
    await toucher(tester, find.byKey(const Key('picto-2517')));
    expect(find.byKey(const Key('ecran-edition-case')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('champ-libelle')))
          .controller!
          .text,
      'chien',
    );
    await toucher(tester, find.byKey(const Key('bouton-enregistrer')));
    expect(e.cas('vide').image, const ImageArasaac(2517));
    expect(e.cas('vide').libelle, 'chien');
  });

  testWidgets('REQ019 un libellé existant n\'est pas écrasé', (tester) async {
    final e = await lance(tester);
    await ouvrirSelecteur(tester, 'm1');
    await tester.enterText(find.byKey(const Key('champ-recherche')), 'chien');
    await tester.pumpAndSettle();
    await toucher(tester, find.byKey(const Key('picto-2517')));
    await toucher(tester, find.byKey(const Key('bouton-enregistrer')));
    expect(e.cas('m1').libelle, 'maman');
    expect(e.cas('m1').image, const ImageArasaac(2517));
  });

  testWidgets('REQ020_AC1/AC2 photo prise : copiée dans photos/', (
    tester,
  ) async {
    final e = await lance(tester);
    await ouvrirSelecteur(tester, 'm1');
    await tester.tap(find.text('Prendre une photo'));
    await io(
      tester,
      jusqua: () =>
          fichiers(e).isNotEmpty &&
          find.byKey(const Key('ecran-edition-case')).evaluate().isNotEmpty,
    );
    expect(e.source.appelsCamera, 1);
    expect(find.byKey(const Key('ecran-edition-case')), findsOneWidget);
    await toucher(tester, find.byKey(const Key('bouton-enregistrer')));
    await io(tester);
    final img = e.cas('m1').image;
    expect(img, isA<ImagePhoto>());
    final nom = (img as ImagePhoto).fichier;
    expect(nom, isNot(contains('/')));
    expect(fichiers(e), [nom]);
    expect(e.stockage.donnees!.grillePar('acc')!.cases.first.image, img);
  });

  testWidgets('REQ020_AC1 photo choisie dans la galerie', (tester) async {
    final e = await lance(tester);
    await ouvrirSelecteur(tester, 'm1');
    await tester.tap(find.text('Choisir dans la galerie'));
    await io(
      tester,
      jusqua: () =>
          fichiers(e).isNotEmpty &&
          find.byKey(const Key('ecran-edition-case')).evaluate().isNotEmpty,
    );
    expect(e.source.appelsGalerie, 1);
    await toucher(tester, find.byKey(const Key('bouton-enregistrer')));
    await io(tester);
    expect(e.cas('m1').image, isA<ImagePhoto>());
    expect(fichiers(e), hasLength(1));
  });

  testWidgets('REQ020_AC1 photo : appli en arrière-plan pendant la prise', (
    tester,
  ) async {
    final e = await lance(tester);
    e.source.pendant = () async {
      final b = tester.binding;
      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        b.handleAppLifecycleStateChanged(s);
      }
    };
    await ouvrirSelecteur(tester, 'm1');
    await tester.tap(find.text('Prendre une photo'));
    await io(
      tester,
      jusqua: () =>
          fichiers(e).isNotEmpty &&
          find.byKey(const Key('ecran-edition-case')).evaluate().isNotEmpty,
    );
    expect(e.etat.verrouille, isFalse);
    await toucher(tester, find.byKey(const Key('bouton-enregistrer')));
    await io(tester);
    expect(e.cas('m1').image, isA<ImagePhoto>());
    expect(fichiers(e), hasLength(1));
  });

  testWidgets('REQ020_AC3 caméra refusée : message, recherche utilisable', (
    tester,
  ) async {
    final e = await lance(tester);
    e.source.refusCamera = true;
    await ouvrirSelecteur(tester, 'm1');
    await tester.tap(find.text('Prendre une photo'));
    await io(tester);
    expect(
      find.textContaining('Accès à l\'appareil photo refusé'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('ecran-selecteur-image')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('champ-recherche')), 'chien');
    await tester.pumpAndSettle();
    await toucher(tester, find.byKey(const Key('picto-2517')));
    await toucher(tester, find.byKey(const Key('bouton-enregistrer')));
    expect(e.cas('m1').image, const ImageArasaac(2517));
  });

  testWidgets('REQ020_AC3 galerie refusée : message dédié', (tester) async {
    final e = await lance(tester);
    e.source.refusGalerie = true;
    await ouvrirSelecteur(tester, 'm1');
    await tester.tap(find.text('Choisir dans la galerie'));
    await io(tester);
    expect(find.textContaining('Accès aux photos refusé'), findsOneWidget);
    expect(fichiers(e), isEmpty);
  });

  testWidgets('annulation de la prise de photo : rien ne change', (
    tester,
  ) async {
    final e = await lance(tester);
    e.source.cheminCamera = null;
    await ouvrirSelecteur(tester, 'm1');
    await tester.tap(find.text('Prendre une photo'));
    await io(tester);
    expect(find.byKey(const Key('ecran-selecteur-image')), findsOneWidget);
    expect(find.textContaining('refusé'), findsNothing);
    expect(fichiers(e), isEmpty);
  });

  testWidgets('REQ020_AC4 remplacer la photo supprime l\'ancien fichier', (
    tester,
  ) async {
    final e = await lance(tester, photo: 'ancienne.jpg');
    await ouvrirSelecteur(tester, 'm1');
    await tester.enterText(find.byKey(const Key('champ-recherche')), 'chien');
    await tester.pumpAndSettle();
    await toucher(tester, find.byKey(const Key('picto-2517')));
    await toucher(tester, find.byKey(const Key('bouton-enregistrer')));
    await io(tester);
    expect(e.cas('m1').image, const ImageArasaac(2517));
    expect(fichiers(e), isEmpty);
  });

  testWidgets('REQ020_AC4 supprimer la case supprime sa photo', (tester) async {
    final e = await lance(tester, photo: 'ancienne.jpg');
    await toucher(tester, find.byKey(const Key('case-m1')));
    await toucher(tester, find.byKey(const Key('bouton-supprimer')));
    await toucher(tester, find.byKey(const Key('confirmer-suppression')));
    await io(tester);
    expect(fichiers(e), isEmpty);
  });

  testWidgets('REQ020 photo importée mais case non enregistrée : nettoyée', (
    tester,
  ) async {
    final e = await lance(tester, photo: 'ancienne.jpg');
    await ouvrirSelecteur(tester, 'm1');
    await tester.tap(find.text('Prendre une photo'));
    await io(
      tester,
      jusqua: () =>
          fichiers(e).length == 2 &&
          find.byKey(const Key('ecran-edition-case')).evaluate().isNotEmpty,
    );
    expect(fichiers(e).length, 2);
    await tester.tap(find.byTooltip('Retour'));
    await io(tester, jusqua: () => fichiers(e).length == 1);
    expect(fichiers(e), ['ancienne.jpg']);
  });

  testWidgets('une photo stockée s\'affiche via le dossier photos', (
    tester,
  ) async {
    final e = await lance(tester, photo: 'ancienne.jpg');
    final image = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('case-m1')),
        matching: find.byType(Image),
      ),
    );
    final p = image.image as FileImage;
    expect(p.file.path, e.photos.resoudre('ancienne.jpg'));
  });
}
