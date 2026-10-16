import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/modeles.dart';
import 'package:glyphe/domaine/photos.dart';
import 'package:glyphe/domaine/sauvegarde.dart';
import 'package:glyphe/domaine/serialisation.dart';
import 'package:glyphe/plateforme/partage.dart';
import 'package:glyphe/plateforme/stockage_fichier.dart';
import 'package:glyphe/ui/app.dart';
import 'package:glyphe/ui/etat_appli.dart';

import '../faux/faux_partage.dart';
import '../faux/faux_stockage.dart';
import '../faux/faux_voix.dart';
import '../faux/fausse_horloge.dart';
import 'ecran_reglages_test.dart'
    show donnees, ouvrirReglages, toucher, vFr, vFr2;
import 'selecteur_image_test.dart' show io;

const confirmation = 'Toutes les données actuelles seront remplacées';
const invalide = 'Fichier de sauvegarde invalide';
const tropRecente = 'Sauvegarde créée par une version plus récente de Glyphe';

/// Données « B » : autre grille, autres réglages, une case photo.
Donnees donneesB() => Donnees(
  accueilId: 'accB',
  reglages: const Reglages(
    voixId: 'fr2',
    debit: 1.5,
    hauteur: 0.8,
    volume: 0.5,
    delaiAntiRepetitionMs: 2000,
    retourAccueilApresMot: true,
  ),
  grilles: [
    Grille(
      id: 'accB',
      nom: 'Accueil B',
      lignes: 2,
      colonnes: 2,
      cases: const [
        Case(
          id: 'banane',
          ligne: 0,
          colonne: 0,
          type: TypeCase.mot,
          libelle: 'banane',
          image: ImagePhoto('p1.jpg'),
        ),
      ],
    ),
  ],
);

Uint8List archiveB(Directory tmp, {Donnees? d}) {
  final dossier = Directory('${tmp.path}/srcphotos')..createSync();
  File('${dossier.path}/p1.jpg').writeAsBytesSync([1, 2, 3, 4]);
  return exporter(d ?? donneesB(), dossier);
}

class Env {
  Env(
    this.etat,
    this.stockage,
    this.partage,
    this.choix,
    this.tmp,
    this.horloge,
  );
  final EtatAppli etat;
  final FauxStockage stockage;
  final FauxPartage partage;
  final FauxChoixFichier choix;
  final Directory tmp;
  final FausseHorloge horloge;
}

Future<Env> lance(
  WidgetTester tester, {
  Uint8List? fichier,
  Size taille = const Size(915, 412),
  FauxStockage? stockage,
  Directory? tmp,
}) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final t = tmp ?? Directory.systemTemp.createTempSync('glyphe_ei_');
  addTearDown(() => t.deleteSync(recursive: true));
  final s = stockage ?? FauxStockage(donnees());
  s.code = '4321';
  final partage = FauxPartage();
  final choix = FauxChoixFichier(fichier);
  final horloge = FausseHorloge();
  final etat = EtatAppli(
    stockage: s,
    voix: FauxVoix(voix: const [vFr, vFr2]),
    horloge: horloge,
    jsonExemples: '{}',
    partage: partage,
    choixFichier: choix,
    dossierTemporaire: t,
  );
  await etat.init();
  etat.ouvrirEdition();
  await tester.pumpWidget(GlypheApp(etat: etat));
  await tester.pumpAndSettle();
  await ouvrirReglages(tester);
  return Env(etat, s, partage, choix, t, horloge);
}

Future<void> importer(WidgetTester tester, Env e) async {
  await toucher(tester, find.byKey(const Key('reglage-importer')));
  await io(tester, jusqua: () => e.choix.appels > 0);
}

Future<void> confirmer(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('confirmer-import')));
  await tester.pumpAndSettle();
}

/// Simule le sélecteur ou le partage du système : l'appli passe en
/// arrière-plan puis revient avant que l'activité réponde.
Future<void> Function() activiteSysteme(WidgetTester tester) => () async {
  final b = tester.binding;
  b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  b.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  b.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
};

