param([string]$AudioRequestPath='')
# Offline audio processing for Surface ARM64. No network operations.
function Get-AudioIndexPath([string]$BookPath){
 $root=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Notizregal\audio'
 [void][IO.Directory]::CreateDirectory($root)
 $hash=[Security.Cryptography.SHA256]::Create()
 try{$id=([BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($BookPath.ToLowerInvariant())))).Replace('-','').ToLowerInvariant()}finally{$hash.Dispose()}
 return Join-Path $root ($id+'.json')
}
function Read-AudioIndex($BookPath){
 $path=Get-AudioIndexPath $BookPath
 if([IO.File]::Exists($path)){
  # Corrupt transcripts must not be silently replaced by an empty index.
  try{return ([IO.File]::ReadAllText($path) | ConvertFrom-Json)}catch{throw ('Audioindex nicht lesbar: '+$path+'. Bitte die .bak-Sicherung prüfen.')}
 }
 return [pscustomobject]@{version=1;book=$BookPath;recordings=@()}
}
function Get-AudioSearchText($Index){return (@($Index.recordings | ForEach-Object {$_.name+"`n"+$_.text}) -join "`n`n")}
function Get-AudioExport($Index,$Title,[bool]$Markdown){
 $lines=[Collections.Generic.List[string]]::new();if($Markdown){$lines.Add('# '+$Title)}else{$lines.Add($Title)}
 $lines.Add('');$lines.Add('Lokal transkribierte Audioaufnahmen. Automatische Erkennung; bitte auf Fehler prüfen.')
 foreach($r in @($Index.recordings)){$lines.Add('');if($Markdown){$lines.Add('## '+$r.name)}else{$lines.Add($r.name)};$lines.Add('');$lines.Add($r.text)}
 return $lines -join "`r`n"
}
function Invoke-AudioProgram($Exe,[string[]]$Arguments,$OutLog,$ErrLog){
 # All native arguments are quoted; paths cannot inject shell syntax.
 $quoted=@($Arguments | ForEach-Object {'"'+$_+'"'}) -join ' '
 $process=Start-Process -FilePath $Exe -ArgumentList $quoted -NoNewWindow -WorkingDirectory ([IO.Path]::GetDirectoryName($OutLog)) -RedirectStandardOutput $OutLog -RedirectStandardError $ErrLog -PassThru
 try{$null=$process.Handle;$process.WaitForExit();$process.Refresh();if($process.ExitCode -ne 0){$message='';if([IO.File]::Exists($ErrLog)){$message=[IO.File]::ReadAllText($ErrLog)};throw ('Audioverarbeitung beendet mit Code '+$process.ExitCode+".`n"+$message)}}finally{$process.Dispose()}
}
if($AudioRequestPath){
 $ErrorActionPreference='Stop'
 . (Join-Path $PSScriptRoot 'TextTools.ps1')
 try{
  $request=[IO.File]::ReadAllText($AudioRequestPath) | ConvertFrom-Json
  $jobDir=[IO.Path]::GetDirectoryName($AudioRequestPath)
  $source=Get-Item -LiteralPath $request.audio
  if($source.Extension -notin @('.ogg','.wav')){throw 'Bitte eine OGG-Vorbis- oder WAV-Aufnahme auswählen.'}
  $ticks=[string]$source.LastWriteTimeUtc.Ticks;$length=$source.Length
  $engine=Join-Path $PSScriptRoot 'AudioEngine'
  foreach($name in @('audio-convert.exe','whisper-cli.exe','ggml-base-q5_1.bin')){if(-not [IO.File]::Exists((Join-Path $engine $name))){throw ('Audio-Komponente fehlt: '+$name+'. Das gesamte ZIP entpacken und mit Start.cmd starten.')}}
  $wav=Join-Path $jobDir 'aufnahme.wav';$prefix=Join-Path $jobDir 'transkript'
  [IO.File]::WriteAllText((Join-Path $jobDir 'status.txt'),'Aufnahme wird lokal in WAV umgewandelt ...')
  Invoke-AudioProgram (Join-Path $engine 'audio-convert.exe') @($source.FullName,$wav) (Join-Path $jobDir 'convert.out') (Join-Path $jobDir 'convert.err')
  $current=Get-Item -LiteralPath $source.FullName
  if([string]$current.LastWriteTimeUtc.Ticks -ne $ticks -or $current.Length -ne $length){throw 'Aufnahme wurde während des Einlesens verändert. Bitte Aufnahme beenden und erneut starten.'}
  $language=if($request.language -in @('de','en','auto')){$request.language}else{'de'}
  [IO.File]::WriteAllText((Join-Path $jobDir 'status.txt'),'Sprache wird lokal erkannt. Das kann länger als die Aufnahme dauern ...')
  # Use relative ASCII worker paths so Unicode Windows profile names do not pass through the CLI code page.
  $baseUri=[Uri]::new($jobDir+[IO.Path]::DirectorySeparatorChar)
  $modelUri=[Uri]::new((Join-Path $engine 'ggml-base-q5_1.bin'))
  $modelArgument=[Uri]::UnescapeDataString($baseUri.MakeRelativeUri($modelUri).ToString()).Replace('/','\')
  Invoke-AudioProgram (Join-Path $engine 'whisper-cli.exe') @('-m',$modelArgument,'-f','aufnahme.wav','-l',$language,'-t','4','-ng','-pp','-oj','-otxt','-of','transkript') (Join-Path $jobDir 'whisper.out') (Join-Path $jobDir 'whisper.err')
  if(-not [IO.File]::Exists($prefix+'.json')){throw 'Die Spracherkennung hat kein Ergebnis erzeugt.'}
  $json=[IO.File]::ReadAllText($prefix+'.json') | ConvertFrom-Json
  $lines=[Collections.Generic.List[string]]::new()
  foreach($segment in @($json.transcription)){
   if($segment.text.Trim()){$time=[TimeSpan]::FromMilliseconds([double]$segment.offsets.from);$mark='{0:00}:{1:00}:{2:00}' -f [int][Math]::Floor($time.TotalHours),$time.Minutes,$time.Seconds;$lines.Add('['+$mark+'] '+$segment.text.Trim())}
  }
  $result=[pscustomobject]@{id=[Guid]::NewGuid().ToString('N');name=$source.Name;source=$source.FullName;sourceTicks=$ticks;sourceLength=$length;created=(Get-Date).ToString('o');language=$language;model='base-q5_1';text=($lines -join "`r`n`r`n");corrected=$false}
  Write-AtomicJson ($AudioRequestPath+'.result') $result
 }catch{[IO.File]::WriteAllText(($AudioRequestPath+'.error'),($_ | Out-String),[Text.UTF8Encoding]::new($true));exit 1}
}
