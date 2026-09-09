param([string]$NextcloudRequestPath = '')
# ----------------------------------------------------------------------------
# Offline-Werkzeug fuer Nextcloud-WebDAV-Sync des Notizregal-Forks.
# Keine externen Bibliotheken; nutzt System.Net.Http. Zugangsdaten liegen in
# %LOCALAPPDATA%\Notizregal\nextcloud.json; das App-Passwort ist per Windows-
# DPAPI (nur aktueller Benutzer) verschluesselt. Benoetigt Windows PowerShell 5.1.
#
# WebDAV-Basis:  <server>/remote.php/dav/files/<benutzer>/<ordner>/<datei>
# ----------------------------------------------------------------------------
Add-Type -AssemblyName System.Net.Http

function Get-NextcloudConfigPath {
    $dir = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Notizregal'
    [void][IO.Directory]::CreateDirectory($dir)
    return Join-Path $dir 'nextcloud.json'
}

# --- DPAPI-Verschluesselung (an den Windows-Benutzer gebunden) --------------
function Protect-NcSecret([string]$Plain) {
    if ([string]::IsNullOrEmpty($Plain)) { return '' }
    $secure = ConvertTo-SecureString $Plain -AsPlainText -Force
    return ConvertFrom-SecureString $secure   # DPAPI, CurrentUser
}
function Unprotect-NcSecret([string]$Enc) {
    if ([string]::IsNullOrEmpty($Enc)) { return '' }
    $secure = ConvertTo-SecureString $Enc
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($secure)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringUni($ptr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeGlobalAllocUnicode($ptr) }
}

function Read-NextcloudConfig {
    $path = Get-NextcloudConfigPath
    if (-not [IO.File]::Exists($path)) {
        throw 'Nextcloud ist noch nicht eingerichtet. Bitte zuerst „Nextcloud einrichten …“ ausfuehren.'
    }
    $cfg = [IO.File]::ReadAllText($path) | ConvertFrom-Json
    if (-not $cfg.baseUrl -or -not $cfg.user) {
        throw 'Nextcloud-Konfiguration unvollstaendig. Bitte „Nextcloud einrichten …“ erneut ausfuehren.'
    }
    return $cfg
}

# --- HttpClient mit Basic-Auth aufbauen ------------------------------------
function New-NextcloudClient($cfg) {
    $handler = [System.Net.Http.HttpClientHandler]::new()
    if ($cfg.PSObject.Properties['verifyTls'] -and -not $cfg.verifyTls) {
        $handler.ServerCertificateCustomValidationCallback = { param($m, $c, $ch, $e) $true }
    }
    $client = [System.Net.Http.HttpClient]::new($handler)
    $client.Timeout = [TimeSpan]::FromSeconds(120)
    $pass = Unprotect-NcSecret ([string]$cfg.passwordEnc)
    $raw = [Text.Encoding]::UTF8.GetBytes(([string]$cfg.user) + ':' + $pass)
    $client.DefaultRequestHeaders.Authorization =
        [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Basic', [Convert]::ToBase64String($raw))
    return $client
}

function Get-NextcloudRoot($cfg) {
    $server = ([string]$cfg.baseUrl).TrimEnd('/')
    return $server + '/remote.php/dav/files/' + [Uri]::EscapeDataString([string]$cfg.user)
}

# Baut die vollstaendige WebDAV-URL aus konfiguriertem Ordner + relativem Pfad.
function Get-NextcloudUrl($cfg, [string]$RelPath) {
    $url = Get-NextcloudRoot $cfg
    $folder = ([string]$cfg.remoteDir).Trim('/')
    $segments = @()
    if ($folder) { $segments += ($folder -split '/') }
    if ($RelPath) { $segments += (($RelPath -replace '\\', '/') -split '/') }
    foreach ($s in $segments) { if ($s) { $url += '/' + [Uri]::EscapeDataString($s) } }
    return $url
}

function Invoke-NcRequest($client, [string]$Method, [string]$Url, $Content, $Headers) {
    $req = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::new($Method), $Url)
    if ($Content) { $req.Content = $Content }
    if ($Headers) { foreach ($k in $Headers.Keys) { [void]$req.Headers.TryAddWithoutValidation($k, $Headers[$k]) } }
    return $client.SendAsync($req).GetAwaiter().GetResult()
}

# Legt fehlende Ordner an (MKCOL je Segment; 405 = existiert bereits).
function Ensure-NextcloudFolder($client, $cfg, [string]$RelDir) {
    $folder = ([string]$cfg.remoteDir).Trim('/')
    $segments = @()
    if ($folder) { $segments += ($folder -split '/') }
    if ($RelDir) { $segments += (($RelDir -replace '\\', '/') -split '/') }
    $current = ''
    foreach ($s in $segments) {
        if (-not $s) { continue }
        $current = if ($current) { $current + '/' + $s } else { $s }
        $url = (Get-NextcloudRoot $cfg)
        foreach ($p in ($current -split '/')) { $url += '/' + [Uri]::EscapeDataString($p) }
        $resp = Invoke-NcRequest $client 'MKCOL' $url $null $null
        $code = [int]$resp.StatusCode
        $resp.Dispose()
        if ($code -ne 201 -and $code -ne 405 -and $code -ne 301) {
            throw ('Ordner konnte nicht angelegt werden (' + $code + '): ' + $current)
        }
    }
}

