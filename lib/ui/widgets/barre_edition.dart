import 'package:flutter/material.dart';

import '../textes.dart';
import '../tokens.dart';
import 'bouton_barre.dart';

/// Barre d'édition (AC-030-4, AC-030-7) : prend la place et la hauteur de la
/// barre de phrase en mode édition. Titre, Ajouter une case, Plus, Terminer.
class BarreEdition extends StatefulWidget {
  const BarreEdition({
    super.key,
    required this.nomGrille,
    required this.onAccueil,
    required this.onTerminer,
    required this.onAjouter,
    required this.onCode,
    required this.onGrilles,
    required this.onTaille,
    required this.onReglages,
    required this.onAPropos,
  });

  final String nomGrille;
  final VoidCallback onAccueil;
  final VoidCallback onTerminer;
  final VoidCallback onAjouter;
  final VoidCallback onCode;
  final VoidCallback onGrilles;
  final VoidCallback onTaille;
  final VoidCallback onReglages;
  final VoidCallback onAPropos;

  @override
  State<BarreEdition> createState() => _BarreEditionState();
}

class _BarreEditionState extends State<BarreEdition> {
  final GlobalKey<PopupMenuButtonState<VoidCallback>> _menu = GlobalKey();

  Widget _titre(GlypheTokens t) => Semantics(
    key: const Key('titre-edition'),
    container: true,
    header: true,
    label: Textes.titreEdition(widget.nomGrille),
    excludeSemantics: true,
    child: MediaQuery.withNoTextScaling(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Textes.modeEdition,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textScaler: TextScaler.noScaling,
            style: GlypheTokens.caption.copyWith(color: t.inkMuted),
          ),
          Text(
            widget.nomGrille,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textScaler: TextScaler.noScaling,
            style: GlypheTokens.body.copyWith(
              color: t.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );

  PopupMenuItem<VoidCallback> _entree(
    GlypheTokens t,
    String cle,
    IconData icone,
    String nom,
    VoidCallback action,
  ) => PopupMenuItem<VoidCallback>(
    key: Key(cle),
    value: action,
    height: GlypheTokens.toucheMin,
    child: Row(
      children: [
        Icon(icone, size: 24, color: t.ink),
        const SizedBox(width: GlypheTokens.espace4),
        Flexible(child: Text(nom, style: GlypheTokens.body)),
      ],
    ),
  );

  Widget _plus(GlypheTokens t) => Semantics(
    key: const Key('bouton-plus'),
    button: true,
    label: Textes.plus,
    excludeSemantics: true,
    onTap: () => _menu.currentState?.showButtonMenu(),
    child: AnneauFocus(
      disque: true,
      child: PopupMenuButton<VoidCallback>(
        key: _menu,
        tooltip: Textes.plus,
        icon: Icon(Icons.more_vert, size: 24, color: t.ink),
        style: IconButton.styleFrom(
          minimumSize: const Size.square(GlypheTokens.toucheMin),
          fixedSize: const Size.square(GlypheTokens.toucheMin),
          splashFactory: NoSplash.splashFactory,
          highlightColor: t.ink.withValues(alpha: 0.12),
          overlayColor: t.ink.withValues(alpha: 0.12),
        ),
        onSelected: (action) => action(),
        itemBuilder: (_) => [
          _entree(
            t,
            'bouton-taille',
            Icons.aspect_ratio_outlined,
            Textes.tailleGrille,
            widget.onTaille,
          ),
          _entree(
            t,
            'bouton-grilles',
            Icons.grid_view_outlined,
            Textes.grilles,
            widget.onGrilles,
          ),
          _entree(
            t,
            'bouton-reglages',
            Icons.settings_outlined,
            Textes.reglages,
            widget.onReglages,
          ),
          _entree(
            t,
            'bouton-code',
            Icons.pin_outlined,
            Textes.codeVerrouillage,
            widget.onCode,
          ),
          _entree(
            t,
            'bouton-a-propos',
            Icons.info_outline,
            Textes.aPropos,
            widget.onAPropos,
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = GlypheTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surface200,
        borderRadius: BorderRadius.circular(GlypheTokens.rayonLg),
        boxShadow: t.ombreBarre,
      ),
      child: SizedBox(
        height: GlypheTokens.barrePhrase,
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: GlypheTokens.espace1),
          child: Row(
            children: [
              BoutonBarre(
                key: const Key('bouton-accueil'),
                libelle: Textes.accueil,
                tooltip: Textes.accueil,
                icone: Icons.home_outlined,
                onTap: widget.onAccueil,
              ),
              const SizedBox(width: GlypheTokens.espace2),
              Expanded(child: _titre(t)),
              const SizedBox(width: GlypheTokens.espace2),
              BoutonBarre(
                key: const Key('ajouter-case'),
                libelle: Textes.ajouterCase,
                tooltip: Textes.ajouterCase,
                icone: Icons.add,
                onTap: widget.onAjouter,
              ),
              const SizedBox(width: GlypheTokens.espace1),
              _plus(t),
              const SizedBox(width: GlypheTokens.espace3),
              BoutonBarre(
                key: const Key('bouton-terminer'),
                libelle: Textes.terminer,
                tooltip: Textes.terminer,
                icone: Icons.lock_outline,
                variante: VarianteBouton.pleine,
                onTap: widget.onTerminer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
