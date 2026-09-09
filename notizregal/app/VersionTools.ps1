param([string]$VersionRequestPath='')
. (Join-Path $PSScriptRoot 'TextTools.ps1')
function Get-VersionDirectory([string]$BookPath){
 $sha=[Security.Cryptography.SHA256]::Create()
 try{$id=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes([IO.Path]::GetFullPath($BookPath).ToLowerInvariant())))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
 $root=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Notizregal/versionen'
 return Join-Path $root $id
}
function Read-VersionIndex([string]$BookPath){
 $path=Join-Path (Get-VersionDirectory $BookPath) 'index.json'
 if(-not [IO.File]::Exists($path)){return [pscustomobject]@{version=1;book=$BookPath;entries=@()}}
 $index=[IO.File]::ReadAllText($path) | ConvertFrom-Json
 if($index.version -ne 1 -or $index.book -ine $BookPath -or $null -eq $index.entries){throw 'Versionsindex beschädigt. Er wird nicht überschrieben; index.json.bak prüfen.'}
 foreach($entry in @($index.entries)){if($entry.hash -notmatch '^[a-f0-9]{64}$'){throw 'Ungültiger Versionsindex.'}}
 return $index
}
function Get-VersionHash([string]$Path){
 $stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
 $sha=[Security.Cryptography.SHA256]::Create()
 try{return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose();$stream.Dispose()}
}
function Enter-VersionLock([string]$BookPath){
 $key=[IO.Path]::GetFileName((Get-VersionDirectory $BookPath))
 $mutex=[Threading.Mutex]::new($false,('Notizregal-Version-'+$key));$locked=$false
 try{try{$locked=$mutex.WaitOne(1500)}catch [Threading.AbandonedMutexException]{$locked=$true};if(-not $locked){throw 'Sicherung läuft bereits. Bitte kurz warten und erneut versuchen.'};return $mutex}catch{$mutex.Dispose();throw}
}
function Save-NotebookVersion([string]$BookPath,[string]$Reason='Manuell',[switch]$AlreadyLocked){
 if([IO.Path]::GetExtension($BookPath) -ine '.xopp'){throw 'Versionen sind für gespeicherte .xopp-Notizbücher verfügbar.'}
 $mutex=$null;$temp='';$inputFile=$null
 try{
  if(-not $AlreadyLocked){$mutex=Enter-VersionLock $BookPath}
  $dir=Get-VersionDirectory $BookPath;[void][IO.Directory]::CreateDirectory($dir)
  $index=Read-VersionIndex $BookPath
  # Deny writes/deletes while obtaining a consistent copy. Never read a half-written journal.
  $inputFile=[IO.File]::Open($BookPath,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
  $ticks=[string][IO.File]::GetLastWriteTimeUtc($BookPath).Ticks;$length=$inputFile.Length
  if($Reason -eq 'Automatisch' -and $index.entries.Count){$last=$index.entries[-1];if($last.sourceTicks -eq $ticks -and $last.length -eq $length){return $last}}
  $temp=Join-Path $dir ([Guid]::NewGuid().ToString('N')+'.tmp')
  $outputFile=[IO.File]::Open($temp,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
  try{$inputFile.CopyTo($outputFile);$outputFile.Flush($true)}finally{$outputFile.Dispose()}
  $inputFile.Dispose();$inputFile=$null
  $null=Read-XoppXml $temp
  $hash=Get-VersionHash $temp
  if($index.entries.Count -and $index.entries[-1].hash -eq $hash){return $index.entries[-1]}
  $blob=Join-Path $dir ($hash+'.nrv')
  if([IO.File]::Exists($blob)){if((Get-VersionHash $blob) -ne $hash){throw 'Gespeicherte Version ist beschädigt.'}}else{[IO.File]::Move($temp,$blob);$temp=''}
  $entry=[pscustomobject]@{id=[Guid]::NewGuid().ToString('N');hash=$hash;created=(Get-Date).ToString('o');sourceTicks=$ticks;length=$length;reason=$Reason}
  $index.entries=@($index.entries)+@($entry);Write-AtomicJson (Join-Path $dir 'index.json') $index
  return $entry
 }finally{if($inputFile){$inputFile.Dispose()};if($temp -and [IO.File]::Exists($temp)){[IO.File]::Delete($temp)};if($mutex){$mutex.ReleaseMutex();$mutex.Dispose()}}
}
function Get-VerifiedVersion([string]$BookPath,[string]$Id){
 $index=Read-VersionIndex $BookPath;$entries=@($index.entries | Where-Object {$_.id -eq $Id})
 if($entries.Count -ne 1){throw 'Version nicht gefunden.'}
 $blob=Join-Path (Get-VersionDirectory $BookPath) ($entries[0].hash+'.nrv')
 if((Get-VersionHash $blob) -ne $entries[0].hash){throw 'Prüfsumme der Sicherung stimmt nicht. Wiederherstellung abgebrochen.'}
 $null=Read-XoppXml $blob
 return $blob
}
function Export-NotebookVersion([string]$BookPath,[string]$Id,[string]$Destination){
 if([IO.Path]::GetFullPath($BookPath) -ieq [IO.Path]::GetFullPath($Destination)){throw 'Für eine Kopie bitte einen anderen Dateinamen wählen. Zum Ersetzen Wiederherstellen verwenden.'}
 $blob=Get-VerifiedVersion $BookPath $Id
 [IO.File]::Copy($blob,$Destination,$false)
}
function Restore-NotebookVersion([string]$BookPath,[string]$Id){
 $mutex=Enter-VersionLock $BookPath;$temp='';$safety=''
 try{
  $blob=Get-VerifiedVersion $BookPath $Id
  $exists=[IO.File]::Exists($BookPath)
  if($exists){$current=Save-NotebookVersion $BookPath 'Vor Wiederherstellung' -AlreadyLocked}
  $parent=[IO.Path]::GetDirectoryName($BookPath)
  $temp=Join-Path $parent ('.notizregal-'+[Guid]::NewGuid().ToString('N')+'.tmp')
  [IO.File]::Copy($blob,$temp,$false)
  if($exists){
   # Keep the exact replaced bytes as an additional recovery file, including any last-moment external save.
   $safety=Join-Path $parent ('.notizregal-vor-wiederherstellung-'+[Guid]::NewGuid().ToString('N')+'.nrv')
   if((Get-VersionHash $BookPath) -ne $current.hash){throw 'Notizbuch wurde zwischenzeitlich geändert. Xournal++ schließen und erneut versuchen.'}
   [IO.File]::Replace($temp,$BookPath,$safety)
  }else{[IO.File]::Move($temp,$BookPath)}
  $temp=''
  # Keep source timestamp different so old text indices become stale.
  [IO.File]::SetLastWriteTimeUtc($BookPath,[DateTime]::UtcNow)
  $warning=''
  try{$null=Save-NotebookVersion $BookPath 'Wiederhergestellt' -AlreadyLocked}catch{$warning='Datei wiederhergestellt, neuer Verlaufseintrag fehlgeschlagen: '+$_.Exception.Message}
  return [pscustomobject]@{safety=$safety;warning=$warning}
 }finally{if($temp -and [IO.File]::Exists($temp)){[IO.File]::Delete($temp)};$mutex.ReleaseMutex();$mutex.Dispose()}
}
if($VersionRequestPath){
 $ErrorActionPreference='Stop';$errors=[Collections.Generic.List[string]]::new();$count=0
 try{
  $request=[IO.File]::ReadAllText($VersionRequestPath) | ConvertFrom-Json
  foreach($path in @($request.paths)){try{$null=Save-NotebookVersion $path 'Automatisch';$count++}catch{$errors.Add($path+': '+$_.Exception.Message)}}
  Write-AtomicJson ($VersionRequestPath+'.result') ([pscustomobject]@{checked=$count;errors=@($errors.ToArray());finished=(Get-Date).ToString('o')})
 }catch{[IO.File]::WriteAllText(($VersionRequestPath+'.error'),($_ | Out-String));exit 1}
}
