import 'package:flutter/material.dart';

import '../textes.dart';
import '../tokens.dart';

/// Barre d'édition (AC-030-4) : prend la place et la hauteur de la barre de
/// phrase en mode édition.
class BarreEdition extends StatelessWidget {
  const BarreEdition({
    super.key,
    required this.onTerminer,
    required this.onAjouter,
    required this.onCode,
    required this.onGrilles,
    required this.onTaille,
    required this.onReglages,
    required this.onAPropos,
  });

  final VoidCallback onTerminer;
  final VoidCallback onAjouter;
  final VoidCallback onCode;
  final VoidCallback onGrilles;
  final VoidCallback onTaille;
  final VoidCallback onReglages;
  final VoidCallback onAPropos;

  static const double _touche = GlypheTokens.toucheMin;

  Widget _libelle(String texte) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(texte, maxLines: 1, textScaler: TextScaler.noScaling),
  );

  @override
  Widget build(BuildContext context) {
    final t = GlypheTokens.of(context);
    final taille = Size.fromHeight(_touche);
    final style = TextStyle(
      fontFamily: GlypheTokens.famille,
      fontSize: 17,
      fontWeight: FontWeight.w700,
    );
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
              Flexible(
                child: FilledButton(
                  onPressed: onTerminer,
                  style: FilledButton.styleFrom(
                    minimumSize: taille,
                    textStyle: style,
                    backgroundColor: t.primary,
                    foregroundColor: t.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: _libelle(Textes.terminer),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: OutlinedButton(
                  key: const Key('ajouter-case'),
                  onPressed: onAjouter,
                  style: OutlinedButton.styleFrom(
                    minimumSize: taille,
                    textStyle: style,
                    foregroundColor: t.ink,
                    backgroundColor: t.surface000,
                    side: BorderSide(color: t.border, width: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: _libelle(Textes.ajouterCase),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<VoidCallback>(
                key: const Key('bouton-plus'),
                tooltip: Textes.plus,
                icon: const Icon(Icons.more_vert),
                iconSize: 28,
                style: IconButton.styleFrom(
                  minimumSize: Size(_touche, _touche),
                ),
                onSelected: (action) => action(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    key: const Key('bouton-code'),
                    value: onCode,
                    child: const Text(Textes.codeVerrouillage),
                  ),
                  PopupMenuItem(
                    key: const Key('bouton-grilles'),
                    value: onGrilles,
                    child: const Text(Textes.grilles),
                  ),
                  PopupMenuItem(
                    key: const Key('bouton-taille'),
                    value: onTaille,
                    child: const Text(Textes.tailleGrille),
                  ),
                  PopupMenuItem(
                    key: const Key('bouton-reglages'),
                    value: onReglages,
                    child: const Text(Textes.reglages),
                  ),
                  PopupMenuItem(
                    key: const Key('bouton-a-propos'),
                    value: onAPropos,
                    child: const Text(Textes.aPropos),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
