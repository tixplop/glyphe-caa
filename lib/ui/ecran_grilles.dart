import 'package:flutter/material.dart';

import '../domaine/edition.dart';
import '../domaine/modeles.dart';
import 'etat_appli.dart';
import 'textes.dart';
import 'tokens.dart';
import 'widgets/bouton_retour.dart';
import 'widgets/titre_barre.dart';

/// Liste de toutes les grilles : renommer, ouvrir, supprimer (REQ-017).
class EcranGrilles extends StatelessWidget {
  const EcranGrilles({super.key, required this.etat});

  final EtatAppli etat;

  void _message(BuildContext context, String texte) =>
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(texte)));

  Future<void> _appliquer(
    BuildContext context,
    Donnees Function(Donnees) operation,
  ) async {
    try {
      await etat.modifierDonnees(operation(etat.session.donnees));
    } on ErreurEdition {
      if (context.mounted) _message(context, Textes.erreurEdition);
    } on Exception {
      if (context.mounted) _message(context, Textes.erreurEnregistrement);
    }
  }

  Future<void> _renommer(BuildContext context, Grille g) async {
    final nom = await showDialog<String>(
      context: context,
      builder: (_) => _DialogueNom(nomInitial: g.nom),
    );
    if (nom == null || !context.mounted) return;
    await _appliquer(context, (d) => renommerGrille(d, g.id, nom));
  }

  Future<void> _supprimer(BuildContext context, Grille g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: GlypheTokens.espace5,
          vertical: GlypheTokens.espace3,
        ),
        key: const Key('dialogue-suppression-grille'),
        title: const Text(Textes.supprimerGrille),
        content: Text(Textes.confirmationSuppressionGrille(g.nom)),
        actions: [
          TextButton(
            key: const Key('annuler-suppression'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(Textes.annuler),
          ),
          FilledButton(
            key: const Key('confirmer-suppression'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(Textes.supprimer),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _appliquer(context, (d) => supprimerGrille(d, g.id));
  }

  void _ouvrir(BuildContext context, Grille g) {
    etat.session.ouvrirGrille(g.id);
    Navigator.of(context).pop();
  }

  Widget _action(String cle, String nom, IconData icone, VoidCallback f) =>
      IconButton(
        key: Key(cle),
        tooltip: nom,
        icon: Icon(icone),
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        onPressed: f,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('ecran-grilles'),
      appBar: AppBar(
        title: const TitreBarre(Textes.grilles),
        leading: const BoutonRetour(),
      ),
      body: ListenableBuilder(
        listenable: etat.session,
        builder: (context, _) {
          final donnees = etat.session.donnees;
          return ListView(
            children: [
              for (final g in donnees.grilles)
                ListTile(
                  key: Key('grille-${g.id}'),
                  minTileHeight: 56,
                  title: Text(g.nom),
                  onTap: () => _ouvrir(context, g),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _action(
                        'ouvrir-${g.id}',
                        Textes.ouvrirGrille(g.nom),
                        Icons.edit_outlined,
                        () => _ouvrir(context, g),
                      ),
                      _action(
                        'renommer-${g.id}',
                        Textes.renommerGrille(g.nom),
                        Icons.drive_file_rename_outline,
                        () => _renommer(context, g),
                      ),
                      // Pas de suppression pour l'accueil (AC-017-3).
                      if (g.id != donnees.accueilId)
                        _action(
                          'supprimer-${g.id}',
                          Textes.supprimerLaGrille(g.nom),
                          Icons.delete_outline,
                          () => _supprimer(context, g),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DialogueNom extends StatefulWidget {
  const _DialogueNom({required this.nomInitial});

  final String nomInitial;

  @override
  State<_DialogueNom> createState() => _DialogueNomState();
}

class _DialogueNomState extends State<_DialogueNom> {
  late final TextEditingController _nom = TextEditingController(
    text: widget.nomInitial,
  );
  String? _erreur;

  @override
  void dispose() {
    _nom.dispose();
    super.dispose();
  }

  void _valider() {
    if (_nom.text.trim().isEmpty) {
      setState(() => _erreur = Textes.erreurNomGrille);
      return;
    }
    Navigator.of(context).pop(_nom.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: GlypheTokens.espace5,
        vertical: GlypheTokens.espace3,
      ),
      title: const Text(Textes.renommer),
      content: TextField(
        key: const Key('champ-nom-grille'),
        controller: _nom,
        autofocus: true,
        decoration: InputDecoration(
          labelText: Textes.nomGrille,
          errorText: _erreur,
        ),
        onSubmitted: (_) => _valider(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Textes.annuler),
        ),
        FilledButton(
          onPressed: _valider,
          child: const Text(Textes.enregistrer),
        ),
      ],
    );
  }
}
