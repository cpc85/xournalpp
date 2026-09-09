# Audio → Text: komplett offline auf dem Surface

## Erstes Update

Notizregal und Stickerpalette schließen. Das vollständige ZIP entpacken und
Start.cmd doppelklicken. Der Starter aktualisiert die Anwendung und kopiert die
enthaltene Spracherkennung einmalig nach %LOCALAPPDATA%\Notizregal-App.
Bestehende Notizbücher, Kategorien und Favoriten bleiben erhalten.

Die Audio-Komponenten sind für Windows ARM64 gebaut, passend zum Surface SQ1.
Das mehrsprachige Sprachmodell ist bereits enthalten: kein Konto, Python,
Internet oder separater Modelldownload nötig. Das Gesamtpaket benötigt mehrere
hundert MB freien Speicher für entpacktes Paket, lokale App-Kopie und Arbeitsdateien.

## Aufnahme in Text umwandeln

1. In Xournal++ die Aufnahme **stoppen** und das Notizbuch speichern.
2. Beim passenden Notizbuch im Regal auf **Audio → Text** klicken.
3. **Aufnahme auswählen …** öffnen und die gespeicherte .ogg- oder .wav-Datei
   aus dem Aufnahmeordner wählen, den du in Xournal++ eingestellt hast.
4. **Deutsch** wählen und **Transkribieren** anklicken.
5. Nach Abschluss erscheint das Transkript mit ungefähren Zeitmarken.
   Es wird automatisch diesem Notizbuch zugeordnet und lokal gespeichert.
6. Dialog schließen. Die Regalsuche findet jetzt auch Wörter aus dem Transkript.

Die Aufnahme wird nicht automatisch beim Stoppen in Xournal++ übernommen.
Du wählst Datei und zugehöriges Notizbuch bewusst im Regal aus. Weitere Aufnahmen
lassen sich demselben Notizbuch hinzufügen und im Auswahlfeld einzeln öffnen.

## Korrigieren, exportieren und in Xournal++ einfügen

- Den Text im Fenster bearbeiten und **Korrekturen speichern** anklicken.
- **Text kopieren** kopiert das aktuell angezeigte Transkript.
  In Xournal++ das Textwerkzeug wählen, auf die Seite klicken und Strg+V drücken.
- **Alle als MD / TXT** exportiert alle Audiotranskripte dieses Notizbuchs.
  Das Dateiformat im Speicherdialog auswählen.
- Bei erneuter Erkennung derselben Aufnahme wird vor dem Ersetzen bestehender
  Korrekturen nachgefragt. Ein Abbruch lässt die gespeicherten Texte bestehen.

XOPP-Dateien werden durch die Audiofunktion nicht verändert. Transkripte und
Handschrifterkennung sind getrennt gespeichert; beide fließen in die Suche ein.

## Geschwindigkeit und Grenzen

Das kleine quantisierte Whisper-base-Modell arbeitet auf der CPU mit vier Threads.
Auf dem SQ1 kann die Verarbeitung länger dauern als die Aufnahme. Die tatsächliche
Geschwindigkeit auf diesem Gerät wurde noch nicht gemessen. Zuerst eine kurze,
gut hörbare Aufnahme von etwa 30–60 Sekunden verwenden. Lange Sitzungen möglichst
in Abschnitte teilen; maximal vier Stunden pro Datei werden angenommen.

Unterstützt: Ogg **Vorbis** und WAV. Ogg Opus, MP3 und M4A werden nicht unterstützt.
Eine noch laufende Aufnahme zuerst beenden. OneDrive-Dateien müssen für vollständig
offline Nutzung bereits lokal vorliegen ("Immer auf diesem Gerät behalten").

Keine Sprecherzuordnung, keine automatische Zusammenfassung, keine Live-Diktierfunktion.
Namen, Zahlen und Fachwörter kontrollieren. Bei Stille oder schlechter Tonqualität
kann die Erkennung falsche Wörter erzeugen. Zeitmarken sind Näherungen.

## Daten, Sicherung und Fehler

- Audioindizes: %LOCALAPPDATA%\Notizregal\audio
- Arbeitsprotokolle und Ergebnisdateien: %LOCALAPPDATA%\Notizregal\audio-auftraege
- App und mitgeliefertes Modell: %LOCALAPPDATA%\Notizregal-App\AudioEngine

Die Texte und Protokolle liegen lokal unverschlüsselt vor. Die temporäre WAV-Kopie
wird nach Abschluss oder Abbruch entfernt. Protokolle und Ergebnistext bleiben zur
Fehlersuche erhalten; bei geschlossener App darf audio-auftraege geleert werden.
Originalaufnahmen bleiben an ihrem bisherigen Ort. Für Sicherungen die Aufnahmen,
Notizbücher und den gesamten Ordner %LOCALAPPDATA%\Notizregal berücksichtigen.
Die Zuordnung ist an den vollständigen Notizbuchpfad gebunden.

Bei Fehlern **Protokoll** öffnen und die genaue Meldung mitteilen. Fehlt eine
Audio-Komponente, das komplette Paket erneut entpacken und Start.cmd ausführen.
Quellen, Lizenzen und Build-Hinweise stehen in AudioEngine\BUILD.md.
