import 'package:flutter/material.dart';

import '../textes.dart';
import '../tokens.dart';

/// Flèche Retour des barres d'application (AC-029-1) : info-bulle et libellé
/// « Retour » en français, sans dépendre de `flutter_localizations`.
class BoutonRetour extends StatelessWidget {
  const BoutonRetour({super.key = const Key('bouton-retour-appli')});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: Textes.retour,
    icon: Icon(Icons.arrow_back, color: GlypheTokens.of(context).ink),
    onPressed: () => Navigator.of(context).maybePop(),
  );
}
