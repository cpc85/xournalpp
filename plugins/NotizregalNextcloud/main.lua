-- Notizregal-Fork: Nextcloud-WebDAV-Sync
-- Aktuelles .xopp in eine Nextcloud hochladen und Dateien zurueckholen.
-- Zugang wird ueber ein WPF-Fenster eingerichtet; das App-Passwort liegt lokal
-- per Windows-DPAPI verschluesselt in %LOCALAPPDATA%\Notizregal\nextcloud.json.

-- ---- Bootstrap ------------------------------------------------------------
local function loadNotizregal()
    local src = debug.getinfo(1, "S").source:sub(2)
    local sep = package.config:sub(1, 1)
    local dir = src:match("^(.*[/\\])") or ("." .. sep)
    local candidates = {}
    local env = os.getenv("NOTIZREGAL_HOME")
    if env and env ~= "" then candidates[#candidates + 1] = env end
    candidates[#candidates + 1] = dir .. ".." .. sep .. ".." .. sep .. "notizregal"
    candidates[#candidates + 1] = dir .. "notizregal"
    for _, home in ipairs(candidates) do
        local f = io.open(home .. sep .. "lua" .. sep .. "notizregal.lua", "r")
        if f then
            f:close()
            package.path = home .. sep .. "lua" .. sep .. "?.lua;" .. package.path
            local ok, mod = pcall(require, "notizregal")
            if ok and mod then mod.home = home; return mod end
        end
    end
    return nil
end
local N = loadNotizregal()

local pending = {}

function initUi()
    app.registerUi({ menu = "Nextcloud einrichten …", callback = "NzNcConfig" })
    app.registerUi({ menu = "Verbindung testen", callback = "NzNcTest" })
    app.registerUi({ menu = "Aktuelles Notizbuch hochladen", callback = "NzNcUpload" })
    app.registerUi({ menu = "Aus Nextcloud herunterladen …", callback = "NzNcDownloadList" })
end

local function ready()
    if not N then
        app.openDialog("Notizregal-Hilfsmodul nicht gefunden (notizregal/lua/notizregal.lua).", { "OK" }, "", true)
        return false
    end
    return N.requireWindows()
end

function NzNcConfig()
    if not ready() then return end
    N.launchApp("NextcloudConfig.ps1")
    N.info("Das Nextcloud-Einrichtungsfenster wird geoeffnet. Dort Server, Benutzer, " ..
        "App-Passwort und Zielordner eintragen, „Verbindung testen“ und speichern.")
end

function NzNcTest()
    if not ready() then return end
    local res, err = N.bridge("nextcloud-test", {})
    if res and res.ok then
        N.info("Verbindung erfolgreich. Der Zielordner ist erreichbar.")
    else
        N.error("Verbindung fehlgeschlagen:\n" .. tostring(err))
    end
end

function NzNcUpload()
    if not ready() then return end
    local book = N.requireBook()
    if not book then return end
    -- Es wird die zuletzt gespeicherte Fassung hochgeladen.
    local res, err = N.bridge("nextcloud-upload", { { "path", book } })
    if res and res.ok then
        N.info("Hochgeladen nach Nextcloud:\n" .. tostring(res.remote) ..
            "  (" .. tostring(res.bytes) .. " Bytes)\n\nHinweis: Es wird der zuletzt " ..
            "gespeicherte Stand uebertragen – vorher speichern.")
    else
        N.error("Upload fehlgeschlagen:\n" .. tostring(err))
    end
end

function NzNcDownloadList()
    if not ready() then return end
    local res, err = N.bridge("nextcloud-list", {})
    if not res or not res.ok then
        N.error("Dateien konnten nicht aufgelistet werden:\n" .. tostring(err))
        return
    end
    local items = res.items or {}
    if #items == 0 then
        N.info("Im konfigurierten Nextcloud-Ordner wurden keine Dateien gefunden.")
        return
    end
    pending.items = items
    local options = {}
    local shown = math.min(#items, 8)
    for i = 1, shown do
        local it = items[i]
        local kb = math.floor((tonumber(it.size) or 0) / 1024)
        options[i] = it.name .. "  (" .. kb .. " KB)"
    end
    options[shown + 1] = "Abbrechen"
    pending.cancel = shown + 1
    app.openDialog("Datei aus Nextcloud herunterladen:", options, "NzNcDownloadPick", false)
end

function NzNcDownloadPick(button)
    if not button or button == pending.cancel then return end
    local it = pending.items[button]
    if not it then return end
    pending.selected = it
    app.fileDialogSave("NzNcDownloadTo", it.name)
end

function NzNcDownloadTo(path)
    if not path or path == "" then return end
    local it = pending.selected
    if not it then return end
    local res, err = N.bridge("nextcloud-download", { { "remote", it.name }, { "dest", path } })
    if not res or not res.ok then
        N.error("Download fehlgeschlagen:\n" .. tostring(err))
        return
    end
    pending.downloaded = path
    if path:lower():match("%.xopp$") then
        app.openDialog("Heruntergeladen:\n" .. path .. "\n\nJetzt in Xournal++ oeffnen?",
            { "Oeffnen", "Schliessen" }, "NzNcAfterDownload", false)
    else
        N.info("Heruntergeladen:\n" .. path)
    end
end

function NzNcAfterDownload(button)
    if button == 1 and pending.downloaded then
        app.openFile(pending.downloaded, 1, false)
    end
end
