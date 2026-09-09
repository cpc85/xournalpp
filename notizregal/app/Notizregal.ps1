# Notizregal 1.4 — Windows PowerShell 5.1 / WPF
# Lokale Verwaltungsoberfläche für Xournal++, keine Netzwerkverbindungen.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName @('PresentationFramework','PresentationCore','WindowsBase','System.Windows.Forms')
$script:DataDir = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Notizregal'
[void][IO.Directory]::CreateDirectory($script:DataDir)
$script:DbPath = Join-Path $script:DataDir 'katalog.json'
$script:Db = [pscustomobject]@{ version=1; roots=@(); executable=''; books=@() }
$script:Books = @()
. (Join-Path $PSScriptRoot 'TextTools.ps1')
. (Join-Path $PSScriptRoot 'AudioTools.ps1')
. (Join-Path $PSScriptRoot 'VersionTools.ps1')
. (Join-Path $PSScriptRoot 'VersionUi.ps1')
$script:FavOnly = $false
$script:Refreshing = $false
# Verhindert konkurrierende Schreibzugriffe mehrerer Fenster.
$created = $false
$script:Mutex = New-Object Threading.Mutex($true, 'Local\Notizregal-1', [ref]$created)
if (-not $created) {
    [void][Windows.MessageBox]::Show('Notizregal ist bereits geöffnet.', 'Notizregal')
    exit
}
function Show-Error($Message) { [void][Windows.MessageBox]::Show([string]$Message, 'Notizregal', 'OK', 'Warning') }
if (Test-Path -LiteralPath $script:DbPath) {
    try {
        $loaded = Get-Content -LiteralPath $script:DbPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($loaded.version -ne 1 -or $null -eq $loaded.roots -or $null -eq $loaded.books) { throw 'Unbekanntes Katalogformat.' }
        $script:Db = $loaded
    } catch {
        Show-Error "Der Katalog konnte nicht gelesen werden. Er wird nicht überschrieben. Sicherung und Hinweise: $script:DataDir`n$($_.Exception.Message)"
        exit 1
    }
}
function Save-Db {
    $temp = $script:DbPath + '.tmp'
    $json = ConvertTo-Json -InputObject $script:Db -Depth 8
    [IO.File]::WriteAllText($temp, $json, (New-Object Text.UTF8Encoding($false)))
    if ([IO.File]::Exists($script:DbPath)) {
        [IO.File]::Replace($temp, $script:DbPath, ($script:DbPath + '.bak'))
    } else { [IO.File]::Move($temp, $script:DbPath) }
}
function Brush($Color) {
    try { return [Windows.Media.BrushConverter]::new().ConvertFromString($Color) }
    catch { return [Windows.Media.Brushes]::Teal }
}
function Open-Book($Path) {
    try {
        if (-not [IO.File]::Exists($Path)) { throw 'Datei nicht gefunden. Prüfe den Ordner oder die Synchronisation und aktualisiere die Übersicht.' }
        if([IO.Path]::GetExtension($Path) -ieq '.xopp'){$null=Save-NotebookVersion $Path 'Vor Öffnen'}
        if([IO.Path]::GetExtension($Path) -ieq '.pdf' -and (-not $script:Db.executable -or -not [IO.File]::Exists($script:Db.executable))){
            $picker=[Microsoft.Win32.OpenFileDialog]::new();$picker.Title='Zum Öffnen der PDF bitte xournalpp.exe auswählen';$picker.Filter='Xournal++ (xournalpp.exe)|xournalpp.exe'
            if(-not $picker.ShowDialog($script:Win)){return}
            $script:Db.executable=$picker.FileName;Save-Db
        }
        $start = New-Object Diagnostics.ProcessStartInfo
        $start.UseShellExecute = $true
        if ($script:Db.executable -and [IO.File]::Exists($script:Db.executable)) {
            $start.FileName = $script:Db.executable
            $start.Arguments = '"' + $Path + '"'
        } else { $start.FileName = $Path }
        [void][Diagnostics.Process]::Start($start)
    } catch { Show-Error ($_.Exception.Message + "`nFalls die Dateizuordnung fehlt: oben 'Xournal++ auswählen' verwenden.") }
}
function Choose-Folder {
    $dialog = New-Object Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Ordner mit Xournal++-Notizbüchern auswählen (inklusive Unterordner)'
    $dialog.ShowNewFolderButton = $true
    try { if ($dialog.ShowDialog() -eq 'OK') { return $dialog.SelectedPath } }
    finally { $dialog.Dispose() }
    return $null
}
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Notizregal · Xournal++" Width="1180" Height="790" MinWidth="760" MinHeight="540" Background="#F5F3EE" FontFamily="Segoe UI" FontSize="14" WindowStartupLocation="CenterScreen">
 <Window.Resources>
  <Style TargetType="Button"><Setter Property="Padding" Value="15,10"/><Setter Property="Margin" Value="0,0,8,8"/><Setter Property="MinHeight" Value="44"/><Setter Property="Background" Value="White"/><Setter Property="Foreground" Value="#183F3A"/><Setter Property="BorderBrush" Value="#D6DDD5"/><Setter Property="Cursor" Value="Hand"/></Style>
  <Style TargetType="TextBox"><Setter Property="Padding" Value="12,10"/><Setter Property="BorderBrush" Value="#D6DDD5"/><Setter Property="VerticalContentAlignment" Value="Center"/></Style>
  <Style TargetType="ComboBox"><Setter Property="Padding" Value="9"/><Setter Property="MinHeight" Value="44"/></Style>
 </Window.Resources>
 <Grid>
  <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
  <Border Background="#153E37" Padding="26,22">
   <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
    <StackPanel><TextBlock Text="NOTIZREGAL" Foreground="#BDE6C1" FontSize="12" FontWeight="Bold"/><TextBlock Text="Deine Gedanken. Ein Platz." Foreground="White" FontSize="29" Margin="0,5,0,0"/><TextBlock Text="Notizbücher für Xournal++" Foreground="#C0D1C8" Margin="0,6,0,0"/></StackPanel>
    <Button x:Name="NewBook" Grid.Column="1" Content="+ Neues Notizbuch" VerticalAlignment="Center" Background="#D4F0BA" BorderThickness="0" FontWeight="SemiBold"/>
   </Grid>
  </Border>
  <StackPanel Grid.Row="1" Margin="24,18,24,8">
   <WrapPanel><Button x:Name="AddFolder" Content="Ordner hinzufügen"/><Button x:Name="OpenPdf" Content="PDF öffnen …"/><Button x:Name="Refresh" Content="Aktualisieren"/><Button x:Name="ChooseExe" Content="Xournal++ auswählen"/><Button x:Name="Manage" Content="Ordner verwalten"/><Button x:Name="Stickers" Content="Bilder &amp; Sticker"/></WrapPanel>
   <Grid Margin="0,4,0,6"><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="180"/><ColumnDefinition Width="165"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
    <TextBox x:Name="Search" ToolTip="Titel, Kategorie, Schlagwörter und erfasste Notiztexte durchsuchen" Margin="0,0,10,0"/>
    <ComboBox x:Name="Category" Grid.Column="1" Margin="0,0,10,0"/>
    <ComboBox x:Name="Sort" Grid.Column="2" Margin="0,0,10,0"><ComboBoxItem Content="Zuletzt geändert"/><ComboBoxItem Content="Titel A–Z"/></ComboBox>
    <Button x:Name="Favorites" Grid.Column="3" Content="☆ Favoriten" Margin="0"/>
   </Grid>
   <TextBlock Text="Suche in Notiztexten und Audiotranskripten · Pro Notizbuch erkennen und exportieren" FontSize="12" Foreground="#61716B"/>
  </StackPanel>
  <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" PanningMode="VerticalOnly" Margin="18,0,18,0">
   <StackPanel><TextBlock x:Name="Empty" TextWrapping="Wrap" Margin="12,30" FontSize="20" Foreground="#54675F"/><WrapPanel x:Name="Shelf"/></StackPanel>
  </ScrollViewer>
  <Border Grid.Row="3" Background="#E8EAE3" Padding="24,10"><StackPanel><TextBlock x:Name="Status" Foreground="#465C51" TextWrapping="Wrap" FontSize="12"/><TextBlock x:Name="VersionStatus" Text="Automatische Versionierung · alle 60 Sekunden bei geöffnetem Regal" Foreground="#465C51" TextWrapping="Wrap" FontSize="12" Margin="0,4,0,0"/></StackPanel></Border>
 </Grid>
