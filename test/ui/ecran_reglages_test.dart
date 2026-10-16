import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/modeles.dart';
import 'package:glyphe/domaine/voix.dart';
import 'package:glyphe/ui/app.dart';
import 'package:glyphe/ui/ecran_code.dart';
import 'package:glyphe/ui/etat_appli.dart';
import 'package:glyphe/ui/textes.dart';

import '../faux/faux_stockage.dart';
import '../faux/faux_voix.dart';
import '../faux/fausse_horloge.dart';
import 'selecteur_image_test.dart' show io;

const vFr = InfoVoix(id: 'fr1', nom: 'Zoé', locale: 'fr-FR');
const vFr2 = InfoVoix(id: 'fr2', nom: 'Amélie', locale: 'fr-CA');
const vEn = InfoVoix(id: 'en1', nom: 'Alice', locale: 'en-US');

Donnees donnees({Reglages reglages = const Reglages()}) => Donnees(
  accueilId: 'acc',
  reglages: reglages,
  grilles: [
    Grille(
      id: 'acc',
      nom: 'Accueil',
      lignes: 2,
      colonnes: 2,
      cases: const [
        Case(
          id: 'pomme',
          ligne: 0,
          colonne: 0,
          type: TypeCase.mot,
          libelle: 'pomme',
        ),
      ],
    ),
  ],
);

class Env {
  Env(this.etat, this.stockage, this.voix);
  final EtatAppli etat;
  final FauxStockage stockage;
  final FauxVoix voix;
  Reglages get reglages => etat.session.donnees.reglages;
}

EtatAppli creer(FauxStockage s, FauxVoix v) => EtatAppli(
  stockage: s,
  voix: v,
  horloge: FausseHorloge(),
  jsonExemples: '{}',
);

Future<Env> lance(
  WidgetTester tester, {
  List<InfoVoix> voix = const [vFr, vFr2, vEn],
  Reglages reglages = const Reglages(),
  Size taille = const Size(640, 360),
  bool ouvrir = true,
}) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final stockage = FauxStockage(donnees(reglages: reglages));
  final faux = FauxVoix(voix: voix);
  final etat = creer(stockage, faux);
  await etat.init();
  etat.ouvrirEdition();
  await tester.pumpWidget(GlypheApp(etat: etat));
  await tester.pumpAndSettle();
  if (ouvrir) await ouvrirReglages(tester);
  return Env(etat, stockage, faux);
}

Future<void> ouvrirReglages(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('bouton-plus')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('bouton-reglages')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('ecran-reglages')), findsOneWidget);
}

