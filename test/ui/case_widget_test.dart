import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/modeles.dart';
import 'package:glyphe/ui/theme.dart';
import 'package:glyphe/ui/tokens.dart';
import 'package:glyphe/ui/widgets/case_widget.dart';

import '../faux/police.dart';

Case _case(
  String lib, {
  TypeCase type = TypeCase.mot,
  Categorie cat = Categorie.action,
}) => Case(
  id: 'x',
  ligne: 0,
  colonne: 0,
  type: type,
  libelle: lib,
  cibleId: type == TypeCase.dossier ? 'g' : null,
  image: const ImageAucune(),
  categorie: cat,
);

Future<void> _pose(
  WidgetTester tester,
  Case c, {
  VoidCallback? onTap,
  Size taille = const Size(88, 88),
  bool orphelin = false,
  Brightness lum = Brightness.light,
}) => tester.pumpWidget(
  MaterialApp(
    theme: themeGlyphe(lum),
    home: Scaffold(
      body: Center(
        child: SizedBox.fromSize(
          size: taille,
          child: CaseWidget(
            caseData: c,
            onTap: onTap ?? () {},
            orphelin: orphelin,
          ),
        ),
      ),
    ),
  ),
);

Text _texte(WidgetTester tester, String s) => tester.widget<Text>(find.text(s));

