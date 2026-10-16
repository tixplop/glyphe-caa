import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/modeles.dart';
import 'package:glyphe/ui/app.dart';
import 'package:glyphe/ui/etat_appli.dart';
import 'package:glyphe/ui/tokens.dart';
import 'package:glyphe/ui/widgets/barre_edition.dart';

import '../faux/faux_stockage.dart';
import '../faux/faux_voix.dart';
import '../faux/fausse_horloge.dart';

const nomLong = 'Une grille au nom vraiment très très long ici';

Case mot(String id, String lib, int l, int c) => Case(
  id: id,
  ligne: l,
  colonne: c,
  type: TypeCase.mot,
  libelle: lib,
  image: ImageArasaac(2617),
  categorie: Categorie.petitMot,
);

Donnees donnees() => Donnees(
  accueilId: 'acc',
  grilles: [
    Grille(
      id: 'acc',
      nom: 'Accueil',
      lignes: 3,
      colonnes: 3,
      cases: [
        mot('je', 'je', 0, 0),
        Case(
          id: 'd-manger',
          ligne: 0,
          colonne: 1,
          type: TypeCase.dossier,
          libelle: 'manger',
          cibleId: 'manger',
        ),
        Case(
          id: 'd-long',
          ligne: 0,
          colonne: 2,
          type: TypeCase.dossier,
          libelle: 'long',
          cibleId: 'long',
        ),
      ],
    ),
    Grille(
      id: 'manger',
      nom: 'Manger',
      lignes: 2,
      colonnes: 2,
      cases: [mot('pomme', 'pomme', 0, 0)],
    ),
    Grille(id: 'long', nom: nomLong, lignes: 2, colonnes: 2, cases: []),
  ],
);

Future<EtatAppli> lance(WidgetTester tester, {Size? taille}) async {
  tester.view.physicalSize = taille ?? const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final etat = EtatAppli(
    stockage: FauxStockage(donnees()),
    voix: FauxVoix(),
    horloge: FausseHorloge(),
    jsonExemples: '{}',
  );
  await etat.init();
  await tester.pumpWidget(GlypheApp(etat: etat));
  await tester.pumpAndSettle();
  return etat;
}

Future<void> edition(WidgetTester tester, EtatAppli etat, [String? id]) async {
  if (id != null) etat.session.ouvrirGrille(id);
  etat.ouvrirEdition();
  await tester.pumpAndSettle();
}

Finder icone(Finder dans, IconData i) =>
    find.descendant(of: dans, matching: find.byIcon(i));

/// Clé repérée (première correspondance parmi les ancêtres) du focus courant.
String? cleDuFocus(Set<String> connues) {
  final f = FocusManager.instance.primaryFocus;
  if (f?.context == null) return null;
  String? trouve;
  f!.context!.visitAncestorElements((e) {
    final k = e.widget.key;
    if (k is ValueKey<String> && connues.contains(k.value)) {
      trouve = k.value;
      return false;
    }
    return true;
  });
  return trouve;
}

/// Tab successifs jusqu'à `fin` (inclus) ; renvoie la suite des clés,
/// sans filtre ni dédoublonnage hors répétitions consécutives.
Future<List<String?>> parcours(
  WidgetTester tester,
  Set<String> connues,
  bool Function(String?) fin,
) async {
  final ordre = <String?>[];
  for (var i = 0; i < 60; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final c = cleDuFocus(connues);
    if (ordre.isEmpty || ordre.last != c) ordre.add(c);
    if (fin(c)) break;
  }
  return ordre;
}

