-- Notizregal-Fork: Notizbuchversionen
-- Sichern / Anzeigen / Wiederherstellen / Exportieren des aktuellen Notizbuchs.
-- Bruecke zu notizregal/NotizregalBridge.ps1 (Windows PowerShell).

-- ---- Bootstrap: gemeinsames Modul finden und laden ------------------------
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

-- Zwischenspeicher fuer die dialoggefuehrte Auswahl.
local pending = {}

function initUi()
    app.registerUi({ menu = "Version jetzt sichern", callback = "NzVersionSave", parentPath = "Notizregal" })
    app.registerUi({ menu = "Versionen anzeigen / wiederherstellen …", callback = "NzVersionList", parentPath = "Notizregal" })
end

local function ready()
    if not N then
        app.openDialog("Notizregal-Hilfsmodul nicht gefunden (erwartet in notizregal/lua/notizregal.lua).", { "OK" }, "", true)
        return false
    end
    return N.requireWindows()
end

function NzVersionSave()
    if not ready() then return end
    local book = N.requireBook()
    if not book then return end
    local res, err = N.bridge("save-version", { { "path", book } })
    if res and res.ok then
        N.info("Version gesichert (" .. tostring(res.reason) .. ").")
    else
        N.error("Sicherung fehlgeschlagen:\n" .. tostring(err))
    end
end

function NzVersionList()
    if not ready() then return end
    local book = N.requireBook()
    if not book then return end
    local res, err = N.bridge("list-versions", { { "path", book } })
    if not res or not res.ok then
        N.error("Versionen konnten nicht gelesen werden:\n" .. tostring(err))
        return
    end
    local versions = res.versions or {}
    if #versions == 0 then
        N.info("Fuer dieses Notizbuch gibt es noch keine gesicherten Versionen. " ..
            "Mit „Version jetzt sichern“ einen Stand anlegen.")
        return
    end
    pending.book = book
    pending.versions = versions
    local options = {}
    local shown = math.min(#versions, 8)
    for i = 1, shown do
        local v = versions[i]
        local when = tostring(v.created):gsub("T", " "):sub(1, 16)
        options[i] = when .. "  (" .. tostring(v.reason) .. ")"
    end
    options[shown + 1] = "Abbrechen"
    pending.cancel = shown + 1
    app.openDialog("Version auswaehlen (neueste zuerst):", options, "NzVersionPick", false)
end

function NzVersionPick(button)
    if not button or button == pending.cancel then return end
    local v = pending.versions[button]
    if not v then return end
    pending.selected = v
    app.openDialog(
        "Version vom " .. tostring(v.created):gsub("T", " "):sub(1, 16) .. ":",
        { "Als Kopie exportieren", "Diese Version wiederherstellen", "Abbrechen" },
        "NzVersionAction", false)
end

function NzVersionAction(button)
    local v = pending.selected
    if not v then return end
    if button == 1 then
        -- Export: Zieldateiname erfragen, dann kopieren.
        app.fileDialogSave("NzVersionExportTo", "Notizbuch-Version.xopp")
    elseif button == 2 then
        local res, err = N.bridge("restore-version", { { "path", pending.book }, { "id", v.id } })
        if res and res.ok then
            local msg = "Version wiederhergestellt. Die vorherige Fassung wurde als " ..
                "Sicherung abgelegt:\n" .. tostring(res.safety) ..
                "\n\nBitte das Notizbuch in Xournal++ neu oeffnen, um den Stand zu sehen."
            if res.warning and res.warning ~= "" then msg = msg .. "\n\nHinweis: " .. tostring(res.warning) end
            N.info(msg)
        else
            N.error("Wiederherstellung fehlgeschlagen:\n" .. tostring(err))
        end
    end
end

function NzVersionExportTo(path)
    if not path or path == "" then return end
    local v = pending.selected
    if not v then return end
    local res, err = N.bridge("export-version",
        { { "path", pending.book }, { "id", v.id }, { "dest", path } })
    if res and res.ok then
        N.info("Version als Kopie gespeichert:\n" .. path)
    else
        N.error("Export fehlgeschlagen:\n" .. tostring(err))
    end
end
