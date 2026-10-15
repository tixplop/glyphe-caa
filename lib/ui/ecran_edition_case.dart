import 'package:flutter/material.dart';

import '../domaine/edition.dart';
import '../domaine/modeles.dart';
import 'etat_appli.dart';
import 'selecteur_image.dart';
import 'textes.dart';
import 'theme.dart';
import 'widgets/image_case.dart';

const String _valeurNouvelleGrille = '__nouvelle_grille__';

/// Écran d'édition d'une case existante ou d'un emplacement vide
/// (REQ-015, REQ-016).
class EcranEditionCase extends StatefulWidget {
  const EcranEditionCase({
    super.key = const Key('ecran-edition-case'),
    required this.etat,
    required this.grilleId,
    this.caseExistante,
    this.ligne,
    this.colonne,
  }) : assert(
         caseExistante != null || (ligne != null && colonne != null),
         'une case existante ou un emplacement est requis',
       );

  final EtatAppli etat;
  final String grilleId;
  final Case? caseExistante;

  /// Emplacement d'une nouvelle case.
  final int? ligne;
  final int? colonne;

  @override
  State<EcranEditionCase> createState() => _EcranEditionCaseState();
}

class _EcranEditionCaseState extends State<EcranEditionCase> {
  late final TextEditingController _libelle;
  late final TextEditingController _texte;
  late TypeCase _type;
  late int? _couleur;
  late ImageCase _image;
  String? _cible;
  String? _erreur;

  /// Une photo a été importée pendant l'édition : à nettoyer si non retenue.
  bool _photoImportee = false;

  Case? get _existante => widget.caseExistante;

  @override
  void initState() {
    super.initState();
    final c = _existante;
    _libelle = TextEditingController(text: c?.libelle ?? '');
    _texte = TextEditingController(text: c?.textePrononce ?? '');
    _type = c?.type ?? TypeCase.mot;
    _couleur = c?.couleur;
    _image = c?.image ?? const ImageAucune();
    final cible = c?.cibleId;
    _cible = cible != null && _proposees.any((g) => g.id == cible)
        ? cible
        : null;
  }

  @override
  void dispose() {
    _libelle.dispose();
    _texte.dispose();
    if (_photoImportee) widget.etat.nettoyerPhotos();
    super.dispose();
  }

  Future<void> _choisirImage() async {
    final r = await Navigator.of(context).push<ResultatImage>(
      MaterialPageRoute(builder: (_) => SelecteurImage(etat: widget.etat)),
    );
    if (r == null || !mounted) return;
    setState(() {
      _image = r.image;
      if (r.image is ImagePhoto) _photoImportee = true;
      final mot = r.motCle;
      if (mot != null && _libelle.text.trim().isEmpty) _libelle.text = mot;
    });
  }

  Donnees get _donnees => widget.etat.session.donnees;
  List<Grille> get _proposees => ciblesProposees(_donnees, widget.grilleId);

  String _message(CodeErreurEdition code) => switch (code) {
    CodeErreurEdition.contenuVide => Textes.erreurContenuVide,
    CodeErreurEdition.cibleManquante => Textes.erreurCible,
    CodeErreurEdition.grillePleine => Textes.erreurGrillePleine,
    _ => Textes.erreurEdition,
  };

  Future<void> _enregistrer() async {
    final etat = widget.etat;
    final existante = _existante;
    final libelle = _libelle.text.trim();
    final dossier = _type == TypeCase.dossier;
    final nouvelle = dossier && _cible == _valeurNouvelleGrille
        ? nouvelleGrillePourDossier(
            libelle.isEmpty ? Textes.nomNouvelleGrille : libelle,
            etat.nouvelId('g'),
          )
        : null;
    final c = Case(
      id: existante?.id ?? etat.nouvelId('c'),
      ligne: existante?.ligne ?? widget.ligne!,
      colonne: existante?.colonne ?? widget.colonne!,
      type: _type,
      libelle: libelle,
      textePrononce: _texte.text.trim(),
      image: _image,
      couleur: _couleur,
      cibleId: dossier && nouvelle == null && _cible != _valeurNouvelleGrille
          ? _cible
          : null,
    );
    try {
      final d = existante == null
          ? ajouterCase(
              _donnees,
              widget.grilleId,
              c,
              ligne: c.ligne,
              colonne: c.colonne,
              nouvelleGrille: nouvelle,
            )
          : modifierCase(
              _donnees,
              widget.grilleId,
              c,
              nouvelleGrille: nouvelle,
            );
      await _appliquer(d);
    } on ErreurEdition catch (e) {
      // Grille remplie pendant l'édition : même consigne que grille pleine.
      final pleine =
          e.code == CodeErreurEdition.emplacementInvalide &&
          existante == null &&
          _donnees.grillePar(widget.grilleId)?.emplacementLibre() == null;
      setState(
        () => _erreur = pleine ? Textes.erreurGrillePleine : _message(e.code),
      );
    }
  }