void main() {
  final t = GlypheTokens.clair;

  testWidgets('REQ030_AC11 rectangles de la barre d\'édition (360×640)', (
    tester,
  ) async {
    final etat = await lance(tester);
    final accueilCom = tester.getRect(find.byKey(const Key('bouton-accueil')));
    final cadenas = tester.getRect(find.byKey(const Key('cadenas')));
    await edition(tester, etat);
    final barre = tester.getRect(find.byType(BarreEdition));
    final accueil = tester.getRect(find.byKey(const Key('bouton-accueil')));
    final ajouter = tester.getRect(find.byKey(const Key('ajouter-case')));
    final plus = tester.getRect(find.byKey(const Key('bouton-plus')));
    final fin = tester.getRect(find.byKey(const Key('bouton-terminer')));
    for (final r in [accueil, ajouter, plus, fin]) {
      expect(r.size, const Size(48, 48));
      expect(r.center.dy, barre.center.dy);
    }
    expect(accueil, accueilCom);
    expect(accueil.left - barre.left, 4);
    expect(fin.left, closeTo(cadenas.left, 0.5));
    expect(fin.top, closeTo(cadenas.top, 0.5));
    expect(fin.size, cadenas.size);
    expect(barre.right - fin.right, 4);
    expect(plus.right + 12, fin.left);
    expect(ajouter.right + 4, plus.left);
    final titre = tester.getRect(find.byKey(const Key('titre-edition')));
    expect(titre.left - accueil.right, 8);
    expect(titre.right + 8, ajouter.left);
    expect(titre.width, 104);
  });

  testWidgets('REQ009_AC7 Accueil : même rectangle en 640×360', (tester) async {
    final etat = await lance(tester, taille: const Size(640, 360));
    final accueilCom = tester.getRect(find.byKey(const Key('bouton-accueil')));
    final cadenas = tester.getRect(find.byKey(const Key('cadenas')));
    await edition(tester, etat);
    expect(tester.getRect(find.byKey(const Key('bouton-accueil'))), accueilCom);
    final fin = tester.getRect(find.byKey(const Key('bouton-terminer')));
    expect((fin.left - cadenas.left).abs(), lessThan(0.5));
    expect((fin.top - cadenas.top).abs(), lessThan(0.5));
  });

  testWidgets('REQ009_AC6 Accueil en édition : revient à l\'accueil', (
    tester,
  ) async {
    final etat = await lance(tester);
    await edition(tester, etat, 'manger');
    await tester.tap(find.byKey(const Key('bouton-accueil')));
    await tester.pumpAndSettle();
    expect(etat.session.grilleCourante.id, 'acc');
    expect(etat.modeEdition, isTrue);
  });

  testWidgets('REQ030_AC7 pas de texte de bouton, icônes et couleurs', (
    tester,
  ) async {
    final etat = await lance(tester);
    await edition(tester, etat);
    expect(find.text('Terminer'), findsNothing);
    expect(find.text('Ajouter une case'), findsNothing);
    expect(find.byType(FittedBox), findsNothing);
    final fin = find.byKey(const Key('bouton-terminer'));
    final ic = tester.widget<Icon>(icone(fin, Icons.lock_outline));
    expect(ic.size, 28);
    expect(ic.color, t.onPrimary);
    final mat = tester.widget<Material>(
      find.descendant(of: fin, matching: find.byType(Material)).first,
    );
    expect(mat.color, t.primary);
    final aj = find.byKey(const Key('ajouter-case'));
    final ica = tester.widget<Icon>(icone(aj, Icons.add));
    expect((ica.size, ica.color), (28, t.ink));
    final matA = tester.widget<Material>(
      find.descendant(of: aj, matching: find.byType(Material)).first,
    );
    expect(matA.color, t.surface000);
    final forme = matA.shape! as RoundedRectangleBorder;
    expect(forme.side.color, t.border);
    expect(forme.side.width, 2);
    expect(forme.borderRadius, BorderRadius.circular(GlypheTokens.rayonMd));
    final plus = tester.widget<Icon>(
      icone(find.byKey(const Key('bouton-plus')), Icons.more_vert),
    );
    expect((plus.size, plus.color), (24, t.ink));
  });

  testWidgets('REQ036_AC2 info-bulles = libellés', (tester) async {
    final etat = await lance(tester);
    await edition(tester, etat);
    for (final (cle, libelle) in [
      ('bouton-accueil', 'Accueil'),
      ('bouton-terminer', 'Terminer'),
      ('ajouter-case', 'Ajouter une case'),
      ('bouton-plus', 'Plus'),
    ]) {
      final tip = find.ancestor(
        of: find.byKey(Key(cle)),
        matching: find.byType(Tooltip),
      );
      final direct = find.descendant(
        of: find.byKey(Key(cle)),
        matching: find.byType(Tooltip),
      );
      final f = tip.evaluate().isNotEmpty ? tip : direct;
      expect(f, findsWidgets, reason: cle);
      expect(tester.widget<Tooltip>(f.first).message, libelle, reason: cle);
    }
  });

  testWidgets('REQ036_AC1 libellés d\'accessibilité', (tester) async {
    final h = tester.ensureSemantics();
    final etat = await lance(tester);
    await edition(tester, etat);
    for (final l in ['Accueil', 'Terminer', 'Ajouter une case', 'Plus']) {
      expect(find.bySemanticsLabel(l), findsWidgets, reason: l);
    }
    h.dispose();
  });

  testWidgets('REQ011_AC3 focus perdu pendant l\'appui clavier : annulé', (
    tester,
  ) async {
    for (final perte in ['tab', 'unfocus']) {
      final etat = await lance(tester);
      etat.session.ouvrirGrille('manger');
      await tester.pumpAndSettle();
      await parcours(tester, {'cadenas'}, (c) => c == 'cadenas');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      if (perte == 'tab') {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      } else {
        FocusManager.instance.primaryFocus!.unfocus();
      }
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(etat.verrouille, isTrue, reason: perte);
    }
  });

  testWidgets('REQ030_AC8 titre « Manger » et sémantique', (tester) async {
    final h = tester.ensureSemantics();
    final etat = await lance(tester);
    await edition(tester, etat, 'manger');
    final titre = find.byKey(const Key('titre-edition'));
    final mode = tester.widget<Text>(
      find.descendant(of: titre, matching: find.text('Mode édition')),
    );
    expect(mode.style!.color, t.inkMuted);
    expect(mode.style!.fontSize, GlypheTokens.caption.fontSize);
    final nom = tester.widget<Text>(
      find.descendant(of: titre, matching: find.text('Manger')),
    );
    expect(nom.style!.color, t.ink);
    expect(nom.style!.fontWeight, FontWeight.w700);
    expect(nom.maxLines, 1);
    expect(nom.overflow, TextOverflow.ellipsis);
    expect(
      tester.getSemantics(find.byKey(const Key('titre-edition'))),
      isSemantics(
        label: 'Mode édition, grille Manger',
        isHeader: true,
        hasTapAction: false,
        isButton: false,
      ),
    );
    // Pas d'en-tête sémantique en-dehors de ce titre : la grille courante
    // est lue en entier.
    expect(
      find.bySemanticsLabel('Mode édition, grille Manger'),
      findsOneWidget,
    );
    h.dispose();
  });

  testWidgets('REQ030_AC8 nom de 40 caractères, 360×640 sans débordement', (
    tester,
  ) async {
    final h = tester.ensureSemantics();
    final etat = await lance(tester);
    await edition(tester, etat, 'long');
    expect(tester.takeException(), isNull);
    expect(nomLong.length, greaterThanOrEqualTo(40));
    expect(find.text(nomLong), findsOneWidget);
    final r = tester.getRect(find.byKey(const Key('titre-edition')));
    final ajouter = tester.getRect(find.byKey(const Key('ajouter-case')));
    expect(r.right, lessThanOrEqualTo(ajouter.left));
    expect(
      tester.getSemantics(find.byKey(const Key('titre-edition'))).label,
      'Mode édition, grille $nomLong',
    );
    h.dispose();
  });

  testWidgets('REQ030_AC8 texte non agrandi par l\'échelle système', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final etat = await lance(tester);
    await edition(tester, etat, 'manger');
    expect(tester.takeException(), isNull);
    final nom = find.descendant(
      of: find.byKey(const Key('titre-edition')),
      matching: find.text('Manger'),
    );
    expect(tester.getSize(nom).height, lessThan(30));
  });

  testWidgets('REQ030_AC8 le titre garde boldText et highContrast', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(boldText: true, highContrast: true);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final etat = await lance(tester);
    await edition(tester, etat, 'manger');
    final contexte = tester.element(
      find.descendant(
        of: find.byKey(const Key('titre-edition')),
        matching: find.text('Manger'),
      ),
    );
    final mq = MediaQuery.of(contexte);
    expect(mq.textScaler, TextScaler.noScaling);
    expect(mq.boldText, isTrue);
    expect(mq.highContrast, isTrue);
  });

  testWidgets('REQ030_AC9 menu Plus : ordre, icônes, hauteur', (tester) async {
    final etat = await lance(tester);
    await edition(tester, etat);
    await tester.tap(find.byKey(const Key('bouton-plus')));
    await tester.pumpAndSettle();
    final attendu = [
      ('bouton-taille', 'Taille de la grille', Icons.aspect_ratio_outlined),
      ('bouton-grilles', 'Grilles', Icons.grid_view_outlined),
      ('bouton-reglages', 'Réglages', Icons.settings_outlined),
      ('bouton-code', 'Code de verrouillage', Icons.pin_outlined),
      ('bouton-a-propos', 'À propos', Icons.info_outline),
    ];
    var haut = -1.0;
    for (final (cle, nom, ic) in attendu) {
      final item = find.byKey(Key(cle));
      expect(item, findsOneWidget, reason: cle);
      final r = tester.getRect(item);
      expect(r.top, greaterThan(haut), reason: cle);
      haut = r.top;
      expect(r.height, greaterThanOrEqualTo(48), reason: cle);
      final i = tester.widget<Icon>(icone(item, ic));
      expect((i.size, i.color), (24, t.ink), reason: cle);
      final texte = tester.widget<Text>(
        find.descendant(of: item, matching: find.text(nom)),
      );
      expect(texte.style!.fontSize, GlypheTokens.body.fontSize, reason: cle);
      expect(
        tester
                .getRect(find.descendant(of: item, matching: find.text(nom)))
                .left -
            tester.getRect(icone(item, ic)).right,
        greaterThanOrEqualTo(16),
        reason: cle,
      );
    }
  });

  testWidgets('REQ014_AC1 Terminer par l\'icône reverrouille', (tester) async {
    final etat = await lance(tester);
    await edition(tester, etat);
    await tester.tap(find.byKey(const Key('bouton-terminer')));
    await tester.pumpAndSettle();
    expect(find.byType(BarreEdition), findsNothing);
    expect(etat.verrouille, isTrue);
  });

  testWidgets('REQ015_AC1 Ajouter une case par l\'icône', (tester) async {
    final etat = await lance(tester);
    await edition(tester, etat);
    await tester.tap(find.byKey(const Key('ajouter-case')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ajouter-case')), findsNothing);
  });

  testWidgets('REQ030_AC8 pas d\'ondulation, voile ink 12 %', (tester) async {
    final etat = await lance(tester);
    await edition(tester, etat);
    final ink = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const Key('bouton-terminer')),
        matching: find.byType(InkWell),
      ),
    );
    expect(ink.splashFactory, NoSplash.splashFactory);
    expect(ink.highlightColor, t.ink.withValues(alpha: 0.12));
  });

  for (final taille in const [Size(360, 640), Size(640, 360)]) {
    testWidgets('REQ030_AC10 ordre de focus en édition $taille', (
      tester,
    ) async {
      final etat = await lance(tester, taille: taille);
      await edition(tester, etat, 'manger');
      final ordre = await parcours(tester, {
        'bouton-accueil',
        'ajouter-case',
        'bouton-plus',
        'bouton-terminer',
        'case-pomme',
        'vide-0-1',
        'vide-1-0',
        'vide-1-1',
      }, (c) => c == 'vide-1-1');
      expect(ordre, [
        'bouton-accueil',
        'ajouter-case',
        'bouton-plus',
        'bouton-terminer',
        'case-pomme',
        'vide-0-1',
        'vide-1-0',
        'vide-1-1',
      ]);
    });

    testWidgets('REQ030_AC10 ordre sémantique en édition $taille', (
      tester,
    ) async {
      final h = tester.ensureSemantics();
      final etat = await lance(tester, taille: taille);
      await edition(tester, etat, 'manger');
      final labels = [
        'Accueil',
        'Mode édition, grille Manger',
        'Ajouter une case',
        'Plus',
        'Terminer',
        'pomme',
        'Ajouter une case',
        'Ajouter une case',
        'Ajouter une case',
      ];
      // L'ordre de parcours est celui de la liste d'enfants du parent.
      final ordre = <String>[];
      void visite(SemanticsNode n) {
        final l = n.label.split('\n').first;
        if (labels.contains(l)) ordre.add(l);
        n.visitChildren((c) {
          visite(c);
          return true;
        });
      }

      visite(
        tester
            .binding
            .renderViews
            .first
            .owner!
            .semanticsOwner!
            .rootSemanticsNode!,
      );
      expect(ordre, labels);
      h.dispose();
    });
  }

  for (final taille in const [Size(360, 640), Size(640, 360)]) {
    testWidgets('REQ030_AC10 ordre de focus en communication $taille', (
      tester,
    ) async {
      final h = tester.ensureSemantics();
      final etat = await lance(tester, taille: taille);
      etat.session.ouvrirGrille('manger');
      await tester.pumpAndSettle();
      expect(etat.verrouille, isTrue);
      // Corbeille et Effacer ne sont actifs (donc focalisables) qu'avec un mot.
      await tester.tap(find.byKey(const Key('case-pomme')));
      await tester.pumpAndSettle();
      final voulu = [
        'bouton-accueil',
        'zone-barre',
        'bouton-corbeille',
        'bouton-effacer',
        'cadenas',
        'case-pomme',
      ];
      final ordre = await parcours(
        tester,
        voulu.toSet(),
        (c) => c == 'case-pomme',
      );
      expect(ordre, voulu);

      // Même ordre pour le lecteur d'écran.
      const labels = [
        'Accueil',
        'Phrase : pomme',
        'Tout effacer',
        'Effacer le dernier mot',
        'Verrouillé',
        'pomme',
      ];
      final noeuds = <String>[];
      void visite(SemanticsNode n) {
        final l = n.label.split('\n').first;
        if (labels.contains(l)) noeuds.add(l);
        n.visitChildren((c) {
          visite(c);
          return true;
        });
      }

      visite(
        tester
            .binding
            .renderViews
            .first
            .owner!
            .semanticsOwner!
            .rootSemanticsNode!,
      );
      expect(noeuds, labels);
      h.dispose();
    });
  }

  testWidgets(
    'REQ030_AC10 cadenas : Entrée maintenue déverrouille, relâcher annule',
    (tester) async {
      final etat = await lance(tester);
      etat.session.ouvrirGrille('manger');
      await tester.pumpAndSettle();
      await parcours(tester, {'cadenas'}, (c) => c == 'cadenas');
      expect(
        find.descendant(
          of: find.byKey(const Key('cadenas')),
          matching: find.byKey(const Key('anneau-focus')),
        ),
        findsOneWidget,
      );
      final anneau = tester.widget<DecoratedBox>(
        find.byKey(const Key('anneau-focus')),
      );
      expect(
        (anneau.decoration as BoxDecoration).border,
        Border.all(color: t.focus, width: GlypheTokens.anneauFocus),
      );
      final r = tester.getRect(find.byKey(const Key('anneau-focus')));
      final c = tester.getRect(find.byKey(const Key('cadenas')));
      expect(r.inflate(-2), c);
      // Relâcher avant 3 s : reste verrouillé.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 2900));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(seconds: 1));
      expect(etat.verrouille, isTrue);
      // Maintenu 3 s : déverrouille.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.pump(const Duration(milliseconds: 3100));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(etat.verrouille, isFalse);
    },
  );

  testWidgets('REQ030_AC10 Effacer au clavier : Entrée retire le dernier mot', (
    tester,
  ) async {
    final etat = await lance(tester);
    etat.session.ouvrirGrille('manger');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('case-pomme')));
    await tester.tap(find.byKey(const Key('case-pomme')));
    await tester.pumpAndSettle();
    expect(etat.session.barre.length, 2);
    await parcours(tester, {'bouton-effacer'}, (c) => c == 'bouton-effacer');
    expect(find.byKey(const Key('anneau-focus')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(etat.session.barre.length, 1);
  });
}
