import 'package:flutter/material.dart';

import '../tokens.dart';

/// Apparence d'un [BoutonBarre].
enum VarianteBouton { contour, pleine, transparente }

/// Bouton carré de 48 des barres (Accueil, Corbeille, Effacer, Ajouter,
/// Terminer...) : icône seule, libellé d'accessibilité, action au relâcher,
/// voile `ink` 12 % sans ondulation, anneau de focus. Aucune action d'appui
/// long. Inactif : opacité 40 %, exposé désactivé, ni focus ni effet.
class BoutonBarre extends StatelessWidget {
  const BoutonBarre({
    super.key,
    required this.libelle,
    required this.icone,
    required this.onTap,
    this.variante = VarianteBouton.contour,
    this.couleurIcone,
    this.tooltip,
    this.actif = true,
    this.focusNode,
  });

  static const double cote = GlypheTokens.toucheMin;

  /// Libellé d'accessibilité.
  final String libelle;
  final IconData icone;
  final VoidCallback onTap;
  final VarianteBouton variante;

  /// Par défaut : `ink` (`on-primary` pour la variante pleine).
  final Color? couleurIcone;

  /// Info-bulle (barre d'édition seulement) ; null = aucune.
  final String? tooltip;
  final bool actif;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final t = GlypheTokens.of(context);
    final pleine = variante == VarianteBouton.pleine;
    final transparente = variante == VarianteBouton.transparente;
    final forme = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(GlypheTokens.rayonMd),
      side: variante == VarianteBouton.contour
          ? BorderSide(color: t.border, width: 2)
          : BorderSide.none,
    );
    Widget bouton = AnneauFocus(
      rayon: GlypheTokens.rayonMd,
      child: Material(
        color: pleine
            ? t.primary
            : transparente
            ? Colors.transparent
            : t.surface000,
        shape: forme,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: forme,
          focusNode: focusNode,
          canRequestFocus: actif,
          onTap: actif ? onTap : null,
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: t.ink.withValues(alpha: 0.12),
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          child: SizedBox.square(
            dimension: cote,
            child: Icon(
              icone,
              size: transparente ? 24 : 28,
              color: couleurIcone ?? (pleine ? t.onPrimary : t.ink),
            ),
          ),
        ),
      ),
    );
    if (tooltip != null) {
      bouton = Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: bouton,
      );
    }
    return Semantics(
      button: true,
      enabled: actif,
      label: libelle,
      excludeSemantics: true,
      onTap: actif ? onTap : null,
      child: Opacity(opacity: actif ? 1 : 0.4, child: bouton),
    );
  }
}

/// Anneau `focus` de 3, décalé de 2, autour de l'enfant dès qu'il (ou un de
/// ses descendants) a le focus. [disque] : anneau circulaire.
class AnneauFocus extends StatefulWidget {
  const AnneauFocus({
    super.key,
    required this.child,
    this.rayon = GlypheTokens.rayonMd,
    this.disque = false,
  });

  final Widget child;
  final double rayon;
  final bool disque;

  @override
  State<AnneauFocus> createState() => _AnneauFocusState();
}

class _AnneauFocusState extends State<AnneauFocus> {
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final t = GlypheTokens.of(context);
    const decalage = 2 + GlypheTokens.anneauFocus;
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
              left: -decalage,
              top: -decalage,
              right: -decalage,
              bottom: -decalage,
              child: IgnorePointer(
                child: DecoratedBox(
                  key: const Key('anneau-focus'),
                  decoration: BoxDecoration(
                    shape: widget.disque ? BoxShape.circle : BoxShape.rectangle,
                    borderRadius: widget.disque
                        ? null
                        : BorderRadius.circular(widget.rayon + decalage),
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
