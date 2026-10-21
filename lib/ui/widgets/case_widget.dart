import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domaine/modeles.dart';
import '../textes.dart';
import '../tokens.dart';
import 'image_case.dart';

/// Une case de la grille (REQ-032, REQ-033) : fond et contour de catégorie,
/// picto et libellé.
///
/// Côte à côte : bloc picto + écart + libellé, centré horizontalement sur le
/// texte affiché (« … » compris pour un libellé tronqué). Repli : libellé sous
/// le picto, centré, dans une case haute et étroite.
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
  static const double _margeX = GlypheTokens.caseMargeX;
  static const double _hLibelle = 16;

  static double _pos(double v) => v < 0 ? 0 : v;

  bool _focus = false;

  bool get _dossier => widget.caseData.type == TypeCase.dossier;

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
            final avecLibelle = libelle.isNotEmpty;
            final li = _pos(box.maxWidth - 2 * _bordure - 2 * _margeX);
            var margeHaut = GlypheTokens.caseMargeHaut;
            var margeBas = GlypheTokens.caseMargeBas;
            var hi = box.maxHeight - 2 * _bordure - margeHaut - margeBas;
            if (avecLibelle && hi < _hLibelle) {
              // Case très basse : plus de marge haute ni basse.
              margeHaut = 0;
              margeBas = 0;
              hi = box.maxHeight - 2 * _bordure;
            }
            hi = _pos(hi);
            final double d;
            final bool superposee;
            if (avecLibelle) {
              final dC = _pos(
                math.min(
                  hi,
                  li -
                      GlypheTokens.caseEcartLibelle -
                      GlypheTokens.caseLibelleMin,
                ),
              );
              final dS = _pos(
                math.min(li, hi - _hLibelle - GlypheTokens.caseEcartPicto),
              );
              superposee = dS > dC;
              d = superposee ? dS : dC;
            } else {
              superposee = false;
              d = math.min(li, hi);
            }
            // Positions (sans libellé ou superposée) dans la zone li x hi ; le
            // côte à côte est porté par le bloc centré (Row).
            final double pictoX = (li - d) / 2;
            final double pictoY;
            final double libelleY;
            if (!avecLibelle) {
              pictoY = (hi - d) / 2;
              libelleY = 0;
            } else {
              final bloc = d + GlypheTokens.caseEcartPicto + _hLibelle;
              pictoY = (hi - bloc) / 2;
              libelleY = pictoY + d + GlypheTokens.caseEcartPicto;
            }
            final hBloc = math.max(d, _hLibelle);
            final picto = SizedBox.square(
              key: const Key('picto'),
              dimension: d,
              child: retour && c.image is ImageAucune
                  ? Icon(
                      Icons.arrow_back,
                      key: const Key('fleche-retour'),
                      size: d,
                      color: t.ink,
                      semanticLabel: null,
                    )
                  : ImageCaseWidget(c.image),
            );
            Widget texte(TextAlign align, {TextWidthBasis? basis}) => Text(
              libelle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              textAlign: align,
              textWidthBasis: basis,
              textScaler: TextScaler.noScaling,
              style: GlypheTokens.caseLibelle.copyWith(color: t.ink),
            );
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
                          Positioned(
                            left: _bordure + _margeX,
                            top: _bordure + margeHaut,
                            width: li,
                            height: hi,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                if (avecLibelle && !superposee)
                                  // Disposition côte à côte : bloc picto +
                                  // écart + libellé centré horizontalement
                                  // (AC-033-16).
                                  Positioned(
                                    left: 0,
                                    width: li,
                                    top: (hi - hBloc) / 2,
                                    height: hBloc,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        picto,
                                        SizedBox(
                                          width: _pos(
                                            math.min(
                                              GlypheTokens.caseEcartLibelle,
                                              li - d,
                                            ),
                                          ),
                                        ),
                                        Flexible(
                                          child: SizedBox(
                                            key: const Key('libelle-place'),
                                            height: _hLibelle,
                                            child: texte(
                                              TextAlign.left,
                                              basis: TextWidthBasis.longestLine,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else ...[
                                  Positioned(
                                    left: pictoX,
                                    top: pictoY,
                                    width: d,
                                    height: d,
                                    child: picto,
                                  ),
                                  if (avecLibelle)
                                    Positioned(
                                      left: 0,
                                      top: libelleY,
                                      width: li,
                                      height: _hLibelle,
                                      child: Align(
                                        key: const Key('libelle-place'),
                                        alignment: Alignment.center,
                                        child: texte(TextAlign.center),
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