  /// Persiste puis ferme l'écran ; en cas d'échec d'écriture, le message
  /// reste affiché sur l'écran.
  Future<void> _appliquer(Donnees d) async {
    try {
      await widget.etat.modifierDonnees(d);
    } catch (_) {
      if (mounted) setState(() => _erreur = Textes.erreurEnregistrement);
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _supprimer() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('confirmation-suppression'),
        title: const Text(Textes.confirmerSuppression),
        actions: [
          TextButton(
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
    if (ok != true || !mounted) return;
    try {
      await _appliquer(
        supprimerCase(_donnees, widget.grilleId, _existante!.id),
      );
    } on ErreurEdition catch (e) {
      setState(() => _erreur = _message(e.code));
    }
  }

  void _ouvrir() {
    final c = _existante!;
    Navigator.of(context).pop();
    widget.etat.session.appuyerCase(c);
  }

  Future<void> _echanger() async {
    final grille = _donnees.grillePar(widget.grilleId)!;
    final c = _existante!;
    final choix = await showDialog<(int, int)>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text(Textes.choisirEmplacement),
        children: [
          for (var l = 0; l < grille.lignes; l++)
            Wrap(
              children: [
                for (var col = 0; col < grille.colonnes; col++)
                  if (l != c.ligne || col != c.colonne)
                    _boutonEmplacement(ctx, grille, l, col),
              ],
            ),
        ],
      ),
    );
    if (choix == null || !mounted) return;
    try {
      await _appliquer(
        echangerEmplacements(
          _donnees,
          widget.grilleId,
          c.id,
          choix.$1,
          choix.$2,
        ),
      );
    } on ErreurEdition catch (e) {
      setState(() => _erreur = _message(e.code));
    }
  }

  Widget _boutonEmplacement(BuildContext ctx, Grille g, int l, int col) {
    final occupant = g.cases
        .where((x) => x.ligne == l && x.colonne == col)
        .firstOrNull;
    final nom = occupant == null || occupant.libelle.isEmpty
        ? '${l + 1}.${col + 1}'
        : '${l + 1}.${col + 1} ${occupant.libelle}';
    return Padding(
      padding: const EdgeInsets.all(4),
      child: OutlinedButton(
        key: Key('emplacement-$l-$col'),
        style: OutlinedButton.styleFrom(minimumSize: const Size(56, 56)),
        onPressed: () => Navigator.of(ctx).pop((l, col)),
        child: Semantics(
          label: Textes.emplacement(l, col),
          excludeSemantics: true,
          child: Text(nom),
        ),
      ),
    );
  }

  Widget _couleurs() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _pastille(
        const Key('couleur-defaut'),
        PaletteCases.parDefaut,
        null,
        Textes.couleurDefaut,
      ),
      for (var i = 0; i < PaletteCases.couleurs.length; i++)
        _pastille(
          Key('couleur-$i'),
          PaletteCases.couleurs[i],
          PaletteCases.couleurs[i].toARGB32(),
          '${Textes.couleur} ${i + 1}',
        ),
    ],
  );

  Widget _pastille(Key key, Color fond, int? valeur, String nom) {
    final choisie = _couleur == valeur;
    return Semantics(
      button: true,
      selected: choisie,
      label: nom,
      excludeSemantics: true,
      child: InkWell(
        key: key,
        onTap: () => setState(() => _couleur = valeur),
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: fond,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black, width: choisie ? 4 : 1),
          ),
          child: choisie ? const Icon(Icons.check, color: Colors.black) : null,
        ),
      ),
    );
  }

  Widget _selecteurCible() {
    final proposees = _proposees;
    return DropdownButton<String>(
      key: const Key('champ-cible'),
      isExpanded: true,
      hint: const Text(Textes.grilleCible),
      value: _cible,
      items: [
        for (final g in proposees)
          DropdownMenuItem(value: g.id, child: Text(g.nom)),
        const DropdownMenuItem(
          value: _valeurNouvelleGrille,
          child: Text(Textes.nouvelleGrille),
        ),
      ],
      onChanged: (v) => setState(() => _cible = v),
    );
  }

  @override
  Widget build(BuildContext context) {
    final existante = _existante;
    final dossier = _type == TypeCase.dossier;
    final cibleValide =
        existante?.cibleId != null &&
        _donnees.grillePar(existante!.cibleId!) != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          existante == null ? Textes.nouvelleCase : Textes.editionCase,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              key: const Key('champ-libelle'),
              controller: _libelle,
              decoration: const InputDecoration(labelText: Textes.libelle),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('champ-texte'),
              controller: _texte,
              decoration: const InputDecoration(
                labelText: Textes.textePrononce,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(width: 56, height: 56, child: ImageCaseWidget(_image)),
                const SizedBox(width: 12),
                OutlinedButton(
                  key: const Key('bouton-image'),
                  onPressed: _choisirImage,
                  child: const Text(Textes.image),
                ),
                const SizedBox(width: 12),
                if (_image is ImageAucune) const Text(Textes.imageAucune),
              ],
            ),
            const SizedBox(height: 16),
            const Text(Textes.couleur),
            const SizedBox(height: 8),
            _couleurs(),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  key: const Key('type-mot'),
                  label: const Text(Textes.typeMot),
                  selected: !dossier,
                  onSelected: (_) => setState(() => _type = TypeCase.mot),
                ),
                ChoiceChip(
                  key: const Key('type-dossier'),
                  label: const Text(Textes.typeDossier),
                  selected: dossier,
                  onSelected: (_) => setState(() => _type = TypeCase.dossier),
                ),
              ],
            ),
            if (dossier) ...[const SizedBox(height: 8), _selecteurCible()],
            if (_erreur != null) ...[
              const SizedBox(height: 12),
              Text(
                _erreur!,
                key: const Key('erreur-edition'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _enregistrer,
              child: const Text(Textes.enregistrer),
            ),
            if (existante != null) ...[
              if (existante.type == TypeCase.dossier && cibleValide)
                TextButton(
                  onPressed: _ouvrir,
                  child: const Text(Textes.ouvrir),
                ),
              TextButton(
                onPressed: _echanger,
                child: const Text(Textes.echanger),
              ),
              TextButton(
                onPressed: _supprimer,
                child: const Text(Textes.supprimer),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
