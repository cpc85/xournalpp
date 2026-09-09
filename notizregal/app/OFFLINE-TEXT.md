# Offline-Texte auf dem Surface SQ1 / 8 GB – Version 1.1

Diese Erweiterung benötigt kein großes KI-Modell, keinen Server und keinen
Cloud-Dienst. Die App enthält keine Netzwerkaufrufe. Die Handschrifterkennung
verwendet die auf dem Gerät installierte Windows-Ink-Erkennung.

## Start

Altes Notizregal schließen, das neue ZIP vollständig entpacken und Start.cmd
öffnen. Der Starter aktualisiert die beiden Programmdateien automatisch im lokalen
Benutzerordner. Notizbücher und der bisherige Katalog bleiben erhalten.

## Notizbuch erfassen

1. Notiz zunächst in Xournal++ speichern.
2. Im Regal beim Notizbuch **Text erkennen / exportieren** anklicken.
3. **Handschrift erkennen** aktiviert lassen und **Text erfassen / aktualisieren**
   wählen. Zum alleinigen Auslesen getippten Texts den Haken entfernen.
4. Der Dienst verarbeitet das Notizbuch in einem eigenen lokalen Prozess.
   Das Fenster bleibt bedienbar; **Abbrechen** beendet den Erkennungsvorgang.
5. Seite im Auswahlfeld wählen. Erkannten Text kontrollieren und gegebenenfalls
   korrigieren, dann **Korrekturen speichern**.
6. **MD / TXT exportieren** öffnet einen Speicherdialog. Im Dateitypfeld Markdown
   oder Text auswählen. Der Export enthält alle Seiten, nicht nur die angezeigte.

Die erfassten Texte stehen anschließend automatisch in der Regalsuche zur
Verfügung, auch nach einem Neustart. Suchtreffer zeigen die erste passende
Seitenzahl und einen kurzen Textausschnitt. Im Textfenster diese Seite auswählen.
Das Original öffnet weiterhin in Xournal++; kein automatischer Sprung zur Seite
in Xournal++.

## Voraussetzung für Handschrift

Windows muss den deutschen Handschrifterkenner installiert haben. Unter
**Einstellungen > Zeit und Sprache > Sprache und Region > Deutsch > Sprachoptionen**
den Eintrag **Handschrift** prüfen. Je nach Windows-Version sind Bezeichnungen
leicht anders.

Die Erkennung selbst läuft offline. Falls das Windows-Sprachfeature fehlt,
muss es zuvor installiert werden (normalerweise einmaliger Download). Auf einem
komplett vom Internet getrennten Surface kann die IT das passende Windows-
Features-on-Demand-Paket offline bereitstellen. Notizregal lädt selbst nichts nach
und benötigt keinen Zugang zum Microsoft-Konto.

Fehlt der deutsche Erkenner oder kann er auf dem Gerät nicht geladen werden,
bleibt die App nutzbar: Getippter Text wird gespeichert und ein Hinweis benennt
die nicht erfasste Handschrift. Es wird nicht unbemerkt auf eine andere Sprache
oder einen Cloud-Dienst gewechselt.

## Was funktioniert, was bleibt offen?

- Getippter Text: Wird direkt aus den Textobjekten im XOPP-XML gelesen.
- Handschrift: Pen-Strokes werden aus Xournal++ in Windows-Ink-Striche umgewandelt
  und seitenweise erkannt. Diese Anbindung ist experimentell und wurde noch nicht
  auf einem Surface ausgeführt. Sie ist kein bereits nachgewiesener ARM-Support.
- Die Erkennung arbeitet mit den gespeicherten Strichen, nicht mit Screenshots.
- Markierungen mit dem Textmarker werden nicht an den Handschrifterkenner geschickt.
- Skizzen und geometrische Formen aus Pen-Strokes können zu falschen Texttreffern
  führen. Ergebnisse unbedingt prüfen, besonders Namen und Zahlen.
- Handschrift aus eingefügten Fotos oder Scans sowie gedruckter Text im
  PDF-Hintergrund werden in Version 1.1 nicht erkannt. Handschrift, die in Xournal++
  auf einen PDF-Hintergrund geschrieben wurde, kann erkannt werden.
- Der Textexport bildet Seiten ab, aber nicht die exakte Positionierung,
  Zeichnungen, Tabellen oder Formatierung. Getippter Text und erkannte Handschrift
  werden je Seite nacheinander abgelegt. Verborgene Ebenen werden mit ausgewertet.
- Volltextsuche findet nur Wörter, die erfasst oder von dir korrigiert wurden.
  Es gibt keine garantierte Erkennungsquote.

## Aktualisieren und Korrekturen

Die App zeigt **Textstand veraltet**, wenn Änderungszeit oder Größe der
Originaldatei vom Erkennungsstand abweichen. Es gibt keine automatische erneute
Erkennung beim Speichern in Xournal++: **Text erfassen / aktualisieren** bewusst
aufrufen. Erneutes Erkennen ersetzt auch eigene Textkorrekturen; vorher erscheint
im Programm eine Rückfrage. Die vorherige Indexfassung bleibt als .bak erhalten.

Für eine neue Erkennung möglichst nicht gleichzeitig in Xournal++ speichern.
Die App prüft, ob die Quelldatei während der Verarbeitung geändert wurde.

## Speicher und Sicherung

Die Suchtexte liegen unter `%LOCALAPPDATA%\Notizregal\texte` als JSON-Dateien.
Je Notizbuch werden Seiten, Text, Warnungen und der Stand der Quelldatei gespeichert.
Die Ordnernamen werden aus dem vollständigen Notizpfad abgeleitet. Verschieben oder
Umbenennen eines Originals erfordert wie bisher eine erneute Zuordnung/Erfassung.

Diese JSON-Dateien enthalten deine Notiztexte unverschlüsselt, ebenso wie ein
MD-/TXT-Export. Sie verlassen das Gerät durch Notizregal nicht. Wenn du einen
Export in einen synchronisierten Ordner speicherst, gelten dessen eigene
Synchronisationseinstellungen.

Beim Sichern den ganzen Ordner `%LOCALAPPDATA%\Notizregal` einschließlich `texte`
und zusätzlich die Originalnotizbücher sichern. Der Gestaltungskatalog wird durch
die Texterkennung nicht ersetzt.

## Technische Grundlage

Microsoft dokumentiert die Erkennung mit InkRecognizerContainer und das Erstellen
von InkStroke-Objekten aus Koordinaten:

- https://learn.microsoft.com/en-us/windows/uwp/ui-input/convert-ink-to-text
- https://learn.microsoft.com/en-us/uwp/api/windows.ui.input.inking.inkrecognizercontainer
- https://learn.microsoft.com/en-us/uwp/api/windows.ui.input.inking.inkstrokebuilder.createstroke

Windows-PowerShell-5.1/WinRT-Brücke. Pro Seite ein begrenzter Erkennungsauftrag;
keine zusätzliche Python-/Ollama-Installation und keine GPU erforderlich.

## Erster Praxistest

Zuerst ein kleines Notizbuch mit ein paar handschriftlichen Zeilen testen.
Wenn im Textfenster ein Fehler erscheint, dessen genauen Text mitteilen.
Ohne Haken bei „Handschrift erkennen“ lässt sich die Textextraktion separat testen.
Das trennt einen Fehler beim XOPP-Lesen von einem Windows-Erkennerproblem.
