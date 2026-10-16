import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/ui/app.dart';
import 'package:glyphe/ui/etat_appli.dart';
import 'package:glyphe/ui/selecteur_image.dart';
import 'package:glyphe/ui/textes.dart';
import 'package:glyphe/ui/widgets/barre_edition.dart';
import 'package:glyphe/ui/widgets/barre_phrase.dart';
import 'package:glyphe/ui/widgets/titre_barre.dart';

import 'accessibilite_edition_test.dart' show etatPret, retour;
import 'verrou_ui_test.dart' as verrou;

const _paysage = Size(640, 360);

void _regler(WidgetTester tester, {double clavier = 0, double? echelle}) {
  tester.view.physicalSize = _paysage;
  tester.view.devicePixelRatio = 1.0;
  tester.view.viewInsets = FakeViewPadding(bottom: clavier);
  addTearDown(tester.view.reset);
  if (echelle != null) {
    tester.platformDispatcher.textScaleFactorTestValue = echelle;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
}

/// Ouvre la case « Manger » de l'accueil : un dossier dont la cible existe.
Future<void> _ouvrirCaseExistante(WidgetTester tester, EtatAppli etat) async {
  expect(etat.session.donnees.grillePar('manger'), isNotNull);
  await tester.tap(find.byKey(const Key('case-accueil-9')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('ecran-edition-case')), findsOneWidget);
  expect(find.byKey(const Key('bouton-ouvrir')), findsOneWidget);
}

/// Fait défiler l'écran courant jusqu'à [dernier] (dernier élément).
Future<void> _jusquAu(WidgetTester tester, Finder dernier, String ecran) async {
  final defilant = find
      .descendant(
        of: find.byType(Scaffold).last,
        matching: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axis == Axis.vertical,
        ),
      )
      .first;
  expect(defilant, findsOneWidget, reason: ecran);
  await tester.scrollUntilVisible(
    dernier,
    80,
    scrollable: defilant,
    maxScrolls: 200,
  );
  await tester.pumpAndSettle();
  expect(dernier, findsOneWidget, reason: ecran);
  expect(tester.getRect(dernier).bottom, lessThanOrEqualTo(360), reason: ecran);
  expect(tester.takeException(), isNull, reason: ecran);
}

/// Ouvre le menu Plus et choisit [cle], en le faisant défiler si besoin.
Future<void> depuisMenu(WidgetTester tester, String cle) async {
  await tester.tap(find.byKey(const Key('bouton-plus')));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(Key(cle)));
  await tester.pumpAndSettle();
  final r = tester.getRect(find.byKey(Key(cle)));
  expect(r.bottom, lessThanOrEqualTo(360), reason: cle);
  await tester.tap(find.byKey(Key(cle)));
  await tester.pumpAndSettle();
}

/// Parcourt tous les écrans et dialogues de l'aidant ; un débordement de
/// rendu fait échouer le test (exception du framework).
Future<void> _parcours(WidgetTester tester) async {
  final etat = await etatPret(tester);
  await tester.pumpWidget(GlypheApp(etat: etat));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);

  etat.ouvrirEdition();
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('bouton-plus')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('bouton-grilles')), findsOneWidget);
  await tester.tapAt(const Offset(2, 2));
  await tester.pumpAndSettle();

  for (final cle in const [
    'bouton-grilles',
    'bouton-reglages',
    'bouton-code',
    'bouton-a-propos',
  ]) {
    await depuisMenu(tester, cle);
    expect(tester.takeException(), isNull, reason: cle);
    await retour(tester);
  }

  await depuisMenu(tester, 'bouton-taille');
  expect(find.byKey(const Key('dialogue-taille')), findsOneWidget);
  await tester.tap(find.text('Annuler'));
  await tester.pumpAndSettle();

  await _ouvrirCaseExistante(tester, etat);
  expect(tester.takeException(), isNull);
  await tester.ensureVisible(find.byKey(const Key('bouton-image')));
  await tester.tap(find.byKey(const Key('bouton-image')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('ecran-selecteur-image')), findsOneWidget);
  expect(tester.takeException(), isNull);
  await retour(tester);
}

