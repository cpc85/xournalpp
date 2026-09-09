# Plan: Notizregal **nativ** in Xournal++ einbauen

Ziel laut Vorgabe: die sechs Notizregal-Funktionen **komplett in Xournal++
integriert** – kein Lua, keine `.ps1`, kein separates Fenster – mit **eigener
Icon-/Toolbar-Palette** und Dialogen *innerhalb* des Programms. Dieses Dokument
beschreibt, **wie** das im vorhandenen C++/GTK-Quellcode geht, welche Dateien
betroffen sind, welcher Aufwand/Risiko je Funktion entsteht und in welcher
Reihenfolge sinnvoll gebaut wird.

> **Rahmenbedingung (unverändert):** Dieser Rechner hat keine C++/GTK-Toolchain –
> nativer Code wird hier **geschrieben, aber nicht kompiliert**. Gebaut wird über
> den **CI-Windows-Build (x64/ARM)**; Iteration = Push → CI-Artefakt → Test.

---

## 1. Wie Xournal++ intern aufgebaut ist (die Andockpunkte)

Aus der Code-Analyse dieses Forks:

| Baustein | Ort | Bedeutung für uns |
|---|---|---|
| **Aktionen** | [Action.enum.h](src/core/enums/Action.enum.h) + generierte NameMap + [ActionDatabase.cpp](src/core/control/actions/ActionDatabase.cpp) | Jede Funktion wird eine `Action` (GAction). Menü/Toolbar verweisen als `win.<name>` darauf; behandelt in [Control.cpp](src/core/control/Control.cpp). |
| **Toolbar + Icons** | [ToolMenuHandler::initToolItems()](src/core/gui/toolbarMenubar/ToolMenuHandler.cpp:196), [ToolButton.cpp](src/core/gui/toolbarMenubar/ToolButton.cpp) | Buttons via `emplaceItem<ToolButton>(name, Kategorie, Action, iconName("…"), Beschreibung)`. Icons werden **per Icon-Name** aus den mitgelieferten Icon-Themes geladen (`ui/iconsColor-*`, `ui/iconsLucide-*`). Kategorie steuert die Gruppe in der Toolbar-Anpassung. |
| **Menüleiste** | [ui/mainmenubar.xml](ui/mainmenubar.xml) (GMenu-XML) | Neues Untermenü „Notizregal“ mit `win.<action>`-Einträgen. |
| **Dialoge** | `ui/*.glade` + Controller-Klasse, Vorbild [LatexController.h](src/core/control/LatexController.h) / [AbstractLatexDialog.h](src/core/gui/dialog/AbstractLatexDialog.h) | Muster für native Dialoge mit externer Engine (LaTeX ruft extern, Ergebnis kommt zurück in die GTK-Oberfläche). |
| **Seitenleiste (Panel)** | [AbstractSidebarPage.h](src/core/gui/sidebar/AbstractSidebarPage.h), [Sidebar.h](src/core/gui/sidebar/Sidebar.h) | Für ein **in-place-Panel** (Sticker-Grid, Notizbuchregal) ohne Fremdfenster. |
| **Speicher-Flow** | [Control::saveImpl()](src/core/control/Control.cpp:2123) | Hook nach erfolgreichem Speichern → automatische Versionssicherung nativ. |
| **Einstellungen** | [Settings.h](src/core/control/settings/Settings.h) (Muster `LatexSettings`) | Für Nextcloud-Konfiguration (URL/Benutzer/Ordner). |
| **Audio** | [AudioRecorder.h](src/core/audio/AudioRecorder.h), [AudioController.cpp](src/core/control/AudioController.cpp) | Aufnahmen liegen bereits als OGG/Vorbis im `.xopp` → native Quelle für Whisper. |

**Icon-Palette:** Xournal++ zeigt Toolbar-Buttons in der „Werkzeugleiste
anpassen“ nach **Kategorie** gruppiert. Wir führen eine neue Kategorie
`Category::NOTIZREGAL` ein und liefern eigene SVGs (Namen z. B.
`nz-version`, `nz-text`, `nz-audio`, `nz-sticker`, `nz-regal`, `nz-cloud`) in die
Icon-Themes (`ui/iconsColor-{light,dark}/hicolor/scalable/actions/` und die
Lucide-Pendants). Damit erscheint eine geschlossene **Notizregal-Icongruppe**,
die man auf jede Toolbar ziehen kann.

---

## 2. Architektur des nativen Notizregal-Moduls

Neues Unterverzeichnis `src/core/control/notizregal/` (plus Dialoge unter
`src/core/gui/dialog/notizregal/`), eingebunden in die bestehende
`CMakeLists.txt`-Quellenliste:

```
src/core/control/notizregal/
  NotebookVersioning.{h,cpp}     Versions-Sicherung/-Wiederherstellung (.xopp)
  NoteTextExtractor.{h,cpp}      getippten Text aus dem Dokument-Modell lesen
  HandwritingRecognizer.{h,cpp}  Windows-Ink (nur win32; #ifdef)
  AudioTranscriber.{h,cpp}       Whisper-Aufruf (Engine gebündelt/gelinkt)
  StickerLibrary.{h,cpp}         OpenMoji-Katalog laden/suchen
  NextcloudClient.{h,cpp}        WebDAV (libcurl): PUT/GET/PROPFIND/MKCOL
  NextcloudSettings.{h,cpp}      Konfiguration (Settings-Integration)
src/core/gui/dialog/notizregal/
  VersionsDialog, AudioDialog, NextcloudConfigDialog   (.glade + Controller)
src/core/gui/sidebar/notizregal/
  StickerSidebarPage, RegalSidebarPage                 (AbstractSidebarPage)
```

Vorteil: Text-/Modellzugriff (getippter Text, Bild-/Sticker-Einfügen) nutzt
**direkt** das Dokumentmodell (`Document`, `Layer`, `Text`, `Image`) statt über
Dateien – schneller und ohne Umweg. Die bisherigen Lua-/PowerShell-Teile
entfallen (siehe §7).

---

## 3. Funktion für Funktion

Legende Aufwand: ● klein · ●● mittel · ●●● groß. „Extern“ = unvermeidbare
Fremdkomponente.

### 3.1 Versionierung ● (empfohlener Start)
- **UI:** Toolbar-Icon `nz-version` + Menü „Notizregal → Versionen …“ →
  nativer **VersionsDialog** (GTK-Liste: Zeitpunkt/Grund, Buttons
  Wiederherstellen/Exportieren). Zusätzlich Auto-Sicherung.
- **C++:** `NotebookVersioning` schreibt beim Speichern
  ([Control::saveImpl](src/core/control/Control.cpp:2123), nach Erfolg) eine
  Kopie + SHA-256 nach `LocalAppData/xournalpp/notizregal/versionen/…` (Logik wie
  im bewährten `VersionTools.ps1`, aber in C++).
- **Extern:** keine. **Risiko:** gering. **Vorteil:** löst zugleich das bisher
  fehlende „Auto-Sicherung beim Speichern“, das im Plugin-API nicht ging.

### 3.2 Text erkennen / exportieren / einfügen ●
- **UI:** Icon `nz-text` + Menüpunkte „Text exportieren (MD/TXT)“, „Text
  einfügen“.
- **C++:** `NoteTextExtractor` liest getippten Text **direkt** aus dem
  Dokumentmodell (kein XML-Parsen nötig). Export über die vorhandenen
  Datei-Dialoge; Einfügen erzeugt ein `Text`-Element.
- **Extern:** nur Handschrift (siehe 3.2b). **Risiko:** gering.

### 3.2b Handschrifterkennung ●● (Windows-only, extern)
- **C++:** `HandwritingRecognizer` ruft **Windows Ink** (WinRT `InkRecognizer`)
  direkt aus C++ (`#ifdef _WIN32`, WinRT/C++) – **kein Fremdfenster**, Ergebnis
  landet im Text/Export. Auf Nicht-Windows deaktiviert.
- **Risiko:** mittel (WinRT-Anbindung, Koordinaten wie in der bewährten PS-Logik).

### 3.3 Audio → Text (Whisper) ●● (extern)
- **UI:** Icon `nz-audio` + **AudioDialog**: Aufnahme des `.xopp` wählen,
  Fortschritt, Ergebnis einfügen/exportieren.
- **C++:** `AudioTranscriber` nutzt die bereits als OGG vorliegenden Aufnahmen.
  **whisper.cpp wird in den Build integriert** (per Arch gebaut) und **in-process
  bzw. als gebündelter Hintergrundprozess ohne Fenster** aufgerufen. Modell
  (`ggml-base`) bleibt eine mitgelieferte Datei (unvermeidbar).
- **Risiko:** mittel (Build-Integration whisper.cpp für x64 **und** ARM64).

### 3.4 Sticker (natives Panel) ●●●
- **UI:** Icon `nz-sticker` + **StickerSidebarPage**: echtes GTK-Grid mit
  OpenMoji-Vorschauen, Suchfeld, Kategorien, Favoriten – **im Xournal++-Fenster**
  (Seitenleiste), kein Fremdfenster. Klick fügt das Bild als `Image` in die Notiz.
- **C++:** `StickerLibrary` lädt `katalog.json` + PNGs; GTK-`GtkFlowBox`/`GtkGrid`
  mit lazy-loading (4.495 Bilder).
- **Extern:** keine. **Risiko:** hoch (viel GTK-UI, Performance des Grids).

