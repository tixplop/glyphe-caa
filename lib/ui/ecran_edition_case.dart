import 'package:flutter/material.dart';

import '../domaine/edition.dart';
import '../domaine/modeles.dart';
import 'etat_appli.dart';
import 'selecteur_image.dart';
import 'textes.dart';
import 'tokens.dart';
import 'widgets/bouton_retour.dart';
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
  late Categorie _categorie;
  late ImageCase _image;
  String? _cible;
  String? _erreur;
  final FocusNode _focusLibelle = FocusNode();
  final FocusNode _focusCible = FocusNode();

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
    _categorie = c?.categorie ?? Categorie.petitMot;
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
    _focusLibelle.dispose();
    _focusCible.dispose();
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
            etat.nouvelId('c'),
            Textes.retour,
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
      categorie: _categorie,
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
      _focaliser(e.code);
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

  /// Place le focus sur le champ concerné par l'erreur (V-003).
  void _focaliser(CodeErreurEdition code) {
    switch (code) {
      case CodeErreurEdition.contenuVide:
        _focusLibelle.requestFocus();
      case CodeErreurEdition.cibleManquante:
        _focusCible.requestFocus();
      default:
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

  Widget _categories() {
    final t = GlypheTokens.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final c in Categorie.values) _optionCategorie(t, c)],
    );
  }

  Widget _optionCategorie(GlypheTokens t, Categorie c) {
    final choisie = _categorie == c;
    final (fond, contour) = t.categorie(c);
    final nom = Textes.nomCategorie(c);
    return Semantics(
      button: true,
      selected: choisie,
      label: nom,
      excludeSemantics: true,
      child: InkWell(
        key: Key('categorie-${c.name}'),
        onTap: () => setState(() => _categorie = c),
        borderRadius: BorderRadius.circular(GlypheTokens.rayonSm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: GlypheTokens.toucheMin),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: fond,
              borderRadius: BorderRadius.circular(GlypheTokens.rayonSm),
              border: Border.all(
                color: contour,
                width: GlypheTokens.contourCase,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (choisie) ...[
                  Icon(Icons.check, color: t.ink),
                  const SizedBox(width: 4),
                ],
                Text(nom, style: TextStyle(color: t.ink)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _selecteurCible() {
    final proposees = _proposees;
    return DropdownButton<String>(
      key: const Key('champ-cible'),
      focusNode: _focusCible,
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

  Widget _action(
    Key cle,
    IconData icone,
    String libelle,
    Color couleur,
    VoidCallback f,
  ) => IconButton(
    key: cle,
    tooltip: libelle,
    icon: Icon(icone, size: 24, color: couleur),
    constraints: const BoxConstraints.tightFor(
      width: GlypheTokens.toucheMin,
      height: GlypheTokens.toucheMin,
    ),
    onPressed: f,
  );

  /// Aperçu de l'image (AC-036-4, AC-036-10) : ouvre le sélecteur.
  Widget _apercu(GlypheTokens t) => Tooltip(
    message: Textes.image,
    excludeFromSemantics: true,
    child: Semantics(
      button: true,
      label: Textes.image,
      onTap: _choisirImage,
      excludeSemantics: true,
      child: Material(
        color: t.surface000,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GlypheTokens.rayonMd),
          side: BorderSide(color: t.border, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('bouton-image'),
          onTap: _choisirImage,
          child: SizedBox.square(
            dimension: 72,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Center(
                child: _image is ImageAucune
                    ? Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 32,
                        color: t.ink,
                      )
                    : ImageCaseWidget(_image),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final existante = _existante;
    final dossier = _type == TypeCase.dossier;
    final cibleValide =
        existante?.cibleId != null &&
        _donnees.grillePar(existante!.cibleId!) != null;
    final t = GlypheTokens.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const BoutonRetour(),
        title: Text(
          existante == null ? Textes.nouvelleCase : Textes.editionCase,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
        actions: [
          if (existante != null)
            _action(
              const Key('bouton-supprimer'),
              Icons.delete_outline,
              Textes.supprimer,
              t.danger,
              _supprimer,
            ),
          if (existante != null)
            _action(
              const Key('bouton-echanger'),
              Icons.swap_horiz,
              Textes.echanger,
              t.ink,
              _echanger,
            ),
          if (existante != null &&
              existante.type == TypeCase.dossier &&
              cibleValide)
            _action(
              const Key('bouton-ouvrir'),
              Icons.folder_open_outlined,
              Textes.ouvrir,
              t.ink,
              _ouvrir,
            ),
          IconButton(
            key: const Key('bouton-enregistrer'),
            tooltip: Textes.enregistrer,
            icon: Icon(Icons.check, size: 24, color: t.onPrimary),
            style: IconButton.styleFrom(
              backgroundColor: t.primary,
              minimumSize: const Size.square(GlypheTokens.toucheMin),
              fixedSize: const Size.square(GlypheTokens.toucheMin),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(GlypheTokens.rayonMd),
              ),
            ),
            onPressed: _enregistrer,
          ),
          const SizedBox(width: GlypheTokens.espace2),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _apercu(t),
                  const SizedBox(width: GlypheTokens.espace3),
                  Expanded(
                    child: TextField(
                      key: const Key('champ-libelle'),
                      focusNode: _focusLibelle,
                      controller: _libelle,
                      decoration: const InputDecoration(
                        labelText: Textes.libelle,
                      ),
                    ),
                  ),
                ],
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
              const Text(Textes.categorie),
              const SizedBox(height: 8),
              _categories(),
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
                  style: TextStyle(color: t.danger),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
