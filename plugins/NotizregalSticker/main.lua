-- Notizregal-Fork: Stickerpalette (OpenMoji)
-- Zwei Wege, da die Lua-API kein Freitext-Eingabefeld bietet:
--  1) "Sticker zum markierten Wort": markierten Text als Suchbegriff nutzen,
--     Treffer als Buttons zeigen und das gewaehlte Bild in die Notiz einfuegen.
--  2) "Stickerpalette oeffnen": das vollstaendige WPF-Fenster (Suche/Favoriten,
--     Bild kopieren -> in Xournal++ mit Strg+V einfuegen).

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
    app.registerUi({ menu = "Sticker zum markierten Wort einfuegen", callback = "NzStickerForSelection" })
    app.registerUi({ menu = "Stickerpalette oeffnen (Suche, Favoriten)", callback = "NzStickerPalette" })
end

local function ready()
    if not N then
        app.openDialog("Notizregal-Hilfsmodul nicht gefunden (notizregal/lua/notizregal.lua).", { "OK" }, "", true)
        return false
    end
    return N.requireWindows()
end

function NzStickerPalette()
    if not ready() then return end
    N.launchApp("Stickerpalette.ps1")
    N.info("Die Stickerpalette wird geoeffnet. Dort ein Bild auswaehlen, „Bild kopieren“ " ..
        "und in Xournal++ mit Strg+V einfuegen.")
end

function NzStickerForSelection()
    if not ready() then return end
    local ok, selection = pcall(function() return app.getTexts("selection") end)
    local query, x, y
    if ok and selection and selection[1] and selection[1].text and selection[1].text ~= "" then
        query = selection[1].text
        x = selection[1].x
        y = selection[1].y
    end
    if not query then
        N.info("Bitte zuerst ein Wort als Text markieren (Auswahlwerkzeug). Es dient als " ..
            "Suchbegriff. Fuer freie Suche „Stickerpalette oeffnen“ verwenden.")
        return
    end
    -- Nur das erste Wort als Suchbegriff, Zeilenumbrueche entfernen.
    query = query:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s.*$", "")
    local res, err = N.bridge("find-stickers", { { "query", query }, { "limit", "6" } })
    if not res or not res.ok then
        N.error("Sticker-Suche fehlgeschlagen:\n" .. tostring(err))
        return
    end
    local items = res.items or {}
    if #items == 0 then
        N.info("Keine passenden Sticker zu „" .. query .. "“ gefunden. " ..
            "Fuer eine breitere Suche „Stickerpalette oeffnen“ verwenden.")
        return
    end
    pending.items = items
    pending.x = x or 72.0
    pending.y = y or 72.0
    local options = {}
    for i, it in ipairs(items) do options[i] = it.name .. "  (" .. it.category .. ")" end
    options[#items + 1] = "Abbrechen"
    pending.cancel = #items + 1
    app.openDialog("Sticker zu „" .. query .. "“ auswaehlen:", options, "NzStickerPick", false)
end

function NzStickerPick(button)
    if not button or button == pending.cancel then return end
    local it = pending.items[button]
    if not it then return end
    local ok, refs = pcall(function()
        return app.addImages({
            images = { { path = it.path, x = pending.x, y = pending.y, maxWidth = 96 } },
            allowUndoRedoAction = "grouped",
        })
    end)
    if not ok then
        N.error("Sticker konnte nicht eingefuegt werden:\n" .. tostring(refs))
        return
    end
    -- addImages liefert bei Fehlern einen String statt einer Referenz.
    if type(refs) == "table" and type(refs[1]) == "string" then
        N.error("Sticker konnte nicht eingefuegt werden:\n" .. refs[1])
        return
    end
    app.refreshPage()
end
