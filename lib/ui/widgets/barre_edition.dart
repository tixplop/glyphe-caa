import 'package:flutter/material.dart';

import '../textes.dart';
import '../tokens.dart';

/// Barre d'édition (AC-030-4, AC-030-7) : prend la place et la hauteur de la
/// barre de phrase en mode édition. Titre, Ajouter une case, Plus, Terminer.
class BarreEdition extends StatefulWidget {
  const BarreEdition({
    super.key,
    required this.nomGrille,
    required this.onTerminer,
    required this.onAjouter,
    required this.onCode,
    required this.onGrilles,
    required this.onTaille,
    required this.onReglages,
    required this.onAPropos,
  });

  final String nomGrille;
  final VoidCallback onTerminer;
  final VoidCallback onAjouter;
  final VoidCallback onCode;
  final VoidCallback onGrilles;
  final VoidCallback onTaille;
  final VoidCallback onReglages;
  final VoidCallback onAPropos;

  static const double _carre = 56;
  static const double _icone = 28;

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
      child: Padding(
        padding: const EdgeInsets.only(left: GlypheTokens.espace2),
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
    child: _AnneauFocus(
      tokens: t,
      disque: true,
      child: PopupMenuButton<VoidCallback>(
        key: _menu,
        tooltip: Textes.plus,
        icon: Icon(Icons.more_vert, size: BarreEdition._icone, color: t.ink),
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
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(child: _titre(t)),
              const SizedBox(width: 8),
              _BoutonCarre(
                boutonKey: const Key('ajouter-case'),
                tokens: t,
                libelle: Textes.ajouterCase,
                icone: Icons.add,
                plein: false,
                onTap: widget.onAjouter,
              ),
              const SizedBox(width: 8),
              _plus(t),
              const SizedBox(width: 12),
              _BoutonCarre(
                boutonKey: const Key('bouton-terminer'),
                tokens: t,
                libelle: Textes.terminer,
                icone: Icons.lock_outline,
                plein: true,
                onTap: widget.onTerminer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carré de 56 (BoutonBarre) : icône seule, info-bulle et libellé
/// d'accessibilité, voile `ink` 12 % sans ondulation.
class _BoutonCarre extends StatelessWidget {
  const _BoutonCarre({
    required this.boutonKey,
    required this.tokens,
    required this.libelle,
    required this.icone,
    required this.plein,
    required this.onTap,
  });

  final Key boutonKey;
  final GlypheTokens tokens;
  final String libelle;
  final IconData icone;
  final bool plein;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final forme = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(GlypheTokens.rayonMd),
      side: plein ? BorderSide.none : BorderSide(color: t.border, width: 2),
    );
    return Semantics(
      key: boutonKey,
      button: true,
      label: libelle,
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: libelle,
        excludeFromSemantics: true,
        child: _AnneauFocus(
          tokens: t,
          disque: false,
          child: Material(
            color: plein ? t.primary : t.surface000,
            shape: forme,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: forme,
              onTap: onTap,
              splashFactory: NoSplash.splashFactory,
              splashColor: Colors.transparent,
              highlightColor: t.ink.withValues(alpha: 0.12),
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
              child: SizedBox.square(
                dimension: BarreEdition._carre,
                child: Icon(
                  icone,
                  size: BarreEdition._icone,
                  color: plein ? t.onPrimary : t.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Anneau `focus` de 3, décalé de 2, autour de l'enfant dès qu'il (ou un de
/// ses descendants) a le focus.
class _AnneauFocus extends StatefulWidget {
  const _AnneauFocus({
    required this.tokens,
    required this.disque,
    required this.child,
  });

  final GlypheTokens tokens;
  final bool disque;
  final Widget child;

  @override
  State<_AnneauFocus> createState() => _AnneauFocusState();
}

class _AnneauFocusState extends State<_AnneauFocus> {
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (v) => setState(() => _focus = v),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
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
                        : BorderRadius.circular(GlypheTokens.rayonMd + 5),
                    border: Border.all(
                      color: t.focus,
                      width: GlypheTokens.anneauFocus,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
