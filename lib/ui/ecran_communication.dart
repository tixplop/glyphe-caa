import 'package:flutter/material.dart';

import '../domaine/modeles.dart';
import '../domaine/session.dart';
import 'etat_appli.dart';
import 'textes.dart';
import 'widgets/barre_phrase.dart';
import 'widgets/case_widget.dart';

/// Écran principal : barre de phrase, commandes, grille courante.
class EcranCommunication extends StatelessWidget {
  const EcranCommunication({super.key, required this.etat});

  final EtatAppli etat;

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
                      verrouille: etat.verrouille,
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
                              commandes,
                            ],
                          )
                        else ...[
                          barre,
                          const SizedBox(height: 6),
                          commandes,
                        ],
                        const SizedBox(height: 6),
                        Expanded(child: _GrilleWidget(session: session)),
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
  const _Commandes({required this.session, required this.verrouille});

  final Session session;
  final bool verrouille;

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
    return Row(
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
        // Place réservée au cadenas (T-008).
        SizedBox(
          width: 56,
          height: 56,
          child: Semantics(
            label: verrouille ? Textes.verrouille : null,
            child: Icon(verrouille ? Icons.lock : Icons.lock_open),
          ),
        ),
      ],
    );
  }
}

class _GrilleWidget extends StatelessWidget {
  const _GrilleWidget({required this.session});

  final Session session;

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
                  Expanded(child: _cellule(parPosition[(l, col)])),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cellule(Case? c) {
    if (c == null) return const SizedBox.shrink();
    return CaseWidget(
      key: Key('case-${c.id}'),
      caseData: c,
      onTap: () => session.appuyerCase(c),
    );
  }
}
