import 'package:flutter/material.dart';

import '../domaine/choix_voix.dart';
import '../domaine/modeles.dart';
import '../domaine/sauvegarde.dart';
import 'ecran_code.dart';
import 'etat_appli.dart';
import 'textes.dart';

/// Délais anti-répétition proposés, en millisecondes (REQ-004).
const List<int> delaisProposes = [0, 500, 1000, 2000, 3000, 5000];

/// Réglages de la voix, du délai anti-répétition, du retour à l'accueil,
/// du code et de la sauvegarde (mode édition uniquement).
class EcranReglages extends StatefulWidget {
  const EcranReglages({super.key, required this.etat});

  final EtatAppli etat;

  @override
  State<EcranReglages> createState() => _EcranReglagesState();
}

class _EcranReglagesState extends State<EcranReglages> {
  Reglages? _vus;
  late double _debit;
  late double _hauteur;
  late double _volume;

  EtatAppli get etat => widget.etat;
  Reglages get _reglages => etat.session.donnees.reglages;

  @override
  void initState() {
    super.initState();
    _synchroniser();
    // La revérification au retour au premier plan vit dans EcranCommunication.
    etat.verifierVoix();
  }

  /// Recopie les curseurs depuis les réglages si ceux-ci ont changé
  /// (import, rechargement) ; sans effet pendant un glissement.
  void _synchroniser() {
    final r = _reglages;
    if (_vus == r) return;
    _vus = r;
    _debit = r.debit;
    _hauteur = r.hauteur;
    _volume = r.volume;
  }

