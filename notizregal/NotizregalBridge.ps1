# NotizregalBridge.ps1
# ----------------------------------------------------------------------------
# Headless-Vermittler zwischen den Xournal++-Lua-Plugins und den bewaehrten
# Notizregal-Werkzeugen (Versionierung, Sticker-Suche). Er wird von den Plugins
# ueber powershell.exe aufgerufen und tauscht Daten ueber Dateien aus:
#
#   -Command      auszufuehrender Befehl (siehe unten)
#   -RequestPath  Pfad einer Anfrage-Datei (Name/Wert-Zeilenpaare, UTF-8)
#
# Das Ergebnis wird als *Lua-Tabellen-Literal* nach "<RequestPath>.result"
# geschrieben (das Plugin laedt es per loadfile). Fehler landen als Text in
# "<RequestPath>.error"; der Prozess endet dann mit Code 1.
#
# Befehle:
#   save-version     req: path            -> { ok, id, reason }
#   list-versions    req: path            -> { ok, versions = { {id,created,reason,length}, ... } }
#   restore-version  req: path, id        -> { ok, safety, warning }
#   export-version   req: path, id, dest  -> { ok }
#   find-stickers    req: query [,limit]  -> { ok, items = { {name,category,path}, ... } }
#
# Benoetigt Windows PowerShell 5.1 (wie das uebrige Notizregal). Die
# Versionslogik selbst ist plattformneutrales .NET; Windows-spezifisch sind
# nur die aufrufenden Plugins.
# ----------------------------------------------------------------------------
param(
    [Parameter(Mandatory = $true)][string]$Command,
    [Parameter(Mandatory = $true)][string]$RequestPath
)
$ErrorActionPreference = 'Stop'

# Ausgabepfad sichern: TextTools.ps1 (via VersionTools dot-gesourct) hat selbst
# einen Parameter namens $RequestPath und wuerde die hiesige Variable auf ''
# zuruecksetzen. Deshalb den Basispfad separat festhalten.
$OutBase = $RequestPath

# --- Anfrage lesen (abwechselnd Name-/Wertzeilen, UTF-8 ohne Interpretation) ---
function Read-Request([string]$Path) {
    $req = @{}
    if ([IO.File]::Exists($Path)) {
        $lines = [IO.File]::ReadAllLines($Path, [Text.UTF8Encoding]::new($false))
        for ($i = 0; $i + 1 -lt $lines.Count; $i += 2) { $req[$lines[$i]] = $lines[$i + 1] }
    }
    return $req
}

