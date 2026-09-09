param([switch]$Quiet)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName @('PresentationFramework','PresentationCore','WindowsBase')
$script:StickerDir=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Notizregal\sticker'
[void][IO.Directory]::CreateDirectory($script:StickerDir)
$script:SettingsPath=Join-Path $script:StickerDir 'einstellungen.json'
$script:Settings=[pscustomobject]@{version=1;autostart=$true;topmost=$false;favorites=@();custom=@()}
$created=$false
$mutex=[Threading.Mutex]::new($true,'Local\NotizregalSticker-1',[ref]$created)
if(-not $created){if(-not $Quiet){[void][Windows.MessageBox]::Show('Die Stickerpalette ist bereits geöffnet.','Stickerpalette')};exit}
function Alert($Text){[void][Windows.MessageBox]::Show([string]$Text,'Stickerpalette','OK','Warning')}
if([IO.File]::Exists($script:SettingsPath)){
 try{$script:Settings=[IO.File]::ReadAllText($script:SettingsPath) | ConvertFrom-Json;if($script:Settings.version -ne 1){throw 'Unbekanntes Einstellungsformat.'}}
 catch{Alert ('Sticker-Einstellungen konnten nicht gelesen werden und werden nicht überschrieben: '+$_.Exception.Message);exit 1}
}
function Save-StickerSettings {
 $tmp=$script:SettingsPath+'.tmp'
 [IO.File]::WriteAllText($tmp,(ConvertTo-Json -InputObject $script:Settings -Depth 8),[Text.UTF8Encoding]::new($true))
 if([IO.File]::Exists($script:SettingsPath)){[IO.File]::Replace($tmp,$script:SettingsPath,$script:SettingsPath+'.bak')}else{[IO.File]::Move($tmp,$script:SettingsPath)}
}
$script:Assets=Join-Path $PSScriptRoot 'OpenMoji'
try{$script:Catalogue=[IO.File]::ReadAllText((Join-Path $script:Assets 'katalog.json')) | ConvertFrom-Json; $script:Catalogue=@($script:Catalogue)}
catch{Alert 'OpenMoji-Bildpaket fehlt oder ist unlesbar. Bitte das gesamte ZIP entpacken und Start.cmd verwenden.';exit 1}
$script:Items=@();$script:Filtered=@();$script:Selected=$null;$script:PageNumber=0;$script:PageSize=60;$script:OnlyFavorites=$false;$script:Loading=$true
function Get-StickerPath($Item){if($Item.kind -eq 'custom'){return Join-Path $script:StickerDir $Item.file};return Join-Path $script:Assets $Item.file}
function Load-Bitmap($Path,[int]$Width=0){
 $bitmap=[Windows.Media.Imaging.BitmapImage]::new();$bitmap.BeginInit();$bitmap.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad
 if($Width -gt 0){$bitmap.DecodePixelWidth=$Width}
 $bitmap.UriSource=[Uri]::new($Path,[UriKind]::Absolute);$bitmap.EndInit();$bitmap.Freeze();return $bitmap
}
function Copy-Sticker {
 if(-not $script:Selected){return}
 try{
  $path=Get-StickerPath $script:Selected;$bitmap=Load-Bitmap $path
  $data=[Windows.DataObject]::new();$data.SetImage($bitmap)
  $png=[IO.MemoryStream]::new([IO.File]::ReadAllBytes($path));$data.SetData('PNG',$png,$false)
  try{[Windows.Clipboard]::SetDataObject($data,$true)}finally{$png.Dispose()}
  $script:Status.Text='Bild kopiert. In Xournal++ Strg+V verwenden. Alternativ „PNG speichern“ und dort das Bildwerkzeug nutzen.'
 }catch{Alert ('Bild konnte nicht kopiert werden: '+$_.Exception.Message+' Bitte erneut versuchen oder PNG speichern.')}
}
[xml]$xaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Stickerpalette · Notizregal" Width="690" Height="810" MinWidth="480" MinHeight="620" WindowStartupLocation="CenterScreen" Background="#F5F3EE" FontFamily="Segoe UI" FontSize="14">
 <Window.Resources>
  <Style TargetType="Button"><Setter Property="Padding" Value="11,9"/><Setter Property="MinHeight" Value="42"/><Setter Property="Margin" Value="0,0,7,6"/><Setter Property="Background" Value="White"/><Setter Property="BorderBrush" Value="#D0DBD4"/><Setter Property="Cursor" Value="Hand"/></Style>
 </Window.Resources>
 <Grid><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
  <Border Background="#153E37" Padding="22,18"><StackPanel><TextBlock Text="STICKERPALETTE" FontSize="12" Foreground="#C7E9BC" FontWeight="Bold"/><TextBlock Text="Ein Bild für deinen Gedanken." FontSize="24" Foreground="White" Margin="0,5,0,5"/><WrapPanel><CheckBox x:Name="Top" Content="Immer im Vordergrund" Foreground="White" Margin="0,8,16,0"/><CheckBox x:Name="Auto" Content="Mit Notizregal starten" Foreground="White" Margin="0,8,0,0"/></WrapPanel></StackPanel></Border>
  <StackPanel Grid.Row="1" Margin="18,14,18,3">
   <TextBox x:Name="Search" Padding="11" ToolTip="Deutsche und englische Namen und Suchbegriffe"/>
   <TextBlock Text="Suche: z. B. Biene, Computer, Warnung, Kaffee" FontSize="11" Foreground="#62766C" Margin="0,4,0,8"/>
   <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><ComboBox x:Name="Category" Padding="9" Margin="0,0,8,6"/><Button x:Name="OnlyFav" Grid.Column="1" Content="☆ Favoriten"/></Grid>
  </StackPanel>
  <ScrollViewer x:Name="Scroll" Grid.Row="2" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" PanningMode="VerticalOnly" Margin="12,0,12,0"><StackPanel><TextBlock x:Name="Empty" Text="Keine passenden Bilder gefunden." Margin="10,20"/><WrapPanel x:Name="Tiles"/></StackPanel></ScrollViewer>
  <Grid Grid.Row="3" Margin="18,8,18,0"><Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><Button x:Name="Prev" Content="← Zurück"/><TextBlock x:Name="PageInfo" Grid.Column="1" VerticalAlignment="Center" HorizontalAlignment="Center"/><Button x:Name="Next" Grid.Column="2" Content="Weiter →"/></Grid>
  <Border Grid.Row="4" Background="#E7EBE3" Padding="18,12"><StackPanel>
   <TextBlock x:Name="SelectionName" Text="Ein Bild auswählen" FontWeight="SemiBold" TextWrapping="Wrap" Margin="0,0,0,8"/>
   <WrapPanel><Button x:Name="Copy" Content="Bild kopieren" IsEnabled="False"/><Button x:Name="SavePng" Content="PNG speichern" IsEnabled="False"/><Button x:Name="Fav" Content="☆ Merken" IsEnabled="False"/><Button x:Name="Import" Content="Eigene Bilder +"/></WrapPanel>
   <TextBlock x:Name="Status" Text="Bild antippen, dann kopieren oder speichern. Vollständig offline." TextWrapping="Wrap" FontSize="12" Foreground="#4C6557" Margin="0,2,0,8"/>
   <TextBlock Text="OpenMoji · CC BY-SA 4.0 | Deutsche Begriffe: Unicode CLDR" FontSize="10" Foreground="#62766C"/>
  </StackPanel></Border>
 </Grid>
