import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/modeles.dart';
import 'package:glyphe/domaine/session.dart';

import 'package:glyphe/domaine/voix.dart';

import '../faux/faux_voix.dart';
import '../faux/fausse_horloge.dart';

Case mot(String id, String lib, {String texte = '', int col = 0}) => Case(
  id: id,
  ligne: 0,
  colonne: col,
  type: TypeCase.mot,
  libelle: lib,
  textePrononce: texte,
  image: ImageArasaac(col + 1),
);

Case dossier(String id, String lib, String? cible) => Case(
  id: id,
  ligne: 1,
  colonne: 0,
  type: TypeCase.dossier,
  libelle: lib,
  cibleId: cible,
);

Donnees donnees({Reglages reglages = const Reglages()}) {
  return Donnees(
    accueilId: 'acc',
    reglages: reglages,
    grilles: [
      Grille(
        id: 'acc',
        nom: 'Accueil',
        lignes: 4,
        colonnes: 4,
        cases: [
          mot('je', 'je', col: 0),
          mot('veux', 'veux', col: 1),
          mot('manger', 'manger', col: 2),
          mot('eau', 'eau', col: 3),
          mot('wc', 'WC', texte: 'je veux aller aux toilettes'),
          mot('photo', '', col: 1),
          dossier('d-manger', 'Manger', 'manger-g'),
          dossier('d-orph', 'Perdu', 'inexistante'),
        ],
      ),
      Grille(
        id: 'manger-g',
        nom: 'Manger',
        lignes: 4,
        colonnes: 4,
        cases: [
          mot('pomme', 'pomme'),
          dossier('d-fruits', 'Fruits', 'fruits-g'),
        ],
      ),
      Grille(
        id: 'fruits-g',
        nom: 'Fruits',
        lignes: 4,
        colonnes: 4,
        cases: [mot('poire', 'poire')],
      ),
    ],
  );
}

({Session s, FauxVoix v, FausseHorloge h}) cree({Donnees? d}) {
  final v = FauxVoix();
  final h = FausseHorloge();
  return (s: Session(d ?? donnees(), v, h), v: v, h: h);
}

Case c(Session s, String id) =>
    s.grilleCourante.cases.firstWhere((x) => x.id == id);

List<String> libelles(Session s) => [for (final e in s.barre) e.libelle];

class VoixQuiLeve extends FauxVoix {
  @override
  Future<void> parler(String texte, ParametresVoix parametres) async =>
      throw StateError('voix indisponible');

  @override
  Future<void> arreter() async => throw StateError('voix indisponible');
}

