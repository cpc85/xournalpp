# Notizregal 1.4 – Versionen und PDF öffnen

## Update

Notizregal und Stickerpalette schließen. ZIP vollständig entpacken und Start.cmd
öffnen. Katalog, Kategorien, Favoriten, Text- und Audioindizes bleiben erhalten.
Die bestehende Offline-Spracherkennung und Stickerpalette sind vollständig enthalten.

## Versionierung der Notizbücher

Gesichert werden die gespeicherten Inhalte von .xopp-Dateien in den eingebundenen
Ordnern. Die erste automatische Prüfung beginnt wenige Sekunden nach dem Start.
Solange das Regal geöffnet ist, prüft es die bereits eingelesenen Notizbücher
etwa alle 60 Sekunden. Eine lange Sicherung darf ihren Durchlauf erst abschließen.
Neue Notizbücher werden mit **Aktualisieren** eingelesen.

Außerdem wird vor dem Öffnen eines XOPP-Notizbuchs aus dem Regal dessen aktueller
Stand gesichert. Schlägt diese Sicherung fehl, zeigt das Regal den Fehler und
öffnet die Datei nicht. Vorherige Fassungen lassen sich erst ab diesem Update
sammeln; ungespeicherte Änderungen in Xournal++ sind nicht enthalten.

Mehrere Speichervorgänge innerhalb einer Minute können zu einem einzigen erfassten
Stand zusammenfallen. Für einen bestimmten Zwischenstand in Xournal++ speichern
und anschließend **Versionen → Jetzt sichern** verwenden. Es handelt sich nicht
um eine Garantie, dass jeder einzelne Speichervorgang erfasst wird.

### Verlauf verwenden

Bei einer XOPP-Karte auf **Versionen** klicken. Die Liste zeigt Zeitpunkt, Anlass
und Dateigröße, neueste Version zuerst.

- **Jetzt sichern:** erstellt einen Stand des gespeicherten Notizbuchs.
- **Als Kopie speichern:** exportiert den gewählten Stand als neue .xopp-Datei.
  Einen freien Dateinamen wählen; vorhandene Dateien werden nicht überschrieben.
- **Wiederherstellen:** ersetzt die aktuelle Datei durch den gewählten Stand.
  Das Notizbuch vorher in Xournal++ schließen und die Rückfrage bestätigen.
  Der aktuelle Stand wird vorher gesichert; die Wiederherstellung erscheint im
  Verlauf. Das Notizbuch danach erneut öffnen.
- **Sicherungsordner:** öffnet die zugehörigen lokalen Versionsdaten.

Identische Inhalte erzeugen keine zusätzliche Version. Wird ein früherer Stand
wiederhergestellt, erhält der Verlauf einen neuen Eintrag; der Dateiinhalt wird
intern nur einmal gespeichert. Vor dem Wiederherstellen wird die Prüfsumme geprüft.
Beschädigte Versionsdateien oder ein defekter Index werden nicht blind übernommen.

Falls die aktuelle XOPP-Datei selbst beschädigt ist und die Sicherung deshalb
scheitert, den gewünschten Stand **als Kopie speichern** und diese Kopie öffnen.

### Speicherort und Umfang

%LOCALAPPDATA%\Notizregal\versionen enthält je Notizbuch einen Unterordner,
index.json, dessen .bak-Fassung und die Sicherungsinhalte als .nrv-Dateien.
Die .nrv-Dateien sind vollständige XOPP-Inhalte mit anderer Erweiterung und
erscheinen nicht als zusätzliche Notizbücher im Regal. Nicht einzeln umbenennen
oder löschen; für die Bedienung den Versionsdialog nutzen.

Nach einer Wiederherstellung liegt zusätzlich eine Datei
.notizregal-vor-wiederherstellung-<ID>.nrv neben dem Notizbuch. Sie enthält exakt
die ersetzte Datei und schützt auch vor einem unmittelbar gleichzeitigen externen
Speichervorgang. Bei Bedarf als Kopie mit .xopp-Endung öffnen. Diese Sicherheitskopie
wird nicht automatisch entfernt.

