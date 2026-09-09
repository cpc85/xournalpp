# Notizregal-Fork von Xournal++

Dieser Fork ergänzt Xournal++ um die Zusatzfunktionen aus **Notizregal 1.4** –
umgesetzt als **aktivierbare Lua-Plugins** über das native Plugin-System von
Xournal++ (Einstellungen → Plugins). Der Xournal++-Kern bleibt unverändert; die
Funktionen sind einzeln zu- und abschaltbar.

> Kurzfassung der Architektur: Die Plugins sind dünne Lua-Brücken. Die
> eigentliche, bewährte Logik (Versionierung, Texterkennung, Whisper-Audio,
> OpenMoji-Sticker) steckt weiterhin in den PowerShell-/EXE-Werkzeugen aus
> Notizregal, die unter `notizregal/` mitgeliefert werden. Ein Dispatcher
> (`notizregal/NotizregalBridge.ps1`) verbindet beides.

## Die fünf Plugins

| Plugin (Ordner) | Menü in Xournal++ | Funktion |
|---|---|---|
| `NotizregalRegal` | Notizbuchregal öffnen | Öffnet das visuelle Regal (Cover, Kategorien, Favoriten, Suche, PDF-Karten, Versionen) als Fenster neben dem Editor. |
| `NotizregalVersionen` | Version sichern / anzeigen | Manuelle Sicherung, Liste, Wiederherstellung und Export von `.xopp`-Versionen des aktuell geöffneten Notizbuchs. |
| `NotizregalTextexport` | Text erkennen / exportieren | Getippten Text (und experimentell Windows-Ink-Handschrift) extrahieren, einfügen oder als Markdown/TXT speichern. |
| `NotizregalAudio` | Audio transkribieren | OGG/WAV-Aufnahmen offline mit dem enthaltenen Whisper-Modell in Text umwandeln, einfügen oder speichern. |
| `NotizregalSticker` | Stickerpalette | OpenMoji-Sticker einfügen – zum markierten Wort direkt in die Notiz, oder über das volle Palettenfenster (Suche/Favoriten). |
| `NotizregalNextcloud` | Nextcloud-Sync | Aktuelles Notizbuch per WebDAV in eine Nextcloud hochladen und Dateien zurückholen; Zugang per WPF-Dialog, App-Passwort lokal per DPAPI verschlüsselt. |

Alle Plugins stehen in `plugins/` und sind mit `enabled=false` vorkonfiguriert –
sie erscheinen erst nach dem Aktivieren in **Einstellungen → Plugins**.

## Aktivieren

1. Xournal++ aus diesem Fork bauen/installieren (siehe `readme/`), oder die
   Plugins in einen von Xournal++ gelesenen Plugin-Ordner legen.
2. In Xournal++: **Bearbeiten → Einstellungen → Plugins**, die gewünschten
   „Notizregal…“-Plugins ankreuzen, Xournal++ neu starten.
3. Die Funktionen erscheinen im Menü **Plugins**.

## Warum Brücken statt reiner Neubau?

Notizregal ist bewusst ein **Verwalter um den Editor herum** (Windows/WPF). Die
Lua-Plugin-API von Xournal++ eignet sich hervorragend für Menü-/Toolbar-Aktionen
und den Aufruf externer Werkzeuge, kann aber keine vollwertigen Fenster wie das
Cover-Regal oder das Grid mit 4.495 Stickern nachbauen (es gibt z. B. auch kein
Freitext-Eingabefeld). Daher:

- **In den Zeichenbereich integriert** (echte Lua-Aktionen): Versionierung,
  Textexport/-einfügen, Audiotranskription, Sticker-Einfügen zum markierten Wort.
- **Als Hilfsfenster geöffnet** (bewährte WPF-Oberfläche): das Regal und die
  volle Stickerpalette (Bild kopieren → in Xournal++ mit Strg+V einfügen).

## Datenaustausch (Bridge-Protokoll)

Vollständig dateibasiert, ohne Zusatzbibliotheken:

- **Anfrage** Lua → PowerShell: Textdatei mit abwechselnden Name-/Wertzeilen (UTF-8).
- **Antwort** PowerShell → Lua: `…​.result` mit einem **Lua-Literal**
  (`return { … }`), das das Plugin per `load()` einliest. Fehler landen in
  `…​.error`. Details siehe Kopf von `notizregal/NotizregalBridge.ps1` und
  `notizregal/lua/notizregal.lua`.