void main() {
  testWidgets('REQ038_AC5 aucun débordement en 640x360', (tester) async {
    _regler(tester);
    await _parcours(tester);
  });

  for (final echelle in const [1.0, 2.0]) {
    testWidgets('REQ038_AC5 les formulaires et listes défilent jusqu\'au bout '
        '(échelle $echelle)', (tester) async {
      _regler(tester, echelle: echelle);
      final etat = await etatPret(tester);
      await tester.pumpWidget(GlypheApp(etat: etat));
      etat.ouvrirEdition();
      await tester.pumpAndSettle();
      await _ouvrirCaseExistante(tester, etat);
      await _jusquAu(
        tester,
        find.byKey(const Key('champ-cible')),
        'édition de case',
      );
      await retour(tester);

      final derniere = etat.session.donnees.grilles.last.id;
      final dernierElement = <String, Finder>{
        'bouton-grilles': find.byKey(Key('grille-$derniere')),
        'bouton-reglages': find.byKey(const Key('reglage-importer')),
        'bouton-code': find.byKey(const Key('champ-confirmation')),
        'bouton-a-propos': find.text(Textes.creditPolice),
      };
      for (final e in dernierElement.entries) {
        await depuisMenu(tester, e.key);
        await _jusquAu(tester, e.value, e.key);
        await retour(tester);
      }

      await _ouvrirCaseExistante(tester, etat);
      await tester.ensureVisible(find.byKey(const Key('bouton-image')));
      await tester.tap(find.byKey(const Key('bouton-image')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('champ-recherche')), 'a');
      await tester.pumpAndSettle();
      await _jusquAu(
        tester,
        find.byKey(const Key('bouton-galerie')),
        'sélecteur d\'image',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('REQ038_AC5 dialogue de code sans débordement', (tester) async {
    await verrou.lance(tester, code: '1234');
    _regler(tester);
    await tester.pumpAndSettle();
    await verrou.appui(tester, const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('champ-code')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('REQ038_AC7 clavier : dialogue de code', (tester) async {
    await verrou.lance(tester, code: '1234');
    _regler(tester, clavier: 200);
    await tester.pumpAndSettle();
    await verrou.appui(tester, const Duration(seconds: 3));
    await tester.pumpAndSettle();

    final champ = find.byKey(const Key('champ-code'));
    expect(champ, findsOneWidget);
    expect(tester.takeException(), isNull);
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isTrue);
    final r = tester.getRect(champ);
    expect(r.top, greaterThanOrEqualTo(0));
    expect(r.bottom, lessThanOrEqualTo(360 - 200));

    final defilant = find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Code oublié'),
      40,
      scrollable: defilant,
    );
    await tester.scrollUntilVisible(
      find.text('Saisissez le code'),
      -40,
      scrollable: defilant,
    );
    await tester.scrollUntilVisible(
      find.text('Code oublié'),
      40,
      scrollable: defilant,
    );
    await tester.tap(find.text('Code oublié'));
    await tester.pumpAndSettle();
    final phrase = find.byKey(const Key('champ-phrase'));
    expect(phrase, findsOneWidget);
    final editablePhrase = tester.widget<EditableText>(
      find.descendant(of: phrase, matching: find.byType(EditableText)),
    );
    expect(editablePhrase.focusNode.hasFocus, isTrue);
    final rp = tester.getRect(phrase);
    expect(rp.top, greaterThanOrEqualTo(0));
    expect(rp.bottom, lessThanOrEqualTo(360 - 200));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text(Textes.recopierPhrase),
      -40,
      scrollable: defilant,
    );
    await tester.scrollUntilVisible(phrase, 40, scrollable: defilant);
    await tester.scrollUntilVisible(
      find.text(verrou.phrase),
      -40,
      scrollable: defilant,
    );
  });

  for (final cle in const ['champ-libelle', 'champ-texte']) {
    testWidgets('REQ038_AC7 clavier : édition de case, $cle', (tester) async {
      _regler(tester);
      final etat = await etatPret(tester);
      await tester.pumpWidget(GlypheApp(etat: etat));
      etat.ouvrirEdition();
      await tester.pumpAndSettle();
      await _ouvrirCaseExistante(tester, etat);

      final champ = find.byKey(Key(cle));
      expect(champ, findsOneWidget);
      if (cle == 'champ-texte') {
        expect(tester.getRect(champ).bottom, greaterThan(160));
      }
      await tester.showKeyboard(champ);
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      await tester.pumpAndSettle();

      final editable = tester.widget<EditableText>(
        find.descendant(of: champ, matching: find.byType(EditableText)),
      );
      expect(editable.focusNode.hasFocus, isTrue);
      final barre = tester.getRect(find.byType(AppBar));
      final r = tester.getRect(champ);
      expect(r.top, greaterThanOrEqualTo(barre.bottom));
      expect(r.bottom, lessThanOrEqualTo(160));
      final enr = find.byKey(const Key('bouton-enregistrer'));
      expect(tester.getRect(enr).bottom, lessThanOrEqualTo(barre.bottom));
      expect(tester.widget<IconButton>(enr).onPressed, isNotNull);
      expect(tester.takeException(), isNull);

      tester.view.viewInsets = FakeViewPadding.zero;
      editable.focusNode.unfocus();
      await tester.pumpAndSettle();
    });
  }

  testWidgets('REQ036_AC12 édition de case en 640x360, échelle 1', (
    tester,
  ) async {
    _regler(tester);
    final etat = await etatPret(tester);
    await tester.pumpWidget(GlypheApp(etat: etat));
    etat.ouvrirEdition();
    await tester.pumpAndSettle();
    await _ouvrirCaseExistante(tester, etat);

    final titre = find.descendant(
      of: find.byType(TitreBarre),
      matching: find.byType(RichText),
    );
    final rp = tester.renderObject<RenderParagraph>(titre);
    expect(rp.didExceedMaxLines, isFalse);
    expect(rp.text.toPlainText(), Textes.editionCase);
    final supprimer = tester.getRect(find.byKey(const Key('bouton-supprimer')));
    expect(
      tester.getRect(find.byType(TitreBarre)).right,
      lessThanOrEqualTo(supprimer.left),
    );
    const actions = [
      'bouton-supprimer',
      'bouton-echanger',
      'bouton-ouvrir',
      'bouton-enregistrer',
    ];
    for (final cle in actions) {
      final r = tester.getRect(find.byKey(Key(cle)));
      expect(r.top, greaterThanOrEqualTo(0), reason: cle);
      expect(r.bottom, lessThanOrEqualTo(56), reason: cle);
    }

    final defilant = find
        .descendant(
          of: find.byType(Scaffold).last,
          matching: find.byWidgetPredicate(
            (w) => w is Scrollable && w.axis == Axis.vertical,
          ),
        )
        .first;
    final position = tester.state<ScrollableState>(defilant).position;
    expect(position.pixels, 0);
    for (final cle in const ['bouton-image', 'champ-libelle']) {
      final r = tester.getRect(find.byKey(Key(cle)));
      expect(r.top, greaterThanOrEqualTo(56), reason: cle);
      expect(r.bottom, lessThanOrEqualTo(360), reason: cle);
    }

    final cible = find.byKey(const Key('champ-cible'));
    expect(tester.getRect(cible).bottom, greaterThan(360));
    final barre = tester.getRect(find.byType(AppBar));
    final enr = tester.getRect(find.byKey(const Key('bouton-enregistrer')));
    await tester.scrollUntilVisible(cible, 80, scrollable: defilant);
    await tester.pumpAndSettle();
    final rc = tester.getRect(cible);
    expect(rc.top, greaterThanOrEqualTo(56));
    expect(rc.bottom, lessThanOrEqualTo(360));
    expect(position.pixels, greaterThan(0));
    expect(tester.getRect(find.byType(AppBar)), barre);
    expect(barre, const Rect.fromLTWH(0, 0, 640, 56));
    expect(tester.getRect(find.byKey(const Key('bouton-enregistrer'))), enr);
    expect(tester.takeException(), isNull);
  });

  testWidgets('REQ028_AC5 échelle 2 en 640x360 : écrans sans débordement', (
    tester,
  ) async {
    _regler(tester, echelle: 2);
    await _parcours(tester);
  });

  testWidgets('REQ028_AC5 titre long : une ligne terminée par une ellipse', (
    tester,
  ) async {
    _regler(tester, echelle: 2);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: TitreBarre('Titre très long ' * 12)),
        ),
      ),
    );
    final texte = tester.widget<Text>(
      find.descendant(of: find.byType(TitreBarre), matching: find.byType(Text)),
    );
    expect(texte.maxLines, 1);
    expect(texte.overflow, TextOverflow.ellipsis);
    final rp = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byType(TitreBarre),
        matching: find.byType(RichText),
      ),
    );
    expect(rp.didExceedMaxLines, isTrue);
    expect(tester.getSize(find.byType(AppBar)).height, 56);
    expect(tester.takeException(), isNull);
  });

  testWidgets('REQ038_AC5 sélecteur : Photo et Galerie fixes sous la liste', (
    tester,
  ) async {
    _regler(tester, echelle: 2);
    final etat = await etatPret(tester);
    await tester.pumpWidget(MaterialApp(home: SelecteurImage(etat: etat)));
    await tester.enterText(find.byKey(const Key('champ-recherche')), 'a');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final cle in const ['bouton-prendre-photo', 'bouton-galerie']) {
      final r = tester.getRect(find.byKey(Key(cle)));
      expect(r.bottom, lessThanOrEqualTo(360), reason: cle);
      expect(r.top, greaterThanOrEqualTo(56), reason: cle);
    }
  });

  testWidgets('REQ028_AC5 barre de l\'édition de case à l\'échelle 2', (
    tester,
  ) async {
    _regler(tester, echelle: 2);
    final etat = await etatPret(tester);
    await tester.pumpWidget(GlypheApp(etat: etat));
    etat.ouvrirEdition();
    await tester.pumpAndSettle();
    await _ouvrirCaseExistante(tester, etat);
    expect(tester.getSize(find.byType(AppBar)).height, 56);
    for (final cle in const [
      'bouton-retour-appli',
      'bouton-supprimer',
      'bouton-echanger',
      'bouton-ouvrir',
      'bouton-enregistrer',
    ]) {
      expect(find.byKey(Key(cle)), findsOneWidget, reason: cle);
    }
    final titre = find.descendant(
      of: find.byType(TitreBarre),
      matching: find.byType(RichText),
    );
    final scaler = tester.widget<RichText>(titre.first).textScaler.scale(10);
    expect(scaler, lessThanOrEqualTo(15));
    expect(tester.takeException(), isNull);
  });

  for (final edition in const [false, true]) {
    testWidgets('REQ028_AC5 cases et barres identiques à l\'échelle 2 et 1 '
        '(${edition ? 'édition' : 'communication'})', (tester) async {
      Future<Map<String, Rect>> rectangles(double echelle) async {
        _regler(tester, echelle: echelle);
        final etat = await etatPret(tester);
        await tester.pumpWidget(GlypheApp(etat: etat));
        if (edition) etat.ouvrirEdition();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final r = <String, Rect>{};
        for (final e in find.byWidgetPredicate((w) {
          final k = w.key;
          return k is ValueKey<String> && k.value.startsWith('case-');
        }).evaluate()) {
          r[(e.widget.key! as ValueKey<String>).value] = tester.getRect(
            find.byWidget(e.widget),
          );
        }
        expect(r, isNotEmpty);
        if (edition) {
          r['barre-edition'] = tester.getRect(find.byType(BarreEdition));
        } else {
          r['barre-phrase'] = tester.getRect(find.byType(BarrePhrase));
        }
        return r;
      }

      final deux = await rectangles(2);
      final un = await rectangles(1);
      expect(deux, un);
    });
  }
}
