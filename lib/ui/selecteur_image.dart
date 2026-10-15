import 'dart:io';

import 'package:flutter/material.dart';

import '../domaine/banque_pictos.dart';
import '../domaine/modeles.dart';
import '../domaine/source_photo.dart';
import 'etat_appli.dart';
import 'textes.dart';
import 'widgets/image_case.dart';

/// Image choisie ; [motCle] propose un libellé pour un pictogramme (REQ-015).
class ResultatImage {
  const ResultatImage(this.image, {this.motCle});

  final ImageCase image;
  final String? motCle;
}

/// Sélecteur d'image : recherche ARASAAC hors ligne, photo, galerie
/// (REQ-019, REQ-020). Renvoie un [ResultatImage], ou null si abandonné.
class SelecteurImage extends StatefulWidget {
  const SelecteurImage({
    super.key = const Key('ecran-selecteur-image'),
    required this.etat,
  });

  final EtatAppli etat;

  @override
  State<SelecteurImage> createState() => _SelecteurImageState();
}

class _SelecteurImageState extends State<SelecteurImage> {
  final TextEditingController _recherche = TextEditingController();
  List<Picto> _resultats = const [];
  String? _erreur;
  bool _occupe = false;

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  void _chercher(String terme) {
    final banque = widget.etat.banque;
    setState(() => _resultats = banque?.rechercher(terme) ?? const []);
  }

  bool get _photosDisponibles =>
      widget.etat.sourcePhoto != null && widget.etat.photos != null;

  Future<void> _photo(Future<String?> Function(SourcePhoto) obtenir) async {
    if (_occupe) return;
    final source = widget.etat.sourcePhoto!;
    final photos = widget.etat.photos!;
    setState(() {
      _occupe = true;
      _erreur = null;
    });
    String? message;
    String? nom;
    try {
      final chemin = await obtenir(source);
      if (chemin != null) nom = await photos.importer(chemin);
    } on PermissionRefusee catch (e) {
      message = e.origine == OrigineAcces.camera
          ? Textes.cameraRefusee
          : Textes.galerieRefusee;
    } on FileSystemException {
      message = Textes.erreurPhoto;
    }
    if (!mounted) return;
    if (nom != null) {
      Navigator.of(context).pop(ResultatImage(ImagePhoto(nom)));
      return;
    }
    setState(() {
      _occupe = false;
      _erreur = message;
    });
  }

  Widget _boutons() {
    final style = FilledButton.styleFrom(minimumSize: const Size(48, 56));
    final actif = _photosDisponibles && !_occupe;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          key: const Key('bouton-prendre-photo'),
          style: style,
          onPressed: actif ? () => _photo((s) => s.prendre()) : null,
          icon: const Icon(Icons.photo_camera),
          label: const Text(Textes.prendrePhoto),
        ),
        FilledButton.icon(
          key: const Key('bouton-galerie'),
          style: style,
          onPressed: actif ? () => _photo((s) => s.choisirGalerie()) : null,
          icon: const Icon(Icons.photo_library),
          label: const Text(Textes.choisirGalerie),
        ),
      ],
    );
  }

  Widget _cellule(Picto p) {
    final mot = p.motsCles.isEmpty ? '${p.id}' : p.motsCles.first;
    return Semantics(
      button: true,
      label: Textes.picto(mot),
      excludeSemantics: true,
      child: InkWell(
        key: Key('picto-${p.id}'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.of(context).pop(
          ResultatImage(
            ImageArasaac(p.id),
            motCle: p.motsCles.isEmpty ? null : p.motsCles.first,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              Expanded(child: ImageCaseWidget(ImageArasaac(p.id))),
              Text(
                mot,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final terme = _recherche.text.trim();
    final vide = terme.isNotEmpty && _resultats.isEmpty;
    final Widget corps;
    if (vide) {
      corps = Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(Textes.aucunPicto, key: Key('aucun-picto')),
              const SizedBox(height: 12),
              _boutons(),
            ],
          ),
        ),
      );
    } else if (terme.isEmpty) {
      corps = const Center(child: Text(Textes.indiceRecherche));
    } else {
      corps = GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 112,
          mainAxisExtent: 112,
        ),
        itemCount: _resultats.length,
        itemBuilder: (_, i) => _cellule(_resultats[i]),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text(Textes.choisirImage)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                key: const Key('champ-recherche'),
                controller: _recherche,
                autofocus: false,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  labelText: Textes.rechercherPicto,
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: _chercher,
              ),
              if (_erreur != null) ...[
                const SizedBox(height: 8),
                Text(
                  _erreur!,
                  key: const Key('erreur-photo'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 8),
              Expanded(child: corps),
              if (!vide) ...[const SizedBox(height: 8), _boutons()],
            ],
          ),
        ),
      ),
    );
  }
}
