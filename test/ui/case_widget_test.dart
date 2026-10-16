import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/modeles.dart';
import 'package:glyphe/ui/theme.dart';
import 'package:glyphe/ui/tokens.dart';
import 'package:glyphe/ui/widgets/case_widget.dart';

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

  testWidgets('REQ033_AC1 picto à 60 % du plus petit côté, libellé dessous', (
    tester,
  ) async {
    await _pose(tester, _case('mange'), taille: const Size(120, 100));
    final picto = tester.getRect(find.byKey(const Key('picto')));
    expect(picto.width, closeTo(0.6 * 94, 0.01));
    expect(picto.height, closeTo(0.6 * 94, 0.01));
    final caseR = tester.getRect(find.byType(CaseWidget));
    expect(picto.center.dx, closeTo(caseR.center.dx, 0.01));
    final lib = tester.getRect(find.text('mange'));
    expect(lib.top, greaterThanOrEqualTo(picto.bottom + 4 - 0.01));
    expect(lib.center.dx, closeTo(caseR.center.dx, 0.01));
    expect(_texte(tester, 'mange').style!.fontSize, 17);
    expect(_texte(tester, 'mange').maxLines, 1);
  });

  testWidgets('REQ001_AC10 case large 148 x 81,3 : picto >= 44, libellé 17', (
    tester,
  ) async {
    await _pose(tester, _case('mange'), taille: const Size(148 + 6, 81.3 + 6));
    expect(tester.takeException(), isNull);
    final picto = tester.getRect(find.byKey(const Key('picto')));
    expect(picto.width, greaterThanOrEqualTo(44));
    expect(picto.height, greaterThanOrEqualTo(44));
    expect(_texte(tester, 'mange').style!.fontSize, 17);
    expect(_texte(tester, 'mange').maxLines, 1);
    final caseR = tester.getRect(find.byType(CaseWidget));
    expect(caseR.contains(picto.topLeft), isTrue);
    expect(
      caseR.contains(tester.getRect(find.text('mange')).bottomRight),
      isTrue,
    );
  });

  testWidgets('REQ033_AC2 libellé trop long : 15 puis ellipsis', (
    tester,
  ) async {
    await _pose(tester, _case('anticonstitutionnellement'));
    final t = _texte(tester, 'anticonstitutionnellement');
    expect(t.style!.fontSize, 15);
    expect(t.overflow, TextOverflow.ellipsis);
    expect(t.maxLines, 1);
    expect(find.byType(FittedBox), findsNothing);
  });

  testWidgets('REQ033_AC2 libellé moyen : bascule en 15 (police de test)', (
    tester,
  ) async {
    // Police de test : 1 em par caractère ; largeur du Text = 100 - 2*3 - 2*3
    // = 88 (marge externe et marge interne, la bordure ne rogne pas le Text).
    await _pose(tester, _case('abcde'), taille: const Size(100, 100));
    expect(_texte(tester, 'abcde').style!.fontSize, 17);
    expect(tester.getSize(find.text('abcde')).width, lessThanOrEqualTo(88));
    await _pose(tester, _case('abcdef'), taille: const Size(100, 100));
    expect(_texte(tester, 'abcdef').style!.fontSize, 15);
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
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
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
    final r = tester.renderObject<RenderBox>(find.text('abcd'));
    expect(r.size.height, closeTo(20, 0.5));
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
      expect(icone.size, closeTo(0.6 * 94, 0.01));
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