  Future<void> _enregistrer(Reglages r) async {
    try {
      await etat.modifierReglages(r);
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(Textes.erreurEnregistrement)),
        );
    }
  }

  bool _occupe = false;

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texte)));
  }

  Future<void> _exporter() async {
    if (_occupe) return;
    _occupe = true;
    try {
      await etat.exporterSauvegarde();
    } on Object {
      _message(Textes.exportImpossible);
    } finally {
      _occupe = false;
    }
  }

  Future<void> _importer() async {
    if (_occupe) return;
    _occupe = true;
    try {
      final analyse = await etat.choisirSauvegarde();
      if (analyse == null || !mounted) return;
      switch (analyse) {
        case ErreurSauvegarde(:final motif):
          _message(
            motif == MotifErreur.tropRecente
                ? Textes.sauvegardeTropRecente
                : Textes.sauvegardeInvalide,
          );
        case SauvegardeValide():
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              key: const Key('dialogue-import'),
              title: const Text(Textes.importer),
              content: const Text(Textes.confirmationImport),
              actions: [
                TextButton(
                  key: const Key('annuler-import'),
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text(Textes.annuler),
                ),
                FilledButton(
                  key: const Key('confirmer-import'),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text(Textes.remplacer),
                ),
              ],
            ),
          );
          if (ok != true) return;
          await etat.appliquerSauvegarde(analyse);
      }
    } on Object {
      _message(Textes.importImpossible);
    } finally {
      _occupe = false;
    }
  }

  Future<void> _ouvrirCode() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => EcranCode(verrou: etat.verrou)),
  );

  Widget _titre(String texte) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(texte, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _avertissement(Key cle, String texte) {
    final c = Theme.of(context).colorScheme;
    return Card(
      key: cle,
      color: c.errorContainer,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: c.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(texte, style: TextStyle(color: c.onErrorContainer)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _curseur({
    required Key cle,
    required String nom,
    required double valeur,
    required double min,
    required double max,
    required int divisions,
    required String Function(double) format,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onFin,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        SizedBox(width: 96, child: Text('$nom : ${format(valeur)}')),
        Expanded(
          child: Slider(
            key: cle,
            value: valeur,
            min: min,
            max: max,
            divisions: divisions,
            label: format(valeur),
            semanticFormatterCallback: format,
            onChanged: onChanged,
            onChangeEnd: onFin,
          ),
        ),
      ],
    ),
  );

  Widget _choix({
    required Key cle,
    required String titre,
    required bool choisi,
    required VoidCallback onTap,
  }) => ListTile(
    key: cle,
    minTileHeight: 56,
    title: Text(titre),
    selected: choisi,
    trailing: choisi ? const Icon(Icons.check) : null,
    onTap: onTap,
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: etat,
      builder: (context, _) {
        _synchroniser();
        final r = _reglages;
        return Scaffold(
          key: const Key('ecran-reglages'),
          appBar: AppBar(title: const Text(Textes.reglages)),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _titre(Textes.sectionVoix),
                  if (etat.aucuneVoix) ...[
                    _avertissement(
                      const Key('avert-aucune-voix'),
                      Textes.aucuneVoix,
                    ),
                    const Padding(
                      key: Key('indication-installation'),
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(Textes.installerVoix),
                    ),
                  ] else if (etat.voixEnregistreeIndisponible)
                    _avertissement(
                      const Key('avert-voix-indispo'),
                      Textes.voixIndisponible,
                    ),
                  _choix(
                    cle: const Key('voix-defaut'),
                    titre: Textes.voixParDefaut,
                    choisi: r.voixId == null,
                    onTap: () =>
                        _enregistrer(_reglages.copyWith(voixId: () => null)),
                  ),
                  for (final v in etat.voixDisponibles)
                    _choix(
                      cle: Key('voix-${v.id}'),
                      titre: '${v.nom} (${v.locale})',
                      choisi: r.voixId == v.id,
                      onTap: () =>
                          _enregistrer(_reglages.copyWith(voixId: () => v.id)),
                    ),
                  _curseur(
                    cle: const Key('curseur-debit'),
                    nom: Textes.debit,
                    valeur: _debit,
                    min: debitMin,
                    max: debitMax,
                    divisions: 15,
                    format: Textes.valeurMultiple,
                    onChanged: (v) => setState(() => _debit = borneDebit(v)),
                    onFin: (v) =>
                        _enregistrer(_reglages.copyWith(debit: borneDebit(v))),
                  ),
                  _curseur(
                    cle: const Key('curseur-hauteur'),
                    nom: Textes.hauteur,
                    valeur: _hauteur,
                    min: hauteurMin,
                    max: hauteurMax,
                    divisions: 15,
                    format: Textes.valeurMultiple,
                    onChanged: (v) =>
                        setState(() => _hauteur = borneHauteur(v)),
                    onFin: (v) => _enregistrer(
                      _reglages.copyWith(hauteur: borneHauteur(v)),
                    ),
                  ),
                  _curseur(
                    cle: const Key('curseur-volume'),
                    nom: Textes.volume,
                    valeur: _volume,
                    min: volumeMin,
                    max: volumeMax,
                    divisions: 20,
                    format: Textes.valeurPourcent,
                    onChanged: (v) => setState(() => _volume = borneVolume(v)),
                    onFin: (v) => _enregistrer(
                      _reglages.copyWith(volume: borneVolume(v)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonal(
                        key: const Key('bouton-tester'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(56, 56),
                        ),
                        onPressed: () =>
                            etat.session.essayerVoix(Textes.phraseTest),
                        child: const Text(Textes.tester),
                      ),
                    ),
                  ),
                  _titre(Textes.delaiAntiRepetition),
                  for (final ms in delaisProposes)
                    _choix(
                      cle: Key('delai-$ms'),
                      titre: ms == 0
                          ? Textes.delaiDesactive
                          : Textes.delaiSecondes(ms),
                      choisi: r.delaiAntiRepetitionMs == ms,
                      onTap: () => _enregistrer(
                        _reglages.copyWith(delaiAntiRepetitionMs: ms),
                      ),
                    ),
                  const Divider(),
                  SwitchListTile(
                    key: const Key('retour-accueil'),
                    title: const Text(Textes.retourAccueilApresMot),
                    value: r.retourAccueilApresMot,
                    onChanged: (v) => _enregistrer(
                      _reglages.copyWith(retourAccueilApresMot: v),
                    ),
                  ),
                  ListTile(
                    key: const Key('reglage-code'),
                    minTileHeight: 56,
                    title: const Text(Textes.codeDeverrouillage),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _ouvrirCode,
                  ),
                  _titre(Textes.sectionSauvegarde),
                  ListTile(
                    key: const Key('reglage-exporter'),
                    minTileHeight: 56,
                    title: const Text(Textes.exporter),
                    onTap: _exporter,
                  ),
                  ListTile(
                    key: const Key('reglage-importer'),
                    minTileHeight: 56,
                    title: const Text(Textes.importer),
                    onTap: _importer,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
