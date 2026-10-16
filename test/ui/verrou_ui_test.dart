import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/modeles.dart';
import 'package:glyphe/ui/app.dart';
import 'package:glyphe/ui/etat_appli.dart';

import '../faux/faux_stockage.dart';
import '../faux/faux_voix.dart';
import '../faux/fausse_horloge.dart';

const phrase = 'Le chat dort sur le canapé';

Donnees donnees() => Donnees(
  accueilId: 'acc',
  grilles: [
    Grille(
      id: 'acc',
      nom: 'Accueil',
      lignes: 2,
      colonnes: 2,
      cases: [
        Case(
          id: 'je',
          ligne: 0,
          colonne: 0,
          type: TypeCase.mot,
          libelle: 'je',
          image: ImageArasaac(2617),
        ),
      ],
    ),
  ],
);

EtatAppli creer(FauxStockage s) => EtatAppli(
  stockage: s,
  voix: FauxVoix(),
  horloge: FausseHorloge(),
  jsonExemples: '{}',
  jsonPhrases: '["$phrase"]',
);

Future<EtatAppli> lance(WidgetTester tester, {String? code}) async {
  tester.view.physicalSize = const Size(640, 360);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final s = FauxStockage(donnees())..code = code;
  final etat = creer(s);
  await etat.init();
  await tester.pumpWidget(GlypheApp(etat: etat));
  await tester.pumpAndSettle();
  return etat;
}

final cadenas = find.byKey(const Key('cadenas'));

/// Appui long sur le cadenas pendant [duree], puis relâchement.
Future<void> appui(WidgetTester tester, Duration duree) async {
  final g = await tester.startGesture(tester.getCenter(cadenas));
  await tester.pump(duree);
  await g.up();
  await tester.pump();
}

