#!/bin/zsh
# WordZuPDF – wandelt .doc/.docx in ein gleichnamiges PDF im selben Ordner um.
# Aufruf: wordzupdf.sh DATEI [DATEI ...]
#
# Engine (Umgebungsvariable WORDZUPDF_ENGINE):
#   auto        (Standard) erst Microsoft Word, bei Fehler LibreOffice
#   word        nur Microsoft Word  – originalgetreues Layout
#   libreoffice nur LibreOffice     – lautlos im Hintergrund, keine Word-Fenster
#
# Ein bereits vorhandenes PDF gleichen Namens wird überschrieben.

ENGINE="${WORDZUPDF_ENGINE:-auto}"
LOG="$HOME/Library/Logs/WordZuPDF.log"
WORD_APP="/Applications/Microsoft Word.app"
SOFFICE="/Applications/LibreOffice.app/Contents/MacOS/soffice"
# Word ist sandboxed: Dateien außerhalb seines Containers lösen Rückfragen
# ("Zugriff gewähren") aus. Daher wird im Container-tmp gearbeitet.
WORD_TMP_ROOT="$HOME/Library/Containers/com.microsoft.Word/Data/tmp"

log() { print -r -- "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"; }

notify() {  # notify TITEL TEXT
  T="$1" M="$2" osascript -e 'display notification (system attribute "M") with title (system attribute "T")' >/dev/null 2>&1
}

# Datei vollständig einlesen (erzwingt Download bei OneDrive-"dataless"-Dateien)
copy_full() {  # copy_full QUELLE ZIEL
  cat -- "$1" > "$2" 2>/dev/null && [[ -s "$2" ]]
}

word_was_running=""
word_used=""

convert_word() {  # convert_word QUELLE ZIEL_PDF
  [[ -d "$WORD_APP" ]] || { log "Word nicht installiert"; return 1; }
  local src="$1" dst="$2" ext="${1:e:l}"
  local work; work=$(mktemp -d "$WORD_TMP_ROOT/wordzupdf.XXXXXX") || return 1
  local in="$work/eingabe.$ext" out="$work/ausgabe.pdf"
  if ! copy_full "$src" "$in"; then
    log "Konnte nicht lesen: $src"; rm -rf "$work"; return 1
  fi
  if [[ -z "$word_used" ]]; then
    pgrep -xq "Microsoft Word" && word_was_running=1
    word_used=1
  fi
  local err
  err=$(osascript - "$in" "$out" 2>&1 <<'APPLESCRIPT'
on run argv
	set inPath to item 1 of argv
	set outPath to item 2 of argv
	tell application "Microsoft Word"
		set display alerts to alerts none
		open (POSIX file inPath) add to recent files false
		set theDoc to missing value
		repeat with i from 1 to 50
			try
				set theDoc to document "eingabe.docx"
			end try
			try
				if theDoc is missing value then set theDoc to document "eingabe.doc"
			end try
			if theDoc is not missing value then exit repeat
			delay 0.2
		end repeat
		if theDoc is missing value then error "Dokument wurde in Word nicht geöffnet"
		try
			save as theDoc file name outPath file format format PDF
		on error e
			close theDoc saving no
			error e
		end try
		close theDoc saving no
	end tell
end run
APPLESCRIPT
)
  if [[ -s "$out" ]]; then
    mv -f "$out" "$dst"; rm -rf "$work"; return 0
  fi
  log "Word-Fehler bei $src: $err"
  rm -rf "$work"; return 1
}

convert_libreoffice() {  # convert_libreoffice QUELLE ZIEL_PDF
  [[ -x "$SOFFICE" ]] || { log "LibreOffice nicht installiert"; return 1; }
  local src="$1" dst="$2" ext="${1:e:l}"
  local work; work=$(mktemp -d "${TMPDIR:-/tmp}/wordzupdf.XXXXXX") || return 1
  local in="$work/eingabe.$ext"
  if ! copy_full "$src" "$in"; then
    log "Konnte nicht lesen: $src"; rm -rf "$work"; return 1
  fi
  # Eigenes Profil, damit ein offenes LibreOffice-Fenster nicht stört
  local err
  err=$("$SOFFICE" -env:UserInstallation="file://$work/profil" --headless --norestore \
        --convert-to pdf --outdir "$work" "$in" 2>&1)
  if [[ -s "$work/eingabe.pdf" ]]; then
    mv -f "$work/eingabe.pdf" "$dst"; rm -rf "$work"; return 0
  fi
  log "LibreOffice-Fehler bei $src: $err"
  rm -rf "$work"; return 1
}

ok=0; failed=()
for f in "$@"; do
  [[ -f "$f" ]] || continue
  case "${f:e:l}" in doc|docx) ;; *) continue ;; esac
  [[ "${f:t}" == '~$'* ]] && continue          # Word-Sperrdateien ignorieren
  pdf="${f:r}.pdf"
  done_=""
  case "$ENGINE" in
    word)        convert_word "$f" "$pdf" && done_=1 ;;
    libreoffice) convert_libreoffice "$f" "$pdf" && done_=1 ;;
    *)           { convert_word "$f" "$pdf" || convert_libreoffice "$f" "$pdf"; } && done_=1 ;;
  esac
  if [[ -n "$done_" ]]; then
    (( ok++ )); log "OK: $pdf"
  else
    failed+=("${f:t}"); log "FEHLER: $f"
  fi
done

# Word wieder beenden, wenn es vorher nicht lief
if [[ -n "$word_used" && -z "$word_was_running" ]]; then
  osascript -e 'tell application "Microsoft Word" to if (count of documents) is 0 then quit' >/dev/null 2>&1
fi

if (( ${#failed} )); then
  notify "In PDF konvertieren" "Fehlgeschlagen: ${(j:, :)failed} – Details in ~/Library/Logs/WordZuPDF.log"
  exit 1
elif (( ok == 1 )); then
  notify "In PDF konvertieren" "PDF erstellt: ${pdf:t}"
elif (( ok > 1 )); then
  notify "In PDF konvertieren" "$ok PDFs erstellt"
fi
exit 0