</Window>
'@
$script:Win = [Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $xaml))
foreach ($name in @('NewBook','AddFolder','OpenPdf','Refresh','ChooseExe','Manage','Stickers','Search','Category','Sort','Favorites','Empty','Shelf','Status','VersionStatus')) {
    Set-Variable -Name $name -Scope Script -Value $script:Win.FindName($name)
}
$script:Win.Dispatcher.add_UnhandledException({ param($sender,$eventArgs) Show-Error $eventArgs.Exception.Message; $eventArgs.Handled=$true })
function Get-Meta($Path) {
    $found = @($script:Db.books | Where-Object { $_.path -ieq $Path })
    if ($found.Count) { return $found[0] }
    return $null
}
function Read-Books {
    $script:Win.Cursor = [Windows.Input.Cursors]::Wait
    try {
        $seen = @{}
        $otherDocs = @{}
        $result = New-Object 'System.Collections.Generic.List[object]'
        $issues = New-Object 'System.Collections.Generic.List[string]'
        foreach ($root in @($script:Db.roots)) {
            if (-not [IO.Directory]::Exists($root)) { $issues.Add("Ordner nicht erreichbar: $root"); continue }
            # Junctions/Symlinks nicht verfolgen. OneDrive-Reparse-Points sind dagegen zulässig.
            $queue = New-Object 'System.Collections.Generic.Queue[string]'
            $queue.Enqueue($root)
            while ($queue.Count -gt 0) {
                $dir = $queue.Dequeue()
                try { $children = @(Get-ChildItem -LiteralPath $dir -Force -ErrorAction Stop) }
                catch { $issues.Add("Nicht lesbar: $dir"); continue }
                foreach ($file in $children) {
                    if ($file.LinkType -in @('Junction','SymbolicLink')) { continue }
                    if ($file.PSIsContainer) { $queue.Enqueue($file.FullName); continue }
                    if ($file.Extension -notin @('.xopp','.pdf')) {
                        if ($file.Extension -in @('.pdf','.doc','.docx','.odt','.rtf','.txt','.md')) {$otherDocs[$file.FullName]=$true}
                        continue
                    }
                    if ($seen.ContainsKey($file.FullName)) { continue }
                    $seen[$file.FullName] = $true
                    $meta = Get-Meta $file.FullName
                    $cat = $file.Directory.Name
                    $title = $file.BaseName
                    $color = '#24685B'; $tags = ''; $fav = $false
                    if ($meta) { $cat=$meta.category; $title=$meta.title; $color=$meta.color; $tags=$meta.tags; $fav=[bool]$meta.favorite }
                    $kind=$file.Extension.TrimStart('.').ToLowerInvariant()
                    $textIndex=if($kind -eq 'xopp'){Read-TextIndex $file.FullName}else{$null}
                    $audioIndex=$null
                    try{$audioIndex=Read-AudioIndex $file.FullName}catch{$issues.Add($_.Exception.Message)}
                    $fulltext=(Get-IndexText $textIndex)+"`n"+(Get-AudioSearchText $audioIndex)
                    $textStale=$textIndex -and ([string]$file.LastWriteTimeUtc.Ticks -ne $textIndex.sourceTicks -or $file.Length -ne $textIndex.sourceLength)
                    $result.Add([pscustomobject]@{kind=$kind;audioIndex=$audioIndex; fulltext=$fulltext; textIndex=$textIndex; textStale=$textStale; path=$file.FullName; title=$title; category=$cat; color=$color; tags=$tags; favorite=$fav; modified=$file.LastWriteTime})
                }
            }
        }
        $script:OtherDocumentCount = $otherDocs.Count
        $script:Books = @($result.ToArray())
        $script:ScanIssues = @($issues.ToArray())
        $old = $script:Category.SelectedItem
        $script:Refreshing = $true
        $script:Category.Items.Clear()
        [void]$script:Category.Items.Add('Alle Kategorien')
        foreach ($cat in @($script:Books | ForEach-Object {$_.category} | Sort-Object -Unique)) { [void]$script:Category.Items.Add($cat) }
        if ($old -and $script:Category.Items.Contains($old)) { $script:Category.SelectedItem=$old } else { $script:Category.SelectedIndex=0 }
        $script:Refreshing=$false
        Render-Shelf
    } finally { $script:Win.Cursor = $null }
}
function Render-Shelf {
    if ($script:Refreshing) { return }
    $script:Shelf.Children.Clear()
    $query = $script:Search.Text.Trim()
    $selected = [string]$script:Category.SelectedItem
    $items = @($script:Books | Where-Object {
        (-not $script:FavOnly -or $_.favorite) -and
        ($script:Category.SelectedIndex -le 0 -or $_.category -eq $selected) -and
        (-not $query -or (($_.title+' '+$_.category+' '+$_.tags+' '+[IO.Path]::GetFileName($_.path)+' '+$_.fulltext).IndexOf($query,[StringComparison]::OrdinalIgnoreCase) -ge 0))
    })
    if ($script:Sort.SelectedIndex -eq 1) { $items=@($items | Sort-Object title) } else { $items=@($items | Sort-Object modified -Descending) }
    $script:Empty.Visibility = if ($items.Count) {'Collapsed'} else {'Visible'}
    $script:Empty.Text = if (@($script:Db.roots).Count -eq 0) {"Dein Regal wartet auf die ersten Notizbücher.`nFüge einen Ordner hinzu oder lege ein neues Notizbuch an."} else { 'Keine passenden Xournal++-Notizbücher oder PDFs gefunden. Filter prüfen und für Offline-Nutzung den OneDrive-Ordner lokal verfügbar halten.' }
    foreach ($book in $items) {
        $card = New-Object Windows.Controls.StackPanel
        $card.Width=226; $card.Margin='8,8,8,18'
        $open = New-Object Windows.Controls.Button
        $open.Padding=0; $open.Margin=0; $open.BorderThickness=0
        $open.HorizontalContentAlignment='Stretch'; $open.Height=244
        $open.Tag=$book.path; $open.ToolTip=$book.path
        $open.Add_Click({param($s,$e) Open-Book $s.Tag})
        $cover = New-Object Windows.Controls.Border
        $cover.Background=Brush $book.color; $cover.CornerRadius=9; $cover.Padding='20,22,16,18'
        $cover.BorderThickness='7,0,0,0'; $cover.BorderBrush=Brush '#193B35'
        $layout=New-Object Windows.Controls.Grid
        foreach ($height in @('Auto','*','Auto')) { $row=New-Object Windows.Controls.RowDefinition; $row.Height=$height; [void]$layout.RowDefinitions.Add($row) }
        $label=New-Object Windows.Controls.TextBlock
        $label.Text=if($book.kind -eq 'pdf'){'PDF · MIT XOURNAL++ ÖFFNEN'}else{'XOURNAL++'}; $label.FontSize=10; $label.Foreground=Brush '#E3EEE7'; [void]$layout.Children.Add($label)
        $title=New-Object Windows.Controls.TextBlock
        $title.Text=$book.title; $title.TextWrapping='Wrap'; $title.FontSize=24; $title.FontWeight='SemiBold'; $title.Foreground=[Windows.Media.Brushes]::White; $title.Margin='0,20,0,8'; $title.MaxHeight=158; $title.TextTrimming='CharacterEllipsis'
        [Windows.Controls.Grid]::SetRow($title,1); [void]$layout.Children.Add($title)
        $category=New-Object Windows.Controls.TextBlock
        $category.Text=$book.category; $category.Foreground=Brush '#E3EEE7'; $category.TextTrimming='CharacterEllipsis'
        [Windows.Controls.Grid]::SetRow($category,2); [void]$layout.Children.Add($category)
        $cover.Child=$layout; $open.Content=$cover; [void]$card.Children.Add($open)
        $date=New-Object Windows.Controls.TextBlock
        $date.Text='Geändert '+$book.modified.ToString('dd.MM.yyyy · HH:mm'); $date.FontSize=11; $date.Foreground=Brush '#61716B'; $date.Margin='2,9,0,9'; [void]$card.Children.Add($date)
        $actions=New-Object Windows.Controls.StackPanel; $actions.Orientation='Horizontal'
        $fav=New-Object Windows.Controls.Button; $fav.Content=if($book.favorite){'★'}else{'☆'}; $fav.Width=48; $fav.Tag=$book; $fav.ToolTip='Favorit umschalten'
        $fav.Add_Click({param($s,$e) $b=$s.Tag; $b.favorite=-not $b.favorite; Store-Meta $b; Read-Books})
        $edit=New-Object Windows.Controls.Button; $edit.Content='Bearbeiten'; $edit.Tag=$book; $edit.Add_Click({param($s,$e) Edit-Book $s.Tag})
        [void]$actions.Children.Add($fav); [void]$actions.Children.Add($edit); [void]$card.Children.Add($actions)
        if($book.kind -eq 'xopp'){
        $versions=[Windows.Controls.Button]::new();$versions.Content='Versionen';$versions.Tag=$book;$versions.Margin='0,0,0,3';$versions.Add_Click({param($s,$e)Show-BookVersions $s.Tag});[void]$card.Children.Add($versions)
        $textButton=New-Object Windows.Controls.Button; $textButton.Content='Text erkennen / exportieren'; $textButton.Tag=$book; $textButton.Margin='0,0,0,3'
        $textButton.Add_Click({param($s,$e) Show-BookText $s.Tag}); [void]$card.Children.Add($textButton)
        if($book.textIndex){
            $textHint=New-Object Windows.Controls.TextBlock; $textHint.FontSize=11; $textHint.TextWrapping='Wrap'; $textHint.Foreground=Brush '#61716B'
            $textHint.Text=if($book.textStale){'Textstand veraltet – bitte aktualisieren'}elseif(-not $book.textIndex.complete){'Text teilweise erfasst – Hinweise prüfen'}else{'Text erfasst · '+$book.textIndex.pages.Count+' Seiten'}
            if($query){
                $matches=@($book.textIndex.pages | Where-Object {([string]$_.text).IndexOf($query,[StringComparison]::OrdinalIgnoreCase) -ge 0})
                if($matches.Count){$hit=$matches[0];$position=([string]$hit.text).IndexOf($query,[StringComparison]::OrdinalIgnoreCase);$begin=[Math]::Max(0,$position-25);$snippet=([string]$hit.text).Substring($begin,[Math]::Min(110,$hit.text.Length-$begin));$textHint.Text+="`nSeite "+$hit.number+': … '+($snippet -replace '\s+',' ')+' …'}
            }
            [void]$card.Children.Add($textHint)
        }
        }else{$hint=[Windows.Controls.TextBlock]::new();$hint.Text='Anmerkungen in Xournal++ als .xopp speichern. Danach im Regal aktualisieren.';$hint.TextWrapping='Wrap';$hint.FontSize=12;$hint.Margin='0,5,0,6';[void]$card.Children.Add($hint)}
        $audioButton=[Windows.Controls.Button]::new();$audioButton.Content='Audio → Text';$audioButton.Tag=$book;$audioButton.Margin='0,4,0,3'
        $audioButton.Add_Click({param($s,$e)Show-BookAudio $s.Tag});[void]$card.Children.Add($audioButton)
        if($book.audioIndex -and $book.audioIndex.recordings.Count){
            $audioHint=[Windows.Controls.TextBlock]::new();$audioHint.FontSize=11;$audioHint.TextWrapping='Wrap';$audioHint.Foreground=Brush '#61716B';$audioHint.Text=$book.audioIndex.recordings.Count.ToString()+' Audiotranskript(e)'
            if($query){$hits=@($book.audioIndex.recordings | Where-Object {($_.name+' '+$_.text).IndexOf($query,[StringComparison]::OrdinalIgnoreCase) -ge 0});if($hits.Count){$hit=$hits[0];$position=([string]$hit.text).IndexOf($query,[StringComparison]::OrdinalIgnoreCase);$start=[Math]::Max(0,$position-25);$snippet=([string]$hit.text).Substring($start,[Math]::Min(110,$hit.text.Length-$start));$audioHint.Text+="`nAudio: "+$hit.name+' · '+($snippet -replace '\s+',' ')}}
            [void]$card.Children.Add($audioHint)
        }
        [void]$script:Shelf.Children.Add($card)
    }
    $script:Status.Text = "$($items.Count) angezeigt · $($script:Books.Count) Notizbücher / PDFs · $(@($script:Db.roots).Count) Ordner · Lokal gespeichert"
    if ($script:OtherDocumentCount -gt 0) { $script:Status.Text += ' · '+$script:OtherDocumentCount+' weitere Dokumente (Word/Text), nicht angezeigt' }
    if ($script:ScanIssues.Count) { $script:Status.Text += ' · Hinweis: '+($script:ScanIssues -join '; ') }
}
function Store-Meta($Book) {
    $rest=@($script:Db.books | Where-Object {$_.path -ine $Book.path})
    $script:Db.books=@($rest)+@([pscustomobject]@{path=$Book.path; title=$Book.title; category=$Book.category; color=$Book.color; tags=$Book.tags; favorite=$Book.favorite})
    Save-Db
}
function Edit-Book($Book) {
    [xml]$dialogXaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Notizbuch gestalten" Width="500" SizeToContent="Height" ResizeMode="NoResize" WindowStartupLocation="CenterOwner" Background="#F5F3EE" FontFamily="Segoe UI" FontSize="14">
 <StackPanel Margin="24">
  <TextBlock Text="Notizbuch gestalten" FontSize="24" FontWeight="SemiBold" Margin="0,0,0,15"/>
  <TextBlock Text="Anzeigename"/><TextBox x:Name="Title" Padding="9" Margin="0,5,0,12"/>
  <TextBlock Text="Kategorie (frei wählbar)"/><TextBox x:Name="Cat" Padding="9" Margin="0,5,0,12"/>
  <TextBlock Text="Schlagwörter für die Suche"/><TextBox x:Name="Tags" Padding="9" Margin="0,5,0,12"/>
  <TextBlock Text="Coverfarbe"/><ComboBox x:Name="Color" Padding="9" Margin="0,5,0,12"/>
  <TextBlock Text="Der Anzeigename ändert den Dateinamen nicht." Foreground="#61716B" Margin="0,0,0,15"/>
  <WrapPanel><Button x:Name="Save" Content="Speichern" Padding="16,10" IsDefault="True" Margin="0,0,8,0"/><Button x:Name="Folder" Content="Datei im Explorer" Padding="16,10" Margin="0,0,8,0"/><Button Content="Abbrechen" Padding="16,10" IsCancel="True"/></WrapPanel>
 </StackPanel>
</Window>
'@
    $dlg=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $dialogXaml)); $dlg.Owner=$script:Win
    $t=$dlg.FindName('Title'); $c=$dlg.FindName('Cat'); $tags=$dlg.FindName('Tags'); $colors=$dlg.FindName('Color')
    $t.Text=$Book.title; $c.Text=$Book.category; $tags.Text=$Book.tags
    $palette=[ordered]@{'Waldgrün'='#24685B';'Ozean'='#285D83';'Bordeaux'='#813F55';'Terrakotta'='#97513B';'Violett'='#675080';'Graphit'='#414E5A';'Ocker'='#80651D'}
    foreach($entry in $palette.GetEnumerator()) { $item=New-Object Windows.Controls.ComboBoxItem; $item.Content=$entry.Key; $item.Tag=$entry.Value; [void]$colors.Items.Add($item); if($entry.Value -eq $Book.color){$colors.SelectedItem=$item} }
    if($colors.SelectedIndex -lt 0){$colors.SelectedIndex=0}
    $dlg.FindName('Save').Add_Click({
        if(-not $t.Text.Trim() -or -not $c.Text.Trim()){Show-Error 'Bitte Titel und Kategorie eingeben.'; return}
        $Book.title=$t.Text.Trim(); $Book.category=$c.Text.Trim(); $Book.tags=$tags.Text.Trim(); $Book.color=$colors.SelectedItem.Tag
        Store-Meta $Book; $dlg.DialogResult=$true
    })
    $dlg.FindName('Folder').Add_Click({
        $start=New-Object Diagnostics.ProcessStartInfo
        $start.FileName='explorer.exe'; $start.Arguments='/select,"'+$Book.path+'"'; $start.UseShellExecute=$true
        [void][Diagnostics.Process]::Start($start)
    })
    [void]$dlg.ShowDialog(); Read-Books
}
function Show-BookText($Book) {
    [xml]$textXaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Notiztext · offline" Width="870" Height="720" MinWidth="700" MinHeight="520" WindowStartupLocation="CenterOwner" FontFamily="Segoe UI" FontSize="14" Background="#F5F3EE">
 <Grid Margin="22"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
  <StackPanel><TextBlock x:Name="BookTitle" FontSize="25" FontWeight="SemiBold"/><TextBlock Text="Texte lokal erkennen, korrigieren und durchsuchen" Margin="0,6,0,12"/></StackPanel>
  <WrapPanel Grid.Row="1"><CheckBox x:Name="Ink" Content="Handschrift erkennen (Windows, experimentell)" IsChecked="True" VerticalAlignment="Center" Margin="0,0,14,8"/><Button x:Name="Recognize" Content="Text erfassen / aktualisieren" Padding="12,10" Margin="0,0,10,8"/><Button x:Name="CancelJob" Content="Abbrechen" Padding="12,10" IsEnabled="False" Margin="0,0,0,8"/></WrapPanel>
  <StackPanel Grid.Row="2"><TextBlock x:Name="TextStatus" TextWrapping="Wrap" Foreground="#566960" Margin="0,0,0,8"/><ComboBox x:Name="Pages" Padding="8" Margin="0,0,0,10"/></StackPanel>
  <TextBox x:Name="ContentText" Grid.Row="3" AcceptsReturn="True" AcceptsTab="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" FontSize="16" Padding="14"/>
  <WrapPanel Grid.Row="4" Margin="0,14,0,0"><Button x:Name="SaveText" Content="Korrekturen speichern" Padding="14,10" Margin="0,0,10,0"/><Button x:Name="ExportMd" Content="MD / TXT exportieren" Padding="14,10" Margin="0,0,10,0"/><Button x:Name="OpenOriginal" Content="Original öffnen" Padding="14,10"/></WrapPanel>
 </Grid>
</Window>
'@
    $dlg=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($textXaml)); $dlg.Owner=$script:Win
    $title=$dlg.FindName('BookTitle');$title.Text=$Book.title
    $editor=$dlg.FindName('ContentText');$pages=$dlg.FindName('Pages');$status=$dlg.FindName('TextStatus')
    $recognize=$dlg.FindName('Recognize');$cancel=$dlg.FindName('CancelJob');$ink=$dlg.FindName('Ink')
    $save=$dlg.FindName('SaveText');$export=$dlg.FindName('ExportMd')
    $state=@{index=(Read-TextIndex $Book.path);page=-1;loading=$false;dirty=$false;process=$null;request='';jobs=[Collections.Generic.List[string]]::new();cancelled=$false}
    $capture={if($state.index -and $state.page -ge 0){$old=$state.index.pages[$state.page]; if($old.text -ne $editor.Text){$old.text=$editor.Text;$old.corrected=$true;$state.dirty=$true}}}
    $fill={
        $state.loading=$true;$pages.Items.Clear();$state.page=-1;$editor.Text=''
        if($state.index){
            foreach($p in @($state.index.pages)){[void]$pages.Items.Add('Seite '+$p.number)}
            if($pages.Items.Count){$pages.SelectedIndex=0;$state.page=0;$editor.Text=$state.index.pages[0].text}
            $notes=@($state.index.warnings)
            $current=Get-Item -LiteralPath $Book.path -ErrorAction SilentlyContinue
            if($current -and ([string]$current.LastWriteTimeUtc.Ticks -ne $state.index.sourceTicks -or $current.Length -ne $state.index.sourceLength)){$notes=@('Original wurde geändert. Der Textstand ist möglicherweise veraltet.')+$notes}
            $status.Text='Erfasst: '+$state.index.created+' · '+$state.index.pages.Count+' Seiten'
            if($notes.Count){$status.Text+="`n"+($notes -join ' ')}
        }else{$status.Text='Noch kein Text erfasst. Für Stiftstriche ist das deutsche Windows-Handschriftpaket erforderlich. PDF- und Bildinhalte werden nicht erfasst.'}
        $save.IsEnabled=[bool]$state.index;$export.IsEnabled=[bool]$state.index;$editor.IsEnabled=[bool]$state.index
        $state.loading=$false
    }
    $pages.Add_SelectionChanged({if(-not $state.loading){& $capture;$state.page=$pages.SelectedIndex;if($state.page -ge 0){$editor.Text=$state.index.pages[$state.page].text}}})
    $save.Add_Click({& $capture;Write-AtomicJson (Get-TextIndexPath $Book.path) $state.index;$state.dirty=$false;$status.Text='Korrekturen lokal gespeichert. Sie werden von der Suche berücksichtigt.'})
    $export.Add_Click({
        & $capture
        $picker=[Microsoft.Win32.SaveFileDialog]::new();$picker.Title='Notiztext exportieren';$picker.Filter='Markdown (*.md)|*.md|Text (*.txt)|*.txt';$picker.DefaultExt='.md'
        $picker.FileName=[IO.Path]::GetFileNameWithoutExtension($Book.path)+'.md'
        if($picker.ShowDialog($dlg)){
            $markdown=[IO.Path]::GetExtension($picker.FileName) -ine '.txt'
            [IO.File]::WriteAllText($picker.FileName,(Export-IndexString $state.index $Book.title $markdown),[Text.UTF8Encoding]::new($true))
            Write-AtomicJson (Get-TextIndexPath $Book.path) $state.index;$state.dirty=$false;$status.Text='Export gespeichert: '+$picker.FileName
        }
    })
    $dlg.FindName('OpenOriginal').Add_Click({Open-Book $Book.path})
    $timer=[Windows.Threading.DispatcherTimer]::new();$timer.Interval=[TimeSpan]::FromMilliseconds(350)
    $timer.Add_Tick({
        if($state.process -and $state.process.HasExited){
            $timer.Stop();$recognize.IsEnabled=$true;$cancel.IsEnabled=$false;$pages.IsEnabled=$true;$ink.IsEnabled=$true
            try{
                if($state.cancelled){throw 'Erkennung abgebrochen. Der bisherige Text bleibt erhalten.'}
                if([IO.File]::Exists($state.request+'.error')){throw [IO.File]::ReadAllText($state.request+'.error')}
                if(-not [IO.File]::Exists($state.request+'.result')){throw 'Textdienst wurde beendet, ohne ein Ergebnis zu liefern.'}
                $new=[IO.File]::ReadAllText($state.request+'.result') | ConvertFrom-Json
                Write-AtomicJson (Get-TextIndexPath $Book.path) $new
                $state.index=$new;$state.dirty=$false;& $fill
            }catch{$status.Text=$_.Exception.Message;$save.IsEnabled=[bool]$state.index;$export.IsEnabled=[bool]$state.index;$editor.IsEnabled=[bool]$state.index}
            finally{$state.process.Dispose();$state.process=$null}
        }
    })
    $recognize.Add_Click({
        & $capture
        if($state.index){
            $reply=[Windows.MessageBox]::Show('Erneute Erkennung ersetzt den gespeicherten Text einschließlich eigener Korrekturen. Fortfahren?','Text neu erfassen','YesNo','Question')
            if($reply -ne 'Yes'){return}
        }
        $jobDir=Join-Path $script:DataDir 'auftraege';[void][IO.Directory]::CreateDirectory($jobDir)
        $state.request=Join-Path $jobDir ([Guid]::NewGuid().ToString('N')+'.json')
        $state.jobs.Add($state.request);$state.cancelled=$false
        Write-AtomicJson $state.request ([pscustomobject]@{path=$Book.path;handwriting=[bool]$ink.IsChecked})
        $start=[Diagnostics.ProcessStartInfo]::new();$start.FileName=Join-Path $PSHOME 'powershell.exe'
        $start.Arguments='-NoLogo -NoProfile -STA -ExecutionPolicy RemoteSigned -File "'+(Join-Path $PSScriptRoot 'TextTools.ps1')+'" -RequestPath "'+$state.request+'"'
        $start.UseShellExecute=$false;$start.CreateNoWindow=$true
        $state.process=[Diagnostics.Process]::Start($start)
        $recognize.IsEnabled=$false;$cancel.IsEnabled=$true;$editor.IsEnabled=$false;$pages.IsEnabled=$false;$save.IsEnabled=$false;$export.IsEnabled=$false;$ink.IsEnabled=$false
        $status.Text='Verarbeite lokal auf diesem Surface … Das Fenster bleibt bedienbar. Bei großen Notizbüchern kann die Erkennung dauern.'
        $timer.Start()
    })
    $cancel.Add_Click({if($state.process -and -not $state.process.HasExited){$state.cancelled=$true;$state.process.Kill();$status.Text='Erkennung abgebrochen. Bisheriger Text bleibt erhalten.'}})
    $dlg.Add_Closing({param($s,$e)
        & $capture
        if($state.dirty){$reply=[Windows.MessageBox]::Show('Textkorrekturen vor dem Schließen speichern?','Notiztext','YesNoCancel','Question');if($reply -eq 'Cancel'){$e.Cancel=$true;return};if($reply -eq 'Yes'){Write-AtomicJson (Get-TextIndexPath $Book.path) $state.index;$state.dirty=$false}}
        $timer.Stop();if($state.process -and -not $state.process.HasExited){$state.process.Kill()}
    })
    & $fill
    try{[void]$dlg.ShowDialog()}finally{
        $timer.Stop();if($state.process){$state.process.Dispose()}
        # Nur selbst erzeugte temporäre Aufträge entfernen; kein Zugriff auf Originalnotizen.
        foreach($jobPath in $state.jobs){foreach($suffix in @('','.result','.error','.bak')){$temp=$jobPath+$suffix;if([IO.File]::Exists($temp)){try{[IO.File]::Delete($temp)}catch{}}}}
    }
    Read-Books
}

