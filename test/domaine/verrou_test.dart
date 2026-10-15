import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/verrou.dart';

import '../faux/faux_stockage.dart';

const phrases = ['Le chat dort sur le canapé', 'Mon été est fini'];

Future<Verrou> verrou([FauxStockage? s]) =>
    Verrou.charger(s ?? FauxStockage(), phrases);

void main() {
  group('Verrou code', () {
    test('REQ012_AC1 définir un code valide', () async {
      final s = FauxStockage();
      final v = await verrou(s);
      expect(v.aCode, isFalse);
      await v.definirCode('1234', '1234');
      expect(v.aCode, isTrue);
      expect(s.code, '1234');
    });

    test('REQ012_AC1 refusé si pas exactement 4 chiffres', () async {
      final v = await verrou();
      for (final c in ['123', '12345', 'abcd', '12a4', '', '١٢٣٤']) {
        await expectLater(
          v.definirCode(c, c),
          throwsA(
            isA<CodeInvalide>().having(
              (e) => e.erreur,
              'erreur',
              ErreurCode.format,
            ),
          ),
          reason: c,
        );
      }
      expect(v.aCode, isFalse);
    });

    test('REQ012_AC1 refusé si les deux saisies diffèrent', () async {
      final v = await verrou();
      await expectLater(
        v.definirCode('1234', '1235'),
        throwsA(
          isA<CodeInvalide>().having(
            (e) => e.erreur,
            'erreur',
            ErreurCode.differentes,
          ),
        ),
      );
      expect(v.aCode, isFalse);
    });

    test('REQ012_AC1 modifier puis supprimer le code', () async {
      final s = FauxStockage();
      final v = await verrou(s);
      await v.definirCode('1234', '1234');
      await v.definirCode('4321', '4321');
      expect(v.verifier('4321'), isTrue);
      expect(v.verifier('1234'), isFalse);
      await v.supprimerCode();
      expect(v.aCode, isFalse);
      expect(s.code, isNull);
    });

    test('REQ012_AC2 verifier bon et mauvais code', () async {
      final v = await verrou();
      await v.definirCode('0042', '0042');
      expect(v.verifier('0042'), isTrue);
      expect(v.verifier('42'), isFalse);
      expect(v.verifier(''), isFalse);
    });

    test('REQ012_AC4 le code persiste après rechargement', () async {
      final s = FauxStockage();
      await (await verrou(s)).definirCode('1234', '1234');
      final v2 = await verrou(s);
      expect(v2.aCode, isTrue);
      expect(v2.verifier('1234'), isTrue);
    });
  });

  group('Verrou code oublié', () {
    test('REQ013_AC2 la phrase vient de la liste embarquée', () async {
      final v = await verrou();
      for (var i = 0; i < 10; i++) {
        expect(phrases, contains(v.phraseSecours(Random(i))));
      }
    });

    test('REQ013_AC2 liste vide : erreur explicite', () async {
      final v = await Verrou.charger(FauxStockage(), const []);
      expect(() => v.phraseSecours(Random(1)), throwsStateError);
    });

    test('REQ013_AC3 recopie correcte supprime le code', () async {
      final s = FauxStockage();
      final v = await verrou(s);
      await v.definirCode('1234', '1234');
      final p = v.phraseSecours(Random(3));
      expect(await v.verifierPhrase(p), isTrue);
      expect(v.aCode, isFalse);
      expect(s.code, isNull);
    });

    test('REQ013_AC3 casse et espaces ignorés', () async {
      final v = await verrou();
      await v.definirCode('1234', '1234');
      final p = v.phraseSecours(Random(3));
      final saisie = '  ${p.toUpperCase().replaceAll(' ', '   ')} ';
      expect(await v.verifierPhrase(saisie), isTrue);
    });

    test('REQ013_AC4 recopie sans accents refusée, code conservé', () async {
      final s = FauxStockage();
      final v = await verrou(s);
      await v.definirCode('1234', '1234');
      final p = v.phraseSecours(Random(3));
      final sansAccent = p.replaceAll('é', 'e');
      expect(sansAccent, isNot(p));
      expect(await v.verifierPhrase(sansAccent), isFalse);
      expect(await v.verifierPhrase('autre chose'), isFalse);
      expect(await v.verifierPhrase(''), isFalse);
      expect(v.aCode, isTrue);
      expect(s.code, '1234');
    });

    test('REQ013_AC4 sans phrase demandée, rien n\'est accepté', () async {
      final v = await verrou();
      await v.definirCode('1234', '1234');
      expect(await v.verifierPhrase(phrases.first), isFalse);
      expect(v.aCode, isTrue);
    });
  });
}
