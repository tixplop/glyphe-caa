import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/modeles.dart';
import 'package:glyphe/domaine/photos.dart';
import 'package:glyphe/ui/widgets/image_case.dart';
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

  // Cotes en côte à côte : picto d, haut à 5, texte à picto.right + 2, ligne
  // centrée sur le picto, ensemble centré sur la case ; [tronque] : libellé
  // tronqué de largeur [largeur].
  void mesures(WidgetTester tester, String lib, double d, {double? largeur}) {
    expect(tester.takeException(), isNull);
    final caseR = tester.getRect(find.byType(CaseWidget)).deflate(3);
    final picto = tester.getRect(find.byKey(const Key('picto')));
    expect(picto.width, closeTo(d, 0.5));
    expect(picto.height, closeTo(d, 0.5));
    expect(picto.top - caseR.top, closeTo(5, 0.5));
    final l = tester.getRect(find.text(lib));
    expect(l.left, closeTo(picto.right + 2, 0.5));
    expect(l.height, closeTo(16, 0.5));
    expect(l.center.dy, closeTo(picto.center.dy, 0.5));
    expect((picto.left + l.right) / 2, closeTo(caseR.center.dx, 0.5));
    final r = tester.renderObject<RenderParagraph>(find.text(lib));
    if (largeur == null) {
      final boites = r.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: lib.length),
      );
      expect(l.left + boites.last.right, closeTo(l.right, 0.5));
      expect(r.didExceedMaxLines, isFalse);
      expect(picto.left - caseR.left, greaterThan(7));
    } else {
      expect(r.didExceedMaxLines, isTrue);
      expect(picto.left - caseR.left, closeTo(7, 0.5));
      expect(l.width, closeTo(largeur, 0.5));
      expect(l.right, lessThanOrEqualTo(caseR.right - 7 + 0.5));
    }
    expect(find.byKey(const Key('libelle-place')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('libelle-place'))).width,
      closeTo(l.width, 0.5),
    );
    expect(_texte(tester, lib).style!.fontSize, 13);
    expect(_texte(tester, lib).maxLines, 1);
    expect(_texte(tester, lib).textAlign, TextAlign.left);
  }

  group('REQ033_AC8 REQ033_AC14 cotes du picto et du libellé', () {
    setUpAll(chargerPolice);

    // (w, h, picto, largeur du libellé tronqué)
    for (final (w, h, d, lg) in const [
      (148.0, 81.3, 72.3, 59.7),
      (216.75, 98.7, 89.7, 111.1),
      (308.0, 228.0, 219.0, 73.0),
      (148.0, 59.0, 50.0, 82.0),
    ]) {
      testWidgets('REQ033_AC8 REQ033_AC16 ${w}x$h : bloc centré', (
        tester,
      ) async {
        for (final lib in ['je', 'Émotions']) {
          await poseRect(tester, _case(lib), w, h);
          mesures(tester, lib, d);
        }
        const long = 'je veux aller aux toilettes';
        await poseRect(tester, _case(long), w, h);
        mesures(tester, long, d, largeur: lg);
      });
    }

    testWidgets('REQ033_AC14 « je » : premier glyphe au bord gauche du Text', (
      tester,
    ) async {
      await poseRect(tester, _case('je'), 148, 81.3);
      final r = tester.renderObject<RenderParagraph>(find.text('je'));
      final boites = r.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 1),
      );
      expect(boites.first.left, closeTo(0, 0.5));
    });

    testWidgets('REQ033_AC13 sonde : « Émotions » en 13 tient en 59,7', (
      tester,
    ) async {
      final p = TextPainter(
        text: TextSpan(text: 'Émotions', style: GlypheTokens.caseLibelle),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout();
      expect(p.width, lessThanOrEqualTo(59.7));
    });

    testWidgets('REQ033_AC15 superposée 148 x 260 : picto 134, ligne 189,5', (
      tester,
    ) async {
      await poseRect(tester, _case('Émotions'), 148, 260);
      expect(tester.takeException(), isNull);
      final caseR = tester.getRect(find.byType(CaseWidget)).deflate(3);
      final picto = tester.getRect(find.byKey(const Key('picto')));
      expect(picto.width, closeTo(134, 0.5));
      expect(picto.left - caseR.left, closeTo(7, 0.5));
      expect(picto.top - caseR.top, closeTo(55.5, 0.5));
      final l = tester.getRect(find.text('Émotions'));
      expect(l.top - caseR.top, closeTo(189.5, 0.5));
      expect(
        tester.getSize(find.byKey(const Key('libelle-place'))).width,
        closeTo(134, 0.5),
      );
      expect(_texte(tester, 'Émotions').textAlign, TextAlign.center);
      expect(
        tester
            .renderObject<RenderParagraph>(find.text('Émotions'))
            .didExceedMaxLines,
        isFalse,
      );
    });

    testWidgets('REQ037_AC10 flèche de 134 au-dessus de « Retour »', (
      tester,
    ) async {
      await poseRect(tester, _case('Retour', type: TypeCase.retour), 148, 260);
      final f = tester.getRect(find.byKey(const Key('fleche-retour')));
      final l = tester.getRect(find.text('Retour'));
      expect(f.width, closeTo(134, 0.5));
      expect(f.bottom, closeTo(l.top, 0.5));
    });

    for (final (w, h) in const [(148.0, 260.0), (148.0, 81.3)]) {
      testWidgets('REQ037_AC9 flèche = picto d\'une case-mot ${w}x$h', (
        tester,
      ) async {
        await poseRect(tester, _case('Retour', type: TypeCase.retour), w, h);
        final fleche = tester.getRect(find.byKey(const Key('fleche-retour')));
        await poseRect(tester, _case('Retour'), w, h);
        final picto = tester.getRect(find.byKey(const Key('picto')));
        expect(fleche.size, picto.size);
        expect(fleche.topLeft, picto.topLeft);
      });
    }

    for (final echelle in const [2.0, 0.85]) {
      testWidgets('REQ035_AC4 échelle $echelle : mêmes rectangles, 13', (
        tester,
      ) async {
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(echelle)),
            child: MaterialApp(
              theme: themeGlyphe(Brightness.light),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 154,
                    height: 87.3,
                    child: CaseWidget(caseData: _case('mange'), onTap: () {}),
                  ),
                ),
              ),
            ),
          ),
        );
        final caseR = tester.getRect(find.byType(CaseWidget)).deflate(3);
        final picto = tester.getRect(find.byKey(const Key('picto')));
        expect(picto.top - caseR.top, closeTo(5, 0.5));
        expect(picto.width, closeTo(72.3, 0.5));
        expect(picto.height, closeTo(72.3, 0.5));
        final l = tester.getRect(find.text('mange'));
        expect(l.left, closeTo(picto.right + 2, 0.5));
        expect(l.center.dy, closeTo(picto.center.dy, 0.5));
        expect((picto.left + l.right) / 2, closeTo(caseR.center.dx, 0.5));
        expect(l.height, closeTo(16, 0.5));
        expect(_texte(tester, 'mange').style!.fontSize, 13);
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
    expect(picto.center.dx, closeTo(caseR.center.dx, 0.5));
    expect(
      find.descendant(of: find.byType(CaseWidget), matching: find.byType(Text)),
      findsNothing,
    );
  });

  testWidgets(
    'REQ033_AC10 REQ033_AC19 case 8x8 en 640x360 : bloc centré dans le contour',
    (tester) async {
      await chargerPolice();
      await poseRect(tester, _case('eau'), 70, 25.5);
      expect(tester.takeException(), isNull);
      final caseR = tester.getRect(find.byType(CaseWidget)).deflate(3);
      final picto = tester.getRect(find.byKey(const Key('picto')));
      expect(picto.width, closeTo(16.5, 0.5));
      final l = tester.getRect(find.text('eau'));
      expect(_texte(tester, 'eau').style!.fontSize, 13);
      expect(
        tester
            .renderObject<RenderParagraph>(find.text('eau'))
            .didExceedMaxLines,
        isFalse,
      );
      expect(l.left, closeTo(picto.right + 2, 0.5));
      expect((picto.left + l.right) / 2, closeTo(caseR.center.dx, 0.5));
      expect(picto.left - caseR.left, greaterThanOrEqualTo(7 - 0.5));
      expect(l.right, lessThanOrEqualTo(caseR.right - 7 + 0.5));
      expect(caseR.contains(l.topLeft), isTrue);
      expect(caseR.contains(l.bottomRight), isTrue);
    },
  );

  testWidgets('REQ033_AC10 case plus basse que le libellé : pas d\'exception', (
    tester,
  ) async {
    await poseRect(tester, _case('eau'), 70, 18);
    expect(tester.takeException(), isNull);
  });

  testWidgets('REQ033_AC11 libellé trop long : 13, une ligne, ellipsis', (
    tester,
  ) async {
    await chargerPolice();
    final h = tester.ensureSemantics();
    const lib = 'je veux aller aux toilettes';
    await poseRect(tester, _case(lib), 148, 81.3);
    expect(tester.takeException(), isNull);
    final caseR = tester.getRect(find.byType(CaseWidget)).deflate(3);
    final r = tester.renderObject<RenderParagraph>(find.text(lib));
    expect(r.didExceedMaxLines, isTrue);
    expect(r.size.width, closeTo(59.7, 0.5));
    expect(
      tester.getRect(find.text(lib)).right,
      lessThanOrEqualTo(caseR.right - 7 + 0.5),
    );
    expect(_texte(tester, lib).style!.fontSize, 13);
    expect(_texte(tester, lib).overflow, TextOverflow.ellipsis);
    expect(
      tester.getSize(find.byKey(const Key('picto'))).width,
      closeTo(72.3, 0.5),
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
      final ligne = tester.getRect(find.text('Manger'));
      expect(coin.overlaps(picto), isFalse, reason: '$w x $h');
      expect(coin.overlaps(ligne), isFalse, reason: '$w x $h');
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
      expect(fleche.width, closeTo(72.3, 0.5));
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

  group('bloc centré (AC-033-16 à 19, AC-037-10)', () {
    setUpAll(chargerPolice);

    testWidgets('REQ033_AC18 picto ARASAAC ou photo : mêmes rectangles', (
      tester,
    ) async {
      final dossier = Directory.systemTemp.createTempSync('glyphe_case');
      addTearDown(() => dossier.deleteSync(recursive: true));
      await tester.runAsync(() async {
        final rec = ui.PictureRecorder();
        ui.Canvas(rec).drawRect(
          const ui.Rect.fromLTWH(0, 0, 300, 400),
          ui.Paint()..color = const ui.Color(0xFF336699),
        );
        final img = await rec.endRecording().toImage(300, 400);
        final oct = await img.toByteData(format: ui.ImageByteFormat.png);
        File('${dossier.path}/p.png')
            .writeAsBytesSync(oct!.buffer.asUint8List());
      });
      Case avec(ImageCase i) => Case(
        id: 'x',
        ligne: 0,
        colonne: 0,
        type: TypeCase.mot,
        libelle: 'chien',
        image: i,
      );
      Future<(Rect, Rect)> mesure(ImageCase i) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: themeGlyphe(Brightness.light),
            home: PhotosScope(
              photos: Photos(dossier),
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 154,
                    height: 87.3,
                    child: CaseWidget(caseData: avec(i), onTap: () {}),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        return (
          tester.getRect(find.byKey(const Key('picto'))),
          tester.getRect(find.text('chien')),
        );
      }

      final (p1, t1) = await mesure(const ImageArasaac(10148));
      final (p2, t2) = await mesure(const ImagePhoto('p.png'));
      expect(p1.width, closeTo(72.3, 0.5));
      expect(p1.top - 3, closeTo(5, 0.5));
      expect(p2, p1);
      expect(t2, t1);
      final image = tester.widget<Image>(
        find.descendant(
          of: find.byKey(const Key('picto')),
          matching: find.byType(Image),
        ),
      );
      expect(image.fit, BoxFit.contain);
    });

    testWidgets('REQ033_AC17 appui à gauche du picto et à droite du libellé', (
      tester,
    ) async {
      var n = 0;
      final h = tester.ensureSemantics();
      await _pose(
        tester,
        _case('je'),
        taille: const Size(154, 87.3),
        onTap: () => n++,
      );
      final r = tester.getRect(find.byType(CaseWidget)).deflate(3);
      await tester.tapAt(Offset(r.left + 4, r.center.dy));
      expect(n, 1);
      await tester.tapAt(Offset(r.right - 4, r.center.dy));
      expect(n, 2);
      final sem = tester.getSemantics(find.bySemanticsLabel('je'));
      expect(sem.rect.width, closeTo(148, 0.5));
      expect(sem.rect.height, closeTo(81.3, 0.5));
      h.dispose();
    });

    testWidgets('REQ037_AC10 case-retour : flèche + Retour centrés', (
      tester,
    ) async {
      await poseRect(tester, _case('Retour', type: TypeCase.retour), 148, 81.3);
      final caseR = tester.getRect(find.byType(CaseWidget)).deflate(3);
      final f = tester.getRect(find.byKey(const Key('fleche-retour')));
      final l = tester.getRect(find.text('Retour'));
      expect(f.width, closeTo(72.3, 0.5));
      expect(f.top - caseR.top, closeTo(5, 0.5));
      expect(l.left, closeTo(f.right + 2, 0.5));
      expect((f.left + l.right) / 2, closeTo(caseR.center.dx, 0.5));
    });
  });
}
