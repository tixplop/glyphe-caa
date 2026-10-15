/// Export / import d'une sauvegarde (REQ-023, REQ-024).
///
/// Archive ZIP : `glyphe.json` (données + réglages + version de format) et
/// `photos/<nom>`. Le code de déverrouillage n'y figure jamais (AC-023-3).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'modeles.dart';
import 'photos.dart';
import 'serialisation.dart';

const String nomFichierDonnees = 'glyphe.json';
const String prefixePhotos = 'photos/';

/// Bornes anti « zip bomb » appliquées avant toute décompression.
class LimitesSauvegarde {
  const LimitesSauvegarde({
    this.maxEntrees = 5000,
    this.maxTailleTotale = 200 * 1024 * 1024,
    this.maxTailleEntree = 25 * 1024 * 1024,
  });

  final int maxEntrees;
  final int maxTailleTotale;
  final int maxTailleEntree;
}

/// `glyphe-sauvegarde-AAAAMMJJ.zip`.
String nomFichierExport(DateTime date) {
  String deux(int n) => n.toString().padLeft(2, '0');
  final annee = date.year.toString().padLeft(4, '0');
  return 'glyphe-sauvegarde-$annee${deux(date.month)}${deux(date.day)}.zip';
}

/// Photos désignées par les cases de [donnees].
Set<String> photosReferencees(Donnees donnees) => {
  for (final g in donnees.grilles)
    for (final c in g.cases)
      if (c.image case ImagePhoto(:final fichier)) fichier,
};

