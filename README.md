# WordZuPDF – „In PDF konvertieren“ im Finder-Kontextmenü

Rechtsklick auf eine oder mehrere `.doc`/`.docx`-Dateien → **Schnellaktionen → In PDF konvertieren**.
Im selben Ordner entsteht ein gleichnamiges PDF (`Bericht.docx` → `Bericht.pdf`). Ein vorhandenes PDF gleichen Namens wird überschrieben.

## Voraussetzungen

- macOS (getestet mit macOS 27)
- Microsoft Word für Mac **und/oder** [LibreOffice](https://www.libreoffice.org) in `/Applications`

## Installation

```sh
git clone https://github.com/makro5652/WordZuPDF.git
cd WordZuPDF
./install.sh              # Standard: erst Word, bei Fehler LibreOffice
./install.sh word         # nur Microsoft Word (originalgetreues Layout)
./install.sh libreoffice  # nur LibreOffice (lautlos, kein Word-Fenster)
./install.sh --deinstallieren
```

Nach Änderungen an `wordzupdf.sh` einfach erneut `./install.sh` ausführen – das Skript wird in die Schnellaktion eingebettet.

## Funktionsweise

- **Word:** Das Dokument wird in Words Sandbox-Ordner kopiert und dort als PDF gespeichert. So gibt es keine „Zugriff gewähren“-Abfragen. Lief Word vorher nicht, wird es danach wieder beendet.
- **LibreOffice:** läuft headless mit eigenem Profil, damit ein offenes LibreOffice-Fenster nicht stört.
- OneDrive-Dateien, die nur in der Cloud liegen, werden beim Einlesen vollständig heruntergeladen; das Original bleibt unverändert.
- Am Ende erscheint eine Mitteilung; Details stehen in `~/Library/Logs/WordZuPDF.log`.

Beim ersten Einsatz fragt macOS evtl. einmalig nach Erlaubnis, Microsoft Word zu steuern bzw. auf den Ordner zuzugreifen – bestätigen.
