import 'package:flutter/material.dart';

/// Titre des barres d'application (AC-028-5) : une ligne, échelle de texte
/// plafonnée à 1,5, terminé par « … » s'il ne tient pas.
class TitreBarre extends StatelessWidget {
  const TitreBarre(this.texte, {super.key});

  final String texte;

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.5,
    child: Text(
      texte,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    ),
  );
}