# --- Beliebigen Wert als Lua-Literal serialisieren -------------------------
function ConvertTo-LuaLiteral($Value) {
    if ($null -eq $Value) { return 'nil' }
    if ($Value -is [bool]) { if ($Value) { return 'true' } else { return 'false' } }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal]) {
        return ([string]$Value)
    }
    if ($Value -is [System.Collections.IDictionary]) {
        $parts = foreach ($key in $Value.Keys) {
            '[' + (ConvertTo-LuaLiteral ([string]$key)) + ']=' + (ConvertTo-LuaLiteral $Value[$key])
        }
        return '{' + ($parts -join ',') + '}'
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        $parts = foreach ($item in $Value) { ConvertTo-LuaLiteral $item }
        return '{' + ($parts -join ',') + '}'
    }
    # Alles Uebrige als String escapen.
    $s = [string]$Value
    $sb = [Text.StringBuilder]::new()
    [void]$sb.Append('"')
    foreach ($ch in $s.ToCharArray()) {
        switch ($ch) {
            '"'  { [void]$sb.Append('\"') }
            '\'  { [void]$sb.Append('\\') }
            "`n" { [void]$sb.Append('\n') }
            "`r" { [void]$sb.Append('\r') }
            "`t" { [void]$sb.Append('\t') }
            default {
                $code = [int][char]$ch
                if ($code -lt 32) { [void]$sb.Append('\' + ('{0:000}' -f $code)) } else { [void]$sb.Append($ch) }
            }
        }
    }
    [void]$sb.Append('"')
    return $sb.ToString()
}

function Write-Result($Value) {
    $lua = 'return ' + (ConvertTo-LuaLiteral $Value)
    [IO.File]::WriteAllText($OutBase + '.result', $lua, [Text.UTF8Encoding]::new($false))
}

# --- Sticker-Suche im OpenMoji-Katalog -------------------------------------
function Invoke-FindStickers($req) {
    $assets = Join-Path $PSScriptRoot 'app\OpenMoji'
    $catalogPath = Join-Path $assets 'katalog.json'
    if (-not [IO.File]::Exists($catalogPath)) {
        throw 'OpenMoji-Bildpaket fehlt. Bitte das gesamte Paket in den Fork uebernehmen (notizregal\app\OpenMoji).'
    }
    # In Windows PowerShell 5.1 enumeriert die Pipeline ein Top-Level-JSON-Array
    # NICHT; @(... | ConvertFrom-Json) ergaebe ein 1-Element-Array. Daher erst
    # zuweisen, dann in ein Array zwingen.
    $catalog = [IO.File]::ReadAllText($catalogPath) | ConvertFrom-Json
    $catalog = @($catalog)
    $query = ([string]$req['query']).Trim().ToLowerInvariant()
    $limit = 24
    if ($req.ContainsKey('limit')) { [int]::TryParse([string]$req['limit'], [ref]$limit) | Out-Null }
    if ($limit -lt 1) { $limit = 1 }
    if ($limit -gt 200) { $limit = 200 }

    if ($query) {
        $terms = @($query -split '\s+' | Where-Object { $_ })
        $matches = foreach ($item in $catalog) {
            $hay = (([string]$item.name) + ' ' + ([string]$item.tags) + ' ' + ([string]$item.category)).ToLowerInvariant()
            $ok = $true
            foreach ($t in $terms) { if ($hay.IndexOf($t) -lt 0) { $ok = $false; break } }
            if ($ok) { $item }
        }
        $matches = @($matches)
    } else {
        $matches = @($catalog)
    }

    $items = @()
    foreach ($item in ($matches | Select-Object -First $limit)) {
        $items += [ordered]@{
            name     = [string]$item.name
            category = [string]$item.category
            path     = [IO.Path]::GetFullPath((Join-Path $assets ([string]$item.file)))
        }
    }
    Write-Result ([ordered]@{ ok = $true; count = $matches.Count; items = $items })
}

# --- Versionsbefehle (nutzen die bewaehrten VersionTools-Funktionen) -------
# VersionTools.ps1 (das seinerseits TextTools.ps1 einbindet) wird weiter unten
# auf Skriptebene dot-gesourct, damit die Funktionen global verfuegbar sind.
function Invoke-SaveVersion($req) {
    $entry = Save-NotebookVersion ([string]$req['path']) 'Manuell'
    Write-Result ([ordered]@{ ok = $true; id = [string]$entry.id; reason = [string]$entry.reason; created = [string]$entry.created })
}

function Invoke-ListVersions($req) {
    $index = Read-VersionIndex ([string]$req['path'])
    $versions = @()
    foreach ($e in @($index.entries)) {
        $versions += [ordered]@{
            id      = [string]$e.id
            created = [string]$e.created
            reason  = [string]$e.reason
            length  = [long]$e.length
        }
    }
    # Neueste zuerst.
    [array]::Reverse($versions)
    Write-Result ([ordered]@{ ok = $true; versions = $versions })
}

function Invoke-RestoreVersion($req) {
    $res = Restore-NotebookVersion ([string]$req['path']) ([string]$req['id'])
    Write-Result ([ordered]@{ ok = $true; safety = [string]$res.safety; warning = [string]$res.warning })
}

function Invoke-ExportVersion($req) {
    Export-NotebookVersion ([string]$req['path']) ([string]$req['id']) ([string]$req['dest'])
    Write-Result ([ordered]@{ ok = $true })
}

# --- Textextraktion (getippter Text + optional Windows-Ink-Handschrift) -----
function Invoke-ExtractText($req) {
    $handwriting = ([string]$req['handwriting']) -eq 'true'
    $index = Convert-XoppToIndex ([string]$req['path']) $handwriting
    Write-Result ([ordered]@{
        ok        = $true
        text      = [string](Get-IndexText $index)
        complete  = [bool]$index.complete
        engine    = [string]$index.engine
        pageCount = @($index.pages).Count
        warnings  = @(@($index.warnings) | ForEach-Object { [string]$_ })
    })
}

# --- Audiotranskription (ruft die bewaehrte AudioTools-Pipeline als Kind) ----
function Invoke-Transcribe($req) {
    $jobDir = Join-Path ([IO.Path]::GetTempPath()) ('nz-audio-' + [Guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($jobDir)
    try {
        $childReq = Join-Path $jobDir 'anfrage.json'
        $lang = [string]$req['language']; if (-not $lang) { $lang = 'de' }
        $payload = [ordered]@{ audio = [string]$req['audio']; language = $lang }
        [IO.File]::WriteAllText($childReq, (ConvertTo-Json -InputObject $payload -Depth 4), [Text.UTF8Encoding]::new($true))
        $audioTools = Join-Path $PSScriptRoot 'app\AudioTools.ps1'
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $audioTools -AudioRequestPath $childReq | Out-Null
        if ([IO.File]::Exists($childReq + '.result')) {
            $r = [IO.File]::ReadAllText($childReq + '.result') | ConvertFrom-Json
            Write-Result ([ordered]@{ ok = $true; text = [string]$r.text; name = [string]$r.name; language = [string]$r.language })
        } elseif ([IO.File]::Exists($childReq + '.error')) {
            throw ([IO.File]::ReadAllText($childReq + '.error'))
        } else {
            throw 'Die Audioverarbeitung hat kein Ergebnis erzeugt.'
        }
    } finally {
        try { [IO.Directory]::Delete($jobDir, $true) } catch { }
    }
}

# --- Nextcloud-WebDAV-Befehle ----------------------------------------------
function Invoke-NextcloudUploadCmd($req) {
    $r = Invoke-NextcloudUpload ([string]$req['path']) ([string]$req['remote'])
    Write-Result ([ordered]@{ ok = $true; remote = [string]$r.remote; bytes = [long]$r.bytes })
}
function Invoke-NextcloudDownloadCmd($req) {
    $r = Invoke-NextcloudDownload ([string]$req['remote']) ([string]$req['dest'])
    Write-Result ([ordered]@{ ok = $true; dest = [string]$r.dest; bytes = [long]$r.bytes })
}
function Invoke-NextcloudListCmd($req) {
    $items = @(Invoke-NextcloudList)
    $out = @()
    foreach ($it in $items) {
        $out += [ordered]@{ name = [string]$it.name; size = [long]$it.size; modified = [string]$it.modified }
    }
    Write-Result ([ordered]@{ ok = $true; items = $out })
}
function Invoke-NextcloudTestCmd($req) {
    $null = Test-Nextcloud
    Write-Result ([ordered]@{ ok = $true })
}

try {
    $req = Read-Request $OutBase
    # Benoetigte Werkzeug-Bibliotheken auf Skriptebene dot-sourcen (damit ihre
    # Funktionen global verfuegbar sind). VersionTools zieht TextTools mit.
    switch -Regex ($Command) {
        '-version$|^list-versions$' { . (Join-Path $PSScriptRoot 'app\VersionTools.ps1') }
        '^extract-text$'            { . (Join-Path $PSScriptRoot 'app\TextTools.ps1') }
        '^nextcloud-'               { . (Join-Path $PSScriptRoot 'app\NextcloudTools.ps1') }
    }
    switch ($Command) {
        'find-stickers'      { Invoke-FindStickers   $req }
        'save-version'       { Invoke-SaveVersion     $req }
        'list-versions'      { Invoke-ListVersions    $req }
        'restore-version'    { Invoke-RestoreVersion  $req }
        'export-version'     { Invoke-ExportVersion   $req }
        'extract-text'       { Invoke-ExtractText     $req }
        'transcribe'         { Invoke-Transcribe      $req }
        'nextcloud-upload'   { Invoke-NextcloudUploadCmd   $req }
        'nextcloud-download' { Invoke-NextcloudDownloadCmd $req }
        'nextcloud-list'     { Invoke-NextcloudListCmd     $req }
        'nextcloud-test'     { Invoke-NextcloudTestCmd     $req }
        default { throw ('Unbekannter Befehl: ' + $Command) }
    }
    exit 0
} catch {
    [IO.File]::WriteAllText($OutBase + '.error', ($_ | Out-String), [Text.UTF8Encoding]::new($false))
    exit 1
}