void arrierePlan(WidgetTester tester) {
  final b = tester.binding;
  b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  b.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  // Retour au premier plan : les images sont suspendues tant que l'appli est
  // en pause, et pumpAndSettle ne rendrait pas la main.
  b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  b.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

void main() {
  group('activité système (sélecteur, partage)', () {
    testWidgets('REQ024_AC1 sélecteur en arrière-plan : import abouti', (
      tester,
    ) async {
      final tmp = Directory.systemTemp.createTempSync('glyphe_ei_h_');
      final e = await lance(tester, fichier: archiveB(tmp), tmp: tmp);
      e.choix.pendant = activiteSysteme(tester);
      await importer(tester, e);
      expect(e.etat.verrouille, isFalse);
      expect(find.byKey(const Key('ecran-reglages')), findsOneWidget);
      expect(find.text(confirmation), findsOneWidget);
      await confirmer(tester);
      await io(
        tester,
        jusqua: () => e.etat.session.donnees.accueilId == 'accB',
      );
      expect(e.stockage.donnees!.accueilId, 'accB');
    });

    testWidgets('REQ023_AC1 partage en arrière-plan : export partagé', (
      tester,
    ) async {
      final e = await lance(tester);
      e.partage.pendant = activiteSysteme(tester);
      await toucher(tester, find.byKey(const Key('reglage-exporter')));
      await io(tester, jusqua: () => e.partage.contenus.isNotEmpty);
      expect(e.etat.verrouille, isFalse);
      expect(find.byKey(const Key('ecran-reglages')), findsOneWidget);
      expect(find.text('Export impossible'), findsNothing);
    });

    testWidgets('REQ014_AC2 arrière-plan hors activité : reverrouille', (
      tester,
    ) async {
      final e = await lance(tester);
      arrierePlan(tester);
      await tester.pumpAndSettle();
      expect(e.etat.verrouille, isTrue);
      expect(find.byKey(const Key('ecran-reglages')), findsNothing);
    });

    testWidgets('REQ014_AC2 absence longue pendant une activité : verrouille', (
      tester,
    ) async {
      final e = await lance(tester);
      final b = tester.binding;
      final f = Completer<void>();
      final activite = e.etat.pendantActiviteSysteme(() => f.future);
      b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      b.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(e.etat.verrouille, isFalse);
      e.horloge.avancer(const Duration(seconds: 61));
      b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      b.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(e.etat.verrouille, isTrue);
      f.complete();
      await activite;
    });

    testWidgets(
      'REQ014_AC2 absence longue, reprise après la fin : verrouille',
      (tester) async {
        final e = await lance(tester);
        final b = tester.binding;
        final f = Completer<void>();
        final activite = e.etat.pendantActiviteSysteme(() => f.future);
        b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        b.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        e.horloge.avancer(const Duration(seconds: 61));
        f.complete();
        await activite;
        expect(e.etat.verrouille, isTrue);
      },
    );

    testWidgets('REQ014_AC2 pause courte pendant une activité : reste ouvert', (
      tester,
    ) async {
      final e = await lance(tester);
      final b = tester.binding;
      final f = Completer<void>();
      final activite = e.etat.pendantActiviteSysteme(() => f.future);
      b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      b.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      e.horloge.avancer(const Duration(seconds: 30));
      b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      b.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      f.complete();
      await activite;
      expect(e.etat.verrouille, isFalse);
    });

    testWidgets(
      'REQ014_AC2 deux absences de 30 s séparées de 10 s dans une même '
      'activité : reste ouvert',
      (tester) async {
        final e = await lance(tester);
        final b = tester.binding;
        final f = Completer<void>();
        final activite = e.etat.pendantActiviteSysteme(() => f.future);
        void partir() {
          b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
          b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
          b.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        }

        void revenir() {
          b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
          b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
          b.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        }

        partir();
        e.horloge.avancer(const Duration(seconds: 30));
        revenir();
        e.horloge.avancer(const Duration(seconds: 10));
        partir();
        e.horloge.avancer(const Duration(seconds: 30));
        revenir();
        await tester.pumpAndSettle();
        f.complete();
        await activite;
        expect(e.etat.verrouille, isFalse);
      },
    );

    testWidgets('REQ014 reverrouille après une activité terminée', (
      tester,
    ) async {
      final tmp = Directory.systemTemp.createTempSync('glyphe_ei_i_');
      final e = await lance(tester, fichier: archiveB(tmp), tmp: tmp);
      await importer(tester, e);
      await tester.tap(find.byKey(const Key('annuler-import')));
      await tester.pumpAndSettle();
      expect(e.etat.activiteSystemeEnCours, isFalse);
      arrierePlan(tester);
      await tester.pumpAndSettle();
      expect(e.etat.verrouille, isTrue);
    });

    testWidgets('REQ014 Terminer verrouille pendant une activité', (
      tester,
    ) async {
      final e = await lance(tester);
      final f = Completer<void>();
      final activite = e.etat.pendantActiviteSysteme(() => f.future);
      e.etat.verrouiller();
      expect(e.etat.verrouille, isTrue);
      f.complete();
      await activite;
      expect(e.etat.activiteSystemeEnCours, isFalse);
    });

    testWidgets('REQ024_AC4 fichier trop volumineux : invalide', (
      tester,
    ) async {
      final e = await lance(tester);
      e.choix.erreur = const FichierTropVolumineux();
      await importer(tester, e);
      await io(tester, jusqua: () => find.text(invalide).evaluate().isNotEmpty);
      expect(find.text(invalide), findsOneWidget);
      expect(e.etat.session.donnees.accueilId, 'acc');
    });

    test(
      'REQ024_AC4 lireBornee refuse sans lire une taille excessive',
      () async {
        var lu = false;
        Future<Uint8List> lire() async {
          lu = true;
          return Uint8List(1);
        }

        await expectLater(
          lireBornee(taille: () async => tailleMaxSauvegarde + 1, lire: lire),
          throwsA(isA<FichierTropVolumineux>()),
        );
        await expectLater(
          lireBornee(taille: () async => null, lire: lire),
          throwsA(isA<FichierTropVolumineux>()),
        );
        expect(lu, isFalse);
        final ok = await lireBornee(
          taille: () async => tailleMaxSauvegarde,
          lire: lire,
        );
        expect(ok, hasLength(1));
      },
    );

    testWidgets('export : archive précédente supprimée au nouvel export', (
      tester,
    ) async {
      final e = await lance(tester);
      final ancienne = File('${e.tmp.path}/glyphe-sauvegarde-20200101.zip')
        ..writeAsBytesSync([1]);
      final autre = File('${e.tmp.path}/autre.txt')..writeAsBytesSync([1]);
      await toucher(tester, find.byKey(const Key('reglage-exporter')));
      await io(tester, jusqua: () => e.partage.contenus.isNotEmpty);
      expect(ancienne.existsSync(), isFalse);
      expect(autre.existsSync(), isTrue);
    });
  });

  group('export', () {
    testWidgets('REQ023_AC1 Exporter partage un zip nommé par la date', (
      tester,
    ) async {
      final e = await lance(tester);
      await toucher(tester, find.byKey(const Key('reglage-exporter')));
      await io(tester, jusqua: () => e.partage.contenus.isNotEmpty);
      expect(e.partage.chemins, hasLength(1));
      final chemin = e.partage.chemins.single;
      expect(chemin, startsWith(e.tmp.path));
      expect(chemin, endsWith('glyphe-sauvegarde-20260101.zip'));
      final r = analyserSauvegarde(e.partage.contenus.single);
      expect(r, isA<SauvegardeValide>());
      expect(
        (r as SauvegardeValide).donnees.grilles.single.cases.single.libelle,
        'pomme',
      );
    });

    testWidgets('REQ023_AC2/AC3 version de format, code absent', (
      tester,
    ) async {
      final e = await lance(tester);
      await toucher(tester, find.byKey(const Key('reglage-exporter')));
      await io(tester, jusqua: () => e.partage.contenus.isNotEmpty);
      final z = ZipDecoder().decodeBytes(e.partage.contenus.single);
      final json = utf8.decode(z.findFile('glyphe.json')!.content);
      expect(jsonDecode(json)['versionFormat'], versionFormatCourant);
      expect(json, isNot(contains('4321')));
      for (final f in z.files) {
        expect(utf8.decode(f.content, allowMalformed: true), isNot('4321'));
      }
    });

    testWidgets('REQ023 échec du partage : message, appli utilisable', (
      tester,
    ) async {
      final e = await lance(tester);
      e.partage.erreur = Exception('indisponible');
      await toucher(tester, find.byKey(const Key('reglage-exporter')));
      await io(
        tester,
        jusqua: () => find.text('Export impossible').evaluate().isNotEmpty,
      );
      expect(find.text('Export impossible'), findsOneWidget);
    });
  });

  group('import', () {
    testWidgets('REQ024_AC1 confirmation avant de remplacer', (tester) async {
      final tmp = Directory.systemTemp.createTempSync('glyphe_ei_a_');
      final e = await lance(tester, fichier: archiveB(tmp), tmp: tmp);
      final avant = e.stockage.ecritures;
      await importer(tester, e);
      expect(find.text(confirmation), findsOneWidget);
      expect(e.stockage.ecritures, avant);
      expect(e.etat.session.donnees.accueilId, 'acc');
    });

    testWidgets('REQ024_AC2 confirmé : session, réglages, curseurs, voix', (
      tester,
    ) async {
      final tmp = Directory.systemTemp.createTempSync('glyphe_ei_b_');
      final e = await lance(tester, fichier: archiveB(tmp), tmp: tmp);
      await importer(tester, e);
      await confirmer(tester);
      await io(
        tester,
        jusqua: () => e.etat.session.donnees.accueilId == 'accB',
      );
      final d = e.etat.session.donnees;
      expect(d.grilles.single.cases.single.libelle, 'banane');
      expect(e.stockage.donnees!.accueilId, 'accB');
      expect(d.reglages.voixId, 'fr2');
      // Écran de réglages à jour.
      double valeur(String k) =>
          tester.widget<Slider>(find.byKey(Key(k))).value;
      expect(valeur('curseur-debit'), closeTo(1.5, 0.001));
      expect(valeur('curseur-hauteur'), closeTo(0.8, 0.001));
      expect(valeur('curseur-volume'), closeTo(0.5, 0.001));
      expect(
        tester.widget<ListTile>(find.byKey(const Key('voix-fr2'))).selected,
        isTrue,
      );
      expect(
        tester.widget<ListTile>(find.byKey(const Key('delai-2000'))).selected,
        isTrue,
      );
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const Key('retour-accueil')))
            .value,
        isTrue,
      );
      // Retour à la communication : la grille importée est affichée.
      Navigator.of(tester.element(find.byKey(const Key('ecran-reglages'))))
          .pop();
      await tester.pumpAndSettle();
      expect(find.text('banane'), findsWidgets);
      expect(find.text('pomme'), findsNothing);
    });

    testWidgets('REQ024_AC2 photos importées, code inchangé (AC6)', (
      tester,
    ) async {
      final tmp = Directory.systemTemp.createTempSync('glyphe_ei_c_');
      final racine = Directory('${tmp.path}/app')..createSync();
      final stockage = StockageFichier(racine);
      await tester.runAsync(() async {
        await stockage.enregistrer(donnees());
        await stockage.ecrireCode('4321');
      });
      final zip = archiveB(tmp);
      tester.view.physicalSize = const Size(915, 412);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final choix = FauxChoixFichier(zip);
      final etat = EtatAppli(
        stockage: stockage,
        voix: FauxVoix(voix: const [vFr, vFr2]),
        horloge: FausseHorloge(),
        jsonExemples: '{}',
        partage: FauxPartage(),
        choixFichier: choix,
        photos: Photos(stockage.dossierPhotos),
        dossierTemporaire: tmp,
      );
      await tester.runAsync(etat.init);
      etat.ouvrirEdition();
      await tester.pumpWidget(GlypheApp(etat: etat));
      await tester.pumpAndSettle();
      await ouvrirReglages(tester);
      await toucher(tester, find.byKey(const Key('reglage-importer')));
      await io(tester, jusqua: () => choix.appels > 0);
      await confirmer(tester);
      await io(tester, jusqua: () => etat.session.donnees.accueilId == 'accB');
      await io(
        tester,
        jusqua: () =>
            File('${stockage.dossierPhotos.path}/p1.jpg').existsSync(),
      );
      expect(File('${stockage.dossierPhotos.path}/p1.jpg').readAsBytesSync(), [
        1,
        2,
        3,
        4,
      ]);
      expect(await tester.runAsync(stockage.lireCode), '4321');
      expect(etat.verrou.verifier('4321'), isTrue);
    });

    testWidgets('REQ024_AC3 annulé à la confirmation : rien ne change', (
      tester,
    ) async {
      final tmp = Directory.systemTemp.createTempSync('glyphe_ei_d_');
      final e = await lance(tester, fichier: archiveB(tmp), tmp: tmp);
      final avant = e.etat.session.donnees;
      final ecritures = e.stockage.ecritures;
      await importer(tester, e);
      await tester.tap(find.byKey(const Key('annuler-import')));
      await tester.pumpAndSettle();
      expect(find.text(confirmation), findsNothing);
      expect(e.etat.session.donnees, same(avant));
      expect(e.stockage.ecritures, ecritures);
    });

    testWidgets('REQ024_AC1 sélection annulée : ni dialogue ni changement', (
      tester,
    ) async {
      final e = await lance(tester);
      final avant = e.etat.session.donnees;
      await importer(tester, e);
      expect(find.byType(AlertDialog), findsNothing);
      expect(e.etat.session.donnees, same(avant));
      expect(e.etat.activiteSystemeEnCours, isFalse);
    });

    testWidgets('REQ024_AC4 fichier invalide : message, rien ne change', (
      tester,
    ) async {
      final e = await lance(
        tester,
        fichier: Uint8List.fromList(utf8.encode('pas un zip')),
      );
      final avant = e.etat.session.donnees;
      final ecritures = e.stockage.ecritures;
      await importer(tester, e);
      await io(tester, jusqua: () => find.text(invalide).evaluate().isNotEmpty);
      expect(find.text(invalide), findsOneWidget);
      expect(find.text(confirmation), findsNothing);
      expect(e.etat.session.donnees, same(avant));
      expect(e.stockage.ecritures, ecritures);
    });

    testWidgets('REQ024_AC4 photo référencée manquante : invalide', (
      tester,
    ) async {
      final z = Archive()
        ..addFile(
          ArchiveFile(
            'glyphe.json',
            0,
            utf8.encode(jsonEncode(donneesVersJson(donneesB()))),
          ),
        );
      final e = await lance(
        tester,
        fichier: Uint8List.fromList(ZipEncoder().encode(z)!),
      );
      await importer(tester, e);
      await io(tester, jusqua: () => find.text(invalide).evaluate().isNotEmpty);
      expect(find.text(invalide), findsOneWidget);
      expect(e.etat.session.donnees.accueilId, 'acc');
    });

    testWidgets('REQ024_AC5 version plus récente : refus et message', (
      tester,
    ) async {
      final json = donneesVersJson(donneesB())..['versionFormat'] = 999;
      final z = Archive()
        ..addFile(ArchiveFile('glyphe.json', 0, utf8.encode(jsonEncode(json))));
      final e = await lance(
        tester,
        fichier: Uint8List.fromList(ZipEncoder().encode(z)!),
      );
      final ecritures = e.stockage.ecritures;
      await importer(tester, e);
      await io(
        tester,
        jusqua: () => find.text(tropRecente).evaluate().isNotEmpty,
      );
      expect(find.text(tropRecente), findsOneWidget);
      expect(find.text(invalide), findsNothing);
      expect(e.etat.session.donnees.accueilId, 'acc');
      expect(e.stockage.ecritures, ecritures);
    });

    testWidgets('REQ024_AC7 échec du remplacement : données intactes', (
      tester,
    ) async {
      final tmp = Directory.systemTemp.createTempSync('glyphe_ei_e_');
      final stockage = FauxStockage(donnees())
        ..echecRemplacement = const FileSystemException('disque plein');
      final e = await lance(
        tester,
        fichier: archiveB(tmp),
        stockage: stockage,
        tmp: tmp,
      );
      final avant = e.etat.session.donnees;
      await importer(tester, e);
      await confirmer(tester);
      await io(
        tester,
        jusqua: () =>
            find.text(invalide).evaluate().isNotEmpty ||
            find.text('Import impossible').evaluate().isNotEmpty,
      );
      expect(find.text('Import impossible'), findsOneWidget);
      expect(e.etat.session.donnees, same(avant));
      expect(stockage.donnees!.accueilId, 'acc');
    });

    testWidgets('REQ024 voix du fichier absente : avertissement affiché', (
      tester,
    ) async {
      final tmp = Directory.systemTemp.createTempSync('glyphe_ei_f_');
      final d = donneesB();
      final sans = Donnees(
        accueilId: d.accueilId,
        grilles: d.grilles,
        reglages: d.reglages.copyWith(voixId: () => 'disparue'),
      );
      final e = await lance(
        tester,
        fichier: archiveB(tmp, d: sans),
        tmp: tmp,
      );
      await importer(tester, e);
      await confirmer(tester);
      await io(
        tester,
        jusqua: () => e.etat.session.donnees.accueilId == 'accB',
      );
      await io(
        tester,
        jusqua: () =>
            find.byKey(const Key('avert-voix-indispo')).evaluate().isNotEmpty,
      );
      expect(find.byKey(const Key('avert-voix-indispo')), findsOneWidget);
    });
  });

  for (final taille in const [
    Size(640, 360),
    Size(915, 412),
    Size(1280, 800),
  ]) {
    testWidgets('REQ028 dialogue d\'import accessible $taille', (tester) async {
      final h = tester.ensureSemantics();
      final tmp = Directory.systemTemp.createTempSync('glyphe_ei_g_');
      final e = await lance(
        tester,
        fichier: archiveB(tmp),
        tmp: tmp,
        taille: taille,
      );
      await importer(tester, e);
      expect(find.text(confirmation), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      h.dispose();
    });
  }
}