void main() {
  group('REQ-002 parole et ajout', () {
    test('REQ002_AC1 texte prononcé dit et élément ajouté', () async {
      final t = cree();
      await t.s.appuyerCase(c(t.s, 'wc'));
      expect(t.v.textesPrononces, ['je veux aller aux toilettes']);
      expect(t.s.barre, hasLength(1));
      expect(t.s.barre.single.image, const ImageArasaac(1));
    });

    test('REQ002_AC2 libellé prononcé si texte vide', () async {
      final t = cree();
      await t.s.appuyerCase(c(t.s, 'eau'));
      expect(t.v.textesPrononces, ['eau']);
    });

    test('REQ002_AC3 WC affiché, phrase dite', () async {
      final t = cree();
      await t.s.appuyerCase(c(t.s, 'wc'));
      expect(libelles(t.s), ['WC']);
      expect(t.v.textesPrononces.single, 'je veux aller aux toilettes');
    });

    test('REQ002_AC4 réglages de voix appliqués', () async {
      final t = cree(
        d: donnees(
          reglages: const Reglages(
            voixId: 'v1',
            debit: 1.5,
            hauteur: 0.8,
            volume: 0.5,
            delaiAntiRepetitionMs: 0,
          ),
        ),
      );
      await t.s.appuyerCase(c(t.s, 'eau'));
      final p = t.v.parametresAppels.single;
      expect([p.voixId, p.debit, p.hauteur, p.volume], ['v1', 1.5, 0.8, 0.5]);
    });

    test('REQ002 case photo seule : rien dit, élément ajouté', () async {
      final t = cree();
      await t.s.appuyerCase(c(t.s, 'photo'));
      expect(t.v.journal, isEmpty);
      expect(t.s.barre, hasLength(1));
    });
  });

  group('REQ-003 interruption', () {
    test('REQ003_AC1 stop puis parler', () async {
      final t = cree();
      await t.s.appuyerCase(c(t.s, 'je'));
      await t.s.appuyerCase(c(t.s, 'veux'));
      expect(t.v.journal, ['stop', 'parler:je', 'stop', 'parler:veux']);
    });

    test(
      'REQ003_AC2 stop émis avant parler(eau) pendant une lecture',
      () async {
        final t = cree();
        await t.s.appuyerCase(c(t.s, 'je'));
        await t.s.appuyerCase(c(t.s, 'veux'));
        await t.s.lireBarre();
        t.v.journal.clear();
        await t.s.appuyerCase(c(t.s, 'eau'));
        expect(t.v.journal, ['stop', 'parler:eau']);
      },
    );
  });

  group('REQ-004 anti-répétition', () {
    test('REQ004_AC1 délai 0 : deux appuis, deux éléments', () async {
      expect(const Reglages().delaiAntiRepetitionMs, 0);
      final t = cree();
      await t.s.appuyerCase(c(t.s, 'eau'));
      await t.s.appuyerCase(c(t.s, 'eau'));
      expect(t.v.textesPrononces, ['eau', 'eau']);
      expect(t.s.barre, hasLength(2));
    });

    Donnees avecDelai() =>
        donnees(reglages: const Reglages(delaiAntiRepetitionMs: 1000));

    test('REQ004_AC2 même case dans le délai ignorée', () async {
      final t = cree(d: avecDelai());
      await t.s.appuyerCase(c(t.s, 'eau'));
      t.h.avancer(const Duration(milliseconds: 500));
      await t.s.appuyerCase(c(t.s, 'eau'));
      expect(t.v.textesPrononces, ['eau']);
      expect(t.s.barre, hasLength(1));
    });

    test('REQ004_AC3 même case après le délai acceptée', () async {
      final t = cree(d: avecDelai());
      await t.s.appuyerCase(c(t.s, 'eau'));
      t.h.avancer(const Duration(milliseconds: 1000));
      await t.s.appuyerCase(c(t.s, 'eau'));
      expect(t.v.textesPrononces, ['eau', 'eau']);
      expect(t.s.barre, hasLength(2));
    });

    test('REQ004_AC4 autre case dans le délai acceptée', () async {
      final t = cree(d: avecDelai());
      await t.s.appuyerCase(c(t.s, 'je'));
      t.h.avancer(const Duration(milliseconds: 100));
      await t.s.appuyerCase(c(t.s, 'eau'));
      expect(t.v.textesPrononces, ['je', 'eau']);
      expect(t.s.barre, hasLength(2));
    });
  });

  group('REQ-005 voix indisponible', () {
    test('voixIndisponible : élément ajouté quand même', () async {
      final h = FausseHorloge();
      final session = Session(donnees(), VoixQuiLeve(), h);
      await session.appuyerCase(c(session, 'eau'));
      expect(session.barre, hasLength(1));
      expect(session.barre.single.libelle, 'eau');
    });
  });

  group('REQ-006 lecture de la barre', () {
    Future<({Session s, FauxVoix v, FausseHorloge h})> trois() async {
      final t = cree();
      for (final id in ['je', 'veux', 'manger']) {
        await t.s.appuyerCase(c(t.s, id));
      }
      t.v.journal.clear();
      return t;
    }

    test('REQ006_AC1 une seule prononciation jointe', () async {
      final t = await trois();
      await t.s.lireBarre();
      expect(t.v.textesPrononces, ['je veux manger']);
    });

    test('REQ006_AC2 barre inchangée', () async {
      final t = await trois();
      await t.s.lireBarre();
      expect(libelles(t.s), ['je', 'veux', 'manger']);
    });

    test('REQ006_AC3 barre vide : rien', () async {
      final t = cree();
      await t.s.lireBarre();
      expect(t.v.journal, isEmpty);
    });

    test('REQ006 utilise les textes prononcés', () async {
      final t = cree();
      await t.s.appuyerCase(c(t.s, 'je'));
      await t.s.appuyerCase(c(t.s, 'wc'));
      t.v.journal.clear();
      await t.s.lireBarre();
      expect(t.v.textesPrononces, ['je je veux aller aux toilettes']);
    });
  });

  group('REQ-007 effacement', () {
    test('REQ007_AC1 effacer le dernier', () async {
      final t = cree();
      for (final id in ['je', 'veux', 'manger']) {
        await t.s.appuyerCase(c(t.s, id));
      }
      t.s.effacerDernier();
      expect(libelles(t.s), ['je', 'veux']);
    });

    test('REQ007_AC2 tout effacer', () async {
      final t = cree();
      await t.s.appuyerCase(c(t.s, 'je'));
      await t.s.appuyerCase(c(t.s, 'veux'));
      t.s.toutEffacer();
      expect(t.s.barre, isEmpty);
    });

    test('REQ007_AC3 sur barre vide, sans erreur', () {
      final t = cree();
      t.s.effacerDernier();
      t.s.toutEffacer();
      expect(t.s.barre, isEmpty);
    });
  });

  group('REQ-008 dossiers', () {
    test('REQ008_AC1 navigation sans parole ni barre', () async {
      final t = cree();
      await t.s.appuyerCase(c(t.s, 'je'));
      t.v.journal.clear();
      await t.s.appuyerCase(c(t.s, 'd-manger'));
      expect(t.s.grilleCourante.id, 'manger-g');
      expect(t.v.journal, isEmpty);
      expect(libelles(t.s), ['je']);
    });

    test('REQ008_AC2 dossier orphelin sans effet', () async {
      final t = cree();
      await t.s.appuyerCase(c(t.s, 'd-orph'));
      expect(t.s.grilleCourante.id, 'acc');
      expect(t.v.journal, isEmpty);
      expect(t.s.barre, isEmpty);
    });
  });

  group('REQ-009 navigation', () {
    Future<Session> profond() async {
      final t = cree();
      await t.s.appuyerCase(c(t.s, 'd-manger'));
      await t.s.appuyerCase(c(t.s, 'd-fruits'));
      return t.s;
    }

    test('REQ009_AC1 retour pas à pas', () async {
      final s = await profond();
      expect(s.grilleCourante.id, 'fruits-g');
      s.retour();
      expect(s.grilleCourante.id, 'manger-g');
      s.retour();
      expect(s.grilleCourante.id, 'acc');
    });

    test('REQ009_AC2 accueil vide l\'historique', () async {
      final s = await profond();
      s.accueil();
      expect(s.grilleCourante.id, 'acc');
      s.retour();
      expect(s.grilleCourante.id, 'acc');
    });

    test('REQ009_AC3 retour sur accueil sans effet', () {
      final t = cree();
      var n = 0;
      t.s.addListener(() => n++);
      t.s.retour();
      expect(t.s.grilleCourante.id, 'acc');
      expect(n, 0);
    });

    test('REQ009_AC4 navigation ne modifie pas la barre', () async {
      final t = cree();
      await t.s.appuyerCase(c(t.s, 'je'));
      await t.s.appuyerCase(c(t.s, 'd-manger'));
      t.s.retour();
      t.s.accueil();
      expect(libelles(t.s), ['je']);
    });
  });

  group('REQ-010 retour à l\'accueil après mot', () {
    Future<Session> dansManger(bool actif) async {
      final t = cree(
        d: donnees(
          reglages: Reglages(
            delaiAntiRepetitionMs: 0,
            retourAccueilApresMot: actif,
          ),
        ),
      );
      await t.s.appuyerCase(c(t.s, 'd-manger'));
      await t.s.appuyerCase(c(t.s, 'pomme'));
      expect(libelles(t.s), ['pomme']);
      return t.s;
    }

    test('REQ010_AC1 désactivé : reste sur la grille', () async {
      expect((await dansManger(false)).grilleCourante.id, 'manger-g');
    });

    test('REQ010_AC2 activé : retour à l\'accueil', () async {
      expect((await dansManger(true)).grilleCourante.id, 'acc');
    });
  });
}
