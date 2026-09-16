#Requires -Version 5.1
# Hub Vocal Roleplay : installer, nettoyer cache, desinstaller, ouvrir TS3.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$cBg = [System.Drawing.Color]::FromArgb(20, 12, 8)
$cPanel = [System.Drawing.Color]::FromArgb(32, 20, 12)
$cGold = [System.Drawing.Color]::FromArgb(212, 168, 74)
$cCream = [System.Drawing.Color]::FromArgb(243, 230, 200)
$cMuted = [System.Drawing.Color]::FromArgb(176, 150, 118)
$cDanger = [System.Drawing.Color]::FromArgb(180, 70, 50)

function Get-Ts3Exe {
    foreach ($p in @(
        (Join-Path $env:LOCALAPPDATA 'Programs\TeamSpeak 3 Client\ts3client_win64.exe'),
        'C:\Program Files\TeamSpeak 3 Client\ts3client_win64.exe',
        'C:\Program Files (x86)\TeamSpeak 3 Client\ts3client_win64.exe'
    )) { if (Test-Path $p) { return $p } }
    return $null
}

function Find-SetupExe {
    $name = 'TeamSpeak-SaltyChat-Setup.exe'
    $dirs = @(
        $scriptDir,
        (Join-Path $scriptDir '..'),
        [Environment]::GetFolderPath('Desktop'),
        (Join-Path $env:USERPROFILE 'Downloads')
    ) | Select-Object -Unique
    foreach ($d in $dirs) {
        if (-not $d -or -not (Test-Path $d)) { continue }
        $direct = Join-Path $d $name
        if (Test-Path $direct) { return (Resolve-Path $direct).Path }
        $found = Get-ChildItem -LiteralPath $d -Filter $name -Recurse -Depth 2 -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName
        if ($found) { return $found }
    }
    return $null
}

function Set-Status([string]$Text, [System.Drawing.Color]$Color) {
    $script:status.ForeColor = $Color
    $script:status.Text = $Text
    $script:form.Refresh()
    [System.Windows.Forms.Application]::DoEvents()
}

function New-ActionButton([string]$Text, [int]$Y, [System.Drawing.Color]$Back, [System.Drawing.Color]$Fore) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Font = New-Object System.Drawing.Font 'Georgia', 10, ([System.Drawing.FontStyle]::Bold)
    $b.BackColor = $Back
    $b.ForeColor = $Fore
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderSize = 0
    $b.Size = New-Object System.Drawing.Size 420, 44
    $b.Location = New-Object System.Drawing.Point 30, $Y
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    $script:form.Controls.Add($b)
    return $b
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Vocal Roleplay'
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.ClientSize = New-Object System.Drawing.Size 480, 420
$form.BackColor = $cBg
$form.Font = New-Object System.Drawing.Font 'Segoe UI', 9

$title = New-Object System.Windows.Forms.Label
$title.Text = 'Vocal Roleplay'
$title.Font = New-Object System.Drawing.Font 'Georgia', 20, ([System.Drawing.FontStyle]::Bold)
$title.ForeColor = $cGold
$title.Location = New-Object System.Drawing.Point 28, 18
$title.AutoSize = $true
$form.Controls.Add($title)

$sub = New-Object System.Windows.Forms.Label
$sub.Text = 'Installe, nettoie ou desinstalle — sans tout recommencer a la main.'
$sub.ForeColor = $cMuted
$sub.Location = New-Object System.Drawing.Point 30, 58
$sub.Size = New-Object System.Drawing.Size 420, 24
$form.Controls.Add($sub)

$btnInstall = New-ActionButton 'Installer / Reparer TeamSpeak + SaltyChat' 100 $cGold $cBg
$btnClean   = New-ActionButton 'Nettoyer le cache RedM' 154 $cPanel $cCream
$btnClean.FlatAppearance.BorderSize = 1
$btnClean.FlatAppearance.BorderColor = $cGold
$btnUninstall = New-ActionButton 'Desinstaller tout (TS / SaltyChat / Overwolf)' 208 $cPanel $cCream
$btnUninstall.FlatAppearance.BorderSize = 1
$btnUninstall.FlatAppearance.BorderColor = $cDanger
$btnOpen = New-ActionButton 'Ouvrir TeamSpeak 3' 262 $cPanel $cCream
$btnOpen.FlatAppearance.BorderSize = 1
$btnOpen.FlatAppearance.BorderColor = $cGold

