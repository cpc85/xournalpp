-- notizregal.lua
-- ---------------------------------------------------------------------------
-- Gemeinsames Hilfsmodul fuer die Notizregal-Plugins in diesem Xournal++-Fork.
-- Es kapselt den Aufruf der PowerShell-Werkzeuge (NotizregalBridge.ps1 und die
-- App-Skripte unter notizregal/app) und den Datenaustausch ueber Dateien.
--
-- Austauschformat:
--   * Anfrage  (Lua -> PS): Textdatei mit abwechselnden Name-/Wertzeilen (UTF-8).
--   * Ergebnis (PS -> Lua): eine Datei "<anfrage>.result", die ein Lua-Literal
--                           der Form  return { ... }  enthaelt und hier per
--                           load() eingelesen wird. Fehler stehen in ".error".
--
-- Das Modul wird von jedem Plugin ueber den kleinen Bootstrap in dessen
-- main.lua geladen; `N.home` (Pfad des Ordners notizregal/) wird dabei gesetzt.
-- ---------------------------------------------------------------------------
local N = {}

N.sep = package.config:sub(1, 1)
N.isWindows = (N.sep == "\\")
N.home = nil  -- vom Bootstrap gesetzt

math.randomseed(os.time())

local function quote(s) return '"' .. tostring(s) .. '"' end

-- Schreibt eine Anfragedatei aus einer geordneten Liste von {name, wert}-Paaren.
function N.writeRequest(path, fields)
    local f = assert(io.open(path, "wb"))
    for _, kv in ipairs(fields) do
        f:write(tostring(kv[1])); f:write("\n")
        f:write(tostring(kv[2] ~= nil and kv[2] or "")); f:write("\n")
    end
    f:close()
end

function N.readAll(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

-- Laedt ein als Lua-Literal geschriebenes Ergebnis (return { ... }).
function N.loadResult(path)
    local data = N.readAll(path)
    if not data or data == "" then return nil end
    local chunk = load(data, "@notizregal-result", "t")
    if not chunk then return nil end
    local ok, value = pcall(chunk)
    if ok then return value end
    return nil
end

-- Verzeichnis fuer temporaere Anfragedateien.
function N.stateDir()
    local ok, dir = pcall(function() return app.getFolder("state") end)
    if ok and dir and dir ~= "" then return dir end
    return N.home or "."
end

-- Ruft ein PowerShell-Werkzeug auf und liefert die Ergebnistabelle zurueck.
--   command : Bridge-Befehl (z. B. "list-versions") oder nil bei App-Skripten
--   fields  : Liste von {name, wert}-Paaren fuer die Anfrage
--   opts    : { script = <rel. Pfad ab notizregal/>, param = <Parametername> }
-- Rueckgabe: (tabelle) bei Erfolg, (nil, fehlertext) bei Fehler.
function N.invoke(command, fields, opts)
    opts = opts or {}
    if not N.isWindows then
        return nil, "Diese Funktion benoetigt Windows PowerShell."
    end
    local script = N.home .. N.sep .. (opts.script or "NotizregalBridge.ps1")
    local param = opts.param or "-RequestPath"
    local req = N.stateDir() .. N.sep ..
        string.format("nzreq_%d_%d.txt", os.time(), math.random(100000, 999999))
    N.writeRequest(req, fields)

    local args = ""
    if command then args = "-Command " .. command .. " " end
    args = args .. param .. " " .. quote(req)
    local cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File " ..
        quote(script) .. " " .. args
    os.execute(cmd)

    local result = N.loadResult(req .. ".result")
    local err = N.readAll(req .. ".error")
    os.remove(req)
    os.remove(req .. ".result")
    os.remove(req .. ".error")
    if result then return result end
    if err and err ~= "" then return nil, err end
    return nil, "Keine Antwort vom Notizregal-Dienst."
end

-- Kurzform fuer Bridge-Befehle.
function N.bridge(command, fields)
    return N.invoke(command, fields, nil)
end

-- Startet ein WPF-Hilfsfenster (Regal, volle Stickerpalette) losgeloest, damit
-- Xournal++ bedienbar bleibt.
function N.launchApp(scriptName)
    if not N.isWindows then
        N.error("Dieses Fenster ist nur unter Windows verfuegbar.")
        return
    end
    local script = N.home .. N.sep .. "app" .. N.sep .. scriptName
    -- 'start' loest den Prozess vom Xournal++-Fenster; Titel als erstes Argument.
    os.execute('start "Notizregal" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ' .. quote(script))
end

-- ---- Bequeme Dialog- und Kontext-Helfer -----------------------------------

function N.info(message)  app.openDialog(message, { "OK" }, "", false) end
function N.error(message) app.openDialog(message, { "OK" }, "", true) end

function N.docPath()
    local ok, structure = pcall(function() return app.getDocumentStructure() end)
    if not ok or not structure then return nil end
    local p = structure.xoppFilename
    if p and p ~= "" then return p end
    return nil
end

function N.requireWindows()
    if not N.isWindows then
        N.error("Diese Notizregal-Funktion ist nur unter Windows verfuegbar; " ..
            "sie nutzt Windows PowerShell und Windows-spezifische Dienste.")
        return false
    end
    return true
end

-- Liefert den Pfad der aktuell geoeffneten .xopp-Datei oder nil (mit Hinweis).
function N.requireBook()
    local p = N.docPath()
    if not p then
        N.error("Bitte das Notizbuch zuerst speichern. Diese Funktion arbeitet " ..
            "auf der gespeicherten .xopp-Datei.")
        return nil
    end
    if not p:lower():match("%.xopp$") then
        N.error("Diese Funktion ist fuer gespeicherte .xopp-Notizbuecher gedacht.")
        return nil
    end
    return p
end

return N
