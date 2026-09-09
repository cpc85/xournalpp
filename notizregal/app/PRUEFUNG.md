# Prüfstand – Notizregal 1.4

Der Benutzer hat Version 1.0.1 auf seinem Surface erfolgreich gestartet.
Version 1.1 erweitert diese Basis. Durchgeführt wurden:

- Syntaxprüfung beider PowerShell-Dateien und des eingebetteten CMD-Startcodes.
- Wohlgeformtheit der drei XAML-Fenster; referenzierte Steuerelemente geprüft.
- Prüfung der neuen Dateistruktur und des ZIP-Archivs.
- Die Erkennung wird erst auf Benutzeraktion in einem separaten Prozess geladen;
  ohne Erkennungskomponenten bleibt das Regal und getippter Textexport nutzbar.
- Quellcodeprüfung der begrenzten XML-Verarbeitung: DTDs und externe XML-Ressourcen
  deaktiviert, maximal 64 MiB XML-Zeichen; keine Netzwerkaufrufe im Programm.

Noch nicht ausgeführt: neue Textfunktionen unter Windows, WinRT-Aufrufe,
Erkennungsqualität und Leistung auf dem Surface SQ1 mit 8 GB RAM.
Die Handschrifterkennung ist deshalb ausdrücklich experimentell.

## Abnahme auf dem Surface

1. Bestehendes Notizregal schließen; neues ZIP entpacken und Start.cmd öffnen.
2. Prüfen, dass bekannte Notizbücher, Kategorien und Favoriten erhalten sind.
3. Testnotiz mit getipptem Text speichern. „Text erkennen / exportieren“ öffnen,
   Handschrift deaktivieren und erfassen. Text auf richtiger Seite kontrollieren.
4. MD und TXT exportieren und in einem Texteditor öffnen.
5. Text korrigieren, speichern, Dialog schließen und im Regal danach suchen.
6. App neu starten: Suchtext und Korrekturen bleiben vorhanden.
7. Kurze handschriftliche Testnotiz erfassen. Bei fehlendem Erkenner die Meldung
   auswerten; deutsches Windows-Handschriftpaket vor Offline-Betrieb installieren.
8. Notiz ändern, im Regal aktualisieren: alter Text muss als veraltet markiert werden.
9. Erkennung abbrechen: alte Texte dürfen nicht ersetzt werden.

Bei Fehlern die genaue Meldung im Textfenster mitteilen. Original-XOPP-Dateien
werden durch die Texterfassung nicht geändert.

## Version 1.2 – Stickerpalette

Alle drei PowerShell-Dateien und beide CMD-Startcodes statisch geprüft.
4.495 PNGs und Katalogreferenzen geprüft, Bildstichprobe visuell kontrolliert.
Die neuen Windows- und Zwischenablagefunktionen sind noch nicht auf dem Surface getestet.
Siehe STICKERPALETTE.md für den ersten praktischen Test.

## Version 1.2.1 – OneDrive

Pauschalen ReparsePoint-Ausschluss durch Prüfung auf Junction/SymbolicLink ersetzt.
PowerShell-Syntax geprüft. PDF-/Word-/Textdateien werden zusätzlich gezählt, um
einen leeren .xopp-Ordner verständlicher anzuzeigen. Ein realer OneDrive-Laufzeittest
steht noch aus. Nach dem Update bestehenden OneDrive-Suchordner aktualisieren und
mit der Liste der .xopp-Dateien im Explorer vergleichen.

## Version 1.3 – Audio → Text

- Vier PowerShell-Dateien mit tree-sitter-powershell auf Syntax geprüft.
- Beide CMD-Startcodes auf Syntax und CMD-Zeilenlänge geprüft.
- XAML-Fenster als XML geprüft; Steuerelementreferenzen abgeglichen.
- whisper.cpp 1.8.5 und eigener OGG/WAV-Decoder für Windows ARM64 gebaut.
  ARMv8-A ohne native Host-CPU-Optimierung, statische Runtime, kein GPU-Backend.
- Beide PE-Dateien melden IMAGE_FILE_MACHINE_ARM64; ausschließlich Windows-System-
  und UCRT-Imports, keine separat mitzuliefernde DLL.