Future<void> toucher(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Glisse le curseur [cle] jusqu'à sa butée gauche, puis attend l'écriture.
Future<void> butee(WidgetTester tester, String cle, Env e) async {
  final f = find.byKey(Key(cle));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.drag(f, const Offset(-2000, 0));
  await io(tester, jusqua: () => e.stockage.ecritures > 0);
}

/// Recrée un état depuis le même stockage (redémarrage).
Future<Reglages> redemarre(Env e) async {
  final etat = creer(e.stockage, e.voix);
  await etat.init();
  return etat.session.donnees.reglages;
}

/// Stockage dont l'écriture reste en attente jusqu'à [terminer] ou [echouer].
class StockageLent extends FauxStockage {
  StockageLent(super.donnees);

  final List<Completer<void>> attentes = [];

  @override
  Future<void> enregistrer(Donnees d) async {
    final c = Completer<void>();
    attentes.add(c);
    await c.future;
    await super.enregistrer(d);
  }
}

void main() {
  testWidgets('REQ021 le menu Plus propose Réglages en mode édition', (
    tester,
  ) async {
    await lance(tester, ouvrir: false);
    await tester.tap(find.byKey(const Key('bouton-plus')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bouton-reglages')), findsOneWidget);
    expect(find.text('Réglages'), findsOneWidget);
  });

  testWidgets('REQ021 aucun accès aux réglages en mode communication', (
    tester,
  ) async {
    final e = await lance(tester, ouvrir: false);
    e.etat.verrouiller();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bouton-plus')), findsNothing);
    expect(find.byKey(const Key('bouton-reglages')), findsNothing);
  });

  testWidgets('REQ021_AC1 voix françaises d\'abord puis ordre alphabétique', (
    tester,
  ) async {
    await lance(tester);
    final cles = [
      for (final w in tester.widgetList(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('voix-') &&
              w.key != const Key('voix-defaut'),
        ),
      ))
        (w.key! as ValueKey<String>).value,
    ];
    expect(cles, ['voix-fr2', 'voix-fr1', 'voix-en1']);
  });

  testWidgets('REQ021_AC2 valeurs par défaut des curseurs', (tester) async {
    await lance(tester);
    Slider s(String c) => tester.widget<Slider>(find.byKey(Key(c)));
    expect((s('curseur-debit').min, s('curseur-debit').max), (0.5, 2.0));
    expect((s('curseur-hauteur').min, s('curseur-hauteur').max), (0.5, 2.0));
    expect((s('curseur-volume').min, s('curseur-volume').max), (0.0, 1.0));
    expect(s('curseur-debit').value, 1.0);
    expect(s('curseur-hauteur').value, 1.0);
    expect(s('curseur-volume').value, 1.0);
    expect(s('curseur-debit').divisions, 15);
  });

  testWidgets('REQ021_AC3 Tester prononce la phrase avec les réglages', (
    tester,
  ) async {
    final e = await lance(
      tester,
      reglages: const Reglages(
        voixId: 'en1',
        debit: 0.7,
        hauteur: 1.5,
        volume: 0.4,
      ),
    );
    await toucher(tester, find.byKey(const Key('bouton-tester')));
    expect(e.voix.textesPrononces, ["Bonjour, je m'appelle Glyphe"]);
    final p = e.voix.parametresAppels.single;
    expect((p.voixId, p.debit, p.hauteur, p.volume), ('en1', 0.7, 1.5, 0.4));
  });

  testWidgets('REQ021_AC4 débit 0,5 transmis aux mots des cases', (
    tester,
  ) async {
    final e = await lance(tester);
    await butee(tester, 'curseur-debit', e);
    expect(e.reglages.debit, 0.5);
    final pomme = e.etat.session.donnees.grillePar('acc')!.cases.single;
    await e.etat.session.appuyerCase(pomme);
    expect(e.voix.textesPrononces, ['pomme']);
    expect(e.voix.parametresAppels.last.debit, 0.5);
  });

  testWidgets('REQ021_AC2/AC5 hauteur et volume bornés et persistants', (
    tester,
  ) async {
    final e = await lance(tester);
    await butee(tester, 'curseur-hauteur', e);
    await butee(tester, 'curseur-volume', e);
    final r = await redemarre(e);
    expect(r.hauteur, 0.5);
    expect(r.volume, 0.0);
    expect(r.debit, 1.0);
  });

  testWidgets('REQ021_AC5 débit persistant après redémarrage', (tester) async {
    final e = await lance(tester);
    await butee(tester, 'curseur-debit', e);
    expect((await redemarre(e)).debit, 0.5);
  });

  testWidgets('REQ021_AC5 voix choisie persistante, et voix par défaut', (
    tester,
  ) async {
    final e = await lance(tester);
    await toucher(tester, find.byKey(const Key('voix-en1')));
    await io(tester, jusqua: () => e.stockage.ecritures > 0);
    expect((await redemarre(e)).voixId, 'en1');
    final avant = e.stockage.ecritures;
    await toucher(tester, find.byKey(const Key('voix-defaut')));
    await io(tester, jusqua: () => e.stockage.ecritures > avant);
    expect((await redemarre(e)).voixId, isNull);
  });

  testWidgets('REQ004 délai anti-répétition choisi et persistant', (
    tester,
  ) async {
    final e = await lance(tester);
    for (final ms in [0, 500, 1000, 2000, 3000, 5000]) {
      expect(find.byKey(Key('delai-$ms')), findsOneWidget, reason: '$ms');
    }
    await toucher(tester, find.byKey(const Key('delai-2000')));
    await io(tester, jusqua: () => e.stockage.ecritures > 0);
    expect(e.reglages.delaiAntiRepetitionMs, 2000);
    expect((await redemarre(e)).delaiAntiRepetitionMs, 2000);
    final avant = e.stockage.ecritures;
    await toucher(tester, find.byKey(const Key('delai-0')));
    await io(tester, jusqua: () => e.stockage.ecritures > avant);
    expect((await redemarre(e)).delaiAntiRepetitionMs, 0);
  });

  testWidgets('REQ010_AC3 retour à l\'accueil persistant', (tester) async {
    final e = await lance(tester);
    final sw = find.byKey(const Key('retour-accueil'));
    expect(tester.widget<SwitchListTile>(sw).value, isFalse);
    await toucher(tester, sw);
    await io(tester, jusqua: () => e.stockage.ecritures > 0);
    expect(e.reglages.retourAccueilApresMot, isTrue);
    expect((await redemarre(e)).retourAccueilApresMot, isTrue);
    expect(tester.widget<SwitchListTile>(sw).value, isTrue);
  });

  testWidgets('REQ012 le code de déverrouillage ouvre l\'écran du code', (
    tester,
  ) async {
    await lance(tester);
    await toucher(tester, find.byKey(const Key('reglage-code')));
    expect(find.byType(EcranCode), findsOneWidget);
  });

  testWidgets('REQ023 entrées Exporter et Importer présentes', (tester) async {
    await lance(tester);
    await tester.ensureVisible(find.byKey(const Key('reglage-importer')));
    expect(find.byKey(const Key('reglage-exporter')), findsOneWidget);
    expect(find.byKey(const Key('reglage-importer')), findsOneWidget);
  });

  testWidgets('REQ005_AC2 aucune voix : avertissement et indication', (
    tester,
  ) async {
    await lance(tester, voix: const []);
    expect(find.text('Aucune voix de synthèse disponible'), findsOneWidget);
    expect(find.byKey(const Key('indication-installation')), findsOneWidget);
    expect(find.text('La voix choisie n\'est plus disponible'), findsNothing);
  });

  testWidgets('REQ005_AC2 pas d\'avertissement quand une voix existe', (
    tester,
  ) async {
    await lance(tester);
    expect(find.text('Aucune voix de synthèse disponible'), findsNothing);
    expect(find.text('La voix choisie n\'est plus disponible'), findsNothing);
  });

  testWidgets('REQ005_AC1 sans voix, un mot est quand même ajouté', (
    tester,
  ) async {
    final e = await lance(tester, voix: const []);
    final pomme = e.etat.session.donnees.grillePar('acc')!.cases.single;
    await e.etat.session.appuyerCase(pomme);
    expect(e.etat.session.barre, hasLength(1));
  });

  testWidgets('REQ022_AC1 voix enregistrée absente : avertissement', (
    tester,
  ) async {
    await lance(tester, reglages: const Reglages(voixId: 'disparue'));
    expect(find.text('La voix choisie n\'est plus disponible'), findsOneWidget);
    expect(find.text('Aucune voix de synthèse disponible'), findsNothing);
  });

  testWidgets('REQ022_AC1 revérification au retour au premier plan', (
    tester,
  ) async {
    final e = await lance(tester, reglages: const Reglages(voixId: 'en1'));
    expect(find.text('La voix choisie n\'est plus disponible'), findsNothing);
    e.voix.voix = const [vFr];
    final b = tester.binding;
    b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    b.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await io(
      tester,
      jusqua: () => find
          .text('La voix choisie n\'est plus disponible')
          .evaluate()
          .isNotEmpty,
    );
    expect(find.text('La voix choisie n\'est plus disponible'), findsOneWidget);
  });

  testWidgets('REQ022_AC1 séquence complète avec reverrouillage puis reprise', (
    tester,
  ) async {
    final e = await lance(tester, reglages: const Reglages(voixId: 'en1'));
    e.voix.voix = const [vFr];
    final b = tester.binding;
    b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    b.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    b.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await io(tester, jusqua: () => e.etat.voixEnregistreeIndisponible);
    expect(find.byKey(const Key('ecran-reglages')), findsNothing);
    final pomme = e.etat.session.donnees.grillePar('acc')!.cases.single;
    await e.etat.session.appuyerCase(pomme);
    expect(e.voix.parametresAppels.last.voixId, 'fr1');
    e.etat.ouvrirEdition();
    await tester.pumpAndSettle();
    await ouvrirReglages(tester);
    expect(find.text('La voix choisie n\'est plus disponible'), findsOneWidget);
  });

  testWidgets('REQ014 verrouiller depuis l\'écran de code ferme tout', (
    tester,
  ) async {
    final e = await lance(tester);
    await toucher(tester, find.byKey(const Key('reglage-code')));
    expect(find.byType(EcranCode), findsOneWidget);
    e.etat.verrouiller();
    await tester.pumpAndSettle();
    expect(find.byType(EcranCode), findsNothing);
    expect(find.byKey(const Key('ecran-reglages')), findsNothing);
  });

  testWidgets('REQ014 passage en arrière-plan depuis l\'écran de code', (
    tester,
  ) async {
    await lance(tester);
    await toucher(tester, find.byKey(const Key('reglage-code')));
    final b = tester.binding;
    b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    b.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    b.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(EcranCode), findsNothing);
    expect(find.byKey(const Key('ecran-reglages')), findsNothing);
    expect(find.byKey(const Key('bouton-plus')), findsNothing);
  });

  testWidgets(
    'REQ022_AC2 voix disparue : prononciation avec la voix par défaut',
    (tester) async {
      final e = await lance(
        tester,
        voix: const [vEn],
        reglages: const Reglages(voixId: 'disparue'),
      );
      final pomme = e.etat.session.donnees.grillePar('acc')!.cases.single;
      await e.etat.session.appuyerCase(pomme);
      expect(e.voix.textesPrononces, ['pomme']);
      expect(e.voix.parametresAppels.last.voixId, isNull);
      await toucher(tester, find.byKey(const Key('bouton-tester')));
      expect(e.voix.parametresAppels.last.voixId, isNull);
      expect(e.reglages.voixId, 'disparue');
    },
  );

  testWidgets('REQ022_AC2 voix disparue : voix française par défaut utilisée', (
    tester,
  ) async {
    final e = await lance(tester, reglages: const Reglages(voixId: 'disparue'));
    final pomme = e.etat.session.donnees.grillePar('acc')!.cases.single;
    await e.etat.session.appuyerCase(pomme);
    expect(e.voix.parametresAppels.last.voixId, 'fr2');
  });

  group('REQ028 accessibilité des réglages', () {
    for (final taille in const [
      Size(640, 360),
      Size(915, 412),
      Size(1280, 800),
    ]) {
      testWidgets('guidelines $taille', (tester) async {
        final h = tester.ensureSemantics();
        await lance(tester, taille: taille);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -3000),
        );
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        h.dispose();
      });
    }

    testWidgets('guidelines avec avertissements', (tester) async {
      final h = tester.ensureSemantics();
      await lance(
        tester,
        voix: const [],
        reglages: const Reglages(voixId: 'x'),
        taille: const Size(640, 360),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      h.dispose();
    });
  });

  group('écritures concurrentes', () {
    Future<(Env, StockageLent)> lent(WidgetTester tester) async {
      tester.view.physicalSize = const Size(915, 412);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final stockage = StockageLent(donnees());
      final faux = FauxVoix(voix: const [vFr, vFr2, vEn]);
      final etat = creer(stockage, faux);
      await etat.init();
      etat.ouvrirEdition();
      await tester.pumpWidget(GlypheApp(etat: etat));
      await tester.pumpAndSettle();
      await ouvrirReglages(tester);
      return (Env(etat, stockage, faux), stockage);
    }

    testWidgets('REQ021_AC2 deux touchers avant la fin de l\'écriture', (
      tester,
    ) async {
      final (e, s) = await lent(tester);
      await tester.tap(find.byKey(const Key('voix-fr1')));
      await tester.ensureVisible(find.byKey(const Key('delai-2000')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delai-2000')));
      await tester.pump();
      expect(s.attentes.length, 2);
      for (final c in s.attentes) {
        c.complete();
      }
      await tester.pumpAndSettle();
      expect(e.reglages.voixId, 'fr1');
      expect(e.reglages.delaiAntiRepetitionMs, 2000);
      expect(s.donnees!.reglages.voixId, 'fr1');
      expect(s.donnees!.reglages.delaiAntiRepetitionMs, 2000);
    });

    testWidgets('REQ021 échec d\'écriture : voix effective cohérente', (
      tester,
    ) async {
      final (e, s) = await lent(tester);
      await tester.tap(find.byKey(const Key('voix-fr1')));
      await tester.pump();
      s.attentes.single.completeError(const FileSystemException('plein'));
      await tester.pumpAndSettle();
      expect(e.reglages.voixId, 'fr1');
      expect(e.etat.session.choixVoix?.voixId, 'fr1');
      expect(find.text(Textes.erreurEnregistrement), findsOneWidget);
    });

    testWidgets('REQ021 le curseur suit le doigt, écriture au relâchement', (
      tester,
    ) async {
      final (e, s) = await lent(tester);
      final f = find.byKey(const Key('curseur-debit'));
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      final avant = tester.widget<Slider>(f).value;
      final g = await tester.startGesture(tester.getCenter(f));
      await g.moveBy(const Offset(-300, 0));
      await tester.pump();
      expect(tester.widget<Slider>(f).value, lessThan(avant));
      expect(s.attentes, isEmpty);
      await g.up();
      await tester.pump();
      expect(s.attentes.length, 1);
      s.attentes.single.complete();
      await tester.pumpAndSettle();
      expect(e.reglages.debit, lessThan(avant));
    });
  });
}
