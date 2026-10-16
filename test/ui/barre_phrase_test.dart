import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/modeles.dart';
import 'package:glyphe/domaine/session.dart';
import 'package:glyphe/ui/theme.dart';
import 'package:glyphe/ui/tokens.dart';
import 'package:glyphe/ui/widgets/barre_phrase.dart';

ElementBarre _el(
  String lib, {
  Categorie cat = Categorie.petitMot,
  ImageCase image = const ImageAucune(),
}) => ElementBarre(
  image: image,
  libelle: lib,
  textePrononce: lib,
  categorie: cat,
);

class _Compteurs {
  int lire = 0, arreter = 0, dernier = 0, tout = 0, accueil = 0, verrou = 0;
}

Future<_Compteurs> _pose(
  WidgetTester tester,
  List<ElementBarre> elements, {
  bool enLecture = false,
  Brightness lum = Brightness.light,
  Size taille = const Size(640, 360),
}) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final n = _Compteurs();
  await tester.pumpWidget(
    MaterialApp(
      theme: themeGlyphe(lum),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Align(
            alignment: Alignment.topCenter,
            child: BarrePhrase(
              elements: elements,
              enLecture: enLecture,
              onLire: () => n.lire++,
              onArreter: () => n.arreter++,
              onEffacerDernier: () => n.dernier++,
              onToutEffacer: () => n.tout++,
              onAccueil: () => n.accueil++,
              onDeverrouille: () => n.verrou++,
            ),
          ),
        ),
      ),
    ),
  );
  return n;
}

Material _materiel(WidgetTester tester, String cle) => tester.widget<Material>(
  find
      .descendant(of: find.byKey(Key(cle)), matching: find.byType(Material))
      .first,
);

double _opacite(WidgetTester tester, String cle) => tester
    .widget<Opacity>(
      find
          .descendant(of: find.byKey(Key(cle)), matching: find.byType(Opacity))
          .first,
    )
    .opacity;

const _boutons = ['bouton-accueil', 'bouton-corbeille', 'bouton-effacer'];

