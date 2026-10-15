import 'package:flutter/material.dart';

import '../../domaine/modeles.dart';
import '../textes.dart';
import '../tokens.dart';
import 'image_case.dart';

/// Une case de la grille : image, libellé dessous, fond coloré.
class CaseWidget extends StatelessWidget {
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

  bool get _dossier => caseData.type == TypeCase.dossier;

  @override
  Widget build(BuildContext context) {
    final libelle = caseData.libelle;
    final nom = libelle.isEmpty ? Textes.caseSansNom : libelle;
    final base = _dossier ? Textes.dossier(nom) : nom;
    final etiquette = orphelin ? '$base, ${Textes.grilleIntrouvable}' : base;
    final (fond, _) = GlypheTokens.of(context).categorie(caseData.categorie);
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Semantics(
        button: true,
        label: etiquette,
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          color: fond,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Colors.black54),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(3),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(child: ImageCaseWidget(caseData.image)),
                      ),
                      if (libelle.isNotEmpty)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            libelle,
                            maxLines: 1,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (orphelin)
                  const Positioned(
                    key: Key('badge-orphelin'),
                    top: 0,
                    left: 0,
                    child: Icon(
                      Icons.warning_amber,
                      size: 22,
                      color: Colors.red,
                    ),
                  ),
                if (_dossier)
                  const Positioned(
                    top: 0,
                    right: 0,
                    child: Icon(Icons.folder, size: 22, color: Colors.black87),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
