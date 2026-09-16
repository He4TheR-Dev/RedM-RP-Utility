#Requires -Version 5.1
# Installe TeamSpeak 3 en silencieux, sans Overwolf ni overlay.
param(
    [Parameter(Mandatory = $true)][string]$SetupFile,
    [int]$TimeoutSec = 240
)

$ErrorActionPreference = 'Continue'

function Get-Ts3Exe {
    foreach ($p in @(
        (Join-Path $env:LOCALAPPDATA 'Programs\TeamSpeak 3 Client\ts3client_win64.exe'),
        'C:\Program Files\TeamSpeak 3 Client\ts3client_win64.exe',
        'C:\Program Files (x86)\TeamSpeak 3 Client\ts3client_win64.exe'
    )) { if (Test-Path $p) { return $p } }
    return $null
}

function Stop-Overwolf {
    Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -like 'Overwolf*' -or $_.ProcessName -eq 'OWInstaller'
    } | Stop-Process -Force -ErrorAction SilentlyContinue
}

function New-OverwolfStub {
    $stub = Join-Path $env:TEMP 'ts3-ow-stub.exe'
    if (Test-Path $stub) { return $stub }
    try {
        Add-Type -TypeDefinition 'public class OwStub { static int Main() { return 0; } }' -OutputAssembly $stub -OutputType ConsoleApplication
    } catch { return $null }
    return $stub
}

function Disable-OverwolfDroppings([string]$Stub) {
    $roots = @($env:TEMP, $env:TMP, (Join-Path $env:LOCALAPPDATA 'Temp')) | Select-Object -Unique
    foreach ($root in $roots) {
        if (-not $root -or -not (Test-Path $root)) { continue }
        Get-ChildItem -LiteralPath $root -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like 'ns*' -or $_.Name -like '*Overwolf*' -or $_.Name -like '*OWInstaller*' } |
            ForEach-Object {
                $files = @($_)
                if ($_.PSIsContainer) {
                    $files = @(Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue |
                        Where-Object { -not $_.PSIsContainer -and ($_.Name -match 'Overwolf|OWInstaller') })
                }
                foreach ($f in $files) {
                    if ($f.PSIsContainer -or $f.Name -notmatch 'Overwolf|OWInstaller') { continue }
                    try {
                        if ($Stub -and (Test-Path $Stub)) {
                            Copy-Item -LiteralPath $Stub -Destination $f.FullName -Force -ErrorAction Stop
                        } else {
                            Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop
                        }
                    } catch { }
                }
            }
    }
}

function Uninstall-Overwolf {
    Stop-Overwolf
    foreach ($un in @(
        'C:\Program Files (x86)\Overwolf\OWUninstaller.exe',
        'C:\Program Files\Overwolf\OWUninstaller.exe'
    )) {
        if (Test-Path $un) {
            try { Start-Process -FilePath $un -ArgumentList '/S' -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue } catch { }
            Stop-Overwolf
        }
    }
    foreach ($p in @(
        (Join-Path $env:LOCALAPPDATA 'Overwolf'),
        (Join-Path $env:APPDATA 'Overwolf')
    )) {
        if (Test-Path $p) { Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function Enable-OverwolfSkip {
    # Astuce Chocolatey : ce dossier fait sauter le telechargement Overwolf dans l'installeur TS3.
    foreach ($root in @($env:TEMP, $env:TMP, (Join-Path $env:LOCALAPPDATA 'Temp'))) {
        if (-not $root) { continue }
        New-Item -ItemType Directory -Path (Join-Path $root 'overwolfdummy') -Force | Out-Null
    }
}

if (-not (Test-Path -LiteralPath $SetupFile)) { throw "Installeur TS3 introuvable : $SetupFile" }
if (Get-Ts3Exe) { Uninstall-Overwolf; if (Get-Ts3Exe) { exit 0 } }

try { Unblock-File -LiteralPath $SetupFile -ErrorAction SilentlyContinue } catch { }

Enable-OverwolfSkip
Stop-Overwolf
$stub = New-OverwolfStub
Disable-OverwolfDroppings $stub

$dest = Join-Path $env:LOCALAPPDATA 'Programs\TeamSpeak 3 Client'
# /D= doit etre le dernier argument NSIS, sans guillemets.
$args = "/S /CURRENTUSER /D=$dest"
$proc = Start-Process -FilePath $SetupFile -ArgumentList $args -PassThru -WindowStyle Hidden
$deadline = (Get-Date).AddSeconds($TimeoutSec)
$seen = $false
while ((Get-Date) -lt $deadline) {
    Stop-Overwolf
    Disable-OverwolfDroppings $stub
    if (Get-Ts3Exe) { $seen = $true }
    if ($seen -and $proc.HasExited) { break }
    if ($proc.HasExited -and -not $seen) { break }
    Start-Sleep -Milliseconds 400
}

if ($proc -and -not $proc.HasExited -and (Get-Ts3Exe)) {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

Get-Process -Name 'ts3client_win64','ts3client' -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
Stop-Overwolf
Uninstall-Overwolf
Start-Sleep -Milliseconds 800

if (-not (Get-Ts3Exe)) {
    if ($proc -and -not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
    throw "TeamSpeak 3 ne s'est pas installe."
}
exit 0
