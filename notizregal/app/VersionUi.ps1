# WPF integration. VersionTools.ps1 contains the independent storage/restore functions.
function Show-BookVersions($Book){
 [xml]$historyXaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Notizbuchversionen" Width="850" Height="570" MinWidth="690" MinHeight="420" WindowStartupLocation="CenterOwner" Background="#F5F3EE" FontFamily="Segoe UI" FontSize="14">
 <Grid Margin="22"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
 <StackPanel><TextBlock x:Name="VersionTitle" FontSize="24" FontWeight="SemiBold"/><TextBlock Text="Gespeicherte Stände · Datum, Anlass und Größe" Margin="0,7,0,12"/></StackPanel>
 <ListBox x:Name="VersionList" Grid.Row="1" Padding="8" ScrollViewer.HorizontalScrollBarVisibility="Auto"/>
 <WrapPanel Grid.Row="2" Margin="0,14,0,8"><Button x:Name="SnapshotNow" Content="Jetzt sichern" Padding="13,11" Margin="0,0,8,8"/><Button x:Name="ExportVersion" Content="Als Kopie speichern" Padding="13,11" Margin="0,0,8,8" IsEnabled="False"/><Button x:Name="RestoreVersion" Content="Wiederherstellen" Padding="13,11" Margin="0,0,8,8" IsEnabled="False"/><Button x:Name="VersionFolder" Content="Sicherungsordner" Padding="13,11" Margin="0,0,0,8"/></WrapPanel>
 <TextBlock x:Name="VersionStatus" Grid.Row="3" Text="Vor dem Wiederherstellen das Notizbuch in Xournal++ schließen. Externe PDF-Hintergründe und Audiodateien separat aufbewahren." TextWrapping="Wrap" Foreground="#51695A"/>
 </Grid>
</Window>
'@
 $dlg=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($historyXaml));$dlg.Owner=$script:Win
 $dlg.FindName('VersionTitle').Text=$Book.title
 $list=$dlg.FindName('VersionList');$status=$dlg.FindName('VersionStatus');$export=$dlg.FindName('ExportVersion');$restore=$dlg.FindName('RestoreVersion')
 $fill={
  $list.Items.Clear();$index=Read-VersionIndex $Book.path
  foreach($entry in @($index.entries | Sort-Object created -Descending)){
   $item=[Windows.Controls.ListBoxItem]::new();$item.Tag=$entry;$item.Padding='8,12'
   $item.Content=([DateTime]::Parse($entry.created).ToLocalTime().ToString('dd.MM.yyyy HH:mm:ss'))+' · '+$entry.reason+' · '+([Math]::Round($entry.length/1024,1))+' KB'
   [void]$list.Items.Add($item)
  }
  if($list.Items.Count){$list.SelectedIndex=0}
 }
 $list.Add_SelectionChanged({$export.IsEnabled=$null -ne $list.SelectedItem;$restore.IsEnabled=$export.IsEnabled})
 $dlg.FindName('SnapshotNow').Add_Click({try{$null=Save-NotebookVersion $Book.path 'Manuell';& $fill;$status.Text='Gespeichert. Identische Inhalte erzeugen keine zusätzliche Version.'}catch{$status.Text=$_.Exception.Message}})
 $export.Add_Click({try{
  if(-not $list.SelectedItem){return}
  $picker=[Microsoft.Win32.SaveFileDialog]::new();$picker.Filter='Xournal++ (*.xopp)|*.xopp';$picker.DefaultExt='.xopp';$picker.FileName=[IO.Path]::GetFileNameWithoutExtension($Book.path)+'-Version-'+[DateTime]::Parse($list.SelectedItem.Tag.created).ToString('yyyyMMdd-HHmmss')+'.xopp'
  if($picker.ShowDialog($dlg)){Export-NotebookVersion $Book.path $list.SelectedItem.Tag.id $picker.FileName;$status.Text='Kopie gespeichert: '+$picker.FileName+'. Relative PDF-Hintergründe ggf. mitkopieren.'}
 }catch{$status.Text=$_.Exception.Message}})
 $restore.Add_Click({try{
  if(-not $list.SelectedItem){return}
  $answer=[Windows.MessageBox]::Show($dlg,'Ist das Notizbuch in Xournal++ geschlossen? Die gewählte Version ersetzt die aktuelle Datei. Der aktuelle gespeicherte Stand wird vorher gesichert.','Version wiederherstellen','YesNo','Question')
  if($answer -ne 'Yes'){return}
  $result=Restore-NotebookVersion $Book.path $list.SelectedItem.Tag.id
  & $fill;$status.Text='Wiederhergestellt. Das Notizbuch kann jetzt erneut geöffnet werden.'
  if($result.warning){$status.Text=$result.warning}
 }catch{$status.Text=$_.Exception.Message}})
 $dlg.FindName('VersionFolder').Add_Click({$dir=Get-VersionDirectory $Book.path;[void][IO.Directory]::CreateDirectory($dir);$si=[Diagnostics.ProcessStartInfo]::new();$si.FileName=$dir;$si.UseShellExecute=$true;[void][Diagnostics.Process]::Start($si)})
 & $fill
 [void]$dlg.ShowDialog();Read-Books
}
function Start-VersionSweep {
 if($script:VersionProcess){
  if(-not $script:VersionProcess.HasExited){return}
  $script:VersionProcess.Dispose();$script:VersionProcess=$null
  try{
   if([IO.File]::Exists($script:VersionRequest+'.error')){throw [IO.File]::ReadAllText($script:VersionRequest+'.error')}
   $result=[IO.File]::ReadAllText($script:VersionRequest+'.result') | ConvertFrom-Json
   $script:VersionStatus.Text=if($result.errors.Count){'Versionssicherung: '+$result.errors.Count+' Datei(en) nicht gesichert. Details: diese Statuszeile antippen.'}else{'Versionen geprüft: '+$result.checked+' Notizbücher · '+[DateTime]::Parse($result.finished).ToLocalTime().ToString('HH:mm:ss')}
   $script:VersionStatus.ToolTip=($result.errors -join "`n")
  }catch{$script:VersionStatus.Text='Versionssicherung fehlgeschlagen: '+$_.Exception.Message}
 }
 if((Get-Date) -lt $script:NextVersionSweep){return}
 $paths=@($script:Books | Where-Object {$_.kind -eq 'xopp'} | ForEach-Object {$_.path})
 $script:NextVersionSweep=(Get-Date).AddSeconds(60)
 if(-not $paths.Count){return}
 try{
  foreach($suffix in @('.result','.error')){if([IO.File]::Exists($script:VersionRequest+$suffix)){[IO.File]::Delete($script:VersionRequest+$suffix)}}
  Write-AtomicJson $script:VersionRequest ([pscustomobject]@{paths=$paths})
  $si=[Diagnostics.ProcessStartInfo]::new();$si.FileName=Join-Path $PSHOME 'powershell.exe';$si.Arguments='-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File "'+(Join-Path $PSScriptRoot 'VersionTools.ps1')+'" -VersionRequestPath "'+$script:VersionRequest+'"';$si.UseShellExecute=$false;$si.CreateNoWindow=$true
  $script:VersionProcess=[Diagnostics.Process]::Start($si);$script:VersionStatus.Text='Gespeicherte Notizbuchversionen werden geprüft …'
 }catch{$script:VersionStatus.Text='Versionssicherung fehlgeschlagen: '+$_.Exception.Message}
}
