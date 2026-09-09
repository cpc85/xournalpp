-- Notizregal-Fork: Text erkennen & exportieren
-- Getippten Notiztext (und experimentell Handschrift via Windows Ink) aus dem
-- gespeicherten .xopp lesen, einfuegen oder als Markdown/TXT exportieren.

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
    app.registerUi({ menu = "Notiztext als Markdown exportieren", callback = "NzTextExportMd" })
    app.registerUi({ menu = "Notiztext als TXT exportieren", callback = "NzTextExportTxt" })
    app.registerUi({ menu = "Text + Handschrift exportieren (experimentell)", callback = "NzTextExportInk" })
    app.registerUi({ menu = "Erkannten Text als Textfeld einfuegen", callback = "NzTextInsert" })
end

local function ready()
    if not N then
        app.openDialog("Notizregal-Hilfsmodul nicht gefunden (notizregal/lua/notizregal.lua).", { "OK" }, "", true)
        return false
    end
    return N.requireWindows()
end

-- Erkennt den Text des aktuellen Notizbuchs. handwriting = true nutzt Windows Ink.
local function extract(handwriting)
    local book = N.requireBook()
    if not book then return nil end
    local res, err = N.bridge("extract-text",
        { { "path", book }, { "handwriting", handwriting and "true" or "false" } })
    if not res or not res.ok then
        N.error("Texterkennung fehlgeschlagen:\n" .. tostring(err))
        return nil
    end
    if res.warnings and #res.warnings > 0 then
        pending.warnings = table.concat(res.warnings, "\n")
    else
        pending.warnings = nil
    end
    return res, book
end

local function titleFromPath(book)
    local name = book:match("([^/\\]+)$") or book
    return (name:gsub("%.[xX][oO][pP][pP]$", ""))
end

local function saveTextFile(path, content)
    local f, ferr = io.open(path, "wb")
    if not f then
        N.error("Datei konnte nicht geschrieben werden:\n" .. tostring(ferr))
        return
    end
    f:write(content)
    f:close()
    local extra = ""
    if pending.warnings then extra = "\n\nHinweise der Erkennung:\n" .. pending.warnings end
    N.info("Text gespeichert:\n" .. path .. extra)
end

local function runExport(handwriting, markdown, suggestExt)
    if not ready() then return end
    local res, book = extract(handwriting)
    if not res then return end
    pending.text = res.text or ""
    pending.markdown = markdown
    pending.title = titleFromPath(book)
    if pending.text == "" then
        N.info("Es wurde kein Text gefunden." .. (pending.warnings and ("\n\n" .. pending.warnings) or ""))
        return
    end
    app.fileDialogSave("NzTextSaveTo", pending.title .. suggestExt)
end

function NzTextExportMd()  runExport(false, true,  ".md")  end
function NzTextExportTxt() runExport(false, false, ".txt") end
function NzTextExportInk() runExport(true,  true,  ".md")  end

function NzTextSaveTo(path)
    if not path or path == "" then return end
    local content
    if pending.markdown then
        content = "# " .. pending.title .. "\r\n\r\n" ..
            "Textexport aus Xournal++ (Notizregal). Handschrift maschinell erkannt; bitte pruefen.\r\n\r\n" ..
            pending.text .. "\r\n"
    else
        content = pending.title .. "\r\n\r\n" .. pending.text .. "\r\n"
    end
    saveTextFile(path, content)
end

function NzTextInsert()
    if not ready() then return end
    local res = extract(false)
    if not res then return end
    local text = res.text or ""
    if text == "" then
        N.info("Es wurde kein getippter Text gefunden.")
        return
    end
    -- In sichtbarer Naehe auf der aktuellen Seite platzieren.
    app.addTexts({
        texts = { { text = text, x = 72.0, y = 72.0, wrap = 400.0 } },
        allowUndoRedoAction = "grouped",
    })
    app.refreshPage()
    N.info("Erkannter Text wurde als Textfeld eingefuegt (oben links). Bei Bedarf verschieben.")
end
