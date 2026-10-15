#!/usr/bin/env bash
# Construit l'APK release puis échoue si la permission INTERNET y figure
# (AC-026-1). À lancer depuis la racine du projet ; nécessite le SDK Android.
set -euo pipefail

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
