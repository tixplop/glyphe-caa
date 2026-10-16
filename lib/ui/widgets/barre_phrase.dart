import 'package:flutter/material.dart';

import '../../domaine/session.dart';
import '../textes.dart';
import '../tokens.dart';
import 'bouton_barre.dart';
import 'cadenas.dart';
import 'image_case.dart';

/// Barre de phrase (REQ-034) : Accueil, zone de mots défilante (appui = lire,
/// ou arrêter pendant la lecture), Corbeille, Effacer et cadenas.
class BarrePhrase extends StatefulWidget {
  const BarrePhrase({
    super.key,
    required this.elements,
    required this.enLecture,
    required this.onLire,
    required this.onArreter,
    required this.onEffacerDernier,
    required this.onToutEffacer,
    required this.onAccueil,
    required this.onDeverrouille,
    this.focusAccueil,
  });

  final List<ElementBarre> elements;
  final bool enLecture;
  final VoidCallback onLire;
  final VoidCallback onArreter;
  final VoidCallback onEffacerDernier;
  final VoidCallback onToutEffacer;
  final VoidCallback onAccueil;
  final VoidCallback onDeverrouille;
  final FocusNode? focusAccueil;

  @override
  State<BarrePhrase> createState() => _BarrePhraseState();
}

class _BarrePhraseState extends State<BarrePhrase> {
  static const double _hauteurZone = 56;
  static const double _cadre = 3;
  static const double _margeZone = 6;

  final ScrollController _controleur = ScrollController();

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

  Widget _contenu(GlypheTokens t, double largeur) {
    if (widget.elements.isEmpty) {
      return Center(
        child: Text(
          Textes.aidePhrase,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GlypheTokens.body.copyWith(color: t.inkMuted),
        ),
      );
    }
    return SingleChildScrollView(
      controller: _controleur,
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: largeur),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.elements.length; i++)
              _puce(t, widget.elements[i], i),
          ],
        ),
      ),
    );
  }

  Widget _zoneMots(GlypheTokens t) {
    final vide = widget.elements.isEmpty;
    final lecture = widget.enLecture;
    final action = lecture ? widget.onArreter : widget.onLire;
    final rayon = BorderRadius.circular(GlypheTokens.rayonMd);
    return Semantics(
      button: true,
      label: vide
          ? Textes.aidePhrase
          : Textes.phrasePrefixe +
                widget.elements
                    .map((e) => e.libelle)
                    .where((l) => l.isNotEmpty)
                    .join(' '),
      hint: lecture
          ? Textes.appuyerPourArreter
          : vide
          ? null
          : Textes.appuyerPourLire,
      excludeSemantics: true,
      onTap: action,
      child: AnneauFocus(
        child: SizedBox(
          height: _hauteurZone,
          child: Material(
            color: Colors.transparent,
            borderRadius: rayon,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const Key('zone-barre'),
              borderRadius: rayon,
              onTap: action,
              splashFactory: NoSplash.splashFactory,
              splashColor: Colors.transparent,
              highlightColor: t.ink.withValues(alpha: 0.12),
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
              child: DecoratedBox(
                key: const Key('cadre-lecture'),
                decoration: BoxDecoration(
                  borderRadius: rayon,
                  border: Border.all(
                    color: lecture ? t.primary : Colors.transparent,
                    width: _cadre,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(_cadre)
                      .add(const EdgeInsets.symmetric(horizontal: _margeZone)),
                  child: LayoutBuilder(
                    builder: (context, c) => _contenu(t, c.maxWidth),
                  ),
                ),
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
    final vide = widget.elements.isEmpty;
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              BoutonBarre(
                key: const Key('bouton-accueil'),
                libelle: Textes.accueil,
                icone: Icons.home_outlined,
                focusNode: widget.focusAccueil,
                onTap: widget.onAccueil,
              ),
              const SizedBox(width: GlypheTokens.espace1),
              Expanded(child: _zoneMots(t)),
              const SizedBox(width: GlypheTokens.espace1),
              BoutonBarre(
                key: const Key('bouton-corbeille'),
                libelle: Textes.toutEffacer,
                icone: Icons.delete_outline,
                couleurIcone: t.danger,
                actif: !vide,
                onTap: widget.onToutEffacer,
              ),
              const SizedBox(width: GlypheTokens.espace3),
              BoutonBarre(
                key: const Key('bouton-effacer'),
                libelle: Textes.effacerDernierMot,
                icone: Icons.backspace_outlined,
                actif: !vide,
                onTap: widget.onEffacerDernier,
              ),
              const SizedBox(width: GlypheTokens.espace1),
              Cadenas(onDeverrouille: widget.onDeverrouille),
            ],
          ),
        ),
      ),
    );
  }
}
