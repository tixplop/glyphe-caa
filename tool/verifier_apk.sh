#!/usr/bin/env bash
# Construit l'APK release puis échoue si la permission INTERNET y figure
# (AC-026-1) ou s'il est signé avec la clé de debug (AC-039-4, vérifié par
# apksigner). À lancer depuis la racine du projet ; nécessite le SDK Android.
set -euo pipefail

if [ ! -f android/key.properties ]; then
  echo "ATTENTION : android/key.properties absent : APK release signé avec la clé de debug (voir README, « Signature de l'APK »)." >&2
fi

flutter build apk --release

apk="build/app/outputs/flutter-apk/app-release.apk"
if [ ! -f "$apk" ]; then
  echo "APK introuvable : $apk" >&2
  exit 2
fi

aapt2="$(command -v aapt2 || true)"
if [ -z "$aapt2" ] && [ -n "${ANDROID_HOME:-}" ]; then
  aapt2="$(ls -d "$ANDROID_HOME"/build-tools/*/aapt2 2>/dev/null | sort -V | tail -1 || true)"
fi

if [ -n "$aapt2" ]; then
  permissions="$("$aapt2" dump permissions "$apk")"
elif command -v apkanalyzer >/dev/null 2>&1; then
  permissions="$(apkanalyzer manifest permissions "$apk")"
else
  echo "Ni aapt2 ni apkanalyzer trouvés (SDK Android requis)." >&2
  exit 2
fi

echo "$permissions"
if echo "$permissions" | grep -q "android.permission.INTERNET"; then
  echo "ECHEC : la permission android.permission.INTERNET est présente." >&2
  exit 1
fi
echo "OK : la permission INTERNET est absente."

apksigner="$(command -v apksigner || true)"
if [ -z "$apksigner" ] && [ -n "${ANDROID_HOME:-}" ]; then
  apksigner="$(ls -d "$ANDROID_HOME"/build-tools/*/apksigner 2>/dev/null | sort -V | tail -1 || true)"
fi
if [ -z "$apksigner" ]; then
  echo "apksigner introuvable (SDK Android requis)." >&2
  exit 2
fi

if ! certs="$("$apksigner" verify --print-certs "$apk")"; then
  echo "ECHEC : la signature de l'APK n'est pas valide." >&2
  exit 1
fi
if echo "$certs" | grep -q "CN=Android Debug"; then
  echo "ECHEC : APK signé avec la clé de debug" >&2
  exit 1
fi
echo "$certs" | grep "Signer #1 certificate DN:" || true
echo "OK : APK signé avec une clé dédiée."
