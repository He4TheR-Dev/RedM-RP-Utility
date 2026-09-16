#Requires -Version 5.1
# Payload appele par l'installeur Windows. Ne pas lancer a la main.
param(
    [Parameter(Mandatory = $true)][string]$PluginZip,
    [string]$SqliteZip = '',
    [string]$ThemeZip = '',
    [string]$Server = '',
    [string]$Nickname = '',
    [string]$ConfigFile = '',
    [string]$LogPath = ''
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $Here 'ui-auto.ps1')

$WorkDir    = Join-Path $env:TEMP 'TS3-SaltyChat-Setup'
$Ts3Plugins = Join-Path $env:APPDATA 'TS3Client\plugins'
$Ts3Db      = Join-Path $env:APPDATA 'TS3Client\settings.db'
if (-not $LogPath) { $LogPath = Join-Path $WorkDir 'setup.log' }

New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
Add-Content -Path $LogPath -Value ("==== {0} payload ====" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -Encoding UTF8

function Write-Log([string]$Message) {
    Add-Content -Path $LogPath -Value $Message -Encoding UTF8
}

function Get-Ts3Exe {
    foreach ($p in @(
        (Join-Path $env:LOCALAPPDATA 'Programs\TeamSpeak 3 Client\ts3client_win64.exe'),
        'C:\Program Files\TeamSpeak 3 Client\ts3client_win64.exe',
        'C:\Program Files (x86)\TeamSpeak 3 Client\ts3client_win64.exe'
    )) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Stop-TeamSpeak {
    Get-Process -Name 'ts3client_win64','ts3client','TeamSpeak','package_inst' -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 800
}

function Stop-Overwolf {
    Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -like 'Overwolf*' -or $_.ProcessName -eq 'OWInstaller'
    } | Stop-Process -Force -ErrorAction SilentlyContinue
    foreach ($un in @(
        'C:\Program Files (x86)\Overwolf\OWUninstaller.exe',
        'C:\Program Files\Overwolf\OWUninstaller.exe'
    )) {
        if (Test-Path $un) {
            try { Start-Process -FilePath $un -ArgumentList '/S' -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue } catch { }
        }
    }
    foreach ($p in @((Join-Path $env:LOCALAPPDATA 'Overwolf'), (Join-Path $env:APPDATA 'Overwolf'))) {
        if (Test-Path $p) { Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function Get-WasapiDevice([string]$NamePattern, [bool]$Capture) {
    $prefix = if ($Capture) { '{0.0.1.00000000}.' } else { '{0.0.0.00000000}.' }
    foreach ($d in (Get-PnpDevice -Class AudioEndpoint -Status OK -ErrorAction SilentlyContinue)) {
        if ($d.FriendlyName -notmatch $NamePattern) { continue }
        if ($d.InstanceId -notmatch 'MMDEVAPI\\(\{0\.0\.[01]\.00000000\}\.\{[0-9A-Fa-f-]+\})') { continue }
        $id = $Matches[1]
        if (-not $id.StartsWith($prefix)) { continue }
        return [pscustomobject]@{ Name = $d.FriendlyName; Id = $id }
    }
    return $null
}

function ConvertTo-SqlLiteral([string]$Value) {
    if ($null -eq $Value) { return '' }
    return $Value.Replace("'", "''")
}

function Get-SqliteExe {
    $sqliteDir = Join-Path $WorkDir 'sqlite'
    $exe = Get-ChildItem $sqliteDir -Filter 'sqlite3.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($exe) { return $exe.FullName }
    if (-not $SqliteZip -or -not (Test-Path $SqliteZip)) { throw 'Archive sqlite introuvable.' }
    Expand-Archive -Path $SqliteZip -DestinationPath $sqliteDir -Force
    $exe = Get-ChildItem $sqliteDir -Filter 'sqlite3.exe' -Recurse | Select-Object -First 1
    if (-not $exe) { throw 'sqlite3.exe introuvable.' }
    return $exe.FullName
}

function Invoke-Sqlite([string]$DbPath, [string]$Sql) {
    $sqlite = Get-SqliteExe
    $sqlFile = Join-Path $WorkDir 'query.sql'
    [IO.File]::WriteAllText($sqlFile, $Sql, [Text.UTF8Encoding]::new($false))
    $out = & $sqlite -batch -noheader $DbPath ".read $sqlFile" 2>&1
    if ($LASTEXITCODE -ne 0) { throw "SQLite a echoue : $out" }
    return $out
}

function Write-SaltyChatAccepted {
    $dir = Join-Path $Ts3Plugins 'SaltyChat'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $path = Join-Path $dir 'settings.json'
    $cfg = @{
        WebSocketAddress   = '127.0.0.1:8088'
        UpdateBranch       = 'Stable'
        AcceptedTerms400   = $true
        AccptedTerms300    = $true
        TosAccepted        = $true
        tos_accepted       = $true
        accepted_terms400  = $true
        accpted_terms300   = $true
    }
    if (Test-Path $path) {
        try {
            $existing = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($p in $existing.PSObject.Properties) {
                if (-not $cfg.ContainsKey($p.Name)) { $cfg[$p.Name] = $p.Value }
            }
        } catch { }
    }
    $cfg.AcceptedTerms400 = $true
    $cfg.AccptedTerms300 = $true
    $cfg.TosAccepted = $true
    $cfg.tos_accepted = $true
    $json = $cfg | ConvertTo-Json -Depth 6
    [IO.File]::WriteAllText($path, $json, [Text.UTF8Encoding]::new($false))
    Write-Log 'SaltyChat conditions acceptees'
}

function Write-Ts3LicenseAccepted {
    if (-not (Test-Path $Ts3Db)) { return }
    $sql = @"
BEGIN;
INSERT INTO General(timestamp, key, value)
VALUES(strftime('%s','now'), 'LastShownLicense', '5')
ON CONFLICT(key) DO UPDATE SET timestamp=excluded.timestamp, value=excluded.value;
INSERT INTO General(timestamp, key, value)
VALUES(strftime('%s','now'), 'LicenseVersion', '5')
ON CONFLICT(key) DO UPDATE SET timestamp=excluded.timestamp, value=excluded.value;
COMMIT;
"@
    try {
        Invoke-Sqlite $Ts3Db $sql | Out-Null
        Write-Log 'Licence TeamSpeak enregistree'
    } catch {
        Write-Log "Licence TS3: $($_.Exception.Message)"
    }
}

function Wait-SettingsDb {
    Write-SaltyChatAccepted
    $exe = Get-Ts3Exe
    if (-not $exe) { throw 'TeamSpeak 3 introuvable apres installation.' }
    Write-Log 'Premier lancement TS3 : profil et licences...'
    Get-Process -Name 'ts3client_win64','ts3client' -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 400
    $proc = Start-Process -FilePath $exe -PassThru -WindowStyle Minimized
    $deadline = (Get-Date).AddSeconds(90)
    $readyAt = $null
    $wroteLicense = $false
    while ((Get-Date) -lt $deadline) {
        Invoke-AcceptFirstRunUi
        if (Test-Path $Ts3Db) {
            if (-not $wroteLicense) {
                Write-Ts3LicenseAccepted
                $wroteLicense = $true
            }
            try {
                $n = Invoke-Sqlite $Ts3Db "SELECT COUNT(*) FROM Profiles WHERE key='DefaultCaptureProfile';"
                if (($n | Select-Object -First 1) -as [int] -ge 1) {
                    if (-not $readyAt) { $readyAt = (Get-Date).AddSeconds(10) }
                }
            } catch { }
        }
        if ($readyAt -and (Get-Date) -ge $readyAt -and -not (Test-FirstRunDialogsOpen)) { break }
        Start-Sleep -Milliseconds 400
    }
    Invoke-AcceptFirstRunUi
    Start-Sleep -Milliseconds 600
    Write-Ts3LicenseAccepted
    Write-SaltyChatAccepted
    Stop-TeamSpeak
    if ($proc -and -not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 1
    if (-not (Test-Path $Ts3Db)) { throw 'Impossible de creer settings.db. Ouvre TeamSpeak 3 une fois puis relance.' }
}

function Install-Theme {
    if (-not $ThemeZip -or -not (Test-Path $ThemeZip)) {
        Write-Log 'Theme Red Dead RP introuvable (zip manquant)'
        return
    }
    $extract = Join-Path $WorkDir 'theme_unpacked'
    if (Test-Path $extract) { Remove-Item $extract -Recurse -Force }
    Expand-Archive -Path $ThemeZip -DestinationPath $extract -Force
    $qss = Get-ChildItem $extract -Filter 'reddead_rp.qss' -Recurse | Select-Object -First 1
    if (-not $qss) { throw 'reddead_rp.qss manquant dans le theme.' }
    $folder = Join-Path $qss.DirectoryName 'reddead_rp'

    $targets = @(
        (Join-Path $env:APPDATA 'TS3Client\styles')
    )
    $installStyles = Join-Path $env:LOCALAPPDATA 'Programs\TeamSpeak 3 Client\styles'
    if (Test-Path (Split-Path $installStyles)) { $targets += $installStyles }

    foreach ($stylesDir in $targets) {
        New-Item -ItemType Directory -Path $stylesDir -Force | Out-Null
        Copy-Item -LiteralPath $qss.FullName -Destination (Join-Path $stylesDir 'reddead_rp.qss') -Force
        $destFolder = Join-Path $stylesDir 'reddead_rp'
        if (Test-Path $destFolder) { Remove-Item $destFolder -Recurse -Force }
        if (Test-Path $folder) {
            Copy-Item -LiteralPath $folder -Destination $destFolder -Recurse -Force
        }
        Write-Log "Theme copie dans $stylesDir"
    }
    Write-Log 'Theme Red Dead RP installe'
}

function Install-Plugin {
    if (-not (Test-Path $PluginZip)) { throw "Plugin introuvable : $PluginZip" }
    $extract = Join-Path $WorkDir 'SaltyChat_unpacked'
    if (Test-Path $extract) { Remove-Item $extract -Recurse -Force }
    Expand-Archive -Path $PluginZip -DestinationPath $extract -Force
    $src = Join-Path $extract 'plugins'
    if (-not (Test-Path $src)) { throw 'Le paquet SaltyChat ne contient pas de dossier plugins.' }
    New-Item -ItemType Directory -Path $Ts3Plugins -Force | Out-Null
    Copy-Item -Path (Join-Path $src '*') -Destination $Ts3Plugins -Recurse -Force
    if (-not (Test-Path (Join-Path $Ts3Plugins 'SaltyChat_win64.dll'))) {
        throw 'SaltyChat_win64.dll manquant.'
    }
    Write-Log 'SaltyChat copie'
}

function Read-Config {
    $cfg = @{ MicName = ''; MicId = ''; SpkName = ''; SpkId = ''; PttVk = 0; PttName = ''; PttKind = 'Keyboard' }
    if (-not $ConfigFile -or -not (Test-Path $ConfigFile)) { return $cfg }
    foreach ($line in Get-Content $ConfigFile -Encoding UTF8) {
        if ($line -notmatch '^(.*?)=(.*)$') { continue }
        $cfg[$Matches[1]] = $Matches[2]
    }
    return $cfg
}

function Set-Ts3Presets {
    Wait-SettingsDb
    $cfg = Read-Config
    $micName = $cfg.MicName
    $micId = $cfg.MicId
    $spkName = $cfg.SpkName
    $spkId = $cfg.SpkId
    $hasCfg = $ConfigFile -and (Test-Path $ConfigFile)
    if (-not $hasCfg -and -not $micId) {
        $auto = Get-WasapiDevice 'A50.*Mic' $true
        if ($auto) { $micName = $auto.Name; $micId = $auto.Id }
    }
    if (-not $hasCfg -and -not $spkId) {
        $auto = Get-WasapiDevice 'A50.*Voice' $false
        if (-not $auto) { $auto = Get-WasapiDevice 'A50.*Game' $false }
        if ($auto) { $spkName = $auto.Name; $spkId = $auto.Id }
    }
    if ($micId) { Write-Log "Micro $micName" } else { Write-Log 'Micro par defaut Windows' }
    if ($spkId) { Write-Log "Casque $spkName" } else { Write-Log 'Casque par defaut Windows' }

    $captureBody = if ($micId) {
        "DeviceDisplayName=$micName`nMode=Windows Audio Session`nDevice=$micId`n"
    } else { "DeviceDisplayName=`nMode=`nDevice=`n" }
    $playbackBody = if ($spkId) {
        "Mode=Windows Audio Session`nDevice=$spkId`nDeviceDisplayName=$spkName`nVolumeModifier=0`nPlayMicClicksOnOwn=false`nPlayMicClicksOnOthers=false`nPlaybackMonoOverCenterSpeaker=false`nAGC=true`n"
    } else {
        "Mode=`nDevice=`nDeviceDisplayName=`nVolumeModifier=0`nPlayMicClicksOnOwn=false`nPlayMicClicksOnOthers=false`nPlaybackMonoOverCenterSpeaker=false`nAGC=true`n"
    }
    $preBody = "denoise=true`nvad_mode=0`nvoiceactivation_level=-40`nvad=false`nagc=true`nvad_over_ptt=false`ncontinous_transmission=false`n"
    $c  = ConvertTo-SqlLiteral $captureBody
    $pb = ConvertTo-SqlLiteral $playbackBody
    $pp = ConvertTo-SqlLiteral $preBody
    $sql = @"
BEGIN;
INSERT INTO Profiles(timestamp, key, value)
SELECT strftime('%s','now'), 'Capture/' || value, '$c'
FROM Profiles WHERE key='DefaultCaptureProfile'
ON CONFLICT(key) DO UPDATE SET timestamp=excluded.timestamp, value=excluded.value;
INSERT INTO Profiles(timestamp, key, value)
SELECT strftime('%s','now'), 'Capture/' || value || '/PreProcessing', '$pp'
FROM Profiles WHERE key='DefaultCaptureProfile'
ON CONFLICT(key) DO UPDATE SET timestamp=excluded.timestamp, value=excluded.value;
INSERT INTO Profiles(timestamp, key, value)
SELECT strftime('%s','now'), 'Playback/' || value, '$pb'
FROM Profiles WHERE key='DefaultCaptureProfile'
ON CONFLICT(key) DO UPDATE SET timestamp=excluded.timestamp, value=excluded.value;
INSERT INTO Application(timestamp, key, value)
VALUES(strftime('%s','now'), 'SoundPack', 'nosounds')
ON CONFLICT(key) DO UPDATE SET timestamp=excluded.timestamp, value=excluded.value;
INSERT INTO Application(timestamp, key, value)
VALUES(strftime('%s','now'), 'LastUsedServerSoundPack', 'nosounds')
ON CONFLICT(key) DO UPDATE SET timestamp=excluded.timestamp, value=excluded.value;
INSERT INTO Application(timestamp, key, value)
VALUES(strftime('%s','now'), 'QtStyleSheet', 'reddead_rp')
ON CONFLICT(key) DO UPDATE SET timestamp=excluded.timestamp, value=excluded.value;
INSERT INTO Application(timestamp, key, value)
VALUES(strftime('%s','now'), 'IconPack', 'default_mono_2014')
ON CONFLICT(key) DO UPDATE SET timestamp=excluded.timestamp, value=excluded.value;
COMMIT;
"@
    Invoke-Sqlite $Ts3Db $sql | Out-Null
    Write-Log 'Prereglages audio et theme appliques'

    $vk = 0
    [void][int]::TryParse($cfg.PttVk, [ref]$vk)
    if ($vk -gt 0) {
        $kind = $cfg.PttKind
        $ident = if ($kind -like 'Mouse*') { "Mouse:$vk" } else { "Keyboard:$vk" }
        $legacy = if ($kind -like 'Mouse*') { "Mouse$vk" } else { "Keyboard$vk" }
        $k = ConvertTo-SqlLiteral $ident
        $leg = ConvertTo-SqlLiteral $legacy
        $kn = ConvertTo-SqlLiteral $cfg.PttName
        $hotSql = @"
BEGIN;
INSERT INTO Application(timestamp, key, value)
VALUES(strftime('%s','now'), 'HotkeyMode', '2')
ON CONFLICT(key) DO UPDATE SET timestamp=excluded.timestamp, value=excluded.value;
INSERT INTO Profiles(timestamp, key, value)
VALUES(strftime('%s','now'), 'Hotkeys/1/action', 'Activate Push-to-Talk')
ON CONFLICT(key) DO UPDATE SET timestamp=excluded.timestamp, value=excluded.value;
INSERT INTO Profiles(timestamp, key, value)
VALUES(strftime('%s','now'), 'Hotkeys/1/Action_Type', 'Activate Push-to-Talk')
ON CONFLICT(key) DO UPDATE SET timestamp=excluded.timestamp, value=excluded.value;
INSERT INTO Profiles(timestamp, key, value)
VALUES(strftime('%s','now'), 'Hotkeys/1/Event_Type', 'Down')
ON CONFLICT(key) DO UPDATE SET timestamp=excluded.timestamp, value=excluded.value;
INSERT INTO Profiles(timestamp, key, value)
VALUES(strftime('%s','now'), 'Hotkeys/1/Event_Mode', 'Down')
ON CONFLICT(key) DO UPDATE SET timestamp=excluded.timestamp, value=excluded.value;
INSERT INTO Profiles(timestamp, key, value)
VALUES(strftime('%s','now'), 'Hotkeys/1/Event_KeyIdentifier1', '$k')
ON CONFLICT(key) DO UPDATE SET timestamp=excluded.timestamp, value=excluded.value;
INSERT INTO Profiles(timestamp, key, value)
VALUES(strftime('%s','now'), 'Hotkeys/1/keys', '$leg')
ON CONFLICT(key) DO UPDATE SET timestamp=excluded.timestamp, value=excluded.value;
INSERT INTO Profiles(timestamp, key, value)
VALUES(strftime('%s','now'), 'Hotkeys/1/keyNames', '$kn')
ON CONFLICT(key) DO UPDATE SET timestamp=excluded.timestamp, value=excluded.value;
INSERT INTO Profiles(timestamp, key, value)
VALUES(strftime('%s','now'), 'Hotkeys/1/identifier', '$k')
ON CONFLICT(key) DO UPDATE SET timestamp=excluded.timestamp, value=excluded.value;
COMMIT;
"@
        Invoke-Sqlite $Ts3Db $hotSql | Out-Null
        Write-Log "PTT $ident ($($cfg.PttName))"
    }
}

function New-ServerShortcut([string]$Ts3Exe, [string]$Address, [string]$Nick) {
    $desktop = [Environment]::GetFolderPath('Desktop')
    $safeName = ($Address -replace '[\\/:*?"<>|]', '_')
    $lnk = Join-Path $desktop "TeamSpeak - $safeName.lnk"
    $args = "ts3server://$Address"
    if ($Nick) { $args += "?nickname=$([uri]::EscapeDataString($Nick))" }
    $w = New-Object -ComObject WScript.Shell
    $s = $w.CreateShortcut($lnk)
    $s.TargetPath = $Ts3Exe
    $s.Arguments = $args
    $s.WorkingDirectory = Split-Path $Ts3Exe
    $s.Description = "Connexion TeamSpeak $Address"
    $s.Save()
    Write-Log "Raccourci $lnk"
}

try {
    Stop-TeamSpeak
    try {
        $list = winget list --id TeamSpeakSystems.TeamSpeakClient.Beta.6 -e 2>$null
        if ($list -match 'TeamSpeakSystems.TeamSpeakClient.Beta.6') {
            winget uninstall --id TeamSpeakSystems.TeamSpeakClient.Beta.6 --exact --disable-interactivity --accept-source-agreements | Out-Null
            Write-Log 'TeamSpeak 6 retire'
        }
    } catch { Write-Log "TS6: $($_.Exception.Message)" }

    Install-Plugin
    Install-Theme
    Stop-TeamSpeak
    Stop-Overwolf
    Set-Ts3Presets
    Stop-Overwolf
    $ts3 = Get-Ts3Exe
    if ($Server -and $ts3) { New-ServerShortcut $ts3 $Server $Nickname }
    Write-Log 'OK'
    exit 0
} catch {
    Write-Log "ECHEC : $($_.Exception.Message)"
    exit 1
}
