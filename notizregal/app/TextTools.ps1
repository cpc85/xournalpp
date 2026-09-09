param([string]$RequestPath='')
# Offline-Textdienst; benötigt Windows PowerShell 5.1, kein Netzwerk.
function Read-XoppXml([string]$Path) {
    $file=$null; $gzip=$null; $reader=$null
    try {
        $file=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
        $gzip=[IO.Compression.GZipStream]::new($file,[IO.Compression.CompressionMode]::Decompress)
        $settings=[Xml.XmlReaderSettings]::new()
        $settings.DtdProcessing=[Xml.DtdProcessing]::Prohibit; $settings.XmlResolver=$null
        $settings.MaxCharactersInDocument=67108864
        $reader=[Xml.XmlReader]::Create($gzip,$settings)
        $doc=[Xml.XmlDocument]::new(); $doc.XmlResolver=$null; $doc.Load($reader)
        if($doc.DocumentElement.Name -ne 'xournal'){throw 'Keine gültige Xournal++-Datei.'}
        return ,$doc
    } finally {if($reader){$reader.Dispose()}; if($gzip){$gzip.Dispose()}; if($file){$file.Dispose()}}
}
function Write-AtomicJson($Path,$Value) {
    $tmp=$Path+'.'+[Guid]::NewGuid().ToString('N')+'.tmp'
    [IO.File]::WriteAllText($tmp,(ConvertTo-Json -InputObject $Value -Depth 12),[Text.UTF8Encoding]::new($true))
    if([IO.File]::Exists($Path)){[IO.File]::Replace($tmp,$Path,$Path+'.bak')}else{[IO.File]::Move($tmp,$Path)}
}
function Get-TextIndexPath([string]$BookPath) {
    $dir=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Notizregal\texte'
    [void][IO.Directory]::CreateDirectory($dir)
    $sha=[Security.Cryptography.SHA256]::Create()
    try {$id=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($BookPath.ToLowerInvariant())))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
    return Join-Path $dir ($id+'.json')
}
function Read-TextIndex($BookPath) {
    $path=Get-TextIndexPath $BookPath
    if([IO.File]::Exists($path)) {
        try {return ([IO.File]::ReadAllText($path) | ConvertFrom-Json)}catch{return $null}
    }
    return $null
}
function Get-IndexText($Index) {
    if(-not $Index){return ''}
    return (@($Index.pages | ForEach-Object {$_.text}) -join "`n`n")
}
function Export-IndexString($Index,[string]$Title,[bool]$Markdown) {
    $lines=[Collections.Generic.List[string]]::new()
    if($Markdown){$lines.Add('# '+$Title)}else{$lines.Add($Title)}
    $lines.Add('')
    $lines.Add('Textexport aus Xournal++. Handschrift maschinell erkannt; bitte prüfen. PDF-/Bildinhalte sind nicht enthalten.')
    foreach($warning in @($Index.warnings)){if($warning){$lines.Add('Hinweis: '+$warning)}}
    foreach($page in @($Index.pages)){
        $lines.Add(''); if($Markdown){$lines.Add('## Seite '+$page.number)}else{$lines.Add('Seite '+$page.number)}
        $lines.Add(''); $lines.Add([string]$page.text)
    }
    return $lines -join "`r`n"
}
function Initialize-Ink {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $null=[type]'Windows.UI.Input.Inking.InkRecognizerContainer, Windows.UI.Input.Inking, ContentType=WindowsRuntime'
    $null=[type]'Windows.UI.Input.Inking.InkStrokeBuilder, Windows.UI.Input.Inking, ContentType=WindowsRuntime'
    $null=[type]'Windows.UI.Input.Inking.InkStrokeContainer, Windows.UI.Input.Inking, ContentType=WindowsRuntime'
    $null=[type]'Windows.UI.Input.Inking.InkRecognitionResult, Windows.UI.Input.Inking, ContentType=WindowsRuntime'
    $null=[type]'Windows.UI.Input.Inking.InkRecognitionTarget, Windows.UI.Input.Inking, ContentType=WindowsRuntime'
    $script:InkEngine=[Windows.UI.Input.Inking.InkRecognizerContainer]::new()
    $recognizers=@($script:InkEngine.GetRecognizers())
    $german=@($recognizers | Where-Object {$_.Name -match 'Deutsch|German|de-DE'})
    if(-not $german.Count){throw 'Deutsche Windows-Handschrifterkennung fehlt. Windows: Zeit und Sprache > Sprache und Region > Deutsch > Sprachoptionen > Handschrift. Das Paket muss vor der Offline-Nutzung installiert sein.'}
    $script:InkEngine.SetDefaultRecognizer($german[0])
    $script:InkBuilder=[Windows.UI.Input.Inking.InkStrokeBuilder]::new()
    # Tatsächlich projizierten Point-Typ ermitteln, statt WPF-Point anzunehmen.
    $method=@([Windows.UI.Input.Inking.InkStrokeBuilder].GetMethods() | Where-Object {$_.Name -eq 'CreateStroke' -and $_.GetParameters().Count -eq 1})[0]
    $script:InkPointType=$method.GetParameters()[0].ParameterType.GetGenericArguments()[0]
    $script:InkListType=[Collections.Generic.List[int]].GetGenericTypeDefinition().MakeGenericType(@($script:InkPointType))
    $script:InkAsTask=@([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {$_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetGenericArguments().Count -eq 1 -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'})[0]
    $script:InkResultType=[Collections.Generic.IReadOnlyList[Windows.UI.Input.Inking.InkRecognitionResult]]
    return $german[0].Name
}
function Recognize-Page($Page) {
    $container=[Windows.UI.Input.Inking.InkStrokeContainer]::new()
    $count=0
    foreach($node in @($Page.SelectNodes('./layer/stroke[@tool="pen"]'))){
        $coords=@($node.InnerText.Trim() -split '\s+')
        if($coords.Count -lt 4 -or ($coords.Count % 2)){continue}
        $points=[Activator]::CreateInstance($script:InkListType)
        for($i=0;$i -lt $coords.Count;$i+=2){
            $x=[double]::Parse($coords[$i],[Globalization.CultureInfo]::InvariantCulture)*96/72
            $y=[double]::Parse($coords[$i+1],[Globalization.CultureInfo]::InvariantCulture)*96/72
            if([double]::IsNaN($x) -or [double]::IsInfinity($x) -or [double]::IsNaN($y) -or [double]::IsInfinity($y)){throw 'Ungültige Strichkoordinaten.'}
            $point=[Activator]::CreateInstance($script:InkPointType)
            $point.X=$x; $point.Y=$y; $points.Add($point)
        }
        $stroke=$script:InkBuilder.CreateStroke($points)
        $container.AddStroke($stroke); $count++
        if($count -gt 25000){throw 'Mehr als 25.000 Stiftstriche auf einer Seite. Bitte die Seite in Xournal++ aufteilen.'}
    }
    if(-not $count){return ''}
    $operation=$script:InkEngine.RecognizeAsync($container,[Windows.UI.Input.Inking.InkRecognitionTarget]::All)
    $task=$script:InkAsTask.MakeGenericMethod(@($script:InkResultType)).Invoke($null,@($operation))
    if(-not $task.Wait(90000)){try{$operation.Cancel()}catch{}; throw 'Zeitlimit bei der Handschrifterkennung (90 Sekunden je Seite).'}
    $parts=[Collections.Generic.List[string]]::new()
    # API-Reihenfolge folgt den vom Erkenner zusammengefassten Textsegmenten.
    foreach($result in $task.Result){$candidates=@($result.GetTextCandidates()); if($candidates.Count){$parts.Add([string]$candidates[0])}}
    return $parts -join ' '
}
function Convert-XoppToIndex([string]$Path,[bool]$Handwriting) {
    $before=Get-Item -LiteralPath $Path
    $stamp=$before.LastWriteTimeUtc.Ticks; $length=$before.Length
    $doc=Read-XoppXml $Path
    $warnings=[Collections.Generic.List[string]]::new()
    $pages=[Collections.Generic.List[object]]::new()
    $number=0; $complete=$true; $engineName=''
    $needInk=$Handwriting -and $doc.SelectNodes('/xournal/page/layer/stroke[@tool="pen"]').Count -gt 0
    $inkOK=$false
    if($needInk){try{$engineName=Initialize-Ink; $inkOK=$true}catch{$warnings.Add($_.Exception.Message);$complete=$false}}
    foreach($page in @($doc.SelectNodes('/xournal/page'))){
        $number++; $parts=[Collections.Generic.List[string]]::new()
        foreach($text in @($page.SelectNodes('./layer/text') | Sort-Object @{Expression={ [double]::Parse($_.GetAttribute('y'),[Globalization.CultureInfo]::InvariantCulture) }}, @{Expression={ [double]::Parse($_.GetAttribute('x'),[Globalization.CultureInfo]::InvariantCulture) }})){
            if($text.InnerText){$parts.Add($text.InnerText)}
        }
        $hasStrokes=$page.SelectNodes('./layer/stroke[@tool="pen"]').Count -gt 0
        if($hasStrokes -and $inkOK){try{$recognized=Recognize-Page $page; if($recognized){$parts.Add($recognized)}else{$warnings.Add("Seite ${number}: Keine Handschrift erkannt.");$complete=$false}}catch{$warnings.Add("Seite ${number}: "+$_.Exception.Message);$complete=$false}}
        elseif($hasStrokes){$warnings.Add("Seite ${number}: Stiftstriche nicht als Text erfasst.");$complete=$false}
        if($page.SelectNodes('./layer/image | ./background[@type="pdf"]').Count){$warnings.Add("Seite ${number}: Bild-/PDF-Inhalte sind nicht enthalten.")}
        $pages.Add([pscustomobject]@{number=$number; text=($parts -join "`r`n`r`n"); corrected=$false})
    }
    $after=Get-Item -LiteralPath $Path
    if($after.LastWriteTimeUtc.Ticks -ne $stamp -or $after.Length -ne $length){throw 'Notiz wurde während der Verarbeitung verändert. Bitte speichern, kurz warten und erneut erkennen.'}
    return [pscustomobject]@{version=1;path=$Path;sourceTicks=[string]$stamp;sourceLength=$length;created=(Get-Date).ToString('o');handwriting=$Handwriting;complete=$complete;engine=$engineName;warnings=@($warnings.ToArray());pages=@($pages.ToArray())}
}
if($RequestPath){
    $ErrorActionPreference='Stop'
    try {
        $request=[IO.File]::ReadAllText($RequestPath) | ConvertFrom-Json
        $result=Convert-XoppToIndex $request.path ([bool]$request.handwriting)
        Write-AtomicJson ($RequestPath+'.result') $result
    } catch {
        [IO.File]::WriteAllText(($RequestPath+'.error'),($_ | Out-String),[Text.UTF8Encoding]::new($true))
        exit 1
    }
}