$script:AddFolder.Add_Click({
    $folder=Choose-Folder
    if($folder -and @($script:Db.roots) -notcontains $folder){$script:Db.roots=@($script:Db.roots)+@($folder); Save-Db; Read-Books}
})
$script:ChooseExe.Add_Click({
    $picker=New-Object Microsoft.Win32.OpenFileDialog
    $picker.Title='xournalpp.exe auswählen'; $picker.Filter='Xournal++ (xournalpp.exe)|xournalpp.exe'
    if($picker.ShowDialog($script:Win)){$script:Db.executable=$picker.FileName; Save-Db; $script:Status.Text='Xournal++ verknüpft: '+$picker.FileName}
})
$script:Manage.Add_Click({
    $dlg=New-Object Windows.Window; $dlg.Title='Ordner verwalten'; $dlg.Width=600; $dlg.Height=370; $dlg.Owner=$script:Win; $dlg.WindowStartupLocation='CenterOwner'
    $panel=New-Object Windows.Controls.StackPanel; $panel.Margin=20
    $hint=New-Object Windows.Controls.TextBlock; $hint.Text='Entfernen blendet einen Suchordner aus. Dateien bleiben erhalten.'; $hint.TextWrapping='Wrap'; $hint.Margin='0,0,0,12'; [void]$panel.Children.Add($hint)
    $list=New-Object Windows.Controls.ListBox; $list.Height=190
    foreach($root in @($script:Db.roots)){[void]$list.Items.Add($root)}
    [void]$panel.Children.Add($list)
    $remove=New-Object Windows.Controls.Button; $remove.Content='Ausgewählten Ordner aus Übersicht entfernen'; $remove.Padding=10; $remove.Margin='0,15,0,0'
    $remove.Add_Click({if($list.SelectedItem){$selected=[string]$list.SelectedItem; $script:Db.roots=@($script:Db.roots | Where-Object {$_ -ine $selected}); Save-Db; $list.Items.Remove($selected)}})
    [void]$panel.Children.Add($remove); $dlg.Content=$panel; [void]$dlg.ShowDialog(); Read-Books
})
$script:NewBook.Add_Click({
    $picker=New-Object Microsoft.Win32.SaveFileDialog
    $picker.Title='Neues Notizbuch speichern · A4, kariert'; $picker.Filter='Xournal++-Notizbuch (*.xopp)|*.xopp'; $picker.DefaultExt='.xopp'; $picker.FileName='Neues Notizbuch.xopp'
    if(@($script:Db.roots).Count -and [IO.Directory]::Exists($script:Db.roots[0])){$picker.InitialDirectory=$script:Db.roots[0]}
    if(-not $picker.ShowDialog($script:Win)){return}
    # CreateNew verhindert auch nach dem Dialog ein Überschreiben vorhandener Notizen.
    if([IO.File]::Exists($picker.FileName)){Show-Error 'Bitte einen neuen Dateinamen wählen. Vorhandene Notizbücher werden nicht überschrieben.'; return}
    $xml='<?xml version="1.0" encoding="UTF-8" standalone="no"?><xournal creator="Notizregal 1.3" fileversion="4"><title>Xournal++ document</title>'
    for($i=0;$i -lt 3;$i++){$xml+='<page width="595.28" height="841.89"><background type="solid" color="#ffffffff" style="graph"/><layer/></page>'}
    $xml+='</xournal>'
    $stream=$null; $gzip=$null
    try {
        $stream=[IO.File]::Open($picker.FileName,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write)
        $gzip=New-Object IO.Compression.GZipStream($stream,[IO.Compression.CompressionMode]::Compress)
        $bytes=[Text.Encoding]::UTF8.GetBytes($xml); $gzip.Write($bytes,0,$bytes.Length)
    } finally {if($gzip){$gzip.Dispose()}; if($stream){$stream.Dispose()}}
    $dir=[IO.Path]::GetDirectoryName($picker.FileName)
    $covered=$false
    foreach($root in @($script:Db.roots)){if($dir -ieq $root -or $dir.StartsWith($root.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){$covered=$true}}
    if(-not $covered){$script:Db.roots=@($script:Db.roots)+@($dir); Save-Db}
    Read-Books; Open-Book $picker.FileName
})
$script:Refresh.Add_Click({Read-Books;$script:NextVersionSweep=Get-Date;Start-VersionSweep})
$script:OpenPdf.Add_Click({$picker=[Microsoft.Win32.OpenFileDialog]::new();$picker.Title='PDF mit Xournal++ öffnen';$picker.Filter='PDF (*.pdf)|*.pdf';if($picker.ShowDialog($script:Win)){Open-Book $picker.FileName}})
$script:Search.Add_TextChanged({Render-Shelf})
$script:Category.Add_SelectionChanged({Render-Shelf})
$script:Sort.Add_SelectionChanged({Render-Shelf})
$script:Favorites.Add_Click({$script:FavOnly=-not $script:FavOnly; $script:Favorites.Content=if($script:FavOnly){'★ Nur Favoriten'}else{'☆ Favoriten'}; Render-Shelf})
function Show-BookAudio($Book){
 [xml]$audioXaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Audio → Text · offline" Width="900" Height="760" MinWidth="730" MinHeight="550" WindowStartupLocation="CenterOwner" FontFamily="Segoe UI" FontSize="14" Background="#F5F3EE">
 <Grid Margin="22"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
  <StackPanel><TextBlock x:Name="AudioTitle" FontSize="25" FontWeight="SemiBold"/><TextBlock Text="Aufnahme auswählen und auf diesem Surface in Text umwandeln" Margin="0,6,0,14"/></StackPanel>
  <StackPanel Grid.Row="1"><WrapPanel><Button x:Name="ChooseAudio" Content="Aufnahme auswählen …" Padding="12,10" Margin="0,0,10,8"/><ComboBox x:Name="Language" Width="145" Padding="8" Margin="0,0,10,8"><ComboBoxItem Content="Deutsch"/><ComboBoxItem Content="Englisch"/><ComboBoxItem Content="Automatisch"/></ComboBox><Button x:Name="Transcribe" Content="Transkribieren" Padding="12,10" IsEnabled="False" Margin="0,0,10,8"/><Button x:Name="CancelAudio" Content="Abbrechen" Padding="12,10" IsEnabled="False" Margin="0,0,0,8"/></WrapPanel><TextBlock x:Name="AudioFile" Text="OGG-Vorbis oder WAV · Aufnahme zuerst in Xournal++ stoppen" TextWrapping="Wrap" Foreground="#51695A"/></StackPanel>
  <StackPanel Grid.Row="2" Margin="0,12,0,10"><TextBlock x:Name="AudioStatus" Text="Keine Cloud. Das mitgelieferte Modell arbeitet auf der CPU." TextWrapping="Wrap" Margin="0,0,0,7"/><ProgressBar x:Name="AudioProgress" Height="5" Visibility="Collapsed"/><ComboBox x:Name="Recordings" Padding="8" Margin="0,10,0,0"/></StackPanel>
  <TextBox x:Name="Transcript" Grid.Row="3" AcceptsReturn="True" AcceptsTab="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" FontSize="16" Padding="14" IsEnabled="False"/>
  <WrapPanel Grid.Row="4" Margin="0,14,0,0"><Button x:Name="SaveAudioText" Content="Korrekturen speichern" Padding="12,10" Margin="0,0,9,0" IsEnabled="False"/><Button x:Name="CopyAudioText" Content="Text kopieren" Padding="12,10" Margin="0,0,9,0" IsEnabled="False"/><Button x:Name="ExportAudioText" Content="Alle als MD / TXT" Padding="12,10" Margin="0,0,9,0" IsEnabled="False"/><Button x:Name="AudioLog" Content="Protokoll" Padding="12,10" IsEnabled="False"/></WrapPanel>
 </Grid>
</Window>
'@
 $dialog=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($audioXaml));$dialog.Owner=$script:Win;$dialog.FindName('AudioTitle').Text=$Book.title
 $choose=$dialog.FindName('ChooseAudio');$language=$dialog.FindName('Language');$language.SelectedIndex=0
 $transcribe=$dialog.FindName('Transcribe');$cancel=$dialog.FindName('CancelAudio');$fileLabel=$dialog.FindName('AudioFile');$status=$dialog.FindName('AudioStatus');$progress=$dialog.FindName('AudioProgress')
 $list=$dialog.FindName('Recordings');$editor=$dialog.FindName('Transcript');$save=$dialog.FindName('SaveAudioText');$copy=$dialog.FindName('CopyAudioText');$export=$dialog.FindName('ExportAudioText');$log=$dialog.FindName('AudioLog')
 $state=@{index=(Read-AudioIndex $Book.path);selected=-1;loading=$false;dirty=$false;source='';process=$null;job='';request='';cancelled=$false;started=$null}
 $capture={if($state.selected -ge 0 -and $state.index.recordings.Count){$item=$state.index.recordings[$state.selected];if($item.text -ne $editor.Text){$item.text=$editor.Text;$item.corrected=$true;$state.dirty=$true}}}
 $fill={
  $state.loading=$true;$list.Items.Clear();$editor.Text='';$state.selected=-1
  foreach($r in @($state.index.recordings)){[void]$list.Items.Add($r.name+' · '+$r.created.Substring(0,16).Replace('T',' '))}
  if($list.Items.Count){$list.SelectedIndex=$list.Items.Count-1;$state.selected=$list.SelectedIndex;$editor.Text=$state.index.recordings[$state.selected].text}
  $has=$list.Items.Count -gt 0;$editor.IsEnabled=$has;$save.IsEnabled=$has;$copy.IsEnabled=$has;$export.IsEnabled=$has
  $state.loading=$false
 }
 $list.Add_SelectionChanged({if(-not $state.loading){& $capture;$state.selected=$list.SelectedIndex;if($state.selected -ge 0){$editor.Text=$state.index.recordings[$state.selected].text}}})
 $save.Add_Click({& $capture;Write-AtomicJson (Get-AudioIndexPath $Book.path) $state.index;$state.dirty=$false;$status.Text='Transkript gespeichert. Die Regalsuche berücksichtigt den Text.'})
 $copy.Add_Click({[Windows.Clipboard]::SetText($editor.Text);$status.Text='Text kopiert. In Xournal++ das Textwerkzeug wählen und einfügen.'})
 $export.Add_Click({
  & $capture;$picker=[Microsoft.Win32.SaveFileDialog]::new();$picker.Title='Audiotranskripte exportieren';$picker.Filter='Markdown (*.md)|*.md|Text (*.txt)|*.txt';$picker.DefaultExt='.md';$picker.FileName=[IO.Path]::GetFileNameWithoutExtension($Book.path)+'-Audio.md'
  if($picker.ShowDialog($dialog)){[IO.File]::WriteAllText($picker.FileName,(Get-AudioExport $state.index $Book.title ([IO.Path]::GetExtension($picker.FileName) -ine '.txt')),[Text.UTF8Encoding]::new($true));Write-AtomicJson (Get-AudioIndexPath $Book.path) $state.index;$state.dirty=$false;$status.Text='Export gespeichert: '+$picker.FileName}
 })
 $choose.Add_Click({
  $picker=[Microsoft.Win32.OpenFileDialog]::new();$picker.Title='Gespeicherte Xournal++-Aufnahme auswählen';$picker.Filter='Audioaufnahmen (*.ogg;*.wav)|*.ogg;*.wav'
  if($picker.ShowDialog($dialog)){$state.source=$picker.FileName;$fileLabel.Text=$state.source;$transcribe.IsEnabled=$true}
 })
 $restoreControls={
  $transcribe.IsEnabled=[bool]$state.source;$choose.IsEnabled=$true;$language.IsEnabled=$true;$cancel.IsEnabled=$false;$list.IsEnabled=$true;$progress.Visibility='Collapsed'
  $has=$state.index.recordings.Count -gt 0;$editor.IsEnabled=$has;$save.IsEnabled=$has;$copy.IsEnabled=$has;$export.IsEnabled=$has
 }
 $stopProcess={
  if($state.process -and -not $state.process.HasExited){
   $state.cancelled=$true
   # Kill only this worker and its decoder/whisper child processes, not other jobs.
   $kill=[Diagnostics.ProcessStartInfo]::new();$kill.FileName=Join-Path $env:SystemRoot 'System32\taskkill.exe';$kill.Arguments='/PID '+$state.process.Id+' /T /F';$kill.UseShellExecute=$false;$kill.CreateNoWindow=$true
   $kp=[Diagnostics.Process]::Start($kill);try{[void]$kp.WaitForExit(5000)}finally{$kp.Dispose()}
  }
 }
 $timer=[Windows.Threading.DispatcherTimer]::new();$timer.Interval=[TimeSpan]::FromMilliseconds(700)
 $timer.Add_Tick({
  if(-not $state.process){return}
  if(-not $state.process.HasExited){
   $elapsed=[int]((Get-Date)-$state.started).TotalSeconds
   try{$message=[IO.File]::ReadAllText((Join-Path $state.job 'status.txt'));$status.Text=$message+' · '+$elapsed+' s'}catch{}
   $err=Join-Path $state.job 'whisper.err'
   if([IO.File]::Exists($err)){try{$tail=[IO.File]::ReadAllText($err);$matches=[regex]::Matches($tail,'progress\s*=\s*(\d+)%');if($matches.Count){$progress.IsIndeterminate=$false;$progress.Value=[double]$matches[$matches.Count-1].Groups[1].Value}}catch{}}
   return
  }
  $timer.Stop();& $restoreControls
  try{
   if($state.cancelled){throw 'Transkription abgebrochen. Bereits gespeicherte Texte bleiben erhalten.'}
   if([IO.File]::Exists($state.request+'.error')){throw [IO.File]::ReadAllText($state.request+'.error')}
   if(-not [IO.File]::Exists($state.request+'.result')){throw 'Kein Ergebnis erhalten. Bitte Protokoll öffnen.'}
   $record=[IO.File]::ReadAllText($state.request+'.result') | ConvertFrom-Json
   $rest=@($state.index.recordings | Where-Object {$_.source -ine $record.source})
   $state.index.recordings=@($rest)+@($record)
   Write-AtomicJson (Get-AudioIndexPath $Book.path) $state.index;$state.dirty=$false;& $fill
   $status.Text=if($record.text){'Transkript gespeichert und durchsuchbar. Bitte Namen, Zahlen und Zeitmarken kontrollieren.'}else{'Keine Sprache erkannt. Prüfe, ob die Aufnahme hörbar ist.'}
  }catch{$status.Text=$_.Exception.Message}
  finally{
   $state.process.Dispose();$state.process=$null
   # Remove only the temporary decoded audio; logs and request remain for diagnostics.
   $wav=Join-Path $state.job 'aufnahme.wav';if([IO.File]::Exists($wav)){try{[IO.File]::Delete($wav)}catch{}}
  }
 })
 $transcribe.Add_Click({
  & $capture
  if(-not [IO.File]::Exists($state.source)){Alert-Audio 'Die Aufnahme ist nicht lokal verfügbar.';return}
  if(@($state.index.recordings | Where-Object {$_.source -ieq $state.source}).Count){if([Windows.MessageBox]::Show('Das vorhandene Transkript dieser Aufnahme einschließlich Korrekturen ersetzen?','Audio erneut erkennen','YesNo','Question') -ne 'Yes'){return}}
  if($state.dirty){Write-AtomicJson (Get-AudioIndexPath $Book.path) $state.index;$state.dirty=$false}
  $state.job=Join-Path $script:DataDir ('audio-auftraege\'+[Guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($state.job)
  $state.request=Join-Path $state.job 'auftrag.json';$state.cancelled=$false
  $lang=@('de','en','auto')[$language.SelectedIndex]
  Write-AtomicJson $state.request ([pscustomobject]@{audio=$state.source;language=$lang})
  $start=[Diagnostics.ProcessStartInfo]::new();$start.FileName=Join-Path $PSHOME 'powershell.exe';$start.Arguments='-NoLogo -NoProfile -STA -ExecutionPolicy RemoteSigned -File "'+(Join-Path $PSScriptRoot 'AudioTools.ps1')+'" -AudioRequestPath "'+$state.request+'"';$start.UseShellExecute=$false;$start.CreateNoWindow=$true
  $state.process=[Diagnostics.Process]::Start($start);$state.started=Get-Date
  $transcribe.IsEnabled=$false;$choose.IsEnabled=$false;$language.IsEnabled=$false;$cancel.IsEnabled=$true;$list.IsEnabled=$false;$editor.IsEnabled=$false;$save.IsEnabled=$false;$copy.IsEnabled=$false;$export.IsEnabled=$false;$log.IsEnabled=$true
  $progress.Visibility='Visible';$progress.IsIndeterminate=$true;$status.Text='Lokale Audioverarbeitung startet ...';$timer.Start()
 })
 $cancel.Add_Click({& $stopProcess})
 $log.Add_Click({
  $parts=[Collections.Generic.List[string]]::new()
  foreach($name in @('auftrag.json.error','convert.err','whisper.err','whisper.out')){$path=Join-Path $state.job $name;if([IO.File]::Exists($path)){$parts.Add($name+"`r`n"+[IO.File]::ReadAllText($path))}}
  $path=Join-Path $state.job 'protokoll.txt';[IO.File]::WriteAllText($path,($parts -join "`r`n`r`n"),[Text.UTF8Encoding]::new($true));$si=[Diagnostics.ProcessStartInfo]::new();$si.FileName=$path;$si.UseShellExecute=$true;[void][Diagnostics.Process]::Start($si)
 })
 $dialog.Add_Closing({param($s,$e)
  if($state.process -and -not $state.process.HasExited){if([Windows.MessageBox]::Show('Laufende Transkription abbrechen und schließen?','Audio → Text','YesNo','Question') -ne 'Yes'){$e.Cancel=$true;return};& $stopProcess}
  & $capture
  if($state.dirty){$reply=[Windows.MessageBox]::Show('Textkorrekturen speichern?','Audiotranskript','YesNoCancel','Question');if($reply -eq 'Cancel'){$e.Cancel=$true;return};if($reply -eq 'Yes'){Write-AtomicJson (Get-AudioIndexPath $Book.path) $state.index;$state.dirty=$false}}
  $timer.Stop()
 })
 & $fill
 try{[void]$dialog.ShowDialog()}finally{$timer.Stop();if($state.process){$state.process.Dispose()};if($state.job){$wav=Join-Path $state.job 'aufnahme.wav';if([IO.File]::Exists($wav)){try{[IO.File]::Delete($wav)}catch{}}}}
 Read-Books
}
function Alert-Audio($Message){[void][Windows.MessageBox]::Show([string]$Message,'Audio → Text','OK','Warning')}

function Open-StickerPalette {
    try {
        $start=[Diagnostics.ProcessStartInfo]::new()
        $start.FileName=Join-Path $PSHOME 'powershell.exe'
        $start.Arguments='-NoLogo -NoProfile -STA -ExecutionPolicy RemoteSigned -File "'+(Join-Path $PSScriptRoot 'Stickerpalette.ps1')+'" -Quiet'
        $start.UseShellExecute=$false;$start.CreateNoWindow=$true
        [void][Diagnostics.Process]::Start($start)
    } catch {Show-Error ('Stickerpalette konnte nicht gestartet werden: '+$_.Exception.Message)}
}
$script:Stickers.Add_Click({Open-StickerPalette})
$script:Win.Add_ContentRendered({
    $auto=$true
    $settings=Join-Path $script:DataDir 'sticker\einstellungen.json'
    if([IO.File]::Exists($settings)) {try {$prefs=[IO.File]::ReadAllText($settings) | ConvertFrom-Json;$auto=[bool]$prefs.autostart}catch{$auto=$false}}
    if($auto){Open-StickerPalette}
})

$script:VersionStatus.Cursor=[Windows.Input.Cursors]::Hand
$script:VersionStatus.Add_MouseLeftButtonUp({
    if([IO.File]::Exists($script:VersionRequest+'.result')){
        $r=[IO.File]::ReadAllText($script:VersionRequest+'.result') | ConvertFrom-Json
        $message='Geprüfte Notizbücher: '+$r.checked+"`n"+($r.errors -join "`n`n")
        [void][Windows.MessageBox]::Show($message,'Sicherungsprotokoll','OK','Information')
    }else{[void][Windows.MessageBox]::Show($script:VersionStatus.Text,'Sicherungsprotokoll')}
})
$script:VersionProcess=$null
$script:NextVersionSweep=Get-Date
$script:VersionRequest=Join-Path $script:DataDir ('versionsauftrag-'+[Guid]::NewGuid().ToString('N')+'.json')
$script:VersionTimer=[Windows.Threading.DispatcherTimer]::new();$script:VersionTimer.Interval=[TimeSpan]::FromSeconds(5);$script:VersionTimer.Add_Tick({Start-VersionSweep})
$script:Sort.SelectedIndex=0
Read-Books
$script:VersionTimer.Start()
try { [void]$script:Win.ShowDialog() } finally {$script:VersionTimer.Stop();if($script:VersionProcess){$script:VersionProcess.Dispose()};$script:Mutex.ReleaseMutex(); $script:Mutex.Dispose()}
