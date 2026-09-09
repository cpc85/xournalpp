# Notizregal 1.4 für Xournal++

Eine lokale Windows-Oberfläche mit farbigen Notizbuchcovern, Kategorien,
Favoriten und Suche. Xournal++ bleibt der Editor für Handschrift und PDF-Notizen.

## Neu in Version 1.4

**Notizbuchversionen** mit automatischer Sicherung bei geöffnetem Regal,
manuellen Ständen, Export als Kopie und Wiederherstellung. **PDFs** erscheinen
als Karten und öffnen direkt in Xournal++; zusätzlich gibt es **PDF öffnen …**.
Anleitung, Sicherungsumfang und Grenzen: **VERSIONEN-UND-PDF.md**.

## Neu in Version 1.3

**Audio → Text** pro Notizbuch: gespeicherte Xournal++-Aufnahmen offline erkennen,
Text korrigieren, durchsuchen, als MD/TXT exportieren und für Xournal++ kopieren.
ARM64-Programme und Sprachmodell sind enthalten. Anleitung: **AUDIO-TEXT.md**.

## Neu in Version 1.2

Zusätzliche Offline-Stickerpalette mit 4.495 OpenMoji-PNGs, Suche, Kategorien,
Favoriten und eigenen Bildern. Sie startet standardmäßig mit dem Regal.
Bedienung und Lizenzhinweise: **STICKERPALETTE.md**.

## Start auf dem Surface

1. ZIP vollständig in einen eigenen Ordner entpacken, z. B. Dokumente\Notizregal.
2. Xournal++ muss bereits installiert sein.
3. `Start.cmd` doppelt anklicken. Kein Administratorstart erforderlich.
   Der Starter kopiert die Anwendung und beim ersten Start die OpenMoji-Bilder und die Spracherkennung automatisch nach
   `%LOCALAPPDATA%\Notizregal-App` und entfernt die Downloadmarkierung gezielt
   von den lokalen Skriptdateien. Das entpackte Paket darf auch auf Z: liegen.
   Es sind keine manuellen PowerShell-Befehle notwendig.
4. **Ordner hinzufügen** wählen und den Ordner mit den `.xopp`- und PDF-Dateien auswählen.
   Unterordner werden mit eingelesen. Mehrere Suchordner sind möglich.
5. Falls ein Coverklick Xournal++ nicht öffnet: **Xournal++ auswählen** anklicken
   und die installierte `xournalpp.exe` auswählen.

Die Oberfläche verwendet Windows PowerShell 5.1 und WPF, die mit Windows
mitgeliefert werden. Kein Python, Browser, Server, Konto oder Download beim Start.
Gedacht für Windows 11 einschließlich Surface ARM; ein tatsächlicher Test auf
Windows/ARM steht noch aus. Nicht für Android, Linux oder macOS.

## So arbeitest du damit

- **Cover antippen:** Das zugehörige Notizbuch öffnet sich in Xournal++.
- **Bearbeiten:** Anzeigename, Kategorie, Schlagwörter und Coverfarbe anpassen.
  Titeländerungen im Regal benennen die Originaldatei nicht um.
- **Stern:** Favorit setzen oder entfernen. Oben auf „Favoriten“ filtern.
- **Suche:** Durchsucht Anzeigename, Dateiname, Kategorie, Schlagwörter und bereits erfasste Notiztexte/Audiotranskripte.
  Beispiel: „Besprechung“, „Kunde Müller“, „Imkerei“.
- **Kategorie:** Frei wählbares Textfeld beim Bearbeiten. Neue Kategorien erscheinen
  im Filter, sobald sie einem vorhandenen Notizbuch zugeordnet wurden.
- **Sortierung:** Zuletzt geändert oder alphabetisch nach Anzeigename.
- **Aktualisieren:** Nach Änderungen in Xournal++ oder neuen Dateien anklicken.
- **Neues Notizbuch:** Erstellt eine neue `.xopp`-Datei mit drei karierten A4-Seiten
  und öffnet sie in Xournal++. Weitere Seiten und andere Papierstile dort einstellen.
  Vorhandene Dateien werden nicht überschrieben.
- **Ordner verwalten:** Suchordner aus der Übersicht entfernen. Das löscht keine
  Originaldateien. Ein weiter eingebundener übergeordneter Ordner findet die Dateien
  weiterhin.