</Window>
'@
$script:Win=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($xaml))
foreach($name in @('Top','Auto','Search','Category','OnlyFav','Scroll','Empty','Tiles','Prev','PageInfo','Next','SelectionName','Copy','SavePng','Fav','Import','Status')){Set-Variable -Name $name -Scope Script -Value $script:Win.FindName($name)}
$script:Win.Dispatcher.add_UnhandledException({param($sender,$eventArgs)Alert $eventArgs.Exception.Message;$eventArgs.Handled=$true})
function Update-StickerItems {
 $script:Items=@($script:Catalogue)+@($script:Settings.custom)
 $old=$script:Category.SelectedItem;$script:Loading=$true;$script:Category.Items.Clear();[void]$script:Category.Items.Add('Alle Kategorien')
 foreach($cat in @($script:Items | ForEach-Object {$_.category} | Sort-Object -Unique)){[void]$script:Category.Items.Add($cat)}
 if($old -and $script:Category.Items.Contains($old)){$script:Category.SelectedItem=$old}else{$script:Category.SelectedIndex=0}
 $script:Loading=$false;Filter-Stickers
}
function Filter-Stickers {
 if($script:Loading){return}
 $words=@($script:Search.Text.Trim() -split '\s+' | Where-Object {$_})
 $category=[string]$script:Category.SelectedItem
 $script:Filtered=@($script:Items | Where-Object {
  $item=$_;$match=$true;$haystack=$item.name+' '+$item.tags+' '+$item.category+' '+$item.id
  foreach($word in $words){if($haystack.IndexOf($word,[StringComparison]::OrdinalIgnoreCase) -lt 0){$match=$false;break}}
  $match -and ($script:Category.SelectedIndex -le 0 -or $item.category -eq $category) -and (-not $script:OnlyFavorites -or @($script:Settings.favorites) -contains $item.id)
 })
 $script:PageNumber=0;Render-StickerPage
}
function Render-StickerPage {
 $script:Tiles.Children.Clear();$count=$script:Filtered.Count;$start=$script:PageNumber*$script:PageSize
 $script:Empty.Visibility=if($count){'Collapsed'}else{'Visible'}
 foreach($item in @($script:Filtered | Select-Object -Skip $start -First $script:PageSize)){
  $button=[Windows.Controls.Button]::new();$button.Width=94;$button.Height=108;$button.Padding=5;$button.Margin=4;$button.Tag=$item;$button.ToolTip=$item.name
  if($script:Selected -and $script:Selected.id -eq $item.id){$button.BorderThickness=3;$button.BorderBrush=[Windows.Media.Brushes]::SeaGreen}
  $panel=[Windows.Controls.StackPanel]::new();$image=[Windows.Controls.Image]::new();$image.Height=66;$image.Width=66;$image.Stretch='Uniform'
  try{$image.Source=Load-Bitmap (Get-StickerPath $item) 112}catch{$button.IsEnabled=$false;$button.ToolTip='Bilddatei nicht lesbar: '+$item.name}
  [void]$panel.Children.Add($image)
  $caption=[Windows.Controls.TextBlock]::new();$caption.Text=$item.name;$caption.FontSize=10;$caption.TextTrimming='CharacterEllipsis';$caption.TextAlignment='Center';$caption.Margin='0,4,0,0';[void]$panel.Children.Add($caption)
  $button.Content=$panel
  $button.Add_Click({param($s,$e)$script:Selected=$s.Tag;$script:SelectionName.Text=$s.Tag.name;$script:Copy.IsEnabled=$true;$script:SavePng.IsEnabled=$true;$script:Fav.IsEnabled=$true;$script:Fav.Content=if(@($script:Settings.favorites) -contains $s.Tag.id){'★ Gemerkt'}else{'☆ Merken'};Render-StickerPage})
  $button.Add_MouseDoubleClick({param($s,$e)Copy-Sticker;$e.Handled=$true})
  [void]$script:Tiles.Children.Add($button)
 }
 $total=[Math]::Max(1,[int][Math]::Ceiling($count/[double]$script:PageSize))
 $script:PageInfo.Text=($script:PageNumber+1).ToString()+' / '+$total+' · '+$count+' Bilder'
 $script:Prev.IsEnabled=$script:PageNumber -gt 0;$script:Next.IsEnabled=($script:PageNumber+1) -lt $total
}
$script:Win.Topmost=[bool]$script:Settings.topmost;$script:Top.IsChecked=[bool]$script:Settings.topmost;$script:Auto.IsChecked=[bool]$script:Settings.autostart
$script:Top.Add_Click({$script:Settings.topmost=[bool]$script:Top.IsChecked;$script:Win.Topmost=$script:Settings.topmost;Save-StickerSettings})
$script:Auto.Add_Click({$script:Settings.autostart=[bool]$script:Auto.IsChecked;Save-StickerSettings})
$script:Copy.Add_Click({Copy-Sticker})
$script:SavePng.Add_Click({
 if(-not $script:Selected){return}
 $picker=[Microsoft.Win32.SaveFileDialog]::new();$picker.Title='Sticker als PNG speichern';$picker.Filter='PNG-Bild (*.png)|*.png';$picker.DefaultExt='.png'
 $safe=$script:Selected.name;foreach($c in [IO.Path]::GetInvalidFileNameChars()){$safe=$safe.Replace([string]$c,'-')};$picker.FileName=$safe+'.png'
 if($picker.ShowDialog($script:Win)){[IO.File]::Copy((Get-StickerPath $script:Selected),$picker.FileName,$true);$script:Status.Text='PNG gespeichert. In Xournal++ mit dem Bildwerkzeug einfügen.'}
})
$script:Fav.Add_Click({if($script:Selected){$id=$script:Selected.id;if(@($script:Settings.favorites) -contains $id){$script:Settings.favorites=@($script:Settings.favorites | Where-Object {$_ -ne $id})}else{$script:Settings.favorites=@($script:Settings.favorites)+@($id)};Save-StickerSettings;$script:Fav.Content=if(@($script:Settings.favorites) -contains $id){'★ Gemerkt'}else{'☆ Merken'};Filter-Stickers}})
$script:OnlyFav.Add_Click({$script:OnlyFavorites=-not $script:OnlyFavorites;$script:OnlyFav.Content=if($script:OnlyFavorites){'★ Nur Favoriten'}else{'☆ Favoriten'};Filter-Stickers})
$script:Prev.Add_Click({$script:PageNumber--;Render-StickerPage;$script:Scroll.ScrollToTop()})
$script:Next.Add_Click({$script:PageNumber++;Render-StickerPage;$script:Scroll.ScrollToTop()})
$debounce=[Windows.Threading.DispatcherTimer]::new();$debounce.Interval=[TimeSpan]::FromMilliseconds(220)
$debounce.Add_Tick({$debounce.Stop();Filter-Stickers})
$script:Search.Add_TextChanged({if(-not $script:Loading){$debounce.Stop();$debounce.Start()}})
$script:Category.Add_SelectionChanged({if(-not $script:Loading){Filter-Stickers}})
$script:Import.Add_Click({
 $picker=[Microsoft.Win32.OpenFileDialog]::new();$picker.Title='Eigene Bilder zur Palette hinzufügen';$picker.Multiselect=$true;$picker.Filter='Bilder|*.png;*.jpg;*.jpeg;*.gif;*.bmp'
 if(-not $picker.ShowDialog($script:Win)){return}
 $own=Join-Path $script:StickerDir 'eigene';[void][IO.Directory]::CreateDirectory($own);$added=0;$errors=[Collections.Generic.List[string]]::new()
 foreach($path in $picker.FileNames){
  try{
   # GIF: erster Frame. Große Fotos werden auf maximal 1600 Pixel Breite skaliert.
   $info=[Windows.Media.Imaging.BitmapDecoder]::Create([Uri]::new($path),[Windows.Media.Imaging.BitmapCreateOptions]::DelayCreation,[Windows.Media.Imaging.BitmapCacheOption]::None);$w=$info.Frames[0].PixelWidth;$h=$info.Frames[0].PixelHeight;$size=[Math]::Max(1,[int]($w*[Math]::Min(1,1600.0/[Math]::Max($w,$h))));$bitmap=Load-Bitmap $path $size;$encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
   $id=[Guid]::NewGuid().ToString('N');$dest=Join-Path $own ($id+'.png');$stream=[IO.File]::Open($dest,[IO.FileMode]::CreateNew)
   try{$encoder.Save($stream)}finally{$stream.Dispose()}
   $script:Settings.custom=@($script:Settings.custom)+@([pscustomobject]@{id=('custom:'+ $id);name=[IO.Path]::GetFileNameWithoutExtension($path);category='Eigene Bilder';tags=[IO.Path]::GetFileNameWithoutExtension($path);file=('eigene\'+$id+'.png');kind='custom'})
   $added++
  }catch{$errors.Add([IO.Path]::GetFileName($path)+': '+$_.Exception.Message)}
 }
 Save-StickerSettings;$script:OnlyFavorites=$false;$script:OnlyFav.Content='☆ Favoriten';$script:Search.Text='';Update-StickerItems;$script:Category.SelectedItem='Eigene Bilder';$script:Status.Text="$added eigene Bilder hinzugefügt. GIFs werden als Standbild übernommen."
 if($errors.Count){Alert ($errors -join "`n")}
})
Update-StickerItems
try{[void]$script:Win.ShowDialog()}finally{$debounce.Stop();$mutex.ReleaseMutex();$mutex.Dispose()}
