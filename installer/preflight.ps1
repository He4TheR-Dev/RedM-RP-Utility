#Requires -Version 5.1
# Nettoyage optionnel avant installation (anciennes versions TS / cache RedM).
param(
    [switch]$UninstallOld,
    [switch]$CleanRedM,
    [string]$LogPath = ''
)

$ErrorActionPreference = 'Continue'
if (-not $LogPath) { $LogPath = Join-Path $env:TEMP 'TS3-SaltyChat-Setup\preflight.log' }
New-Item -ItemType Directory -Path (Split-Path $LogPath) -Force | Out-Null

function Write-Log([string]$Message) {
    Add-Content -Path $LogPath -Value ("{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message) -Encoding UTF8
}

Write-Log ("==== preflight uninstall={0} redm={1} ====" -f [bool]$UninstallOld, [bool]$CleanRedM)

function Stop-Named([string[]]$Names) {
    Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $n = $_.ProcessName
        # Ne jamais tuer cet installeur (TeamSpeak-SaltyChat-Setup / .tmp)
        if ($n -like 'TeamSpeak-SaltyChat-Setup*') { return $false }
        if ($n -like '*SaltyChat-Setup*') { return $false }
        foreach ($p in $Names) {
            if ($n -like $p) { return $true }
        }
        return $false
    } | Stop-Process -Force -ErrorAction SilentlyContinue
}

if ($UninstallOld) {
    Write-Log 'Arret TeamSpeak / Overwolf...'
    # "TeamSpeak" exact = TS6. Pas de "TeamSpeak*" sinon on tue l'installeur.
    Stop-Named @('ts3client*','TeamSpeak','Overwolf*','OWInstaller*','package_inst*')
    Start-Sleep -Milliseconds 500

    $unins = @(
        (Join-Path $env:LOCALAPPDATA 'TeamSpeakSaltyChatSetup\unins000.exe'),
        'C:\Program Files\TeamSpeak 3 Client\uninstall.exe',
        'C:\Program Files (x86)\TeamSpeak 3 Client\uninstall.exe',
        (Join-Path $env:LOCALAPPDATA 'Programs\TeamSpeak 3 Client\uninstall.exe'),
        'C:\Program Files (x86)\Overwolf\OWUninstaller.exe',
        'C:\Program Files\Overwolf\OWUninstaller.exe'
    )
    foreach ($u in $unins) {
        if (-not (Test-Path $u)) { continue }
        Write-Log "Desinstall $u"
        $args = if ($u -match 'unins000') { @('/SILENT','/NORESTART') } else { @('/S') }
        try {
            Start-Process -FilePath $u -ArgumentList $args -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
        } catch {
            Write-Log ("echec: {0}" -f $_.Exception.Message)
        }
    }

    Stop-Named @('ts3client*','TeamSpeak','Overwolf*','OWInstaller*')
    Start-Sleep -Milliseconds 600

    $wipe = @(
        (Join-Path $env:APPDATA 'TS3Client'),
        (Join-Path $env:LOCALAPPDATA 'Programs\TeamSpeak 3 Client'),
        (Join-Path $env:LOCALAPPDATA 'TeamSpeakSaltyChatSetup'),
        (Join-Path $env:LOCALAPPDATA 'Overwolf'),
        (Join-Path $env:APPDATA 'Overwolf'),
        'C:\Program Files\TeamSpeak 3 Client',
        'C:\Program Files (x86)\TeamSpeak 3 Client'
    )
    foreach ($p in $wipe) {
        if (-not (Test-Path $p)) { continue }
        Write-Log "Supprime $p"
        Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue
    }

    Get-ChildItem ([Environment]::GetFolderPath('Desktop')) -Filter 'TeamSpeak*.lnk' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike '*SaltyChat-Setup*' } |
        Remove-Item -Force -ErrorAction SilentlyContinue

    Write-Log 'Anciennes versions retirees'
}

if ($CleanRedM) {
    $cleaner = Join-Path $PSScriptRoot 'clean-redm.ps1'
    if (Test-Path -LiteralPath $cleaner) {
        Write-Log 'Nettoyage cache RedM (clean-redm.ps1)...'
        & $cleaner -LogPath $LogPath -Quiet
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    } else {
        Write-Log 'clean-redm.ps1 absent, nettoyage integre...'
        Stop-Named @('RedM*','CitizenFX*','FXServer*','Chrome_ChildProcess*')
        Get-Process -ErrorAction SilentlyContinue | Where-Object {
            $_.ProcessName -match '^(RedM|CitizenFX|FiveM|GTAProcess|RageGame)' -or
            $_.MainWindowTitle -match 'RedM'
        } | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 800
        $appRoots = @(
            (Join-Path $env:LOCALAPPDATA 'RedM\RedM.app'),
            (Join-Path $env:LOCALAPPDATA 'RedM Application Data'),
            (Join-Path $env:LOCALAPPDATA 'RedM\Application Data')
        )
        $cleaned = $false
        foreach ($root in $appRoots) {
            if (-not (Test-Path $root)) { continue }
            Write-Log "RedM root $root"
            foreach ($name in @('logs','Logs','crashes','Crashes')) {
                $p = Join-Path $root $name
                if (Test-Path $p) {
                    Write-Log "Supprime $p"
                    Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue
                    $cleaned = $true
                }
            }
            $data = $null
            foreach ($d in @('data','Data')) {
                $cand = Join-Path $root $d
                if (Test-Path $cand) { $data = $cand; break }
            }
            if (-not $data) { continue }
            Get-ChildItem -LiteralPath $data -Force -ErrorAction SilentlyContinue | ForEach-Object {
                if ($_.Name -ieq 'game-storage') {
                    Write-Log "Conserve $($_.FullName)"
                } else {
                    Write-Log "Supprime $($_.FullName)"
                    Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
                    $script:cleaned = $true
                }
            }
        }
        if (-not $cleaned) {
            Write-Log 'Aucun dossier RedM data trouve (RedM peut ne pas etre installe)'
        } else {
            Write-Log 'Cache RedM nettoye (game-storage preserve)'
        }
    }
}

Write-Log 'OK'
exit 0
