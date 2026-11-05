#!/bin/zsh
# Installiert die Finder-Schnellaktion "In PDF konvertieren".
# Aufruf: ./install.sh [auto|word|libreoffice]     (Standard: auto)
#         ./install.sh --deinstallieren
set -e
cd "${0:A:h}"
ZIEL="$HOME/Library/Services/In PDF konvertieren.workflow"

if [[ "$1" == "--deinstallieren" ]]; then
  rm -rf "$ZIEL"; /System/Library/CoreServices/pbs -update
  echo "Schnellaktion entfernt."; exit 0
fi

ENGINE="${1:-auto}"
case "$ENGINE" in auto|word|libreoffice) ;; *) echo "Unbekannte Engine: $ENGINE"; exit 1 ;; esac

rm -rf "$ZIEL"
mkdir -p "$ZIEL/Contents"
cp vorlage/Info.plist vorlage/document.wflow "$ZIEL/Contents/"
# Skript direkt in die Schnellaktion einbetten (keine externe Abhängigkeit)
SKRIPT="WORDZUPDF_ENGINE=\"\${WORDZUPDF_ENGINE:-$ENGINE}\"
$(<wordzupdf.sh)"
plutil -replace actions.0.action.ActionParameters.COMMAND_STRING -string "$SKRIPT" "$ZIEL/Contents/document.wflow"

/System/Library/CoreServices/pbs -flush
/System/Library/CoreServices/pbs -update
echo "Installiert: $ZIEL (Engine: $ENGINE)"
echo "Rechtsklick auf eine .doc/.docx-Datei im Finder → Schnellaktionen → In PDF konvertieren"