/// Construit l'archive. Lève [FileSystemException] si une photo référencée
/// est introuvable (l'archive produite serait inimportable).
Uint8List exporter(Donnees donnees, Directory dossierPhotos) {
  final archive = Archive();
  final json = utf8.encode(jsonEncode(donneesVersJson(donnees)));
  archive.addFile(ArchiveFile(nomFichierDonnees, json.length, json));
  for (final nom in photosReferencees(donnees).toList()..sort()) {
    if (!nomPhotoValide(nom)) {
      throw FormatInvalide('nom de photo invalide : $nom');
    }
    final fichier = File('${dossierPhotos.path}/$nom');
    if (!fichier.existsSync()) {
      throw FileSystemException('Photo introuvable', fichier.path);
    }
    final octets = fichier.readAsBytesSync();
    archive.addFile(ArchiveFile('$prefixePhotos$nom', octets.length, octets));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

enum MotifErreur { invalide, tropRecente }

sealed class ResultatAnalyse {
  const ResultatAnalyse();
}

class ErreurSauvegarde extends ResultatAnalyse {
  const ErreurSauvegarde(this.motif, [this.detail = '']);
  final MotifErreur motif;
  final String detail;

  @override
  String toString() => 'ErreurSauvegarde($motif, $detail)';
}

/// Sauvegarde entièrement validée, prête à être installée.
class SauvegardeValide extends ResultatAnalyse {
  SauvegardeValide(this.donnees, Map<String, Uint8List> photos)
    : photos = Map.unmodifiable(photos) {
    for (final nom in photos.keys) {
      if (!nomPhotoValide(nom)) {
        throw ArgumentError.value(nom, 'photos', 'nom de photo invalide');
      }
    }
  }

  final Donnees donnees;
  final Map<String, Uint8List> photos;
}

ErreurSauvegarde _invalide(String detail) =>
    ErreurSauvegarde(MotifErreur.invalide, detail);

/// Valide intégralement [octets] sans rien écrire. [espion], réservé aux
/// tests, reçoit la taille de chaque bloc décompressé conservé.
ResultatAnalyse analyserSauvegarde(
  List<int> octets, {
  LimitesSauvegarde limites = const LimitesSauvegarde(),
  void Function(int octets)? espion,
}) {
  try {
    return _analyser(octets, limites, espion);
  } on FormatInvalide catch (e) {
    return _invalide(e.message);
  } on Object catch (e) {
    // Archive tronquée, corrompue, UTF-8 invalide, etc.
    return _invalide('$e');
  }
}

ResultatAnalyse _analyser(
  List<int> octets,
  LimitesSauvegarde limites,
  void Function(int octets)? espion,
) {
  // 1. Contrôle des seuls en-têtes : rien n'est décompressé à ce stade.
  final repertoire = ZipDirectory.read(InputStream(octets));
  final entetes = repertoire.fileHeaders;
  if (entetes.length > limites.maxEntrees) {
    return _invalide('trop d\'entrées : ${entetes.length}');
  }
  final noms = <String>{};
  final entrees = <_Entree>[];
  var total = 0;
  for (final h in entetes) {
    final nom = h.filename;
    final erreur = _erreurNom(nom);
    if (erreur != null) return _invalide('$erreur : $nom');
    if (!noms.add(nom)) return _invalide('entrée en double : $nom');
    final unix = (h.versionMadeBy >> 8) == 3;
    final typeUnix = ((h.externalFileAttributes ?? 0) >> 16) & 0xF000;
    if (unix &&
        typeUnix != 0x8000 &&
        typeUnix != 0x0000 &&
        typeUnix != 0x4000) {
      return _invalide('lien ou fichier spécial refusé : $nom');
    }
    final centrale = h.uncompressedSize ?? -1;
    final entree = _lireEntree(octets, h);
    if (entree == null) return _invalide('en-tête local incohérent : $nom');
    // La taille locale est lue dans les octets bruts (le décodeur la
    // remplace par celle du répertoire central).
    if (centrale < 0 ||
        (entree.tailleLocale != null && centrale != entree.tailleLocale)) {
      return _invalide('taille incohérente : $nom');
    }
    if (centrale > limites.maxTailleEntree) {
      return _invalide('entrée trop volumineuse : $nom');
    }
    total += centrale;
    if (total > limites.maxTailleTotale) {
      return _invalide('archive trop volumineuse');
    }
    entrees.add(entree);
  }
  if (!noms.contains(nomFichierDonnees)) {
    return _invalide('$nomFichierDonnees absent');
  }

  // 2. Décompression bornée de chaque entrée, puis CRC sur la sortie bornée.
  Uint8List? json;
  final photos = <String, Uint8List>{};
  var reel = 0;
  for (final e in entrees) {
    if (e.nom == prefixePhotos) continue; // dossier
    final borne = [
      e.tailleDeclaree,
      limites.maxTailleEntree,
      limites.maxTailleTotale - reel,
    ].reduce((a, b) => a < b ? a : b);
    final contenu = _extraire(e, borne, espion);
    if (contenu == null || contenu.length != e.tailleDeclaree) {
      return _invalide('taille réelle incohérente : ${e.nom}');
    }
    if (getCrc32(contenu) != e.crc32) {
      return _invalide('CRC invalide : ${e.nom}');
    }
    reel += contenu.length;
    if (e.nom == nomFichierDonnees) {
      json = contenu;
    } else {
      photos[e.nom.substring(prefixePhotos.length)] = contenu;
    }
  }
  if (json == null) return _invalide('$nomFichierDonnees absent');

  // 3. Données.
  final brut = jsonDecode(utf8.decode(json));
  if (brut is Map && brut['versionFormat'] is int) {
    final v = brut['versionFormat'] as int;
    if (v > versionFormatCourant) {
      return const ErreurSauvegarde(MotifErreur.tropRecente);
    }
  }
  final donnees = donneesDepuisJson(brut);
  final requises = photosReferencees(donnees);
  for (final nom in requises) {
    if (!photos.containsKey(nom)) return _invalide('photo absente : $nom');
  }
  // Les photos non référencées sont ignorées (jamais installées).
  photos.removeWhere((nom, _) => !requises.contains(nom));
  return SauvegardeValide(donnees, photos);
}

/// Null si le nom d'entrée est acceptable : `glyphe.json`, `photos/` ou
/// `photos/<nom valide>`. Le nom est celui des octets de l'archive.
String? _erreurNom(String nom) {
  if (nom == nomFichierDonnees || nom == prefixePhotos) return null;
  if (nom.contains(r'\')) return 'antislash refusé';
  if (nom.startsWith('/')) return 'chemin absolu refusé';
  if (nom.split('/').contains('..')) return 'chemin « .. » refusé';
  if (!nom.startsWith(prefixePhotos)) return 'entrée inattendue';
  final reste = nom.substring(prefixePhotos.length);
  if (!nomPhotoValide(reste)) return 'nom de photo invalide';
  return null;
}

/// Entrée validée au niveau des en-têtes, prête à être extraite.
class _Entree {
  _Entree(
    this.nom,
    this.methode,
    this.crc32,
    this.tailleDeclaree,
    this.tailleLocale,
    this.donnees,
  );
  final String nom;
  final int methode;
  final int crc32;
  final int tailleDeclaree;

  /// Taille lue dans l'en-tête local ; null si elle y est différée
  /// (descripteur de données).
  final int? tailleLocale;
  final Uint8List donnees; // octets compressés (vue, sans copie)
}

int _u16(Uint8List b, int i) => b[i] | (b[i + 1] << 8);
int _u32(Uint8List b, int i) => _u16(b, i) | (_u16(b, i + 2) << 16);

/// Lit l'en-tête local brut de [h] ; null s'il est incohérent.
_Entree? _lireEntree(List<int> source, ZipFileHeader h) {
  final b = source is Uint8List ? source : Uint8List.fromList(source);
  final debut = h.localHeaderOffset ?? -1;
  final compresse = h.compressedSize ?? -1;
  if (debut < 0 || compresse < 0 || debut + 30 > b.length) return null;
  if (_u32(b, debut) != 0x04034b50) return null;
  final flags = _u16(b, debut + 6);
  if (flags & 0x1 != 0) return null; // chiffrée
  final methode = _u16(b, debut + 8);
  if (methode != 0 && methode != 8) return null;
  final differe = flags & 0x8 != 0;
  final localeUnc = _u32(b, debut + 22);
  final donneesDebut = debut + 30 + _u16(b, debut + 26) + _u16(b, debut + 28);
  if (donneesDebut + compresse > b.length) return null;
  if (!differe && _u32(b, debut + 18) != compresse) return null;
  return _Entree(
    h.filename,
    methode,
    h.crc32 ?? 0,
    h.uncompressedSize ?? -1,
    differe ? null : localeUnc,
    Uint8List.sublistView(b, donneesDebut, donneesDebut + compresse),
  );
}

/// Taille d'un morceau d'entrée fournie à l'inflateur.
const int _tailleMorceau = 4096;

/// Décompresse [e] en produisant au plus [borne] + 1 octets : null si la
/// sortie dépasse [borne] ou si le flux est invalide.
Uint8List? _extraire(_Entree e, int borne, void Function(int)? espion) {
  if (borne < 0) return null;
  if (e.methode == 0) {
    if (e.donnees.length > borne) return null;
    espion?.call(e.donnees.length);
    return e.donnees;
  }
  final filtre = RawZLibFilter.inflateFilter(raw: true);
  final sortie = BytesBuilder(copy: false);
  final d = e.donnees;
  for (var i = 0; i < d.length; i += _tailleMorceau) {
    final fin = i + _tailleMorceau < d.length ? i + _tailleMorceau : d.length;
    filtre.process(d, i, fin);
    while (true) {
      final bloc = filtre.processed(flush: true);
      if (bloc == null || bloc.isEmpty) break;
      if (sortie.length + bloc.length > borne) {
        // Arrêt immédiat : seule la part utile (au plus borne + 1) est vue.
        espion?.call(borne + 1 - sortie.length);
        return null;
      }
      espion?.call(bloc.length);
      sortie.add(bloc);
    }
  }
  return sortie.takeBytes();
}
