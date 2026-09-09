-- Notizregal-Fork: Notizbuchregal
-- Oeffnet die visuelle Dokumentverwaltung (Cover, Kategorien, Favoriten, Suche,
-- Versionen, PDF-Karten) als eigenstaendiges Fenster neben Xournal++.
-- Das Regal ist bewusst ein Verwalter *um* den Editor herum; es laeuft daher als
-- WPF-Hilfsfenster (Windows) und nicht im Xournal++-Zeichenbereich.

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

function initUi()
    app.registerUi({ menu = "Notizbuchregal oeffnen", callback = "NzRegalOpen", parentPath = "Notizregal" })
end

function NzRegalOpen()
    if not N then
        app.openDialog("Notizregal-Hilfsmodul nicht gefunden (notizregal/lua/notizregal.lua).", { "OK" }, "", true)
        return
    end
    if not N.requireWindows() then return end
    N.launchApp("Notizregal.ps1")
    N.info("Das Notizbuchregal wird geoeffnet. Beim ersten Start richtet es sich ein " ..
        "(OpenMoji-Bilder und Spracherkennung werden nach %LOCALAPPDATA% kopiert). " ..
        "Ein Coverklick oeffnet das Notizbuch in Xournal++.")
end
