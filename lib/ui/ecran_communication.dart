import 'package:flutter/material.dart';

import '../domaine/modeles.dart';
import '../domaine/session.dart';
import 'dialogue_code.dart';
import 'ecran_code.dart';
import 'dialogue_taille.dart';
import 'ecran_edition_case.dart';
import 'ecran_grilles.dart';
import 'ecran_reglages.dart';
import 'etat_appli.dart';
import 'textes.dart';
import 'widgets/barre_phrase.dart';
import 'widgets/cadenas.dart';
import 'widgets/case_widget.dart';

/// Écran principal : barre de phrase, commandes, grille courante.
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
      onPause: etat.verrouiller,
      onHide: etat.verrouiller,
      onDetach: etat.verrouiller,
      // Retour au premier plan : la voix a pu être (dés)installée (AC-022-1).
      onResume: etat.verifierVoix,
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
          child: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final barre = BarrePhrase(
                      elements: session.barre,
                      onLire: session.lireBarre,
                    );
                    final commandes = _Commandes(
                      session: session,
                      modeEdition: etat.modeEdition,
                      onDeverrouille: _deverrouiller,
                      onTerminer: etat.verrouiller,
                      onCode: _ouvrirEcranCode,
                      onAjouter: _ajouter,
                      onGrilles: _ouvrirGrilles,
                      onTaille: _regler,
                      onReglages: _ouvrirReglages,
                    );
                    // Paysage peu haut : barre et commandes côte à côte pour
                    // laisser assez de hauteur aux cases (>= 48 dp).
                    final compact =
                        c.maxHeight < 480 && c.maxWidth > c.maxHeight;
                    return Column(
                      children: [
                        if (compact)
                          Row(
                            children: [
                              Expanded(child: barre),
                              const SizedBox(width: 6),
                              if (etat.modeEdition)
                                SizedBox(
                                  width: c.maxWidth * 0.7,
                                  child: commandes,
                                )
                              else
                                commandes,
                            ],
                          )
                        else ...[
                          barre,
                          const SizedBox(height: 6),
                          commandes,
                        ],
                        const SizedBox(height: 6),
                        Expanded(
                          child: _GrilleWidget(
                            session: session,
                            modeEdition: etat.modeEdition,
                            onEditer: _editer,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Commandes extends StatelessWidget {
  const _Commandes({
    required this.session,
    required this.modeEdition,
    required this.onDeverrouille,
    required this.onTerminer,
    required this.onCode,
    required this.onAjouter,
    required this.onGrilles,
    required this.onTaille,
    required this.onReglages,
  });

  final Session session;
  final bool modeEdition;
  final VoidCallback onDeverrouille;
  final VoidCallback onTerminer;
  final VoidCallback onCode;
  final VoidCallback onAjouter;
  final VoidCallback onGrilles;
  final VoidCallback onTaille;
  final VoidCallback onReglages;

  static final ButtonStyle _styleTexte = TextButton.styleFrom(
    minimumSize: const Size(56, 56),
    padding: const EdgeInsets.symmetric(horizontal: 8),
  );

  Widget _bouton(String nom, IconData icone, VoidCallback onPressed) =>
      IconButton.filledTonal(
        tooltip: nom,
        icon: Icon(icone),
        onPressed: onPressed,
        constraints: const BoxConstraints.tightFor(width: 56, height: 56),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          minimumSize: const Size(56, 56),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final principale = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _bouton(Textes.lire, Icons.volume_up, session.lireBarre),
        _bouton(
          Textes.effacerDernier,
          Icons.backspace_outlined,
          session.effacerDernier,
        ),
        _bouton(Textes.toutEffacer, Icons.delete_outline, session.toutEffacer),
        _bouton(Textes.retour, Icons.arrow_back, session.retour),
        _bouton(Textes.accueil, Icons.home, session.accueil),
        if (!modeEdition) Cadenas(onDeverrouille: onDeverrouille),
      ],
    );
    // Actions d'édition : rendues uniquement en mode édition (AC-011-4).
    if (!modeEdition) return principale;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        principale,
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: onTerminer,
              style: _styleTexte,
              child: const Text(Textes.terminer),
            ),
            TextButton(
              key: const Key('ajouter-case'),
              onPressed: onAjouter,
              style: _styleTexte,
              child: const Text(Textes.ajouterCase),
            ),
            PopupMenuButton<VoidCallback>(
              key: const Key('bouton-plus'),
              tooltip: Textes.plus,
              icon: const Icon(Icons.more_vert),
              iconSize: 28,
              style: IconButton.styleFrom(minimumSize: const Size(56, 56)),
              onSelected: (action) => action(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  key: const Key('bouton-code'),
                  value: onCode,
                  child: const Text(Textes.codeVerrouillage),
                ),
                PopupMenuItem(
                  key: const Key('bouton-grilles'),
                  value: onGrilles,
                  child: const Text(Textes.grilles),
                ),
                PopupMenuItem(
                  key: const Key('bouton-taille'),
                  value: onTaille,
                  child: const Text(Textes.tailleGrille),
                ),
                PopupMenuItem(
                  key: const Key('bouton-reglages'),
                  value: onReglages,
                  child: const Text(Textes.reglages),
                ),
              ],
            ),
          ],
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
                    child: _cellule(grille, l, col, parPosition[(l, col)]),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cellule(Grille grille, int l, int col, Case? c) {
    if (c == null) {
      if (!modeEdition) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.all(3),
        child: Semantics(
          button: true,
          label: Textes.ajouterCase,
          excludeSemantics: true,
          child: InkWell(
            key: Key('vide-$l-$col'),
            onTap: () => onEditer(grille, ligne: l, colonne: col),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black38),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(child: Icon(Icons.add)),
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