void main() {
  testWidgets('REQ033_AC1 REQ032_AC2 forme, fond et contour de catégorie', (
    tester,
  ) async {
    await _pose(tester, _case('mange'));
    final m = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(CaseWidget),
            matching: find.byType(Material),
          )
          .first,
    );
    final t = GlypheTokens.clair;
    final forme = m.shape! as RoundedRectangleBorder;
    expect(m.color, t.catActionBg);
    expect(forme.side.color, t.catActionEdge);
    expect(forme.side.width, 3);
    expect(forme.borderRadius, BorderRadius.circular(14));
    expect(_texte(tester, 'mange').style!.color, t.ink);
  });

  testWidgets('REQ032_AC2 thème sombre', (tester) async {
    await _pose(tester, _case('mange'), lum: Brightness.dark);
    final m = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(CaseWidget),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(m.color, GlypheTokens.sombre.catActionBg);
    expect(_texte(tester, 'mange').style!.color, GlypheTokens.sombre.ink);
  });

  // Case posée sur un rectangle dessiné w x h (zone = +6 de marge externe).
  Future<void> poseRect(WidgetTester tester, Case c, double w, double h) =>
      _pose(tester, c, taille: Size(w + 6, h + 6));

  void mesures(WidgetTester tester, String lib, double w, double h, double d) {
    expect(tester.takeException(), isNull);
    final caseR = tester.getRect(find.byType(CaseWidget)).deflate(3);
    final picto = tester.getRect(find.byKey(const Key('picto')));
    expect(picto.width, closeTo(d, 0.5));
    expect(picto.height, closeTo(d, 0.5));
    expect(picto.top - caseR.top, closeTo(5, 0.5));
    expect(picto.center.dx, closeTo(caseR.center.dx, 0.5));
    final l = tester.getRect(find.text(lib));
    expect(caseR.bottom - l.bottom, closeTo(4, 0.5));
    expect(l.height, closeTo(18, 0.5));
    expect(l.width, lessThanOrEqualTo(w - 14 + 0.5));
    expect(_texte(tester, lib).style!.fontSize, 15);
    expect(_texte(tester, lib).maxLines, 1);
  }

  group('REQ033_AC8 cotes du picto et du libellé', () {
    setUpAll(chargerPolice);

    for (final (w, h, d) in const [
      (148.0, 81.3, 54.3),
      (216.75, 98.7, 71.7),
      (308.0, 228.0, 201.0),
      (148.0, 59.3, 32.3),
    ]) {
      testWidgets('REQ033_AC8 ${w}x$h : picto $d', (tester) async {
        await poseRect(tester, _case('mange'), w, h);
        mesures(tester, 'mange', w, h, d);
      });
    }
  });

  testWidgets('REQ033_AC9 sans libellé : picto 72,3, haut à 5, aucun Text', (
    tester,
  ) async {
    await poseRect(tester, _case(''), 148, 81.3);
    final caseR = tester.getRect(find.byType(CaseWidget)).deflate(3);
    final picto = tester.getRect(find.byKey(const Key('picto')));
    expect(picto.width, closeTo(72.3, 0.5));
    expect(picto.top - caseR.top, closeTo(5, 0.5));
    expect(
      find.descendant(of: find.byType(CaseWidget), matching: find.byType(Text)),
      findsNothing,
    );
  });

  testWidgets('REQ033_AC10 case 8x8 en 640x360 : sans exception, libellé dans '
      'le contour', (tester) async {
    // Vraie case 8x8 en 640x360 : zone d'environ 76 x 31, rectangle dessiné
    // d'environ 70 x 25 (hi < 18 : marges verticales à 0, picto d'environ 1).
    await _pose(tester, _case('eau'), taille: const Size(76, 31));
    expect(tester.takeException(), isNull);
    final caseR = tester.getRect(find.byType(CaseWidget)).deflate(3);
    expect(caseR.width, closeTo(70, 0.5));
    expect(caseR.height, closeTo(25, 0.5));
    final l = tester.getRect(find.text('eau'));
    expect(_texte(tester, 'eau').style!.fontSize, 15);
    expect(
      tester.renderObject<RenderParagraph>(find.text('eau')).didExceedMaxLines,
      isFalse,
    );
    expect(l.height, lessThanOrEqualTo(18 + 0.5));
    expect(caseR.contains(l.topLeft), isTrue);
    expect(caseR.contains(l.bottomRight), isTrue);
    expect(
      tester.getSize(find.byKey(const Key('picto'))).width,
      closeTo(1, 0.5),
    );
  });

  testWidgets('REQ033_AC10 case plus basse que le libellé : pas d\'exception', (
    tester,
  ) async {
    await _pose(tester, _case('eau'), taille: const Size(40, 24));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(const Key('picto'))).width, 0);
  });

  testWidgets('REQ033_AC11 libellé trop long : 15, une ligne, ellipsis', (
    tester,
  ) async {
    final h = tester.ensureSemantics();
    const lib = 'je veux aller aux toilettes';
    await poseRect(tester, _case(lib), 148, 81.3);
    expect(tester.takeException(), isNull);
    final r = tester.renderObject<RenderParagraph>(find.text(lib));
    expect(r.didExceedMaxLines, isTrue);
    expect(r.size.width, lessThanOrEqualTo(134 + 0.5));
    expect(_texte(tester, lib).style!.fontSize, 15);
    expect(_texte(tester, lib).overflow, TextOverflow.ellipsis);
    expect(
      tester.getSize(find.byKey(const Key('picto'))).width,
      closeTo(54.3, 0.5),
    );
    expect(find.bySemanticsLabel(lib), findsOneWidget);
    expect(find.byType(FittedBox), findsNothing);
    h.dispose();
  });

  testWidgets('REQ033_AC12 coin et badge hors du picto, aux trois tailles', (
    tester,
  ) async {
    for (final (w, h) in const [
      (148.0, 81.3),
      (216.75, 98.7),
      (308.0, 228.0),
    ]) {
      await _pose(
        tester,
        _case('Manger', type: TypeCase.dossier),
        taille: Size(w + 6, h + 6),
        orphelin: true,
      );
      final caseR = tester.getRect(find.byType(CaseWidget)).deflate(3);
      final picto = tester.getRect(find.byKey(const Key('picto')));
      final coin = tester.getRect(find.byKey(const Key('coin-dossier')));
      final badge = tester.getRect(find.byKey(const Key('badge-orphelin')));
      expect(coin.topRight, caseR.topRight);
      expect(badge.topLeft, caseR.topLeft);
      expect(coin.overlaps(picto), isFalse, reason: '$w x $h');
    }
  });

  testWidgets('REQ033_AC2 libellé d\'accessibilité complet', (tester) async {
    final h = tester.ensureSemantics();
    await _pose(tester, _case('anticonstitutionnellement'));
    expect(find.bySemanticsLabel('anticonstitutionnellement'), findsOneWidget);
    h.dispose();
  });

  testWidgets('REQ033_AC2 échelle de police système sans effet', (
    tester,
  ) async {
    await chargerPolice();
    Future<RenderParagraph> mesure(double echelle) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(echelle)),
          child: MaterialApp(
            theme: themeGlyphe(Brightness.light),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: CaseWidget(caseData: _case('abcd'), onTap: () {}),
                ),
              ),
            ),
          ),
        ),
      );
      return tester.renderObject<RenderParagraph>(find.text('abcd'));
    }

    final p1 = await mesure(1);
    final largeur1 = p1.size.width;
    final p2 = await mesure(2);
    expect(p2.textScaler, TextScaler.noScaling);
    expect(p2.size.width, closeTo(largeur1, 0.01));
    expect(p2.size.height, closeTo(p1.size.height, 0.01));
  });

  group('REQ033_AC3 appui', () {
    testWidgets('pointeur posé : rien ; relâché : action', (tester) async {
      var n = 0;
      await _pose(tester, _case('mange'), onTap: () => n++);
      final g = await tester.startGesture(
        tester.getCenter(find.byType(CaseWidget)),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(n, 0);
      await g.up();
      await tester.pump();
      expect(n, 1);
    });

    testWidgets('glissé hors de la case puis relâché : rien', (tester) async {
      var n = 0;
      await _pose(tester, _case('mange'), onTap: () => n++);
      final g = await tester.startGesture(
        tester.getCenter(find.byType(CaseWidget)),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await g.moveTo(
        tester.getCenter(find.byType(CaseWidget)) + const Offset(150, 0),
      );
      await tester.pump();
      await g.up();
      await tester.pump();
      expect(n, 0);
    });

    testWidgets('voile ink 12 % sans ondulation', (tester) async {
      await _pose(tester, _case('mange'), onTap: () {});
      final ink = tester.widget<InkWell>(find.byType(InkWell));
      expect(
        ink.highlightColor,
        GlypheTokens.clair.ink.withValues(alpha: 0.12),
      );
      expect(ink.splashFactory, NoSplash.splashFactory);
    });
  });

  group('REQ008_AC4 dossier', () {
    testWidgets('coin replié de 16 en couleur de contour', (tester) async {
      await _pose(
        tester,
        _case('Manger', type: TypeCase.dossier, cat: Categorie.objet),
      );
      final coin = find.byKey(const Key('coin-dossier'));
      expect(tester.getSize(coin), const Size(16, 16));
      final d = tester.widget<Container>(coin).decoration! as BoxDecoration;
      expect(d.color, GlypheTokens.clair.catObjectEdge);
      expect(
        d.borderRadius,
        const BorderRadius.only(
          topRight: Radius.circular(14),
          bottomLeft: Radius.circular(6),
        ),
      );
      expect(find.byIcon(Icons.folder), findsNothing);
    });

    testWidgets('pas de coin pour un mot', (tester) async {
      await _pose(tester, _case('mange'));
      expect(find.byKey(const Key('coin-dossier')), findsNothing);
    });

    testWidgets('REQ033_AC5 badge orphelin en danger', (tester) async {
      await _pose(
        tester,
        _case('Perdu', type: TypeCase.dossier),
        orphelin: true,
      );
      final icone = tester.widget<Icon>(
        find
            .descendant(
              of: find.byKey(const Key('badge-orphelin')),
              matching: find.byType(Icon),
            )
            .first,
      );
      expect(icone.color, GlypheTokens.clair.danger);
    });
  });

  group('REQ033_AC4 focus', () {
    Future<void> deuxCases(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(
        theme: themeGlyphe(Brightness.light),
        home: Scaffold(
          body: Row(
            children: [
              Expanded(
                child: CaseWidget(caseData: _case('un'), onTap: () {}),
              ),
              Expanded(
                child: CaseWidget(caseData: _case('deux'), onTap: () {}),
              ),
            ],
          ),
        ),
      ),
    );

    testWidgets('Tab : anneau sur la première puis la deuxième', (
      tester,
    ) async {
      await deuxCases(tester);
      expect(find.byKey(const Key('anneau-focus')), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      var anneau = find.byKey(const Key('anneau-focus'));
      expect(anneau, findsOneWidget);
      expect(
        tester.getCenter(anneau).dx,
        closeTo(tester.getCenter(find.byType(CaseWidget).first).dx, 0.01),
      );
      final d = tester.widget<DecoratedBox>(anneau).decoration as BoxDecoration;
      expect((d.border! as Border).top.width, 3);
      expect((d.border! as Border).top.color, GlypheTokens.clair.focus);
      final matiere = tester.getRect(
        find
            .descendant(
              of: find.byType(CaseWidget).first,
              matching: find.byType(Material),
            )
            .first,
      );
      // Anneau de 3 décalé de 2 : 5 de chaque côté de la case.
      expect(tester.getRect(anneau), matiere.inflate(5));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      anneau = find.byKey(const Key('anneau-focus'));
      expect(anneau, findsOneWidget);
      expect(
        tester.getCenter(anneau).dx,
        closeTo(tester.getCenter(find.byType(CaseWidget).last).dx, 0.01),
      );
    });
  });

  group('case-retour (REQ-037)', () {
    testWidgets('REQ037_AC4 AC9 flèche ink à la taille du picto, sans coin', (
      tester,
    ) async {
      final h = tester.ensureSemantics();
      await _pose(
        tester,
        _case('Retour', type: TypeCase.retour, cat: Categorie.petitMot),
        taille: const Size(120, 100),
      );
      final fleche = find.byKey(const Key('fleche-retour'));
      expect(fleche, findsOneWidget);
      final icone = tester.widget<Icon>(fleche);
      expect(icone.icon, Icons.arrow_back);
      expect(icone.color, GlypheTokens.clair.ink);
      expect(icone.size, closeTo(tester.getSize(fleche).width, 0.01));
      expect(
        tester.getCenter(fleche).dx,
        closeTo(tester.getCenter(find.byType(CaseWidget)).dx, 0.01),
      );
      expect(find.byKey(const Key('coin-dossier')), findsNothing);
      expect(find.text('Retour'), findsOneWidget);
      final m = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(CaseWidget),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(m.color, GlypheTokens.clair.catLittleBg);
      // Seul le libellé est exposé au lecteur d'écran.
      expect(find.bySemanticsLabel('Retour'), findsOneWidget);
      h.dispose();
    });

    testWidgets('REQ037_AC9 flèche de la taille du picto d\'une case-mot', (
      tester,
    ) async {
      await poseRect(tester, _case('Retour', type: TypeCase.retour), 148, 81.3);
      final fleche = tester.getSize(find.byKey(const Key('fleche-retour')));
      await poseRect(tester, _case('mange'), 148, 81.3);
      final picto = tester.getSize(find.byKey(const Key('picto')));
      expect(fleche, picto);
      expect(fleche.width, closeTo(54.3, 0.5));
    });

    testWidgets('REQ037_AC4 sans libellé : sémantique « Retour »', (
      tester,
    ) async {
      final h = tester.ensureSemantics();
      await _pose(tester, _case('', type: TypeCase.retour));
      expect(find.bySemanticsLabel('Retour'), findsOneWidget);
      h.dispose();
    });

    testWidgets('REQ037_AC4 avec image : rendu de case-mot', (tester) async {
      const c = Case(
        id: 'x',
        ligne: 0,
        colonne: 0,
        type: TypeCase.retour,
        libelle: 'Retour',
        image: ImageArasaac(2617),
      );
      await _pose(tester, c);
      expect(find.byKey(const Key('fleche-retour')), findsNothing);
      expect(find.byKey(const Key('coin-dossier')), findsNothing);
    });

    testWidgets('REQ037_AC4 appui', (tester) async {
      var n = 0;
      await _pose(
        tester,
        _case('Retour', type: TypeCase.retour),
        onTap: () => n++,
      );
      await tester.tap(find.byType(CaseWidget));
      expect(n, 1);
    });
  });
}
