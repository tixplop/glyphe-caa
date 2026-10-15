import 'dart:convert';

import 'texte_normalise.dart';

/// Un pictogramme de la banque embarquée.
class Picto {
  const Picto({required this.id, required this.motsCles});

  final int id;
  final List<String> motsCles;
}

/// Index de la banque ARASAAC embarquée, interrogeable hors ligne.
class BanquePictos {
  BanquePictos._(this._entrees);

  /// Construit la banque depuis le JSON `[{id, motsCles: [...]}]`.
  factory BanquePictos.depuisJson(String json) {
    final decode = jsonDecode(json);
    if (decode is! List) {
      throw const FormatException('Index de pictos invalide');
    }
    final entrees = <_Entree>[];
    for (final e in decode) {
      if (e is! Map || e['id'] is! int || e['motsCles'] is! List) {
        throw const FormatException('Entrée de picto invalide');
      }
      final mots = (e['motsCles'] as List).cast<String>();
      entrees.add(
        _Entree(
          Picto(id: e['id'] as int, motsCles: List.unmodifiable(mots)),
          mots.map(normaliserTexte).toList(),
        ),
      );
    }
    return BanquePictos._(entrees);
  }

  final List<_Entree> _entrees;

  int get taille => _entrees.length;

  /// Pictos dont un mot-clé correspond : exacts, puis préfixes, puis contenant.
  List<Picto> rechercher(String terme) {
    final t = normaliserTexte(terme);
    if (t.isEmpty) return const [];
    final exacts = <Picto>[];
    final prefixes = <Picto>[];
    final contenant = <Picto>[];
    for (final e in _entrees) {
      var rang = 3;
      for (final m in e.motsNormalises) {
        if (m == t) {
          rang = 0;
          break;
        } else if (m.startsWith(t)) {
          if (rang > 1) rang = 1;
        } else if (m.contains(t)) {
          if (rang > 2) rang = 2;
        }
      }
      switch (rang) {
        case 0:
          exacts.add(e.picto);
        case 1:
          prefixes.add(e.picto);
        case 2:
          contenant.add(e.picto);
      }
    }
    return [...exacts, ...prefixes, ...contenant];
  }
}

class _Entree {
  _Entree(this.picto, this.motsNormalises);

  final Picto picto;
  final List<String> motsNormalises;
}
