$ErrorActionPreference = 'Stop'
# ----------------------------------------------------------------------------
# WPF-Konfiguration fuer den Nextcloud-WebDAV-Sync. Der Benutzer traegt hier
# Server, Benutzername, App-Passwort und Zielordner ein. Das App-Passwort wird
# per Windows-DPAPI (aktueller Benutzer) verschluesselt gespeichert; es verlaesst
# das Geraet nicht und wird nirgends im Klartext abgelegt.
# ----------------------------------------------------------------------------
Add-Type -AssemblyName @('PresentationFramework', 'PresentationCore', 'WindowsBase')
. (Join-Path $PSScriptRoot 'NextcloudTools.ps1')

$existing = $null
$cfgPath = Get-NextcloudConfigPath
if ([IO.File]::Exists($cfgPath)) { try { $existing = [IO.File]::ReadAllText($cfgPath) | ConvertFrom-Json } catch { } }

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Nextcloud einrichten · Notizregal" Width="560" Height="560" WindowStartupLocation="CenterScreen"
        Background="#F5F3EE" FontFamily="Segoe UI" FontSize="14">
 <Grid Margin="22">
  <Grid.RowDefinitions>
   <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
   <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
   <RowDefinition Height="*"/><RowDefinition Height="Auto"/>
  </Grid.RowDefinitions>
  <TextBlock Grid.Row="0" Text="Nextcloud-WebDAV-Sync" FontSize="20" FontWeight="Bold" Foreground="#153E37" Margin="0,0,0,4"/>
  <TextBlock Grid.Row="1" TextWrapping="Wrap" Foreground="#4C6557" Margin="0,0,0,14"
             Text="Erstelle in Nextcloud unter Einstellungen &gt; Sicherheit ein App-Passwort. Es wird lokal verschluesselt gespeichert."/>
  <TextBlock Grid.Row="2" Text="Server-URL (z. B. https://cloud.example.de)"/>
  <TextBox   Grid.Row="3" x:Name="Url" Padding="8" Margin="0,3,0,10"/>
  <Grid Grid.Row="4">
   <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="14"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
   <StackPanel Grid.Column="0"><TextBlock Text="Benutzername"/><TextBox x:Name="User" Padding="8" Margin="0,3,0,10"/></StackPanel>
   <StackPanel Grid.Column="2"><TextBlock Text="Zielordner (z. B. Notizen)"/><TextBox x:Name="Folder" Padding="8" Margin="0,3,0,10"/></StackPanel>
  </Grid>
  <TextBlock Grid.Row="5" x:Name="PwLabel" Text="App-Passwort"/>
  <PasswordBox Grid.Row="6" x:Name="Pw" Padding="8" Margin="0,3,0,10"/>
  <CheckBox  Grid.Row="7" x:Name="VerifyTls" Content="TLS-Zertifikat pruefen (empfohlen)" IsChecked="True" Margin="0,0,0,10"/>
  <TextBlock Grid.Row="8" x:Name="Status" TextWrapping="Wrap" VerticalAlignment="Top" Foreground="#4C6557"/>
  <StackPanel Grid.Row="9" Orientation="Horizontal" HorizontalAlignment="Right">
   <Button x:Name="TestBtn" Content="Verbindung testen" Padding="12,8" Margin="0,0,8,0" MinHeight="40"/>
   <Button x:Name="SaveBtn" Content="Speichern" Padding="16,8" Margin="0,0,8,0" MinHeight="40" Background="#153E37" Foreground="White"/>
   <Button x:Name="CancelBtn" Content="Abbrechen" Padding="12,8" MinHeight="40"/>
  </StackPanel>
 </Grid>
</Window>
'@

$win = [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($xaml))
$Url = $win.FindName('Url'); $User = $win.FindName('User'); $Folder = $win.FindName('Folder')
$Pw = $win.FindName('Pw'); $PwLabel = $win.FindName('PwLabel'); $VerifyTls = $win.FindName('VerifyTls')
$Status = $win.FindName('Status'); $TestBtn = $win.FindName('TestBtn'); $SaveBtn = $win.FindName('SaveBtn'); $CancelBtn = $win.FindName('CancelBtn')

if ($existing) {
    $Url.Text = [string]$existing.baseUrl
    $User.Text = [string]$existing.user
    $Folder.Text = [string]$existing.remoteDir
    if ($existing.PSObject.Properties['verifyTls']) { $VerifyTls.IsChecked = [bool]$existing.verifyTls }
    if ($existing.passwordEnc) { $PwLabel.Text = 'App-Passwort (gespeichert – leer lassen zum Beibehalten)' }
}

# Baut ein Konfigurationsobjekt aus den Feldern; behaelt gespeichertes Passwort,
# wenn das Feld leer bleibt.
function Build-Config {
    $enc = ''
    if ($Pw.Password) { $enc = Protect-NcSecret $Pw.Password }
    elseif ($existing -and $existing.passwordEnc) { $enc = [string]$existing.passwordEnc }
    return [ordered]@{
        version     = 1
        baseUrl     = ([string]$Url.Text).Trim()
        user        = ([string]$User.Text).Trim()
        remoteDir   = ([string]$Folder.Text).Trim()
        passwordEnc = $enc
        verifyTls   = [bool]$VerifyTls.IsChecked
    }
}

function Validate($cfg) {
    if (-not $cfg.baseUrl) { throw 'Bitte die Server-URL eingeben.' }
    if ($cfg.baseUrl -notmatch '^https?://') { throw 'Die Server-URL muss mit http:// oder https:// beginnen.' }
    if (-not $cfg.user) { throw 'Bitte den Benutzernamen eingeben.' }
    if (-not $cfg.passwordEnc) { throw 'Bitte ein App-Passwort eingeben.' }
}

$TestBtn.add_Click({
    try {
        $Status.Foreground = '#4C6557'; $Status.Text = 'Verbindung wird getestet …'
        $win.Dispatcher.Invoke([Action] {}, 'Background')
        $cfg = Build-Config; Validate $cfg
        $obj = [pscustomobject]$cfg
        $null = Test-Nextcloud $obj
        $Status.Foreground = '#1B7A3D'; $Status.Text = 'Verbindung erfolgreich. Ordner ist erreichbar.'
    } catch {
        $Status.Foreground = '#B00020'; $Status.Text = 'Test fehlgeschlagen: ' + $_.Exception.Message
    }
})

$SaveBtn.add_Click({
    try {
        $cfg = Build-Config; Validate $cfg
        $tmp = $cfgPath + '.tmp'
        [IO.File]::WriteAllText($tmp, (ConvertTo-Json -InputObject $cfg -Depth 6), [Text.UTF8Encoding]::new($true))
        if ([IO.File]::Exists($cfgPath)) { [IO.File]::Replace($tmp, $cfgPath, $cfgPath + '.bak') } else { [IO.File]::Move($tmp, $cfgPath) }
        $Status.Foreground = '#1B7A3D'; $Status.Text = 'Gespeichert.'
        $win.Close()
    } catch {
        $Status.Foreground = '#B00020'; $Status.Text = 'Speichern fehlgeschlagen: ' + $_.Exception.Message
    }
})

$CancelBtn.add_Click({ $win.Close() })
$win.Dispatcher.add_UnhandledException({ param($s, $e) [void][Windows.MessageBox]::Show($e.Exception.Message, 'Nextcloud'); $e.Handled = $true })
[void]$win.ShowDialog()
