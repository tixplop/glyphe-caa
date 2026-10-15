import 'package:flutter/material.dart';

import '../../domaine/onglets.dart';
import '../../domaine/session.dart';
import '../textes.dart';
import '../tokens.dart';
import 'cadenas.dart';

/// Barre de navigation (REQ-031) : Retour, onglets de catégorie qui
/// défilent, cadenas (communication) ou espace de même largeur (édition).
class BarreNavigation extends StatelessWidget {
  const BarreNavigation({
    super.key,
    required this.session,
    required this.modeEdition,
    required this.onDeverrouille,
  });

  final Session session;
  final bool modeEdition;
  final VoidCallback onDeverrouille;

  static const double _touche = GlypheTokens.toucheMin;

  Widget _retour(GlypheTokens t, bool surAccueil) => Semantics(
    button: true,
    label: Textes.retour,
    excludeSemantics: true,
    onTap: surAccueil ? null : session.retour,
    child: Opacity(
      key: const Key('bouton-retour'),
      opacity: surAccueil ? 0.4 : 1,
      child: Tooltip(
        message: Textes.retour,
        child: InkWell(
          borderRadius: BorderRadius.circular(GlypheTokens.rayonPilule),
          onTap: surAccueil ? null : session.retour,
          child: SizedBox(
            width: _touche,
            height: _touche,
            child: Icon(Icons.arrow_back, color: t.ink, size: 28),
          ),
        ),
      ),
    ),
  );

  Widget _onglet(GlypheTokens t, Onglet o, bool actif) {
    final encre = actif ? t.onPrimary : t.ink;
    final forme = StadiumBorder(
      side: actif ? BorderSide.none : BorderSide(color: t.border, width: 2),
    );
    void ouvrir() =>
        o.estAccueil ? session.accueil() : session.ouvrirGrille(o.grilleId);
    return Semantics(
      button: true,
      selected: actif,
      label: o.libelle,
      excludeSemantics: true,
      onTap: ouvrir,
      child: Material(
        key: Key('onglet-${o.grilleId}'),
        color: actif ? t.primary : t.surface000,
        shape: forme,
        child: InkWell(
          customBorder: forme,
          onTap: ouvrir,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _touche),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (o.estAccueil) ...[
                    Icon(Icons.home, size: 20, color: encre),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    o.libelle,
                    maxLines: 1,
                    textScaler: TextScaler.noScaling,
                    style: GlypheTokens.body.copyWith(
                      color: encre,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = GlypheTokens.of(context);
    final donnees = session.donnees;
    final onglets = ongletsDe(donnees);
    final actif = ongletActif(donnees, session.chemin);
    final surAccueil = session.grilleCourante.id == donnees.accueilId;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surface200,
        borderRadius: BorderRadius.circular(GlypheTokens.rayonLg),
        boxShadow: t.ombreBarre,
      ),
      child: SizedBox(
        height: GlypheTokens.barreAppli,
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              _retour(t, surAccueil),
              const SizedBox(width: 4),
              Expanded(
                child: Center(
                  child: SizedBox(
                    height: _touche,
                    child: ListView.separated(
                      key: const Key('onglets'),
                      scrollDirection: Axis.horizontal,
                      itemCount: onglets.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) =>
                          _onglet(t, onglets[i], onglets[i].grilleId == actif),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              if (modeEdition)
                const SizedBox(key: Key('espace-cadenas'), width: _touche)
              else
                Cadenas(onDeverrouille: onDeverrouille),
            ],
          ),
        ),
      ),
    );
  }
}
