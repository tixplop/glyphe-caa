# Glyphe

Glyphe est une application de communication améliorée et alternative (CAA) par pictogrammes : on compose une phrase en touchant des cases, puis l'appli la lit à voix haute. Elle est gratuite, non commerciale, fonctionne entièrement hors ligne et ne demande aucune permission réseau (la permission `INTERNET` est retirée du build).

## Prérequis

- Flutter (canal stable) : `git clone --depth 1 -b stable https://github.com/flutter/flutter.git ~/development/flutter`, puis ajouter `~/development/flutter/bin` au `PATH`.
- SDK Android (pour construire l'APK uniquement) :
  1. Télécharger `commandlinetools-linux-*_latest.zip` (page « Command line tools only » de developer.android.com/studio) et le décompresser pour obtenir `~/Android/Sdk/cmdline-tools/latest/` (contenant `bin/`, `lib/`).
  2. `export ANDROID_HOME=$HOME/Android/Sdk`
  3. `export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools`
  4. `android --sdk=$HOME/Android/Sdk sdk install platform-tools "platforms;android-35" "build-tools;35.0.0"` (`sdkmanager` y est un alias déprécié ; pour des cmdline-tools plus anciens, l'équivalent est `sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0"`).
  5. `flutter config --android-sdk ~/Android/Sdk`, puis `flutter doctor --android-licenses`.

  Gradle installe lui-même build-tools/platform 36 et CMake au premier build.
- Java 21.
- Vérification : `flutter doctor`.

`flutter test` et `flutter analyze` n'ont besoin que de Flutter.

## Installation

```
flutter pub get
```

## Tests et lint

```
flutter --no-color test --reporter compact
flutter analyze --no-pub && dart format --output=none --set-exit-if-changed lib test tool
```

## Construire et installer l'APK

```
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
```

L'identifiant de l'appli est `org.glyphe.glyphe`. Pour construire l'APK et vérifier que la permission `INTERNET` y est absente : `bash tool/verifier_apk.sh`.

## Régénérer la banque ARASAAC

La banque de pictogrammes embarquée (`assets/arasaac/`) est produite par un outil qui interroge l'API ARASAAC (réseau nécessaire, uniquement au développement) :

```
dart run tool/generer_banque_arasaac.dart
```

## iOS

Le code est compatible iOS, mais il n'est pas compilé ni testé sans Mac : seul Android est construit.

## Usage

- **Déverrouiller l'édition** : maintenir le cadenas appuyé 3 secondes. Si un code est défini, il est demandé.
- **Code** : le code de déverrouillage (4 chiffres) se définit, se modifie ou se supprime dans les réglages.
- **Code oublié** : sur l'écran de saisie du code, « Code oublié » affiche une phrase à recopier. Si la recopie est correcte, le code est supprimé et le mode édition s'ouvre (ensuite l'appui long seul suffit ; on peut redéfinir un code dans les réglages). Si la recopie est fausse, le code est conservé et l'appli reste verrouillée.
- **Export / import** : dans les réglages, section « Sauvegarde », « Exporter » crée un fichier de sauvegarde et « Importer » le restaure. L'import remplace toutes les données actuelles après confirmation.

## Licence et attribution

Glyphe est gratuit et réservé à un usage non commercial.

Les symboles pictographiques utilisés sont la propriété du Gouvernement d'Aragon et ont été créés par Sergio Palao pour ARASAAC (http://www.arasaac.org), qui les distribue sous licence Creative Commons BY-NC-SA (usage non commercial, partage dans les mêmes conditions).
