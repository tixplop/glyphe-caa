import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/voix.dart';
import 'package:glyphe/plateforme/voix_flutter_tts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const canal = MethodChannel('flutter_tts');
  final appels = <MethodCall>[];
  Object? Function(MethodCall)? reponse;

  setUp(() {
    appels.clear();
    reponse = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (call) async {
          appels.add(call);
          return reponse?.call(call);
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, null);
  });

  double? valeur(String m) =>
      (appels.firstWhere((c) => c.method == m).arguments as num).toDouble();

  test('REQ003_AC2 stop est émis avant speak', () async {
    await VoixFlutterTts().parler('eau', const ParametresVoix());
    final noms = appels.map((c) => c.method).toList();
    expect(noms.indexOf('stop'), greaterThanOrEqualTo(0));
    expect(noms.indexOf('stop'), lessThan(noms.indexOf('speak')));
    expect(noms.last, 'speak');
  });

  test('REQ021_AC4 débit 0,5x plus lent que 1x', () async {
    final v = VoixFlutterTts();
    await v.parler('eau', const ParametresVoix(debit: 0.5));
    final lent = valeur('setSpeechRate');
    appels.clear();
    await v.parler('eau', const ParametresVoix(debit: 1));
    final normal = valeur('setSpeechRate');
    expect(lent, lessThan(normal!));
    expect(normal, 0.5);
    expect(lent, 0.25);
  });

  test('REQ021_AC2 débit 2x -> 1,0 et valeurs hors bornes bornées', () {
    expect(VoixFlutterTts.debitPlateforme(2), 1.0);
    expect(VoixFlutterTts.debitPlateforme(10), 1.0);
    expect(VoixFlutterTts.debitPlateforme(0), 0.25);
  });

  test('REQ002_AC4 voix, hauteur et volume transmis', () async {
    await VoixFlutterTts().parler(
      'bonjour',
      const ParametresVoix(voixId: 'Marie|fr-FR', hauteur: 1.5, volume: 0.3),
    );
    final sv = appels.firstWhere((c) => c.method == 'setVoice');
    expect(Map<Object?, Object?>.from(sv.arguments as Map), {
      'name': 'Marie',
      'locale': 'fr-FR',
    });
    expect(valeur('setPitch'), 1.5);
    expect(valeur('setVolume'), 0.3);
    expect(appels.any((c) => c.method == 'speak'), isTrue);
  });

  test('REQ022_AC2 voixId null ou indécodable : clearVoice', () async {
    final v = VoixFlutterTts();
    await v.parler('a', const ParametresVoix(voixId: 'M|fr'));
    expect(appels.any((c) => c.method == 'clearVoice'), isFalse);
    appels.clear();
    await v.parler('a', const ParametresVoix());
    expect(appels.map((c) => c.method), contains('clearVoice'));
    expect(appels.any((c) => c.method == 'setVoice'), isFalse);
    appels.clear();
    await v.parler('a', const ParametresVoix(voixId: 'sansbarre'));
    expect(appels.map((c) => c.method), contains('clearVoice'));
  });

  test('REQ021_AC1 voixDisponibles convertit la liste du moteur', () async {
    reponse = (c) => c.method == 'getVoices'
        ? [
            {'name': 'Marie', 'locale': 'fr-FR'},
            {'name': '', 'locale': 'fr-FR'},
            'bizarre',
          ]
        : null;
    final l = await VoixFlutterTts().voixDisponibles();
    expect(l, [
      const InfoVoix(id: 'Marie|fr-FR', nom: 'Marie', locale: 'fr-FR'),
    ]);
  });

  test('REQ005_AC1 liste absente ou erreur : liste vide', () async {
    expect(await VoixFlutterTts().voixDisponibles(), isEmpty);
    reponse = (c) => throw PlatformException(code: 'x');
    expect(await VoixFlutterTts().voixDisponibles(), isEmpty);
  });

  test('REQ005_AC1 exception du moteur absorbée', () async {
    reponse = (c) => throw PlatformException(code: 'boom');
    final v = VoixFlutterTts();
    await v.parler('eau', const ParametresVoix(voixId: 'M|fr'));
    await v.arreter();
  });
}