Es gibt keine automatische Löschung alter Versionen. Der Speicherbedarf wächst
mit den unterschiedlichen gespeicherten Ständen. Den gesamten Ordner
%LOCALAPPDATA%\Notizregal zusammen mit den Originaldateien sichern.
Versionsdaten sind lokal und werden nicht vom Regal in OneDrive hochgeladen.
Die Zuordnung erfolgt über den vollständigen Notizbuchpfad. Verschieben oder
Umbenennen startet einen neuen Verlauf; der bisherige bleibt am alten Pfad erhalten.

Die Versionierung enthält die XOPP-Datei. Externe PDF-Hintergründe und Audioaufnahmen
sowie Metadaten, Textkorrekturen und Audiotranskripte werden nicht pro Version
mitgesichert. Diese Dateien deshalb separat aufbewahren. Nach Wiederherstellung
wird ein alter Notiztextindex als veraltet markiert; bei Bedarf neu erfassen.
Audiotranskripte bleiben dem Notizbuch zugeordnet.

Unter der Regalanzeige steht der letzte Sicherungsstatus. **Diese Statuszeile
antippen** zeigt die Fehlermeldungen des letzten Durchlaufs. Eine gesperrte,
beschädigte oder nicht verfügbare Datei verhindert nicht die Sicherung anderer
Notizbücher. OneDrive-Dateien für Offline-Arbeit auf dem Gerät bereithalten.
Ein beim Schließen bereits laufender Sicherungsdurchlauf darf noch fertig werden;
es werden danach keine weiteren automatischen Durchläufe gestartet.

## PDFs direkt mit Xournal++ öffnen

PDFs aus den eingebundenen Ordnern erscheinen jetzt als eigene **PDF-Karten**,
inklusive Kategorien, Favoriten und Suche nach Dateiname/Metadaten. Karte antippen,
um die PDF an Xournal++ zu übergeben. Ohne hinterlegten Programmpfad fragt das Regal
nach der installierten xournalpp.exe. Die Windows-Standardzuordnung für PDFs wird
nicht verändert; das Regal verwendet für PDFs ausdrücklich Xournal++.

Mit **PDF öffnen …** oben kannst du außerdem eine beliebige PDF außerhalb der
Suchordner öffnen. Diese Aktion verschiebt die Datei nicht und bindet ihren Ordner
nicht automatisch ins Regal ein.

1. PDF öffnen und in Xournal++ beschriften.
2. In Xournal++ als **.xopp** in einem eingebundenen Ordner speichern.
3. Im Regal **Aktualisieren** anklicken. Das neue Notizbuch besitzt jetzt den
   Versionsverlauf und die vorhandene Notiztexterkennung.

Die Original-PDF bleibt eine eigene Karte. PDF und zugehöriges XOPP können daher
beide im Regal stehen. Die PDF-Inhalte werden durch dieses Update nicht als
Volltext indexiert. Für PDFs ist keine eigene Versionshistorie enthalten; die
Versionierung gilt für das gespeicherte .xopp-Notizbuch mit seinen Anmerkungen.

Xournal++ speichert PDF-Hintergrund und Notizbuch getrennt. Original-PDF deshalb
aufbewahren. Beim späteren Kopieren eines alten Notizbuchstands muss ein relativ
verknüpfter PDF-Hintergrund ggf. mitkopiert werden. Die Kopie ändert keine internen
Verknüpfungen. Offizielle Anleitung:
https://xournalpp.github.io/guide/pdfs/

## Prüfstand

Versionierung unter PowerShell 7.6.6/Linux tatsächlich ausgeführt: Erstsicherung,
Änderungen, Deduplizierung, Kopie, Wiederherstellung, genaue Rücksicherung,
Prüfsummenfehler, beschädigter Index, fehlende Datei, Hintergrundprozess und
prozessübergreifende Sperre geprüft. PDF-Pfadübergabe mit Testprogramm geprüft.
Sechs PowerShell-Dateien, beide CMD-Starter und sechs XAML-Fenster statisch geprüft.
Die neue WPF-Oberfläche, Windows-PowerShell-5.1-Laufzeit und das Zusammenspiel mit
einem echten Xournal++ unter Windows auf dem SQ1 benötigen noch den Gerätetest.