- **Datei im Explorer:** Im Bearbeitungsdialog die Originaldatei anzeigen.

Die Cover sind gestaltete Buchumschläge mit Titel und Kategorie. Es sind keine
Vorschaubilder der ersten handschriftlichen Seite. Neu in 1.1: Über „Text erkennen /
exportieren“ können getippter Text und – experimentell – Stiftstriche offline
erfasst werden. Die Suche berücksichtigt danach auch diese Texte. Details und
Voraussetzungen stehen in `OFFLINE-TEXT.md`.

## Daten und Sicherung

Originalnotizen bleiben an ihrem bisherigen Speicherort. Das Regal liest die
Dateiliste; bearbeitet wird in Xournal++. Beim Anlegen eines neuen Notizbuchs schreibt Notizregal eine neue `.xopp`-Datei.
Bei ausdrücklich bestätigter Wiederherstellung ersetzt es die aktuelle XOPP-Datei
nach vorheriger Sicherung. Versionskopien werden separat in LocalAppData abgelegt.

Eigene Metadaten werden unter `%LOCALAPPDATA%\Notizregal\katalog.json` gespeichert.
Darin stehen Ordnerpfade, optional der Xournal++-Programmpfad sowie Titel,
Kategorien, Farben, Schlagwörter und Favoriten. Änderungen werden zunächst in eine
Temporärdatei geschrieben und dann atomar ersetzt; die vorherige Fassung bleibt
als `katalog.json.bak` erhalten. Bei einem unlesbaren Katalog startet das Programm
nicht weiter und überschreibt ihn nicht.

Für eine vollständige Sicherung sowohl deine Notizordner als auch den Ordner
`%LOCALAPPDATA%\Notizregal` sichern. Zum Zurücksetzen nur den Katalogordner nach dem
Beenden umbenennen. Originalnotizen bleiben erhalten. Zum Wiederherstellen einer
Sicherung bei geschlossenem Programm die bisherige JSON aufbewahren und eine
Kopie der `.bak` als `katalog.json` einsetzen.

Metadaten sind an den vollständigen Dateipfad gebunden. Wenn du eine Datei im
Explorer verschiebst oder umbenennst, wird sie neu erkannt und ihre bisherige
Gestaltung nicht automatisch übertragen. Es gibt keine Verschiebe-, Umbenennungs- oder Löschfunktion für Originaldateien.

## Nextcloud

Ein lokal synchronisierter Nextcloud-Ordner kann als Suchordner eingebunden werden.
Notizregal selbst stellt keine Verbindung zur Cloud her. Dateien müssen lokal
verfügbar sein; Echte Windows-Junctions und symbolische Links werden beim Scan übersprungen;
OneDrive-Cloud-Einträge werden ab Version 1.2.1 nicht mehr pauschal ausgeblendet. Bei großen Ordnern kann der Scan kurz blockieren.

Bei PDF-Notizen die `.xopp` und das zugehörige Original-PDF gemeinsam aufbewahren.
Das Regal kopiert oder verschiebt diese Dateien nicht. In Xournal++ beim PDF-Import
„Attach file to the journal“ nutzen und zusammenhängende Dateien gemeinsam sichern.
Nicht gleichzeitig auf mehreren Geräten an derselben Notiz arbeiten.

Der Gestaltungskatalog in LocalAppData wird nicht über Nextcloud synchronisiert.

## Startprobleme

**Start über CMD:** ZIP vollständig entpacken und die neue `Start.cmd` verwenden.
Die neue Startdatei führt die lokale Bereitstellung und Freigabe der heruntergeladenen
Skriptdatei selbst aus. `Notizregal.ps1`, `TextTools.ps1`, `AudioTools.ps1`, `VersionTools.ps1`, `VersionUi.ps1` und `Stickerpalette.ps1` werden im Anwendungsordner aktualisiert;
Notizbücher und Katalogdaten bleiben erhalten. Bitte ein bereits geöffnetes
Notizregal vor dem Update schließen.

Der Starter verwendet RemoteSigned nur für seinen PowerShell-Prozess. Er ändert
keine dauerhafte Ausführungsrichtlinie. Zentrale Firmenrichtlinien gelten weiter;
bei vorgeschriebener Signierung muss die IT das Skript freigeben bzw. signieren.
Eine digitale Signatur ist in diesem Paket nicht enthalten.