void main() {
  testWidgets('REQ034_AC1 barre de 72 de haut, surface-200', (tester) async {
    await _pose(tester, [_el('je')]);
    expect(tester.getSize(find.byType(BarrePhrase)).height, 72);
    final t = GlypheTokens.clair;
    final deco = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(BarrePhrase),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((d) => d.decoration)
        .whereType<BoxDecoration>();
    expect(deco.any((d) => d.color == t.surface200), isTrue);
  });

  testWidgets('REQ034_AC1 contour de la puce = contour de la catégorie', (
    tester,
  ) async {
    await _pose(tester, [_el('manger', cat: Categorie.action)]);
    final t = GlypheTokens.clair;
    final puce = find.byKey(const Key('element-barre-0'));
    final deco = tester
        .widgetList<DecoratedBox>(
          find.descendant(of: puce, matching: find.byType(DecoratedBox)),
        )
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.border != null);
    final b = deco.border! as Border;
    expect(b.top.color, t.catActionEdge);
    expect(b.top.width, 2);
    expect(deco.color, t.surface000);
    final texte = tester.widget<Text>(
      find.descendant(of: puce, matching: find.text('manger')),
    );
    expect(texte.style!.fontSize, 24);
    expect(texte.style!.fontWeight, FontWeight.w700);
    expect(texte.style!.color, t.ink);
  });

  testWidgets('REQ034_AC1 élément sans libellé : image seule', (tester) async {
    await _pose(tester, [_el('', image: ImageArasaac(2617))]);
    final puce = find.byKey(const Key('element-barre-0'));
    expect(
      find.descendant(of: puce, matching: find.byType(Text)),
      findsNothing,
    );
    expect(
      find.descendant(of: puce, matching: find.byType(Image)),
      findsOneWidget,
    );
  });

  testWidgets('REQ034_AC2 AC9 géométrie 4|48|4|zone|4|48|12|48|4|48|4', (
    tester,
  ) async {
    await _pose(tester, [_el('je')], taille: const Size(360, 640));
    final barre = tester.getRect(find.byType(BarrePhrase));
    final acc = tester.getRect(find.byKey(const Key('bouton-accueil')));
    final zone = tester.getRect(find.byKey(const Key('zone-barre')));
    final cor = tester.getRect(find.byKey(const Key('bouton-corbeille')));
    final eff = tester.getRect(find.byKey(const Key('bouton-effacer')));
    final cad = tester.getRect(find.byKey(const Key('cadenas')));
    expect(barre.width, 336);
    for (final r in [acc, cor, eff, cad]) {
      expect(r.size, const Size(48, 48));
      expect(r.center.dy, barre.center.dy);
    }
    expect(acc.left - barre.left, 4);
    expect(zone.left - acc.right, 4);
    expect(cor.left - zone.right, 4);
    expect(eff.left - cor.right, 12);
    expect(cad.left - eff.right, 4);
    expect(barre.right - cad.right, 4);
    expect(zone.size, const Size(112, 56));
    expect(zone.center.dy, barre.center.dy);
  });

  testWidgets('REQ034_AC6 zone de 164 en 412x915, 392 en 640x360', (
    tester,
  ) async {
    await _pose(tester, [_el('je')], taille: const Size(412, 915));
    expect(tester.getSize(find.byKey(const Key('zone-barre'))).width, 164);
    await _pose(tester, [_el('je')], taille: const Size(640, 360));
    expect(tester.getSize(find.byKey(const Key('zone-barre'))).width, 392);
  });

  testWidgets('REQ036_AC11 rendu des boutons à contour et du cadenas', (
    tester,
  ) async {
    await _pose(tester, [_el('je')]);
    final t = GlypheTokens.clair;
    for (final k in _boutons) {
      final m = _materiel(tester, k);
      expect(m.color, t.surface000, reason: k);
      final forme = m.shape! as RoundedRectangleBorder;
      expect(forme.side.color, t.border, reason: k);
      expect(forme.side.width, 2, reason: k);
      expect(forme.borderRadius, BorderRadius.circular(GlypheTokens.rayonMd));
      expect(
        find.descendant(of: find.byKey(Key(k)), matching: find.byType(Text)),
        findsNothing,
      );
    }
    Icon icone(IconData d) => tester.widget<Icon>(find.byIcon(d));
    expect(icone(Icons.home_outlined).size, 28);
    expect(icone(Icons.home_outlined).color, t.ink);
    expect(icone(Icons.delete_outline).size, 28);
    expect(icone(Icons.delete_outline).color, t.danger);
    expect(icone(Icons.backspace_outlined).size, 28);
    expect(icone(Icons.backspace_outlined).color, t.ink);
    expect(icone(Icons.lock_outline).size, 24);
    expect(icone(Icons.lock_outline).color, t.ink);
    expect(find.byIcon(Icons.volume_up_outlined), findsNothing);
    expect(find.byKey(const Key('bouton-parler')), findsNothing);
  });

  testWidgets('REQ036_AC2 aucune info-bulle dans la barre de phrase', (
    tester,
  ) async {
    await _pose(tester, [_el('je')]);
    expect(find.byType(Tooltip), findsNothing);
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('bouton-accueil'))),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(Tooltip), findsNothing);
    await g.up();
  });

  testWidgets('REQ034_AC3 barre vide : aide, Corbeille et Effacer à 40 %', (
    tester,
  ) async {
    final h = tester.ensureSemantics();
    final n = await _pose(tester, []);
    final aide = tester.widget<Text>(find.text('Ta phrase apparaît ici'));
    expect(aide.style!.color, GlypheTokens.clair.inkMuted);
    for (final k in ['bouton-corbeille', 'bouton-effacer']) {
      expect(_opacite(tester, k), 0.4, reason: k);
      await tester.tap(find.byKey(Key(k)));
      await tester.longPress(find.byKey(Key(k)));
      await tester.pumpAndSettle();
      final d = tester.getSemantics(find.byKey(Key(k))).getSemanticsData();
      expect(d.flagsCollection.isEnabled, ui.Tristate.isFalse, reason: k);
    }
    expect((n.dernier, n.tout), (0, 0));
    for (final k in ['bouton-accueil']) {
      expect(_opacite(tester, k), 1);
    }
    await tester.tap(find.byKey(const Key('bouton-accueil')));
    expect(n.accueil, 1);
    h.dispose();
  });

  testWidgets('REQ034_AC3 barre non vide : pas d\'aide, boutons à 100 %', (
    tester,
  ) async {
    await _pose(tester, [_el('je')]);
    expect(find.text('Ta phrase apparaît ici'), findsNothing);
    for (final k in _boutons) {
      expect(_opacite(tester, k), 1, reason: k);
    }
  });

  testWidgets('REQ034_AC4 appui sur la zone : lit, puis arrête en lecture', (
    tester,
  ) async {
    final n = await _pose(tester, [_el('je')]);
    await tester.tap(find.byKey(const Key('zone-barre')));
    expect((n.lire, n.arreter), (1, 0));
    final n2 = await _pose(tester, [_el('je')], enLecture: true);
    await tester.tap(find.byKey(const Key('zone-barre')));
    expect((n2.lire, n2.arreter), (0, 1));
  });

  testWidgets('REQ034_AC10 cadre de lecture réservé, puces immobiles', (
    tester,
  ) async {
    await _pose(tester, [_el('je'), _el('veux')]);
    final t = GlypheTokens.clair;
    BoxDecoration cadre() =>
        tester
                .widget<DecoratedBox>(find.byKey(const Key('cadre-lecture')))
                .decoration
            as BoxDecoration;
    expect(cadre().border!.top.color, Colors.transparent);
    expect(cadre().border!.top.width, 3);
    expect(cadre().borderRadius, BorderRadius.circular(GlypheTokens.rayonMd));
    final avant = [
      for (var i = 0; i < 2; i++)
        tester.getRect(find.byKey(Key('element-barre-$i'))),
    ];
    final zoneAvant = tester.getRect(find.byKey(const Key('zone-barre')));
    await _pose(tester, [_el('je'), _el('veux')], enLecture: true);
    expect(cadre().border!.top.color, t.primary);
    expect(cadre().border!.top.width, 3);
    for (var i = 0; i < 2; i++) {
      final r = tester.getRect(find.byKey(Key('element-barre-$i')));
      expect((r.left - avant[i].left).abs(), lessThan(0.5));
      expect((r.top - avant[i].top).abs(), lessThan(0.5));
    }
    expect(tester.getRect(find.byKey(const Key('zone-barre'))), zoneAvant);
  });

  testWidgets('REQ034_AC8 AC11 sémantique de la zone de mots', (tester) async {
    final h = tester.ensureSemantics();
    await _pose(tester, [_el('je'), _el('veux'), _el('manger')]);
    var d = tester
        .getSemantics(find.byKey(const Key('zone-barre')))
        .getSemanticsData();
    expect(d.label, 'Phrase : je veux manger');
    expect(d.hint, 'Appuyer pour lire');
    await _pose(tester, [
      _el('je'),
      _el('veux'),
      _el('manger'),
    ], enLecture: true);
    d = tester
        .getSemantics(find.byKey(const Key('zone-barre')))
        .getSemanticsData();
    expect(d.hint, 'Appuyer pour arrêter');
    await _pose(tester, []);
    d = tester
        .getSemantics(find.byKey(const Key('zone-barre')))
        .getSemanticsData();
    expect(d.label, 'Ta phrase apparaît ici');
    h.dispose();
  });

  testWidgets('REQ034_AC11 aide en 360 : 2 lignes au plus, sans débordement', (
    tester,
  ) async {
    await _pose(tester, [], taille: const Size(360, 640));
    final texte = tester.widget<Text>(find.text('Ta phrase apparaît ici'));
    expect(texte.maxLines, 2);
    expect(texte.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
    final zone = tester.getRect(find.byKey(const Key('zone-barre')));
    final r = tester.getRect(find.text('Ta phrase apparaît ici'));
    expect(zone.contains(r.topLeft) && zone.contains(r.bottomRight), isTrue);
  });

  testWidgets('REQ034_AC11 la première puce commence à 9 de la zone', (
    tester,
  ) async {
    await _pose(tester, [
      _el('je'),
      _el('veux'),
      _el('manger'),
      _el('aussi'),
    ], taille: const Size(360, 640));
    final zone = tester.getRect(find.byKey(const Key('zone-barre')));
    final scroll = tester.getRect(find.byType(SingleChildScrollView));
    expect(scroll.left - zone.left, 9);
  });

  testWidgets('REQ034_AC1 puces centrées dans la zone', (tester) async {
    await _pose(tester, [_el('je')]);
    final zone = tester.getRect(find.byKey(const Key('zone-barre')));
    final puce = tester.getRect(find.byKey(const Key('element-barre-0')));
    expect((puce.center.dx - zone.center.dx).abs(), lessThan(0.5));
    expect((puce.center.dy - zone.center.dy).abs(), lessThan(0.5));
  });

  testWidgets('REQ034_AC7 cadenas : appui maintenu 3 s déverrouille', (
    tester,
  ) async {
    final n = await _pose(tester, [_el('je')]);
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('cadenas'))),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(n.verrou, 0);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(n.verrou, 1);
    await g.up();
  });

  testWidgets('REQ007_AC1 Effacer retire le dernier mot', (tester) async {
    final n = await _pose(tester, [_el('je')]);
    await tester.tap(find.byKey(const Key('bouton-effacer')));
    await tester.pump(const Duration(seconds: 1));
    expect((n.dernier, n.tout), (1, 0));
  });

  testWidgets('REQ007_AC2 Corbeille efface tout, sans dialogue', (
    tester,
  ) async {
    final n = await _pose(tester, [_el('je')]);
    await tester.tap(find.byKey(const Key('bouton-corbeille')));
    await tester.pumpAndSettle();
    expect((n.dernier, n.tout), (0, 1));
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('REQ007_AC4 appui maintenu 1 s sur Effacer : un seul mot', (
    tester,
  ) async {
    final n = await _pose(tester, [_el('je'), _el('veux')]);
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('bouton-effacer'))),
    );
    await tester.pump(const Duration(seconds: 1));
    await g.up();
    await tester.pump(const Duration(seconds: 1));
    expect((n.dernier, n.tout), (1, 0));
  });

  testWidgets('REQ007_AC8 glisser hors du bouton annule l\'action', (
    tester,
  ) async {
    final n = await _pose(tester, [_el('je')]);
    for (final k in ['bouton-effacer', 'bouton-corbeille', 'bouton-accueil']) {
      final g = await tester.startGesture(tester.getCenter(find.byKey(Key(k))));
      await g.moveBy(const Offset(0, 200));
      await g.up();
      await tester.pump();
    }
    expect((n.dernier, n.tout, n.accueil), (0, 0, 0));
  });

  testWidgets('REQ007_AC8 AC-030-10 Tab puis Entrée ou Espace', (tester) async {
    final n = await _pose(tester, [_el('je')]);
    Future<void> touche(LogicalKeyboardKey k) async {
      await tester.sendKeyEvent(k);
      await tester.pump();
    }

    await touche(LogicalKeyboardKey.tab);
    await touche(LogicalKeyboardKey.enter);
    expect(n.accueil, 1);
    expect(find.byKey(const Key('anneau-focus')), findsOneWidget);
    await touche(LogicalKeyboardKey.tab);
    await touche(LogicalKeyboardKey.enter);
    expect(n.lire, 1);
    await touche(LogicalKeyboardKey.tab);
    await touche(LogicalKeyboardKey.space);
    expect(n.tout, 1);
    await touche(LogicalKeyboardKey.tab);
    await touche(LogicalKeyboardKey.enter);
    expect(n.dernier, 1);
  });

  testWidgets('REQ007_AC5 libellés, sans action d\'appui long', (tester) async {
    final h = tester.ensureSemantics();
    await _pose(tester, [_el('je')]);
    const attendus = {
      'bouton-accueil': 'Accueil',
      'bouton-corbeille': 'Tout effacer',
      'bouton-effacer': 'Effacer le dernier mot',
    };
    attendus.forEach((k, libelle) {
      final d = tester.getSemantics(find.byKey(Key(k))).getSemanticsData();
      expect(d.label, libelle, reason: k);
      expect(d.hasAction(SemanticsAction.tap), isTrue, reason: k);
      expect(d.hasAction(SemanticsAction.longPress), isFalse, reason: k);
      expect(d.customSemanticsActionIds, isEmpty, reason: k);
    });
    h.dispose();
  });

  testWidgets('REQ036_AC11 Corbeille vide la barre (bout en bout)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final elements = <ElementBarre>[_el('je'), _el('veux')];
    await tester.pumpWidget(
      MaterialApp(
        theme: themeGlyphe(Brightness.light),
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: BarrePhrase(
                elements: List.of(elements),
                enLecture: false,
                onLire: () {},
                onArreter: () {},
                onEffacerDernier: () {},
                onToutEffacer: () => setState(elements.clear),
                onAccueil: () {},
                onDeverrouille: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('bouton-corbeille')));
    await tester.pump();
    expect(find.text('Ta phrase apparaît ici'), findsOneWidget);
    expect(_opacite(tester, 'bouton-corbeille'), 0.4);
    expect(_opacite(tester, 'bouton-effacer'), 0.4);
  });
}
