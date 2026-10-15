import 'package:flutter/material.dart';

import '../domaine/modeles.dart';
import '../domaine/session.dart';
import 'dialogue_code.dart';
import 'ecran_a_propos.dart';
import 'ecran_code.dart';
import 'dialogue_taille.dart';
import 'ecran_edition_case.dart';
import 'ecran_grilles.dart';
import 'ecran_reglages.dart';
import 'etat_appli.dart';
import 'textes.dart';
import 'tokens.dart';
import 'widgets/barre_edition.dart';
import 'widgets/barre_navigation.dart';
import 'widgets/barre_phrase.dart';
import 'widgets/case_widget.dart';

/// Écran principal : barre de phrase (ou d'édition), navigation, grille.
class EcranCommunication extends StatefulWidget {
  const EcranCommunication({super.key, required this.etat});

  final EtatAppli etat;

  @override
  State<EcranCommunication> createState() => _EcranCommunicationState();
}

class _EcranCommunicationState extends State<EcranCommunication> {
  late final AppLifecycleListener _cycleDeVie;
  late bool _etaitVerrouille;

  EtatAppli get etat => widget.etat;

  @override
  void initState() {
    super.initState();
    // Arrière-plan ou fermeture : reverrouillage (AC-014-2).
    _etaitVerrouille = etat.verrouille;
    etat.addListener(_surChangement);
    _cycleDeVie = AppLifecycleListener(
      onPause: etat.verrouillerSurCycleDeVie,
      onHide: etat.verrouillerSurCycleDeVie,
      onDetach: etat.verrouillerSurCycleDeVie,
      // Retour au premier plan : la voix a pu être (dés)installée (AC-022-1).
      onResume: etat.surRetourPremierPlan,
    );
  }

  @override
  void dispose() {
    etat.removeListener(_surChangement);
    _cycleDeVie.dispose();
    super.dispose();
  }

  /// Au reverrouillage, referme tout écran ou dialogue d'édition poussé
  /// au-dessus de l'écran de communication (AC-014-2, AC-011-4).
  /// Seule la transition déverrouillé -> verrouillé ferme les routes.
  void _surChangement() {
    final passeAuVerrou = etat.verrouille && !_etaitVerrouille;
    _etaitVerrouille = etat.verrouille;
    if (!passeAuVerrou || !mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _editer(Grille grille, {Case? c, int? ligne, int? colonne}) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EcranEditionCase(
            etat: etat,
            grilleId: grille.id,
            caseExistante: c,
            ligne: ligne,
            colonne: colonne,
          ),
        ),
      );