$panel = New-Object System.Windows.Forms.Panel
$panel.Location = New-Object System.Drawing.Point 30, 320
$panel.Size = New-Object System.Drawing.Size 420, 56
$panel.BackColor = $cPanel
$form.Controls.Add($panel)

$status = New-Object System.Windows.Forms.Label
$status.Text = if (Get-Ts3Exe) { 'TeamSpeak 3 detecte. Choisis une action.' } else { 'TeamSpeak 3 non detecte. Lance Installer / Reparer.' }
$status.ForeColor = $cMuted
$status.Location = New-Object System.Drawing.Point 12, 10
$status.Size = New-Object System.Drawing.Size 396, 36
$panel.Controls.Add($status)

$btnInstall.Add_Click({
    Set-Status 'Recherche de l''installeur...' $cGold
    $setup = Find-SetupExe
    if (-not $setup) {
        $dlg = New-Object System.Windows.Forms.OpenFileDialog
        $dlg.Filter = 'Installeur Vocal Roleplay|TeamSpeak-SaltyChat-Setup.exe|Tous|*.exe'
        $dlg.Title = 'Selectionne TeamSpeak-SaltyChat-Setup.exe'
        if ($dlg.ShowDialog() -ne 'OK') {
            Set-Status 'Installation annulee.' $cMuted
            return
        }
        $setup = $dlg.FileName
    }
    Set-Status "Lancement : $(Split-Path $setup -Leaf)" $cGold
    Start-Process -FilePath $setup
    Set-Status 'Installeur lance. Reviens ici apres pour nettoyer le cache.' $cCream
})

$btnClean.Add_Click({
    $ui = Join-Path $scriptDir 'clean-redm-ui.ps1'
    $core = Join-Path $scriptDir 'clean-redm.ps1'
    if (-not (Test-Path $core)) {
        Set-Status 'clean-redm.ps1 manquant. Relance l''installeur principal.' $cDanger
        return
    }
    if (Test-Path $ui) {
        Set-Status 'Ouverture du nettoyeur...' $cGold
        Start-Process -FilePath 'powershell.exe' -ArgumentList @(
            '-NoLogo','-NoProfile','-STA','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File', $ui
        ) -WindowStyle Hidden
        Set-Status 'Nettoyeur ouvert.' $cCream
        return
    }
    Set-Status 'Nettoyage en cours...' $cGold
    $log = Join-Path $env:LOCALAPPDATA 'TeamSpeakSaltyChatSetup\clean-redm.log'
    $p = Start-Process -FilePath 'powershell.exe' -ArgumentList @(
        '-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File', $core, '-LogPath', $log
    ) -Wait -PassThru -WindowStyle Hidden
    if ($p.ExitCode -eq 0) {
        Set-Status 'Cache RedM nettoye (game-storage conserve).' $cCream
    } else {
        Set-Status "Echec nettoyage (code $($p.ExitCode))." $cDanger
    }
})

$btnUninstall.Add_Click({
    $r = [System.Windows.Forms.MessageBox]::Show(
        "Desinstaller TeamSpeak 3, SaltyChat et Overwolf ?`n`nRedM et game-storage ne sont pas touches.",
        'Desinstaller tout',
        'YesNo',
        'Warning')
    if ($r -ne 'Yes') {
        Set-Status 'Desinstallation annulee.' $cMuted
        return
    }
    $pre = Join-Path $scriptDir 'preflight.ps1'
    if (-not (Test-Path $pre)) {
        Set-Status 'preflight.ps1 manquant. Relance l''installeur principal.' $cDanger
        return
    }
    Set-Status 'Desinstallation en cours...' $cGold
    $log = Join-Path $env:LOCALAPPDATA 'TeamSpeakSaltyChatSetup\uninstall.log'
    $p = Start-Process -FilePath 'powershell.exe' -ArgumentList @(
        '-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File', $pre,
        '-UninstallOld', '-LogPath', $log
    ) -Wait -PassThru -WindowStyle Hidden
    if ($p.ExitCode -eq 0) {
        Set-Status 'Tout a ete desinstalle. Tu peux reinstaller via le bouton du haut.' $cCream
    } else {
        Set-Status "Desinstallation terminee avec code $($p.ExitCode). Voir uninstall.log." $cGold
    }
})

$btnOpen.Add_Click({
    $exe = Get-Ts3Exe
    if (-not $exe) {
        Set-Status 'TeamSpeak 3 introuvable. Lance Installer / Reparer.' $cDanger
        return
    }
    Start-Process -FilePath $exe
    Set-Status 'TeamSpeak 3 lance.' $cCream
})

[void]$form.ShowDialog()
exit 0
