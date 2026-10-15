import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
  int lire = 0, arreter = 0, dernier = 0, tout = 0;
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
        body: Align(
          alignment: Alignment.topCenter,
          child: BarrePhrase(
            elements: elements,
            enLecture: enLecture,
            onLire: () => n.lire++,
            onArreter: () => n.arreter++,
            onEffacerDernier: () => n.dernier++,
            onToutEffacer: () => n.tout++,
          ),
        ),
      ),
    ),
  );
  return n;
}

Color? _fondBouton(WidgetTester tester, String cle) {
  final m = find.descendant(
    of: find.byKey(Key(cle)),
    matching: find.byType(Material),
  );
  return tester.widget<Material>(m.first).color;
}

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

  testWidgets('REQ034_AC2 boutons Effacer et Parler >= 56 de haut', (
    tester,
  ) async {
    await _pose(tester, [_el('je')]);
    for (final k in ['bouton-effacer', 'bouton-parler']) {
      final r = tester.getRect(find.byKey(Key(k)));
      expect(r.height, greaterThanOrEqualTo(56), reason: k);
      expect(r.width, greaterThanOrEqualTo(56), reason: k);
    }
    expect(
      tester.getRect(find.byKey(const Key('bouton-effacer'))).right,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const Key('bouton-parler'))).left,
      ),
    );
    expect(
      tester.getRect(find.byKey(const Key('zone-barre'))).right,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const Key('bouton-effacer'))).left,
      ),
    );
    final t = GlypheTokens.clair;
    expect(_fondBouton(tester, 'bouton-parler'), t.primary);
    expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
  });

  testWidgets('REQ034_AC7 géométrie 8/56/12/56/8, centrés, zone >= 180', (
    tester,
  ) async {
    await _pose(tester, [_el('je')], taille: const Size(360, 640));
    final barre = tester.getRect(find.byType(BarrePhrase));
    final zone = tester.getRect(find.byKey(const Key('zone-barre')));
    final eff = tester.getRect(find.byKey(const Key('bouton-effacer')));
    final par = tester.getRect(find.byKey(const Key('bouton-parler')));
    expect(eff.size, const Size(56, 56));
    expect(par.size, const Size(56, 56));
    expect(eff.left - zone.right, 8);
    expect(par.left - eff.right, 12);
    expect(barre.right - par.right, 8);
    expect(eff.center.dy, barre.center.dy);
    expect(par.center.dy, barre.center.dy);
    expect(zone.width, greaterThanOrEqualTo(180));
  });

  testWidgets('REQ034_AC9 ni texte ni info-bulle dans les boutons', (
    tester,
  ) async {
    await _pose(tester, [_el('je')]);
    for (final k in ['bouton-effacer', 'bouton-parler']) {
      expect(
        find.descendant(of: find.byKey(Key(k)), matching: find.byType(Text)),
        findsNothing,
      );
    }
    expect(find.byType(Tooltip), findsNothing);
  });

  testWidgets('REQ034_AC9 icône Parler -> Arrêter au même rectangle', (
    tester,
  ) async {
    await _pose(tester, [_el('je')]);
    final avant = tester.getRect(find.byKey(const Key('bouton-parler')));
    await _pose(tester, [_el('je')], enLecture: true);
    expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_outlined), findsNothing);
    expect(tester.getRect(find.byKey(const Key('bouton-parler'))), avant);
  });

  testWidgets('REQ034_AC10 Effacer désactivé barre vide, actif ensuite', (
    tester,
  ) async {
    final h = tester.ensureSemantics();
    final n = await _pose(tester, []);
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(
              of: find.byKey(const Key('bouton-effacer')),
              matching: find.byType(Opacity),
            ),
          )
          .opacity,
      0.4,
    );
    await tester.tap(find.byKey(const Key('bouton-effacer')));
    await tester.longPress(find.byKey(const Key('bouton-effacer')));
    await tester.pumpAndSettle();
    expect((n.dernier, n.tout), (0, 0));
    final d = tester
        .getSemantics(find.byKey(const Key('bouton-effacer')))
        .getSemanticsData();
    expect(d.flagsCollection.isEnabled, ui.Tristate.isFalse);
    await _pose(tester, [_el('je')]);
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(
              of: find.byKey(const Key('bouton-effacer')),
              matching: find.byType(Opacity),
            ),
          )
          .opacity,
      1,
    );
    h.dispose();
  });

  testWidgets('REQ034_AC2 AC9 libellé sémantique Parler puis Arrêter', (
    tester,
  ) async {
    final h = tester.ensureSemantics();
    await _pose(tester, [_el('je')]);
    expect(
      tester.getSemantics(find.byKey(const Key('bouton-parler'))).label,
      'Parler',
    );
    await _pose(tester, [_el('je')], enLecture: true);
    expect(
      tester.getSemantics(find.byKey(const Key('bouton-parler'))).label,
      'Arrêter',
    );
    h.dispose();
  });

  testWidgets('REQ034_AC11 libellé sémantique de la zone de mots', (
    tester,
  ) async {
    final h = tester.ensureSemantics();
    await _pose(tester, [_el('je'), _el('veux'), _el('manger')]);
    var d = tester
        .getSemantics(find.byKey(const Key('zone-barre')))
        .getSemanticsData();
    expect(d.label, 'Phrase : je veux manger');
    expect(d.hint, 'Appuyer pour lire');
    await _pose(tester, []);
    d = tester
        .getSemantics(find.byKey(const Key('zone-barre')))
        .getSemanticsData();
    expect(d.label, 'Ta phrase apparaît ici');
    h.dispose();
  });

  testWidgets('REQ034_AC3 barre vide : aide, Parler désactivé sans effet', (
    tester,
  ) async {
    final n = await _pose(tester, []);
    final aide = tester.widget<Text>(find.text('Ta phrase apparaît ici'));
    expect(aide.style!.color, GlypheTokens.clair.inkMuted);
    final op = tester.widget<Opacity>(find.byKey(const Key('bouton-parler')));
    expect(op.opacity, 0.4);
    await tester.tap(find.byKey(const Key('bouton-parler')));
    expect(n.lire, 0);
  });

  testWidgets('REQ034_AC3 barre non vide : pas d\'aide, Parler actif', (
    tester,
  ) async {
    final n = await _pose(tester, [_el('je')]);
    expect(find.text('Ta phrase apparaît ici'), findsNothing);
    await tester.tap(find.byKey(const Key('bouton-parler')));
    expect(n.lire, 1);
  });

  testWidgets('REQ034_AC4 en lecture : Arrêter et appel onArreter', (
    tester,
  ) async {
    final n = await _pose(tester, [_el('je')], enLecture: true);
    expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_outlined), findsNothing);
    await tester.tap(find.byKey(const Key('bouton-parler')));
    expect(n.arreter, 1);
    expect(n.lire, 0);
  });

  testWidgets('REQ034_AC4 Arrêter reste actif si la barre est vide', (
    tester,
  ) async {
    final n = await _pose(tester, [], enLecture: true);
    await tester.tap(find.byKey(const Key('bouton-parler')));
    expect(n.arreter, 1);
  });

  testWidgets('REQ034_AC5 appui sur la zone de mots lit la phrase', (
    tester,
  ) async {
    final n = await _pose(tester, [_el('je')]);
    await tester.tap(find.byKey(const Key('zone-barre')));
    expect(n.lire, 1);
  });

  testWidgets('REQ007_AC1 appui court : dernier mot seulement', (tester) async {
    final n = await _pose(tester, [_el('je')]);
    await tester.tap(find.byKey(const Key('bouton-effacer')));
    await tester.pump(const Duration(seconds: 1));
    expect((n.dernier, n.tout), (1, 0));
  });

  testWidgets('REQ007_AC2 appui long : tout effacer, pas d\'appui court', (
    tester,
  ) async {
    final n = await _pose(tester, [_el('je')]);
    await tester.longPress(find.byKey(const Key('bouton-effacer')));
    await tester.pumpAndSettle();
    expect((n.dernier, n.tout), (0, 1));
  });

  testWidgets('REQ007_AC4 rouge danger tant que le doigt reste posé', (
    tester,
  ) async {
    await _pose(tester, [_el('je')]);
    final t = GlypheTokens.clair;
    expect(_fondBouton(tester, 'bouton-effacer'), isNot(t.danger));
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('bouton-effacer'))),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    expect(_fondBouton(tester, 'bouton-effacer'), t.danger);
    await g.up();
    await tester.pump();
    expect(_fondBouton(tester, 'bouton-effacer'), isNot(t.danger));
  });

  testWidgets(
    'REQ007_AC4 danger plein tant que le doigt reste posé après vidage',
    (tester) async {
      tester.view.physicalSize = const Size(640, 360);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final elements = <ElementBarre>[_el('je')];
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
                ),
              ),
            ),
          ),
        ),
      );
      final cle = find.byKey(const Key('bouton-effacer'));
      final g = await tester.startGesture(tester.getCenter(cle));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      await tester.pump();
      expect(elements, isEmpty);
      expect(_fondBouton(tester, 'bouton-effacer'), GlypheTokens.clair.danger);
      final op = tester.widget<Opacity>(
        find.ancestor(of: cle, matching: find.byType(Opacity)).first,
      );
      expect(op.opacity, 1);
      await g.up();
      await tester.pump();
      expect(
        _fondBouton(tester, 'bouton-effacer'),
        isNot(GlypheTokens.clair.danger),
      );
    },
  );

  testWidgets('REQ007_AC5 libellé et action d\'appui long exposés', (
    tester,
  ) async {
    final h = tester.ensureSemantics();
    final n = await _pose(tester, [_el('je')]);
    final noeud = tester.getSemantics(find.byKey(const Key('bouton-effacer')));
    final d = noeud.getSemanticsData();
    expect(d.label, 'Effacer le dernier mot');
    expect(d.hasAction(SemanticsAction.longPress), isTrue);
    expect(d.hasAction(SemanticsAction.tap), isTrue);
    final indice = CustomSemanticsAction.overridingAction(
      hint: 'Tout effacer',
      action: SemanticsAction.longPress,
    );
    expect(
      d.customSemanticsActionIds,
      contains(CustomSemanticsAction.getIdentifier(indice)),
    );
    tester.semantics.performAction(
      find.semantics.byLabel('Effacer le dernier mot'),
      SemanticsAction.longPress,
    );
    expect(n.tout, 1);
    h.dispose();
  });
}