**Andere Startfehler:** Das CMD-Fenster bleibt bei Fehlern geöffnet. Zusätzlich wird
soweit möglich ein Protokoll in `%LOCALAPPDATA%\Notizregal\startfehler.txt` erstellt.
Dieses Protokoll kann zur Fehlerbehebung verwendet werden; es kann lokale Pfade enthalten.

**Xournal++ öffnet nicht:** Die passende `xournalpp.exe` im Programm auswählen.
Ohne expliziten Programmpfad verwendet Windows die Standardzuordnung für `.xopp`.

**Ein Notizbuch fehlt:** Filter und Favoriten prüfen, Aktualisieren klicken und
kontrollieren, ob die Datei im eingebundenen Ordner liegt und lokal verfügbar ist.
Nicht lesbare Ordner werden in der Statuszeile gemeldet.

## Prüfung und Stand

Version 1.3 ergänzt Offline-Audiotranskription zur vorhandenen Texterfassung, zum MD-/TXT-Export und zur Volltextsuche. Der korrigierte CMD-Start aus 1.0.1 bleibt erhalten. Die enthaltenen
`PRUEFUNG.md`-Hinweise nennen die durchgeführten Prüfungen und die noch erforderlichen
Windows-Tests. WPF-Oberfläche und Xournal++-Start konnten in der Linux-Bauumgebung
nicht ausgeführt werden. Es wird keine bereits getestete ARM-Kompatibilität behauptet.

## Dateien

- `Start.cmd`: startet Notizregal und optional die Stickerpalette.
- `Start-Stickerpalette.cmd`: startet nur die Stickerpalette.
- `Stickerpalette.ps1`: vollständiger Quellcode des Zusatzfensters.
- `OpenMoji`: Offline-Bildpaket, Suchkatalog und Lizenzdateien.
- `STICKERPALETTE.md`: Anleitung für Bilder und Sticker.
- `Notizregal.ps1`: vollständiger, anpassbarer Quellcode einschließlich Oberfläche.
- `README.md`: diese Anleitung.
- `VersionTools.ps1`: Sicherung, Prüfsummen und Wiederherstellung.
- `VersionUi.ps1`: Versionsdialog und automatische Hintergrundprüfung.
- `VERSIONEN-UND-PDF.md`: Anleitung für Versionsverlauf und PDF-Karten.
- `AudioTools.ps1`: lokale Audioverarbeitung.
- `AudioEngine`: ARM64-Programme, Sprachmodell, Quellen und Lizenzen.
- `AUDIO-TEXT.md`: Anleitung für Aufnahme, Transkription und Textübernahme.
- `TextTools.ps1`: lokale Textextraktion und Windows-Ink-Anbindung.
- `OFFLINE-TEXT.md`: Anleitung für Export und Offline-Handschrifterkennung.
- `PRUEFUNG.md`: Prüfergebnisse und kurzer Surface-Abnahmelauf.

Keine Telemetrie, kein Update-Dienst, keine externen Laufzeitbibliotheken.

## OneDrive – Korrektur in 1.2.1

Die vorherige Version übersprang alle sogenannten Reparse Points. OneDrive nutzt
diese Kennzeichnung auch für reguläre synchronisierte Dateien und Ordner. Der
Filter wurde auf echte Junctions und symbolische Links eingeschränkt.

Ab Version 1.4 zeigt das Regal `.xopp`-Notizbücher und PDFs. Word-/Textdateien
werden nur als weitere Dokumente gezählt. PDF-Anmerkungen in Xournal++ als `.xopp`
im Suchordner speichern, um auch für diese Notizen den Versionsverlauf zu erhalten.

Für Offline-Arbeit im Explorer den OneDrive-Notizordner mit der rechten Maustaste
anklicken und **Immer auf diesem Gerät behalten** wählen. Warten, bis die Dateien
heruntergeladen sind, dann im Regal **Aktualisieren** anklicken. Ein sichtbarer
Dateiname bedeutet noch nicht, dass der Inhalt offline verfügbar ist.

Bestehende Kategorien und Favoriten bleiben erhalten; den Ordner musst du nicht
entfernen oder neu hinzufügen. Die Korrektur ist statisch geprüft, aber noch nicht
mit einem echten OneDrive-Ordner auf dem Surface getestet.
