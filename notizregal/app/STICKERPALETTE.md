# Stickerpalette – Notizregal 1.2

## Start

1. Notizregal und gegebenenfalls die alte Stickerpalette schließen.
2. Das neue ZIP **vollständig** entpacken, einschließlich des Ordners `OpenMoji`.
3. `Start.cmd` doppelt anklicken. Beim ersten Start werden die Bilder zusätzlich
   lokal bereitgestellt; das kann wegen der vielen Dateien etwas dauern.
4. Notizregal und Stickerpalette öffnen sich. Alternativ im Regal auf
   **Bilder & Sticker** klicken.

`Start-Stickerpalette.cmd` startet nur die Palette. Beide Starter können aus einem
entpackten Ordner auf Z: verwendet werden. Sie kopieren die Programmdateien und das
Bildpaket nach `%LOCALAPPDATA%\Notizregal-App`. Nach dem ersten Start werden die
OpenMoji-Bilder nur bei geänderter Paketversion erneut kopiert.

Kein Installer, keine Administratorrechte und kein Internet während der Nutzung.
Zentrale Windows-Richtlinien gelten weiterhin. Eine Signatur ist nicht enthalten.

## Enthalten

- 4.495 farbige OpenMoji-Motive (OpenMoji 17.0.0).
- PNG mit transparentem Hintergrund, jeweils 618 × 618 Pixel.
- Kategorien in deutscher Sprache.
- 1.606 Einträge mit deutschen Namen/Suchbegriffen aus Unicode CLDR; für die
  übrigen Einträge dienen die englischen Originalnamen als Rückfall.
- Suche nach mehreren Begriffen: Alle eingegebenen Wörter müssen passen.
- Favoriten, gespeicherte Fensteroptionen und Import eigener Bilder.

Es werden maximal 60 Vorschaubilder pro Seite geladen. Das hält die Anzeige auch
bei vielen Motiven überschaubar und reduziert den Speicherbedarf auf dem Surface.

## In Xournal++ verwenden

1. Ein Motiv antippen; sein Name steht unten.
2. **Bild kopieren** wählen.
3. Zu Xournal++ wechseln und **Strg+V** drücken. Größe und Position dort anpassen.

Die Palette legt sowohl ein Bitmap als auch PNG-Daten in die Windows-Zwischenablage.
Die tatsächliche Übergabe, insbesondere der Transparenz, muss noch auf deinem
Surface mit der installierten Xournal++-Version getestet werden.

**Falls Einfügen nicht klappt oder der Hintergrund falsch erscheint:**
In der Palette **PNG speichern** wählen. Anschließend in Xournal++ das Bildwerkzeug
verwenden und die gespeicherte PNG auswählen. Das ist der unabhängige Ausweichweg.

## Fenster und Favoriten

- **Immer im Vordergrund:** Palette über anderen Fenstern halten.
- **Mit Notizregal starten:** automatisches Mitstarten aktivieren/deaktivieren;
  standardmäßig aktiv. Das ist kein Windows-Autostart beim Anmelden.
- **Merken:** das ausgewählte Motiv zu Favoriten hinzufügen oder entfernen.
- **Favoriten:** nur gemerkte Bilder anzeigen.
- **Zurück / Weiter:** durch die Bildseiten blättern.

Die Palette ist ein separates Fenster in einem eigenen Prozess. Sie kann auch
weiter geöffnet bleiben, wenn du das Notizregal schließt. Es wird pro Windows-
Sitzung nur eine Palette geöffnet.

## Eigene Bilder

**Eigene Bilder +** nimmt PNG, JPG/JPEG, GIF und BMP auf. Die Dateien werden in die
lokale Sammlung kopiert und als PNG gespeichert; die Quelldateien bleiben erhalten.
GIFs werden als Standbild (erster Frame) übernommen. Große Fotos werden auf maximal
1.600 Pixel an der längeren Kante verkleinert. Dateinamen dienen als Suchbegriffe.
SVG-Import und animierte GIF-Wiedergabe sind in dieser Version nicht enthalten.

Eigene Bilder liegen unter `%LOCALAPPDATA%\Notizregal\sticker\eigene`.
Favoriten und Optionen stehen daneben in `einstellungen.json` (mit .bak-Sicherung).
Der bisherige Notizbuchkatalog und der Textindex werden durch die Palette nicht
verändert. Zur Sicherung den gesamten Ordner `%LOCALAPPDATA%\Notizregal` kopieren.

## Bildquellen und Lizenzen

OpenMoji: https://github.com/hfg-gmuend/openmoji
Urheber: OpenMoji / HfG Schwäbisch Gmünd und Mitwirkende. Grafiken CC BY-SA 4.0.
Für dieses Paket wurden die SVGs in PNG gerastert. Lizenz und Quellenangaben liegen
unter `OpenMoji`. Bei der Weitergabe verwendeter OpenMoji-Grafiken die zugehörigen
Lizenzbedingungen und Quellenangaben beibehalten.

Deutsche Namen und Suchbegriffe: Unicode CLDR 48.2.0.
https://github.com/unicode-org/cldr-json
Die mitgelieferte Unicode-Lizenz steht in `OpenMoji/LICENSE-Unicode.txt`.

## Prüfstand

Geprüft: PowerShell-Syntax, XAML-Struktur, Starter, Katalog, alle 4.495 PNG-Dateien,
Beispiele der deutschen Suchbegriffe und ZIP-Integrität.

Noch nicht praktisch geprüft: neues WPF-Fenster unter Windows/ARM,
Zwischenablage nach Xournal++, Importdialoge und gemeinsame Fensterbedienung.
Die bestehende Version 1.0.1 hatte der Benutzer auf dem Surface erfolgreich gestartet.