function Invoke-NextcloudUpload([string]$LocalPath, [string]$RemoteName) {
    if (-not [IO.File]::Exists($LocalPath)) { throw ('Datei nicht gefunden: ' + $LocalPath) }
    if (-not $RemoteName) { $RemoteName = [IO.Path]::GetFileName($LocalPath) }
    $cfg = Read-NextcloudConfig
    $client = New-NextcloudClient $cfg
    try {
        Ensure-NextcloudFolder $client $cfg ''
        $bytes = [IO.File]::ReadAllBytes($LocalPath)
        $content = [System.Net.Http.ByteArrayContent]::new($bytes)
        $content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::new('application/octet-stream')
        $url = Get-NextcloudUrl $cfg $RemoteName
        $resp = Invoke-NcRequest $client 'PUT' $url $content $null
        $code = [int]$resp.StatusCode
        $resp.Dispose()
        if ($code -ne 200 -and $code -ne 201 -and $code -ne 204) {
            throw ('Upload fehlgeschlagen (HTTP ' + $code + ').')
        }
        return [ordered]@{ ok = $true; remote = $RemoteName; bytes = $bytes.Length; code = $code }
    } finally { $client.Dispose() }
}

function Invoke-NextcloudDownload([string]$RemoteName, [string]$DestPath) {
    $cfg = Read-NextcloudConfig
    $client = New-NextcloudClient $cfg
    try {
        $url = Get-NextcloudUrl $cfg $RemoteName
        $resp = Invoke-NcRequest $client 'GET' $url $null $null
        $code = [int]$resp.StatusCode
        if ($code -ne 200) { $resp.Dispose(); throw ('Download fehlgeschlagen (HTTP ' + $code + ').') }
        $bytes = $resp.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
        $resp.Dispose()
        [IO.File]::WriteAllBytes($DestPath, $bytes)
        return [ordered]@{ ok = $true; dest = $DestPath; bytes = $bytes.Length }
    } finally { $client.Dispose() }
}

# PROPFIND Depth:1 auf dem konfigurierten Ordner; liefert Datei-Eintraege.
# $Cfg optional: sonst aus der gespeicherten Konfiguration.
function Invoke-NextcloudList($Cfg) {
    $cfg = if ($Cfg) { $Cfg } else { Read-NextcloudConfig }
    $client = New-NextcloudClient $cfg
    try {
        $body = '<?xml version="1.0" encoding="utf-8"?><d:propfind xmlns:d="DAV:"><d:prop><d:getcontentlength/><d:getlastmodified/><d:resourcetype/></d:prop></d:propfind>'
        $content = [System.Net.Http.StringContent]::new($body, [Text.Encoding]::UTF8, 'application/xml')
        $url = Get-NextcloudUrl $cfg ''
        $resp = Invoke-NcRequest $client 'PROPFIND' $url $content @{ 'Depth' = '1' }
        $code = [int]$resp.StatusCode
        $xmlText = $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        $resp.Dispose()
        if ($code -eq 404) { return @() }
        if ($code -ne 207) { throw ('Auflisten fehlgeschlagen (HTTP ' + $code + ').') }
        $doc = [Xml.XmlDocument]::new(); $doc.XmlResolver = $null; $doc.LoadXml($xmlText)
        $ns = [Xml.XmlNamespaceManager]::new($doc.NameTable); $ns.AddNamespace('d', 'DAV:')
        $items = @()
        foreach ($r in @($doc.SelectNodes('//d:response', $ns))) {
            $href = [string]$r.SelectSingleNode('d:href', $ns).InnerText
            $isDir = ($r.SelectSingleNode('.//d:resourcetype/d:collection', $ns) -ne $null)
            if ($isDir) { continue }
            $name = [Uri]::UnescapeDataString(($href.TrimEnd('/') -split '/')[-1])
            $lenNode = $r.SelectSingleNode('.//d:getcontentlength', $ns)
            $modNode = $r.SelectSingleNode('.//d:getlastmodified', $ns)
            $items += [ordered]@{
                name     = $name
                size     = [long]([string]$lenNode.InnerText -as [long])
                modified = [string]$modNode.InnerText
            }
        }
        return $items
    } finally { $client.Dispose() }
}

function Test-Nextcloud($Cfg) {
    $null = Invoke-NextcloudList $Cfg
    return $true
}

# --- Headless-Einstieg (fuer die WPF-Konfiguration zum Verbindungstest) -----
if ($NextcloudRequestPath) {
    $ErrorActionPreference = 'Stop'
    try {
        $request = [IO.File]::ReadAllText($NextcloudRequestPath) | ConvertFrom-Json
        switch ([string]$request.op) {
            'test'   { $null = Test-Nextcloud; $out = [ordered]@{ ok = $true } }
            default  { throw ('Unbekannte Operation: ' + $request.op) }
        }
        [IO.File]::WriteAllText($NextcloudRequestPath + '.result',
            (ConvertTo-Json -InputObject $out -Depth 6), [Text.UTF8Encoding]::new($true))
    } catch {
        [IO.File]::WriteAllText($NextcloudRequestPath + '.error', ($_ | Out-String), [Text.UTF8Encoding]::new($true))
        exit 1
    }
}
