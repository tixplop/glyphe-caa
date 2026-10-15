import 'package:flutter/material.dart';

import '../../domaine/modeles.dart';
import '../../domaine/onglets.dart';
import '../../domaine/session.dart';
import '../textes.dart';
import '../tokens.dart';
import 'cadenas.dart';
import 'image_case.dart';

/// Barre de navigation (REQ-031) : Retour, onglets de catégorie qui
/// défilent, cadenas (communication) ou espace de même largeur (édition).
class BarreNavigation extends StatefulWidget {
  const BarreNavigation({
    super.key,
    required this.session,
    required this.modeEdition,
    required this.onDeverrouille,
  });

  final Session session;
  final bool modeEdition;
  final VoidCallback onDeverrouille;

  @override
  State<BarreNavigation> createState() => _BarreNavigationState();
}

class _BarreNavigationState extends State<BarreNavigation> {
  static const double _touche = GlypheTokens.toucheMin;
  // Marge interne de la rangée : l'anneau de focus (5 autour du disque) ne
  // doit pas être rogné.
  static const double _margeRangee = 5;
  // Disque (48) + écart (2) + barre indicatrice (3).
  static const double _bloc = _touche + 2 + 3;

  final ScrollController _defilement = ScrollController();
  final Map<String, GlobalKey> _cles = {};
  String? _dernierActif;

  @override
  void dispose() {
    _defilement.dispose();
    super.dispose();
  }

  Session get _session => widget.session;

  Widget _retour(GlypheTokens t, bool surAccueil) => Semantics(
    button: true,
    label: Textes.retour,
    excludeSemantics: true,
    onTap: surAccueil ? null : _session.retour,
    child: Opacity(
      key: const Key('bouton-retour'),
      opacity: surAccueil ? 0.4 : 1,
      child: _Pastille(
        tokens: t,
        disque: true,
        couleur: Colors.transparent,
        contour: BorderSide.none,
        onTap: surAccueil ? null : _session.retour,
        child: Icon(Icons.arrow_back, color: t.ink, size: 28),
      ),
    ),
  );

