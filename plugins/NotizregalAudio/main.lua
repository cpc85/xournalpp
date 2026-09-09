-- Notizregal-Fork: Audio -> Text (offline)
-- OGG/WAV-Aufnahme auswaehlen, mit dem enthaltenen Whisper-Modell offline
-- transkribieren und den Text einfuegen oder als Datei speichern.
-- Benoetigt die AudioEngine (whisper-cli, Modell) unter notizregal/app/AudioEngine.

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
    app.registerUi({ menu = "Audioaufnahme transkribieren …", callback = "NzAudioPick" })
end

local function ready()
    if not N then
        app.openDialog("Notizregal-Hilfsmodul nicht gefunden (notizregal/lua/notizregal.lua).", { "OK" }, "", true)
        return false
    end
    return N.requireWindows()
end

function NzAudioPick()
    if not ready() then return end
    app.fileDialogOpen("NzAudioTranscribe", { "*.ogg", "*.wav" })
end

function NzAudioTranscribe(path)
    if not path or path == "" then return end
    N.info("Die Aufnahme wird lokal transkribiert. Das kann laenger dauern als die " ..
        "Aufnahme selbst – bitte warten. Xournal++ reagiert waehrenddessen nicht.")
    local res, err = N.bridge("transcribe", { { "audio", path }, { "language", "de" } })
    if not res or not res.ok then
        N.error("Transkription fehlgeschlagen:\n" .. tostring(err))
        return
    end
    pending.text = res.text or ""
    pending.name = res.name or "Audio"
    if pending.text == "" then
        N.info("Es wurde kein Text erkannt.")
        return
    end
    app.openDialog("Transkription fertig (" .. tostring(pending.name) .. "). Was soll geschehen?",
        { "Als Textfeld einfuegen", "Als Markdown speichern", "Schliessen" }, "NzAudioAction", false)
end

function NzAudioAction(button)
    if button == 1 then
        app.addTexts({
            texts = { { text = pending.text, x = 72.0, y = 72.0, wrap = 400.0 } },
            allowUndoRedoAction = "grouped",
        })
        app.refreshPage()
        N.info("Transkript eingefuegt (oben links). Bei Bedarf verschieben.")
    elseif button == 2 then
        app.fileDialogSave("NzAudioSaveTo", (pending.name:gsub("%.%w+$", "")) .. ".md")
    end
end

function NzAudioSaveTo(path)
    if not path or path == "" then return end
    local f, ferr = io.open(path, "wb")
    if not f then N.error("Datei konnte nicht geschrieben werden:\n" .. tostring(ferr)); return end
    f:write("# " .. pending.name .. "\r\n\r\n")
    f:write("Lokal transkribierte Audioaufnahme (Notizregal/Whisper). Bitte auf Fehler pruefen.\r\n\r\n")
    f:write(pending.text .. "\r\n")
    f:close()
    N.info("Transkript gespeichert:\n" .. path)
end