Bridge-Befehle: `save-version`, `list-versions`, `restore-version`,
`export-version`, `extract-text`, `transcribe`, `find-stickers`,
`nextcloud-upload`, `nextcloud-download`, `nextcloud-list`, `nextcloud-test`.

### Nextcloud-WebDAV-Sync

`NotizregalNextcloud` lädt das aktuell geöffnete `.xopp` per WebDAV hoch
(`PUT` auf `<server>/remote.php/dav/files/<benutzer>/<ordner>/…`), listet den
Zielordner (`PROPFIND`) und lädt Dateien zurück (`GET`, `.xopp` optional direkt
öffnen). Zugangsdaten werden über das WPF-Fenster `NextcloudConfig.ps1`
eingegeben und in `%LOCALAPPDATA%\Notizregal\nextcloud.json` gespeichert; das
**App-Passwort ist per Windows-DPAPI** (an den Windows-Benutzer gebunden)
verschlüsselt und verlässt das Gerät nicht. Empfohlen: HTTPS und ein
Nextcloud-App-Passwort (Einstellungen → Sicherheit). Der WebDAV-Client wurde
gegen einen lokalen Test-Server geprüft (Upload/Liste/Download, Basic-Auth).

## Voraussetzungen und Grenzen

- **Windows** mit **Windows PowerShell 5.1** (WPF/WinRT). Auf Nicht-Windows
  melden die Plugins dies und tun nichts (der Editor bleibt unberührt).
- **Handschrifterkennung** nutzt Windows Ink (deutsches Handschriftpaket muss
  installiert sein) – experimentell.
- **Audiotranskription** nutzt die enthaltene `AudioEngine` (whisper-cli, Modell),
  ausgelegt auf **Windows ARM64** (Surface SQ1). Auf x64 ggf. passende Binärdateien
  bereitstellen.
- **Automatische Versionssicherung beim Speichern** bietet die Lua-API nicht
  (kein Save-Ereignis); Sicherung erfolgt hier manuell bzw. weiterhin durch das
  Regal-Fenster im Hintergrund, solange es geöffnet ist.
- Diese Integration wurde auf einem Nicht-Windows-Build-System **nicht** in einem
  laufenden Xournal++ getestet; die PowerShell-Bridge selbst ist getestet
  (Versionen, Sticker-Suche, Textextraktion). Windows-/Surface-Abnahme steht aus.

## Assets (wichtig für Git)

Zwei große Binärbestände sind aus Größengründen **nicht** versioniert (siehe
`.gitignore`) und müssen aus dem Original-Paket `Notizregal-Surface-v1.4.zip`
nach `notizregal/app/` übernommen werden – oder per **Git LFS** verwaltet:

- `notizregal/app/OpenMoji/png/` – 4.495 Sticker-PNGs (~111 MB)
- `notizregal/app/AudioEngine/ggml-base-q5_1.bin` – Whisper-Modell (~57 MB)
- `notizregal/app/AudioEngine/source/whisper.cpp-v1.8.5.tar.gz` – Quell-Tarball

Ohne diese Dateien laufen die übrigen Plugins normal; Sticker-/Audiofunktionen
melden das Fehlen verständlich. Katalog (`katalog.json`), Lizenztexte und die
kleinen Programme (`whisper-cli.exe`, `audio-convert.exe`) sind versioniert.

## Build/Installation

`install(DIRECTORY notizregal …)` in `CMakeLists.txt` liefert den Werkzeugordner
nach `share/xournalpp/notizregal`. Die Plugins finden ihn relativ als
`../../notizregal`; alternativ kann `NOTIZREGAL_HOME` auf den Ordner gesetzt
werden. Die neuen Plugin-Ordner werden über die bestehende
`install(DIRECTORY plugins …)`-Regel automatisch mitinstalliert.

## Lizenzen

Der eigene Fork-Code (Plugins, Bridge) steht unter derselben Lizenz wie
Xournal++ (GPL), sofern nicht anders festgelegt. Die mitgelieferten Bestände
behalten ihre Lizenzen (Dateien unter `notizregal/app/…`):

- **OpenMoji** – CC BY-SA 4.0 (`LICENSE-OpenMoji.txt`), deutsche Begriffe: Unicode CLDR.
- **whisper.cpp / Modell / Laufzeit** – siehe `AudioEngine/LICENSE-*.txt`.

Vor einer Veröffentlichung die Lizenz für den eigenen Anwendungscode festlegen
und alle enthaltenen Urheber-/Lizenzhinweise übernehmen.
