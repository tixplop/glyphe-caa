import 'package:flutter/material.dart';

import '../domaine/edition.dart';
import '../domaine/modeles.dart';
import 'etat_appli.dart';
import 'textes.dart';

/// Ouvre le dialogue de taille de la grille courante et enregistre le choix
/// (REQ-018). Les cases hors taille sont masquées, jamais supprimées.
Future<void> reglerTaille(BuildContext context, EtatAppli etat) async {
  final grille = etat.session.grilleCourante;
  final choix = await showDialog<({int lignes, int colonnes})>(
    context: context,
    builder: (_) => DialogueTaille(grille: grille),
  );
  if (choix == null) return;
  if (choix.lignes == grille.lignes && choix.colonnes == grille.colonnes) {
    return;
  }
  try {
    await etat.modifierDonnees(
      redimensionnerGrille(
        etat.session.donnees,
        grille.id,
        choix.lignes,
        choix.colonnes,
      ),
    );
  } on ErreurEdition {
    if (context.mounted) _message(context, Textes.erreurEdition);
  } on Exception {
    if (context.mounted) _message(context, Textes.erreurEnregistrement);
  }
}

void _message(BuildContext context, String texte) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texte)));

/// Lignes et colonnes de 1 à 8 pour [grille].
class DialogueTaille extends StatefulWidget {
  const DialogueTaille({super.key, required this.grille});

  final Grille grille;

  @override
  State<DialogueTaille> createState() => _DialogueTailleState();
}

class _DialogueTailleState extends State<DialogueTaille> {
  late int _lignes = widget.grille.lignes;
  late int _colonnes = widget.grille.colonnes;

  Widget _reglage({
    required String nom,
    required String prefixe,
    required int valeur,
    required String moins,
    required String plus,
    required ValueChanged<int> onChange,
  }) => Row(
    children: [
      Expanded(child: Text(nom)),
      IconButton(
        key: Key('$prefixe-moins'),
        tooltip: moins,
        icon: const Icon(Icons.remove),
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        onPressed: valeur > tailleMin ? () => onChange(valeur - 1) : null,
      ),
      SizedBox(
        width: 32,
        child: Text(
          '$valeur',
          key: Key('$prefixe-valeur'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      IconButton(
        key: Key('$prefixe-plus'),
        tooltip: plus,
        icon: const Icon(Icons.add),
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        onPressed: valeur < tailleMax ? () => onChange(valeur + 1) : null,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('dialogue-taille'),
      title: const Text(Textes.tailleGrille),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _reglage(
              nom: Textes.lignes,
              prefixe: 'lignes',
              valeur: _lignes,
              moins: Textes.moinsLignes,
              plus: Textes.plusLignes,
              onChange: (v) => setState(() => _lignes = v),
            ),
            _reglage(
              nom: Textes.colonnes,
              prefixe: 'colonnes',
              valeur: _colonnes,
              moins: Textes.moinsColonnes,
              plus: Textes.plusColonnes,
              onChange: (v) => setState(() => _colonnes = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Textes.annuler),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop((lignes: _lignes, colonnes: _colonnes)),
          child: const Text(Textes.enregistrer),
        ),
      ],
    );
  }
}
