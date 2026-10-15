// Usage : dart run tool/generer_banque_arasaac.dart [--plafond N]
import 'dart:convert';
import 'dart:io';

import 'selection_arasaac.dart';

const _urlIndex = 'https://api.arasaac.org/v1/pictograms/all/fr';

Future<void> main(List<String> args) async {
  var plafond = 3000;
  final i = args.indexOf('--plafond');
  if (i >= 0) {
    final n = i + 1 < args.length ? int.tryParse(args[i + 1]) : null;
    if (n == null || n <= 0) {
      stderr.writeln('--plafond attend un entier positif');
      exit(64);
    }
    plafond = n;
  }
  final mots = File('tool/mots_obligatoires.txt')
      .readAsLinesSync()
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .toSet();

  final client = HttpClient();
  try {
    final brut = await _telecharger(client, Uri.parse(_urlIndex));
    final pictos = jsonDecode(utf8.decode(brut)) as List<dynamic>;
    final index = selectionnerPictos(
      pictos,
      motsObligatoires: mots,
      plafond: plafond,
    );
    final dossier = Directory('assets/arasaac')..createSync(recursive: true);
    var fait = 0;
    var echecs = 0;
    final absents = <Object?>{};
    for (final e in index) {
      final id = e['id'];
      final f = File('${dossier.path}/$id.png');
      if (!f.existsSync() || f.lengthSync() == 0) {
        try {
          final octets = await _telecharger(
            client,
            Uri.parse(
              'https://static.arasaac.org/pictograms/$id/${id}_300.png',
            ),
          );
          final tmp = File('${f.path}.tmp')..writeAsBytesSync(octets);
          tmp.renameSync(f.path);
        } on HttpException catch (err) {
          if (err.message == 'HTTP 404') {
            stderr.writeln('Image absente, picto ignoré : $id');
            absents.add(id);
          } else {
            stderr.writeln('Échec picto $id : $err');
            echecs++;
          }
        } on Object catch (err) {
          stderr.writeln('Échec picto $id : $err');
          echecs++;
        }
      }
      fait++;
      if (fait % 200 == 0) stdout.writeln('$fait/${index.length}');
    }
    if (echecs > 0) {
      stderr.writeln('$echecs échec(s) : relancer pour reprendre.');
      exit(1);
    }
    index.removeWhere((e) => absents.contains(e['id']));
    File('assets/arasaac/index.json').writeAsStringSync(jsonEncode(index));
    var total = 0;
    for (final e in index) {
      total += File('${dossier.path}/${e['id']}.png').lengthSync();
    }
    stdout.writeln(
      '${index.length} pictos, ${(total / 1048576).toStringAsFixed(1)} Mo',
    );
  } finally {
    client.close();
  }
}

Future<List<int>> _telecharger(HttpClient client, Uri url) async {
  final req = await client.getUrl(url);
  final rep = await req.close();
  if (rep.statusCode != 200) {
    await rep.drain<void>();
    throw HttpException('HTTP ${rep.statusCode}', uri: url);
  }
  final out = <int>[];
  await for (final part in rep) {
    out.addAll(part);
  }
  return out;
}