### 3.5 Notizbuchregal (natives Panel) ●●●
- **UI:** Icon `nz-regal` + **RegalSidebarPage** oder eigener Andock-Bereich:
  Cover-Kacheln, Kategorien, Favoriten, Suche, PDF-Karten – nativ.
- **C++:** Katalog (`katalog.json`-Äquivalent) nativ; Klick öffnet Datei via
  `Control::openFile`. **Konzepthinweis:** Das Regal ist ein Verwalter *vieler*
  Dokumente – als Panel im Editor sinnvoll, aber die aufwendigste Fläche.
- **Extern:** keine. **Risiko:** hoch.

### 3.6 Nextcloud-WebDAV-Sync ●●
- **UI:** Icon `nz-cloud` + Menü „Hochladen / Herunterladen …“ + nativer
  **NextcloudConfigDialog**.
- **C++:** `NextcloudClient` per **libcurl** (PUT/GET/PROPFIND/MKCOL, Basic-Auth) –
  Logik wie im getesteten `NextcloudTools.ps1`. Konfiguration in `NextcloudSettings`;
  App-Passwort im **Windows Credential Manager** (statt Klartext).
- **Extern:** libcurl (neue Build-Abhängigkeit; in MSYS2 vorhanden).
  **Risiko:** mittel.

---

## 4. Build & CI (x64 + ARM)

- Neue Quelldateien in die `add_library`/`target_sources`-Liste der
  [CMakeLists.txt](CMakeLists.txt) aufnehmen; neue Icons landen automatisch über
  die bestehenden `install(DIRECTORY ui …)`-Regeln.
- **Neue Abhängigkeiten:** `libcurl` (Nextcloud) und `whisper.cpp` (Audio) müssen
  in `.github/actions/install_deps_windows` bzw. der MSYS2-Paketliste ergänzt und
  **für x64 (UCRT64/MINGW64) und ARM64 (CLANGARM64 auf `windows-11-arm`)** gebaut
  werden.
- **Aktions-Namemap:** `Action.enum.h` erweitern und die generierte NameMap neu
  erzeugen (`generateConvertNEW.php`) – PHP nur zur Build-/Dev-Zeit.
- **Plattformgrenzen:** Handschrift (WinRT) ist Windows-only; Whisper braucht die
  Modell-Datei. Beides bleibt so – aber **ohne Fremdfenster**.

---

## 5. Migration weg von Lua/PowerShell

Sobald eine Funktion nativ vorliegt, entfällt ihr Lua-Plugin und der zugehörige
PowerShell-Teil. `notizregal/app/OpenMoji` (Katalog+PNGs) und das Whisper-Modell
bleiben als **Assets** (jetzt von C++ genutzt). Das Lua-Bridge-Gerüst
(`NotizregalBridge.ps1`, `lua/notizregal.lua`, `plugins/Notizregal*`) wird nach
vollständiger Portierung entfernt. Bis dahin können native und Plugin-Variante
parallel existieren.

---

## 6. Empfohlene Reihenfolge (Meilensteine)

1. **M1 – Fundament + Versionierung + Text** (● + ●): neue Kategorie/Icon-Palette,
   Aktionen, Menü, `NotebookVersioning` (inkl. Auto-Sicherung), `NoteTextExtractor`.
   → Erster CI-Build, an dem sich das Muster real verifizieren lässt.
2. **M2 – Nextcloud** (●●): `NextcloudClient` (libcurl) + Config-Dialog + Settings.
3. **M3 – Audio/Whisper** (●●): whisper.cpp in den Build, `AudioTranscriber`, Dialog.
4. **M4 – Sticker-Panel** (●●●): native Sidebar mit Grid/Suche/Favoriten.
5. **M5 – Regal-Panel** (●●●) + **Handschrift** (●●, Windows-Ink nativ).

Begründung: zuerst kleine, risikoarme, sofort testbare Bausteine (M1) inkl. der
Icon-Palette; die aufwendigen GTK-Flächen (Sticker/Regal) zuletzt.

---

## 7. Offene Entscheidungen für dich

1. **Reihenfolge/Umfang:** M1 zuerst wie vorgeschlagen, oder anders priorisieren?
2. **Regal als Panel vs. Menüfunktion:** Cover-Regal wirklich als In-Editor-Panel
   (aufwendig) – oder reicht dir „Datei/PDF öffnen + Versionsverwaltung“ nativ,
   ohne die Cover-Kacheloberfläche?
3. **Whisper:** in den Build compilieren (schlanker, aber ARM64-Build-Arbeit) –
   oder gebündelte Engine-Datei je Arch beilegen (einfacher, aber Binärdateien)?
4. **Passwort-Ablage Nextcloud:** Windows Credential Manager (empfohlen) ok?

Sag mir die Antworten (oder „M1 starten“), dann setze ich Meilenstein 1 im Code
um und wir lassen den ersten x64/ARM-CI-Build laufen.
