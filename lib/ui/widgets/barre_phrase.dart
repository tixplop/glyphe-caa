import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domaine/session.dart';
import '../textes.dart';
import '../tokens.dart';
import 'image_case.dart';

/// Barre de phrase (REQ-034) : zone de mots défilante (appui = lire), bouton
/// Effacer (appui court = dernier mot, appui long = tout) et bouton
/// Parler / Arrêter.
class BarrePhrase extends StatefulWidget {
  const BarrePhrase({
    super.key,
    required this.elements,
    required this.enLecture,
    required this.onLire,
    required this.onArreter,
    required this.onEffacerDernier,
    required this.onToutEffacer,
  });

  final List<ElementBarre> elements;
  final bool enLecture;
  final VoidCallback onLire;
  final VoidCallback onArreter;
  final VoidCallback onEffacerDernier;
  final VoidCallback onToutEffacer;

  @override
  State<BarrePhrase> createState() => _BarrePhraseState();
}

class _BarrePhraseState extends State<BarrePhrase> {
  static const double _hauteurBouton = 56;

  final ScrollController _controleur = ScrollController();
  bool _appuiLong = false;
  bool _focusEffacer = false;

  @override
  void didUpdateWidget(BarrePhrase ancien) {
    super.didUpdateWidget(ancien);
    if (widget.elements.length > ancien.elements.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controleur.hasClients) {
          _controleur.jumpTo(_controleur.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  void _definirAppuiLong(bool v) {
    if (_appuiLong != v) setState(() => _appuiLong = v);
  }

  Widget _puce(GlypheTokens t, ElementBarre e, int i) {
    final (_, contour) = t.categorie(e.categorie);
    return Padding(
      key: Key('element-barre-$i'),
      padding: EdgeInsets.only(right: i == widget.elements.length - 1 ? 0 : 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.surface000,
          borderRadius: BorderRadius.circular(GlypheTokens.rayonSm),
          border: Border.all(color: contour, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 28, height: 28, child: ImageCaseWidget(e.image)),
              if (e.libelle.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  e.libelle,
                  maxLines: 1,
                  style: GlypheTokens.sentence.copyWith(color: t.ink),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _zoneMots(GlypheTokens t) {
    final vide = widget.elements.isEmpty;
    return Semantics(
      button: true,
      label: vide
          ? Textes.aidePhrase
          : Textes.phrasePrefixe +
                widget.elements
                    .map((e) => e.libelle)
                    .where((l) => l.isNotEmpty)
                    .join(' '),
      hint: vide ? null : Textes.appuyerPourLire,
      excludeSemantics: true,
      onTap: widget.onLire,
      child: InkWell(
        key: const Key('zone-barre'),
        borderRadius: BorderRadius.circular(GlypheTokens.rayonSm),
        onTap: widget.onLire,
        child: SizedBox(
          height: double.infinity,
          child: SingleChildScrollView(
            controller: _controleur,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: GlypheTokens.barrePhrase),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    if (vide)
                      Text(
                        Textes.aidePhrase,
                        style: GlypheTokens.body.copyWith(color: t.inkMuted),
                      )
                    else
                      for (var i = 0; i < widget.elements.length; i++)
                        _puce(t, widget.elements[i], i),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _boutonEffacer(GlypheTokens t) {
    final fond = _appuiLong ? t.danger : t.surface000;
    final encre = _appuiLong ? t.onDanger : t.ink;
    final rayon = BorderRadius.circular(GlypheTokens.rayonMd);
    final actif = widget.enLecture || widget.elements.isNotEmpty;
    return Semantics(
      button: true,
      enabled: actif,
      label: Textes.effacerDernierMot,
      excludeSemantics: true,
      onTap: actif ? widget.onEffacerDernier : null,
      onLongPress: actif ? widget.onToutEffacer : null,
      onLongPressHint: actif ? Textes.toutEffacer : null,
      child: Opacity(
        opacity: (actif || _appuiLong) ? 1 : 0.4,
        child: GestureDetector(
          key: const Key('bouton-effacer'),
          behavior: HitTestBehavior.opaque,
          onTap: actif ? widget.onEffacerDernier : null,
          onLongPressStart: actif
              ? (_) {
                  _definirAppuiLong(true);
                  widget.onToutEffacer();
                }
              : null,
          onLongPressEnd: (_) => _definirAppuiLong(false),
          onLongPressCancel: () => _definirAppuiLong(false),
          child: Focus(
            canRequestFocus: actif,
            onFocusChange: (v) => setState(() => _focusEffacer = v),
            onKeyEvent: (_, e) {
              if (e is KeyDownEvent &&
                  const [
                    LogicalKeyboardKey.enter,
                    LogicalKeyboardKey.numpadEnter,
                    LogicalKeyboardKey.space,
                  ].contains(e.logicalKey)) {
                widget.onEffacerDernier();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Material(
                  color: fond,
                  shape: RoundedRectangleBorder(
                    borderRadius: rayon,
                    side: BorderSide(
                      color: _appuiLong ? t.danger : t.border,
                      width: 2,
                    ),
                  ),
                  child: SizedBox(
                    width: _hauteurBouton,
                    height: _hauteurBouton,
                    child: Icon(
                      Icons.backspace_outlined,
                      color: encre,
                      size: 28,
                    ),
                  ),
                ),
                if (_focusEffacer)
                  Positioned(
                    left: -5,
                    top: -5,
                    right: -5,
                    bottom: -5,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        key: const Key('anneau-focus'),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            GlypheTokens.rayonMd + 5,
                          ),
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
          ),
        ),
      ),
    );
  }

  Widget _boutonParler(GlypheTokens t) {
    final enLecture = widget.enLecture;
    // « Arrêter » reste actif même si la barre a été effacée pendant la lecture.
    final actif = enLecture || widget.elements.isNotEmpty;
    final action = enLecture ? widget.onArreter : widget.onLire;
    final libelle = enLecture ? Textes.arreter : Textes.parler;
    return Semantics(
      button: true,
      enabled: actif,
      label: libelle,
      excludeSemantics: true,
      onTap: actif ? action : null,
      child: Opacity(
        key: const Key('bouton-parler'),
        opacity: actif ? 1 : 0.4,
        child: Material(
          color: t.primary,
          borderRadius: BorderRadius.circular(GlypheTokens.rayonMd),
          child: InkWell(
            borderRadius: BorderRadius.circular(GlypheTokens.rayonMd),
            onTap: actif ? action : null,
            child: SizedBox(
              width: _hauteurBouton,
              height: _hauteurBouton,
              child: Icon(
                enLecture
                    ? Icons.stop_circle_outlined
                    : Icons.volume_up_outlined,
                color: t.onPrimary,
                size: 28,
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
    return _barre(t);
  }

  Widget _barre(GlypheTokens t) {
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _zoneMots(t)),
              const SizedBox(width: 8),
              _boutonEffacer(t),
              const SizedBox(width: 12),
              _boutonParler(t),
            ],
          ),
        ),
      ),
    );
  }
}