  /// Ajoute une case au premier emplacement libre, sinon invite à agrandir
  /// la grille (AC-015-1).
  Future<void> _ajouter() async {
    final grille = etat.session.grilleCourante;
    final libre = grille.emplacementLibre();
    if (libre == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(Textes.erreurGrillePleine)),
        );
      return;
    }
    await _editer(grille, ligne: libre.ligne, colonne: libre.colonne);
  }

  Future<void> _ouvrirGrilles() => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => EcranGrilles(etat: etat)));

  Future<void> _ouvrirReglages() => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => EcranReglages(etat: etat)));

  Future<void> _ouvrirAPropos() =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const EcranAPropos()));

  Future<void> _regler() => reglerTaille(context, etat);

  Future<void> _deverrouiller() async {
    if (!etat.verrou.aCode) {
      etat.ouvrirEdition();
      return;
    }
    final ok = await demanderCode(context, etat.verrou, etat.aleatoire);
    if (ok) etat.ouvrirEdition();
  }

  Future<void> _ouvrirEcranCode() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => EcranCode(verrou: etat.verrou)),
  );

  @override
  Widget build(BuildContext context) {
    final session = etat.session;
    return ListenableBuilder(
      listenable: Listenable.merge([session, etat]),
      builder: (context, _) {
        final surAccueil =
            session.grilleCourante.id == session.donnees.accueilId;
        return PopScope(
          canPop: surAccueil,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) session.retour();
          },
          // La disposition de communication ignore l'échelle de texte du
          // système (AC-035-4).
          child: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.noScaling),
            child: Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: GlypheTokens.espace2),
                  child: LayoutBuilder(builder: _disposition),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Marge latérale de l'écran (AC-030-1).
  static const double _marge = GlypheTokens.espace3;

  Widget _disposition(BuildContext context, BoxConstraints c) {
    final session = etat.session;
    final haut = etat.modeEdition
        ? BarreEdition(
            nomGrille: session.grilleCourante.nom,
            onTerminer: etat.verrouiller,
            onAjouter: _ajouter,
            onCode: _ouvrirEcranCode,
            onGrilles: _ouvrirGrilles,
            onTaille: _regler,
            onReglages: _ouvrirReglages,
            onAPropos: _ouvrirAPropos,
          )
        : BarrePhrase(
            elements: session.barre,
            enLecture: session.enLecture,
            onLire: session.lireBarre,
            onArreter: session.arreterLecture,
            onEffacerDernier: session.effacerDernier,
            onToutEffacer: session.toutEffacer,
          );
    final navigation = BarreNavigation(
      session: session,
      modeEdition: etat.modeEdition,
      onDeverrouille: _deverrouiller,
    );
    // Paysage peu haut : les deux barres sur une seule rangée de 72
    // (AC-030-3).
    final compact = c.maxHeight < 480 && c.maxWidth > c.maxHeight;
    final barres = Padding(
      padding: const EdgeInsets.symmetric(horizontal: _marge),
      child: compact
          ? SizedBox(
              height: GlypheTokens.barrePhrase,
              child: Row(
                children: [
                  Expanded(flex: 55, child: haut),
                  const SizedBox(width: GlypheTokens.espace2),
                  Expanded(flex: 45, child: Center(child: navigation)),
                ],
              ),
            )
          : Column(
              children: [
                haut,
                const SizedBox(height: GlypheTokens.espace2),
                navigation,
              ],
            ),
    );
    return Column(
      children: [
        barres,
        // Les cases portent déjà 4 dp de marge propre : on retire cette part
        // pour obtenir marges de 12 et gouttière de 8 (AC-030-1).
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _marge - _GrilleWidget.margeCase,
              GlypheTokens.espace2 - _GrilleWidget.margeCase,
              _marge - _GrilleWidget.margeCase,
              _marge - _GrilleWidget.margeCase,
            ),
            child: _GrilleWidget(
              session: session,
              modeEdition: etat.modeEdition,
              onEditer: _editer,
            ),
          ),
        ),
      ],
    );
  }
}

class _GrilleWidget extends StatelessWidget {
  const _GrilleWidget({
    required this.session,
    required this.modeEdition,
    required this.onEditer,
  });

  final Session session;
  final bool modeEdition;
  final Future<void> Function(Grille, {Case? c, int? ligne, int? colonne})
  onEditer;

  /// Marge totale autour de chaque case : 3 propres à la case + 1 ajouté ici,
  /// soit une gouttière de 8 entre deux cases (AC-030-1).
  static const double margeCase = 4;

  @override
  Widget build(BuildContext context) {
    final grille = session.grilleCourante;
    final parPosition = {
      for (final c in grille.casesVisibles) (c.ligne, c.colonne): c,
    };
    return Column(
      key: const Key('grille'),
      children: [
        for (var l = 0; l < grille.lignes; l++)
          Expanded(
            child: Row(
              children: [
                for (var col = 0; col < grille.colonnes; col++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(margeCase - 3),
                      child: _cellule(
                        context,
                        grille,
                        l,
                        col,
                        parPosition[(l, col)],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cellule(
    BuildContext context,
    Grille grille,
    int l,
    int col,
    Case? c,
  ) {
    if (c == null) {
      if (!modeEdition) return const SizedBox.shrink();
      final t = GlypheTokens.of(context);
      return Padding(
        padding: const EdgeInsets.all(3),
        child: Semantics(
          button: true,
          label: Textes.ajouterCase,
          excludeSemantics: true,
          onTap: () => onEditer(grille, ligne: l, colonne: col),
          child: InkWell(
            key: Key('vide-$l-$col'),
            borderRadius: BorderRadius.circular(GlypheTokens.rayonMd),
            onTap: () => onEditer(grille, ligne: l, colonne: col),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: t.border),
                borderRadius: BorderRadius.circular(GlypheTokens.rayonMd),
              ),
              child: Center(child: Icon(Icons.add, color: t.ink)),
            ),
          ),
        ),
      );
    }
    final orphelin =
        modeEdition &&
        c.type == TypeCase.dossier &&
        (c.cibleId == null || session.donnees.grillePar(c.cibleId!) == null);
    return CaseWidget(
      key: Key('case-${c.id}'),
      caseData: c,
      orphelin: orphelin,
      onTap: () =>
          modeEdition ? onEditer(grille, c: c) : session.appuyerCase(c),
    );
  }
}