/// Retour au premier plan par la séquence de transitions valide.
void reprendre(WidgetTester tester, AppLifecycleState depuis) {
  final b = tester.binding;
  if (depuis == AppLifecycleState.paused) {
    b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  }
  b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  b.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

void main() {
  testWidgets('REQ011_AC1 appui court : reste verrouillé', (tester) async {
    final etat = await lance(tester);
    await appui(tester, const Duration(milliseconds: 2900));
    await tester.pumpAndSettle();
    expect(etat.verrouille, isTrue);
    expect(find.byKey(const Key('bouton-terminer')), findsNothing);
  });

  testWidgets('REQ011_AC1 simple tap : rien ne se passe', (tester) async {
    final etat = await lance(tester);
    await tester.tap(cadenas);
    await tester.pumpAndSettle();
    expect(etat.verrouille, isTrue);
  });

  testWidgets('REQ011_AC2 3 s sans code : mode édition', (tester) async {
    final etat = await lance(tester);
    final g = await tester.startGesture(tester.getCenter(cadenas));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    expect(etat.verrouille, isFalse);
    expect(etat.modeEdition, isTrue);
    expect(find.byKey(const Key('bouton-terminer')), findsOneWidget);
  });

  testWidgets('REQ011_AC3 progression visible, annulée au relâchement', (
    tester,
  ) async {
    await lance(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final g = await tester.startGesture(tester.getCenter(cadenas));
    await tester.pump(); // premier cycle : le ticker démarre
    await tester.pump(const Duration(milliseconds: 1500));
    final p = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(p.value, closeTo(0.5, 0.05));
    await g.up();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // Un nouvel appui court ne cumule pas avec le précédent.
    await appui(tester, const Duration(milliseconds: 2000));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bouton-terminer')), findsNothing);
  });

  testWidgets('REQ011_AC4 mode communication : aucune action d\'édition', (
    tester,
  ) async {
    await lance(tester);
    expect(find.byKey(const Key('bouton-terminer')), findsNothing);
    expect(find.byTooltip('Code de verrouillage'), findsNothing);
    expect(find.byIcon(Icons.settings), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.byIcon(Icons.edit), findsNothing);
  });

  testWidgets('REQ012_AC2 code défini : le code est demandé, bon code', (
    tester,
  ) async {
    final etat = await lance(tester, code: '1234');
    await appui(tester, const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(etat.verrouille, isTrue);
    expect(find.byKey(const Key('champ-code')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('champ-code')), '1234');
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(etat.modeEdition, isTrue);
    expect(find.byKey(const Key('champ-code')), findsNothing);
  });

  testWidgets('REQ012_AC3 mauvais code : message, reste verrouillé', (
    tester,
  ) async {
    final etat = await lance(tester, code: '1234');
    await appui(tester, const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('champ-code')), '9999');
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(find.text('Code incorrect'), findsOneWidget);
    expect(etat.verrouille, isTrue);
  });

  testWidgets('REQ012_AC4 code persistant après recréation de l\'état', (
    tester,
  ) async {
    final s = FauxStockage(donnees());
    final e1 = creer(s);
    await e1.init();
    await e1.verrou.definirCode('1234', '1234');
    final e2 = creer(s);
    await e2.init();
    expect(e2.verrou.aCode, isTrue);
    expect(e2.verrou.verifier('1234'), isTrue);
  });

  testWidgets('REQ013_AC1 le dialogue propose Code oublié', (tester) async {
    await lance(tester, code: '1234');
    await appui(tester, const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Code oublié'), findsOneWidget);
  });

  testWidgets('REQ013_AC2 Code oublié affiche une phrase à recopier', (
    tester,
  ) async {
    await lance(tester, code: '1234');
    await appui(tester, const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Code oublié'));
    await tester.pumpAndSettle();
    expect(find.text(phrase), findsOneWidget);
    expect(find.byKey(const Key('champ-phrase')), findsOneWidget);
  });

  testWidgets('REQ013_AC3 recopie correcte : code supprimé, édition', (
    tester,
  ) async {
    final etat = await lance(tester, code: '1234');
    await appui(tester, const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Code oublié'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('champ-phrase')),
      '  LE chat   dort sur le canapé ',
    );
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(etat.modeEdition, isTrue);
    expect(etat.verrou.aCode, isFalse);
    expect(etat.session.donnees.grilles.length, 1);
    // Ensuite, l'appui long seul déverrouille.
    await tester.tap(find.byKey(const Key('bouton-terminer')));
    await tester.pumpAndSettle();
    expect(etat.verrouille, isTrue);
    await appui(tester, const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(etat.modeEdition, isTrue);
  });

  testWidgets('REQ013_AC4 recopie incorrecte : code conservé, message', (
    tester,
  ) async {
    final etat = await lance(tester, code: '1234');
    await appui(tester, const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Code oublié'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('champ-phrase')),
      'le chat dort sur le canape',
    );
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(find.text('Phrase incorrecte'), findsOneWidget);
    expect(etat.verrouille, isTrue);
    expect(etat.verrou.aCode, isTrue);
  });

  testWidgets('REQ014_AC1 Terminer : retour en communication verrouillé', (
    tester,
  ) async {
    final etat = await lance(tester);
    await appui(tester, const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bouton-terminer')));
    await tester.pumpAndSettle();
    expect(etat.verrouille, isTrue);
    expect(find.byKey(const Key('bouton-terminer')), findsNothing);
  });

  for (final etatCycle in [
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.detached,
  ]) {
    testWidgets('REQ014_AC2 $etatCycle reverrouille', (tester) async {
      final etat = await lance(tester);
      await appui(tester, const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(etat.modeEdition, isTrue);
      tester.binding.handleAppLifecycleStateChanged(etatCycle);
      await tester.pumpAndSettle();
      expect(etat.verrouille, isTrue);
      if (etatCycle != AppLifecycleState.detached) {
        // Les frames sont suspendues en arrière-plan : on vérifie au retour.
        reprendre(tester, etatCycle);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('bouton-terminer')), findsNothing);
        expect(cadenas, findsOneWidget);
      }
    });
  }

  testWidgets('REQ014_AC3 après reverrouillage, code exigé de nouveau', (
    tester,
  ) async {
    final etat = await lance(tester, code: '1234');
    await appui(tester, const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('champ-code')), '1234');
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    reprendre(tester, AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(etat.verrouille, isTrue);
    await appui(tester, const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('champ-code')), findsOneWidget);
    expect(etat.verrouille, isTrue);
  });

  testWidgets('REQ014_AC2 reverrouillage ferme les écrans d\'édition', (
    tester,
  ) async {
    final etat = await lance(tester);
    await appui(tester, const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bouton-plus')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bouton-code')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('champ-nouveau')), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    reprendre(tester, AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(etat.verrouille, isTrue);
    expect(find.byKey(const Key('champ-nouveau')), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsWidgets);
  });

  testWidgets('REQ014_AC2 menu Plus ouvert puis paused : reverrouillé', (
    tester,
  ) async {
    final etat = await lance(tester);
    await appui(tester, const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bouton-plus')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bouton-code')), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    reprendre(tester, AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bouton-code')), findsNothing);
    expect(etat.verrouille, isTrue);
    expect(find.byKey(const Key('bouton-terminer')), findsNothing);
  });

  testWidgets('REQ012_AC1 écran code : définir, refus, supprimer', (
    tester,
  ) async {
    final etat = await lance(tester);
    await appui(tester, const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bouton-plus')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bouton-code')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('champ-nouveau')), '12');
    await tester.enterText(find.byKey(const Key('champ-confirmation')), '12');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Le code doit comporter 4 chiffres'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('champ-nouveau')), '1234');
    await tester.enterText(find.byKey(const Key('champ-confirmation')), '1235');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Les deux saisies sont différentes'), findsOneWidget);
    expect(etat.verrou.aCode, isFalse);
    await tester.enterText(find.byKey(const Key('champ-confirmation')), '1234');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(etat.verrou.aCode, isTrue);
    await tester.tap(find.byKey(const Key('bouton-plus')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bouton-code')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer le code'));
    await tester.pumpAndSettle();
    expect(etat.verrou.aCode, isFalse);
  });
}