  Widget _onglet(GlypheTokens t, Onglet o, bool actif) {
    void ouvrir() =>
        o.estAccueil ? _session.accueil() : _session.ouvrirGrille(o.grilleId);
    final sansImage = !o.estAccueil && o.image is ImageAucune;
    final Widget contenu;
    if (o.estAccueil) {
      contenu = Icon(Icons.home_outlined, size: 28, color: t.ink);
    } else if (sansImage) {
      contenu = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          o.libelle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          textScaler: TextScaler.noScaling,
          style: GlypheTokens.body.copyWith(
            color: t.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    } else {
      contenu = SizedBox.square(dimension: 28, child: ImageCaseWidget(o.image));
    }
    return Semantics(
      button: true,
      selected: actif,
      label: o.libelle,
      excludeSemantics: true,
      onTap: ouvrir,
      child: Column(
        key: _cles.putIfAbsent(o.grilleId, GlobalKey.new),
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: sansImage ? 128 : _touche),
            child: _Pastille(
              materialKey: Key('onglet-${o.grilleId}'),
              tokens: t,
              disque: !sansImage,
              couleur: t.surface000,
              contour: actif
                  ? BorderSide(color: t.primary, width: 3)
                  : BorderSide(color: t.border, width: 2),
              onTap: ouvrir,
              child: contenu,
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 3,
            child: actif
                ? DecoratedBox(
                    key: const Key('indicateur-onglet'),
                    decoration: BoxDecoration(
                      color: t.primary,
                      borderRadius: BorderRadius.circular(
                        GlypheTokens.rayonPilule,
                      ),
                    ),
                    child: const SizedBox(width: 20, height: 3),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  /// Fait défiler la rangée, sans animation, pour que l'onglet actif soit
  /// entier (AC-031-11).
  void _montrer(String id) {
    if (!mounted || !_defilement.hasClients) return;
    final ctx = _cles[id]?.currentContext;
    if (ctx == null || !ctx.mounted) return;
    final item = ctx.findRenderObject();
    final zone = Scrollable.maybeOf(ctx)?.context.findRenderObject();
    if (item is! RenderBox || zone is! RenderBox) return;
    if (!item.attached || !zone.attached) return;
    final g = item.localToGlobal(Offset.zero, ancestor: zone);
    final gauche = g.dx;
    final droite = g.dx + item.size.width;
    final largeur = zone.size.width;
    if (gauche >= 0 && droite <= largeur) return;
    final pos = _defilement.position;
    final double cible;
    if (gauche < 0) {
      cible = pos.pixels + gauche - _margeRangee;
    } else {
      cible = pos.pixels + droite - (largeur - _margeRangee);
    }
    _defilement.jumpTo(cible.clamp(0.0, pos.maxScrollExtent));
  }

  @override
  Widget build(BuildContext context) {
    final t = GlypheTokens.of(context);
    final donnees = _session.donnees;
    final onglets = ongletsDe(donnees);
    final actif = ongletActif(donnees, _session.chemin);
    final surAccueil = _session.grilleCourante.id == donnees.accueilId;
    _cles.removeWhere((id, _) => !onglets.any((o) => o.grilleId == id));
    if (actif != _dernierActif) {
      _dernierActif = actif;
      if (actif != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _montrer(actif));
      }
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surface200,
        borderRadius: BorderRadius.circular(GlypheTokens.rayonLg),
        boxShadow: t.ombreBarre,
      ),
      child: SizedBox(
        height: GlypheTokens.barreAppli,
        width: double.infinity,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: SizedBox(
              height: _bloc,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _retour(t, surAccueil),
                  const SizedBox(width: 4),
                  Expanded(
                    child: OverflowBox(
                      minHeight: 64,
                      maxHeight: 64,
                      child: SingleChildScrollView(
                        key: const Key('onglets'),
                        controller: _defilement,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: _margeRangee,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            for (var i = 0; i < onglets.length; i++) ...[
                              if (i > 0)
                                const SizedBox(width: GlypheTokens.espace1),
                              _onglet(
                                t,
                                onglets[i],
                                onglets[i].grilleId == actif,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (widget.modeEdition)
                    const SizedBox(key: Key('espace-cadenas'), width: _touche)
                  else
                    Cadenas(onDeverrouille: widget.onDeverrouille),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Zone tactile de 48 de haut : voile `ink` 12 % à l'appui (sans ondulation),
/// action au relâcher, anneau `focus` au focus clavier.
class _Pastille extends StatefulWidget {
  const _Pastille({
    this.materialKey,
    required this.tokens,
    required this.disque,
    required this.couleur,
    required this.contour,
    required this.onTap,
    required this.child,
  });

  final Key? materialKey;
  final GlypheTokens tokens;
  final bool disque;
  final Color couleur;
  final BorderSide contour;
  final VoidCallback? onTap;
  final Widget child;

  @override
  State<_Pastille> createState() => _PastilleState();
}

class _PastilleState extends State<_Pastille> {
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    final OutlinedBorder forme = widget.disque
        ? CircleBorder(side: widget.contour)
        : StadiumBorder(side: widget.contour);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          key: widget.materialKey,
          color: widget.couleur,
          shape: forme,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: forme,
            onTap: widget.onTap,
            onFocusChange: (v) => setState(() => _focus = v),
            splashFactory: NoSplash.splashFactory,
            splashColor: Colors.transparent,
            highlightColor: t.ink.withValues(alpha: 0.12),
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
            child: widget.disque
                ? SizedBox.square(
                    dimension: GlypheTokens.toucheMin,
                    child: Center(child: widget.child),
                  )
                : SizedBox(
                    height: GlypheTokens.toucheMin,
                    child: Center(widthFactor: 1, child: widget.child),
                  ),
          ),
        ),
        if (_focus)
          Positioned(
            left: -5,
            top: -5,
            right: -5,
            bottom: -5,
            child: IgnorePointer(
              child: DecoratedBox(
                key: const Key('anneau-focus'),
                decoration: BoxDecoration(
                  shape: widget.disque ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: widget.disque
                      ? null
                      : BorderRadius.circular(GlypheTokens.rayonPilule),
                  border: Border.all(
                    color: t.focus,
                    width: GlypheTokens.anneauFocus,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
