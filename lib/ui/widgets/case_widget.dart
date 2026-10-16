import 'package:flutter/material.dart';

import '../../domaine/modeles.dart';
import '../textes.dart';
import '../tokens.dart';
import 'image_case.dart';

/// Une case de la grille : picto, libellé dessous, fond et contour de
/// catégorie (REQ-032, REQ-033).
class CaseWidget extends StatefulWidget {
  const CaseWidget({
    super.key,
    required this.caseData,
    required this.onTap,
    this.orphelin = false,
    this.focusNode,
  });

  final Case caseData;
  final VoidCallback onTap;

  /// Dossier dont la grille cible n'existe plus (signalé en édition).
  final bool orphelin;

  /// Nœud de focus de la case (focus après navigation, AC-009-9).
  final FocusNode? focusNode;

  @override
  State<CaseWidget> createState() => _CaseWidgetState();
}

class _CaseWidgetState extends State<CaseWidget> {
  static const double _bordure = GlypheTokens.contourCase;
  static const double _marge = 3;
  static const double _coin = 16;

  bool _focus = false;

  bool get _dossier => widget.caseData.type == TypeCase.dossier;

  /// Style du libellé : `cell-label`, ou `cell-label-small` s'il ne tient pas.
  TextStyle _style(String libelle, double largeur, Color encre) {
    final grand = GlypheTokens.cellLabel.copyWith(color: encre);
    final mesure = TextPainter(
      text: TextSpan(text: libelle, style: grand),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    final tient = mesure.width <= largeur;
    mesure.dispose();
    return tient ? grand : GlypheTokens.cellLabelSmall.copyWith(color: encre);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.caseData;
    final libelle = c.libelle;
    final retour = c.type == TypeCase.retour;
    final nom = libelle.isEmpty
        ? (retour ? Textes.retour : Textes.caseSansNom)
        : libelle;
    final base = _dossier ? Textes.dossier(nom) : nom;
    final etiquette = widget.orphelin
        ? '$base, ${Textes.grilleIntrouvable}'
        : base;
    final t = GlypheTokens.of(context);
    final (fond, contour) = t.categorie(c.categorie);
    final rayon = BorderRadius.circular(GlypheTokens.rayonMd);
    return Padding(
      padding: const EdgeInsets.all(_marge),
      child: Semantics(
        button: true,
        label: etiquette,
        excludeSemantics: true,
        onTap: widget.onTap,
        child: LayoutBuilder(
          builder: (context, box) {
            final cote =
                0.6 *
                (box.maxWidth < box.maxHeight ? box.maxWidth : box.maxHeight);
            // Case basse (grille dense) : sans picto possible, on retire la
            // marge interne et l'écart pour que le libellé tienne.
            final basse =
                libelle.isNotEmpty &&
                box.maxHeight <
                    (GlypheTokens.cellLabel.height! *
                                GlypheTokens.cellLabel.fontSize!)
                            .ceil() +
                        GlypheTokens.espace1 +
                        2 * _marge;
            final margeInterne = basse ? 0.0 : _marge;
            final largeurLibelle = box.maxWidth - 2 * margeInterne;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Material(
                    color: fond,
                    shape: RoundedRectangleBorder(
                      borderRadius: rayon,
                      side: BorderSide(color: contour, width: _bordure),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: widget.onTap,
                      focusNode: widget.focusNode,
                      onFocusChange: (v) => setState(() => _focus = v),
                      splashFactory: NoSplash.splashFactory,
                      splashColor: Colors.transparent,
                      highlightColor: t.ink.withValues(alpha: 0.12),
                      hoverColor: Colors.transparent,
                      focusColor: Colors.transparent,
                      child: Stack(
                        children: [
                          Padding(
                            padding: EdgeInsets.all(margeInterne),
                            child: Column(
                              children: [
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, zone) {
                                      final h = zone.maxHeight;
                                      final d = cote < h ? cote : h;
                                      return Center(
                                        child: SizedBox.square(
                                          key: const Key('picto'),
                                          dimension: d,
                                          child:
                                              retour && c.image is ImageAucune
                                              ? Icon(
                                                  Icons.arrow_back,
                                                  key: const Key(
                                                    'fleche-retour',
                                                  ),
                                                  size: d,
                                                  color: t.ink,
                                                  semanticLabel: null,
                                                )
                                              : ImageCaseWidget(c.image),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                if (libelle.isNotEmpty) ...[
                                  SizedBox(
                                    height: basse ? 0 : GlypheTokens.espace1,
                                  ),
                                  Text(
                                    libelle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: false,
                                    textAlign: TextAlign.center,
                                    textScaler: TextScaler.noScaling,
                                    style: _style(
                                      libelle,
                                      largeurLibelle,
                                      t.ink,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (widget.orphelin)
                            Positioned(
                              key: const Key('badge-orphelin'),
                              top: 0,
                              left: 0,
                              child: Icon(
                                Icons.warning_amber,
                                size: 22,
                                color: t.danger,
                              ),
                            ),
                          if (_dossier)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                key: const Key('coin-dossier'),
                                width: _coin,
                                height: _coin,
                                decoration: BoxDecoration(
                                  color: contour,
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(
                                      GlypheTokens.rayonMd,
                                    ),
                                    bottomLeft: Radius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
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
                          border: Border.all(
                            color: t.focus,
                            width: GlypheTokens.anneauFocus,
                          ),
                          borderRadius: BorderRadius.circular(
                            GlypheTokens.rayonMd + 5,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
