import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/choix_voix.dart';
import 'package:glyphe/domaine/voix.dart';

InfoVoix v(String nom, String locale) =>
    InfoVoix(id: '$nom|$locale', nom: nom, locale: locale);

void main() {
  test('REQ021_AC1 voix fr* d abord puis ordre alphabétique', () {
    final t = trierVoix([
      v('Zoe', 'en-US'),
      v('Marie', 'fr-FR'),
      v('Alex', 'en-GB'),
      v('Luc', 'fr_CA'),
    ]);
    expect(t.map((e) => e.nom), ['Luc', 'Marie', 'Alex', 'Zoe']);
  });

  test('REQ021_AC1 une locale commençant par fr sans être française', () {
    final t = trierVoix([v('A', 'fro-XX'), v('B', 'fr')]);
    expect(t.first.nom, 'B');
  });

  test('REQ022_AC1 voix enregistrée présente est conservée', () {
    final l = [v('Marie', 'fr-FR'), v('Alex', 'en-GB')];
    final c = choisirVoix(l, 'Alex|en-GB');
    expect(c.voixId, 'Alex|en-GB');
    expect(c.voixEnregistreeIndisponible, isFalse);
    expect(c.aucuneVoix, isFalse);
  });

  test('REQ022_AC1 voix enregistrée absente : défaut fr et indicateur', () {
    final l = [v('Alex', 'en-GB'), v('Marie', 'fr-FR')];
    final c = choisirVoix(l, 'Disparue|fr-FR');
    expect(c.voixId, 'Marie|fr-FR');
    expect(c.voixEnregistreeIndisponible, isTrue);
  });

  test('REQ022_AC2 pas de voix fr : défaut système (null)', () {
    final c = choisirVoix([v('Alex', 'en-GB')], 'X|fr');
    expect(c.voixId, isNull);
    expect(c.voixEnregistreeIndisponible, isTrue);
    expect(c.aucuneVoix, isFalse);
  });

  test('REQ021 sans voix enregistrée : pas d avertissement', () {
    final c = choisirVoix([v('Marie', 'fr-FR')], null);
    expect(c.voixId, 'Marie|fr-FR');
    expect(c.voixEnregistreeIndisponible, isFalse);
  });

  test('REQ005_AC1 liste vide : aucuneVoix', () {
    final c = choisirVoix(const [], null);
    expect(c.aucuneVoix, isTrue);
    expect(c.voixId, isNull);
    expect(c.voixEnregistreeIndisponible, isFalse);
  });

  test('REQ021_AC2 bornes débit, hauteur, volume', () {
    expect(borneDebit(0.1), 0.5);
    expect(borneDebit(5), 2.0);
    expect(borneDebit(1.04), 1.0);
    expect(borneDebit(double.nan), 0.5);
    expect(borneHauteur(0.7), 0.7);
    expect(borneHauteur(9), 2.0);
    expect(borneVolume(-1), 0.0);
    expect(borneVolume(3), 1.0);
    expect(borneVolume(0.4), 0.4);
  });
}
