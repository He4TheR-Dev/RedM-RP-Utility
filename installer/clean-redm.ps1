#Requires -Version 5.1
# Nettoyage cache RedM (Logs / Crashes / Data), conserve game-storage.
param(
    [string]$LogPath = '',
    [switch]$Quiet
)

$ErrorActionPreference = 'Continue'
if (-not $LogPath) {
    $LogPath = Join-Path $env:LOCALAPPDATA 'TeamSpeakSaltyChatSetup\clean-redm.log'
}
New-Item -ItemType Directory -Path (Split-Path $LogPath) -Force | Out-Null

function Write-Log([string]$Message) {
    Add-Content -Path $LogPath -Value ("{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message) -Encoding UTF8
}

function Get-FolderBytes([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return [int64]0 }
    try {
        return [int64]((Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { -not $_.PSIsContainer } |
            Measure-Object -Property Length -Sum).Sum)
    } catch { return [int64]0 }
}

function Stop-RedM {
    Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -like 'TeamSpeak-SaltyChat-Setup*' -or $_.ProcessName -like '*SaltyChat-Setup*'
    } | Out-Null
    Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $n = $_.ProcessName
        if ($n -like 'TeamSpeak-SaltyChat-Setup*') { return $false }
        return ($n -like 'RedM*' -or $n -like 'CitizenFX*' -or $n -match '^(FiveM|GTAProcess|RageGame)') -or
            ($_.MainWindowTitle -match 'RedM')
    } | Stop-Process -Force -ErrorAction SilentlyContinue
}

Write-Log '==== clean-redm ===='
Stop-RedM
Start-Sleep -Milliseconds 700

$appRoots = @(
    (Join-Path $env:LOCALAPPDATA 'RedM\RedM.app'),
    (Join-Path $env:LOCALAPPDATA 'RedM Application Data'),
    (Join-Path $env:LOCALAPPDATA 'RedM\Application Data')
)

$before = [int64]0
$after = [int64]0
$cleaned = $false
$keptGameStorage = $false
$foundRoot = $false

foreach ($root in $appRoots) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    $foundRoot = $true
    Write-Log "RedM root $root"
    $before += Get-FolderBytes $root

    foreach ($name in @('logs', 'Logs', 'crashes', 'Crashes')) {
        $p = Join-Path $root $name
        if (Test-Path -LiteralPath $p) {
            Write-Log "Supprime $p"
            Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue
            $cleaned = $true
        }
    }

    $data = $null
    foreach ($d in @('data', 'Data')) {
        $cand = Join-Path $root $d
        if (Test-Path -LiteralPath $cand) { $data = $cand; break }
    }
    if (-not $data) {
        $after += Get-FolderBytes $root
        continue
    }

    Get-ChildItem -LiteralPath $data -Force -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Name -ieq 'game-storage') {
            Write-Log "Conserve $($_.FullName)"
            $script:keptGameStorage = $true
        } else {
            Write-Log "Supprime $($_.FullName)"
            Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
            $script:cleaned = $true
        }
    }
    $after += Get-FolderBytes $root
}

$freed = [Math]::Max([int64]0, $before - $after)
$result = [pscustomobject]@{
    FoundRoot        = $foundRoot
    Cleaned          = $cleaned
    KeptGameStorage  = $keptGameStorage
    BytesBefore      = $before
    BytesAfter       = $after
    BytesFreed       = $freed
    MegabytesFreed   = [math]::Round($freed / 1MB, 1)
    LogPath          = $LogPath
}

if (-not $foundRoot) {
    Write-Log 'Aucun dossier RedM trouve (RedM peut ne pas etre installe)'
} elseif (-not $cleaned) {
    Write-Log 'Rien a nettoyer'
} else {
    Write-Log ("Cache RedM nettoye, {0} Mo liberes (game-storage preserve)" -f $result.MegabytesFreed)
}
Write-Log 'OK'

if (-not $Quiet) {
    $result | ConvertTo-Json -Compress | Write-Output
}
exit 0
