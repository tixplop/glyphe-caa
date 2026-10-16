import 'dart:math' as math;

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
import 'widgets/barre_phrase.dart';
import 'widgets/case_widget.dart';

/// Écran principal : barre de phrase (ou d'édition), puis grille.
class EcranCommunication extends StatefulWidget {
  const EcranCommunication({super.key, required this.etat});

  final EtatAppli etat;

  @override
  State<EcranCommunication> createState() => _EcranCommunicationState();
}

class _EcranCommunicationState extends State<EcranCommunication> {
  late final AppLifecycleListener _cycleDeVie;
  late bool _etaitVerrouille;
  final FocusNode _focusAccueil = FocusNode(debugLabel: 'accueil');

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
    _focusAccueil.dispose();
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
              // Cet écran n'a aucun champ de saisie : il ignore le clavier
              // pour que la grille ne s'écrase pas au retour de l'édition
              // clavier ouvert (AC-038-8, DEC-019).
              resizeToAvoidBottomInset: false,
              body: Builder(
                builder: (context) {
                  // Marges de sécurité symétriques : max(gauche, droite)
                  // des deux côtés, haut et bas tels quels (AC-038-6).
                  final sur = MediaQuery.paddingOf(context);
                  final cote = math.max(sur.left, sur.right);
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      cote,
                      sur.top + GlypheTokens.espace2,
                      cote,
                      sur.bottom,
                    ),
                    child: LayoutBuilder(builder: _disposition),
                  );
                },
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
    final barre = etat.modeEdition
        ? BarreEdition(
            nomGrille: session.grilleCourante.nom,
            onAccueil: session.accueil,
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
            onAccueil: session.accueil,
            focusAccueil: _focusAccueil,
            onDeverrouille: _deverrouiller,
          );
    final barres = Padding(
      padding: const EdgeInsets.symmetric(horizontal: _marge),
      child: barre,
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
              focusAccueil: _focusAccueil,
            ),
          ),
        ),
      ],
    );
  }
}

class _GrilleWidget extends StatefulWidget {
  const _GrilleWidget({
    required this.session,
    required this.modeEdition,
    required this.onEditer,
    required this.focusAccueil,
  });

  final Session session;
  final bool modeEdition;
  final Future<void> Function(Grille, {Case? c, int? ligne, int? colonne})
  onEditer;
  final FocusNode focusAccueil;

  /// Marge totale autour de chaque case : 3 propres à la case + 1 ajouté ici,
  /// soit une gouttière de 8 entre deux cases (AC-030-1).
  static const double margeCase = 4;

  @override
  State<_GrilleWidget> createState() => _GrilleWidgetState();
}

class _GrilleWidgetState extends State<_GrilleWidget> {
  final FocusNode _premiere = FocusNode(debugLabel: 'premiere-case');
  late String _grilleId;

  @override
  void initState() {
    super.initState();
    _grilleId = widget.session.grilleCourante.id;
  }

  Session get session => widget.session;
  bool get modeEdition => widget.modeEdition;
  static const double margeCase = _GrilleWidget.margeCase;

  @override
  void dispose() {
    _premiere.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_GrilleWidget ancien) {
    super.didUpdateWidget(ancien);
    final id = session.grilleCourante.id;
    if (id == _grilleId) return;
    _grilleId = id;
    // Le focus était sur une case de la grille qui disparaît : il suit la
    // navigation (AC-009-9). Ailleurs (ex. Accueil), il ne bouge pas.
    final ctx = FocusManager.instance.primaryFocus?.context;
    final surCase =
        ctx != null &&
        ctx.findAncestorStateOfType<_GrilleWidgetState>() == this &&
        ctx.findAncestorWidgetOfExactType<CaseWidget>() != null;
    if (!surCase || modeEdition) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_premiereCase(session.grilleCourante) != null) {
        _premiere.requestFocus();
      } else {
        widget.focusAccueil.requestFocus();
      }
    });
  }

  /// Première case visible dans l'ordre de lecture.
  Case? _premiereCase(Grille g) {
    Case? p;
    for (final c in g.casesVisibles) {
      if (p == null ||
          c.ligne < p.ligne ||
          (c.ligne == p.ligne && c.colonne < p.colonne)) {
        p = c;
      }
    }
    return p;
  }

  @override
  Widget build(BuildContext context) {
    final grille = session.grilleCourante;
    final premiere = _premiereCase(grille);
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
                        premiere,
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
    Case? premiere,
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
          onTap: () => widget.onEditer(grille, ligne: l, colonne: col),
          child: InkWell(
            key: Key('vide-$l-$col'),
            borderRadius: BorderRadius.circular(GlypheTokens.rayonMd),
            onTap: () => widget.onEditer(grille, ligne: l, colonne: col),
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
      focusNode: identical(c, premiere) ? _premiere : null,
      onTap: () =>
          modeEdition ? widget.onEditer(grille, c: c) : session.appuyerCase(c),
    );
  }
}
