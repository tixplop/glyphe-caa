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
  });

  final Case caseData;
  final VoidCallback onTap;

  /// Dossier dont la grille cible n'existe plus (signalé en édition).
  final bool orphelin;

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
    final nom = libelle.isEmpty ? Textes.caseSansNom : libelle;
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
            final largeurLibelle = box.maxWidth - 2 * _marge;
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
                      onFocusChange: (v) => setState(() => _focus = v),
                      splashFactory: NoSplash.splashFactory,
                      splashColor: Colors.transparent,
                      highlightColor: t.ink.withValues(alpha: 0.12),
                      hoverColor: Colors.transparent,
                      focusColor: Colors.transparent,
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(_marge),
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
                                          child: ImageCaseWidget(c.image),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                if (libelle.isNotEmpty) ...[
                                  const SizedBox(height: GlypheTokens.espace1),
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