- SHA256 des mitgelieferten mehrsprachigen base-q5_1-Modells gegen den LFS-Hash
  der gepinnten Modellquelle geprüft.
- Derselbe Decoder- und Whisper-Quellcode unter Linux gebaut und ausgeführt:
  JFK-Test-WAV erfolgreich konvertiert und mit gebündeltem Modell transkribiert.
- Zusätzliche Testdatei Ogg Vorbis, Stereo 44,1 kHz, Dateiname mit Leerzeichen und ü:
  konvertiert zu Mono-PCM16/16 kHz; der Erkenner lieferte den erwarteten englischen
  Satz. Eine ungültige OGG-Datei wurde mit Fehlercode abgewiesen.
- Quellcodeprüfung: separate Audioindizes, atomare Speicherung, erneute Erkennung
  erst nach Rückfrage, keine Schreibzugriffe auf Originalaufnahme oder XOPP.

Noch offen: Ausführung der neuen WPF-Oberfläche und ARM64-EXEs auf Windows,
Abbruch des Windows-Prozessbaums, Zwischenablage sowie Geschwindigkeit und deutsche
Erkennungsqualität auf dem SQ1. Linux-Funktionstests ersetzen diesen Gerätetest nicht.

### Kurzer Gerätetest

1. Update starten und Erhalt der vorhandenen Notizbücher und Kategorien prüfen.
2. Kurze deutsche Aufnahme stoppen, beim passenden Buch Audio → Text öffnen.
3. Datei wählen und transkribieren. Text, Zeitmarken und Fehlerprotokoll prüfen.
4. Ein Wort korrigieren, speichern, Fenster schließen und danach im Regal suchen.
5. App neu starten und prüfen, dass Text und Korrektur erhalten sind.
6. MD/TXT exportieren und Text über das Textwerkzeug in Xournal++ einfügen.
7. Eine weitere Erkennung abbrechen und Erhalt des ersten Transkripts prüfen.

## Version 1.4 – Versionierung und PDF-Karten

Tatsächliche Funktionstests mit PowerShell 7.6.6 unter Linux:
- Erstsicherung, neuer Inhalt, keine doppelte Version bei identischen Inhalten.
- Export enthält exakt die alten Bytes und verändert das Original nicht.
- Export über Original oder vorhandene Kopie wird abgewiesen.
- Wiederherstellung liefert den alten Inhalt und behält die exakt ersetzten Bytes.
- Beschädigte Sicherung wird abgewiesen; Original bleibt unverändert.
- Ungültiges XOPP erzeugt keine Version; ungültiger Index wird nicht überschrieben.
- Wiederherstellung bei fehlender Originaldatei auf Funktionsebene geprüft.
- Hintergrundprozess sichert valide Dateien trotz Fehlern anderer Dateien.
- Prozessübergreifende Mutex-Sperre verhindert konkurrierende Sicherungen.
- Tatsächliche Open-Book-Funktion übergibt PDF-Pfad mit Leerzeichen, Umlaut, $ und &
  als genau ein Argument an konfiguriertes Testprogramm.
- Sechs PS1-Dateien mit PowerShell-Parser und tree-sitter geprüft, beide CMD-Zeilen
  auf Syntax/Längenlimit geprüft, sechs XAML-Fenster samt Namensreferenzen geprüft.

Noch ausstehend: WPF-Laufzeit, Windows-Dateisperren/OneDrive-Replace-Verhalten,
Windows PowerShell 5.1 und tatsächlicher PDF-Import durch Xournal++ auf dem Surface.

Geräteabnahme: Start.cmd öffnen, PDFs im bestehenden Ordner aktualisieren und
öffnen. Als XOPP speichern und aktualisieren. Version A manuell sichern, in Xournal++
Version B speichern, mindestens einen automatischen Durchlauf abwarten. Xournal++
schließen, A als Kopie exportieren und wiederherstellen. Prüfen, dass B weiterhin
im Verlauf und als zusätzliche .nrv-Rücksicherung vorhanden ist.
