#Requires -Version 5.1
# UI simple pour vider le cache RedM sans reinstaller.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$cleaner = Join-Path $scriptDir 'clean-redm.ps1'
if (-not (Test-Path $cleaner)) {
    [System.Windows.Forms.MessageBox]::Show(
        "Fichier clean-redm.ps1 introuvable.`nRelance l'installeur Vocal Roleplay.",
        'Nettoyer cache RedM', 'OK', 'Error') | Out-Null
    exit 1
}

$cBg = [System.Drawing.Color]::FromArgb(20, 12, 8)
$cPanel = [System.Drawing.Color]::FromArgb(32, 20, 12)
$cGold = [System.Drawing.Color]::FromArgb(212, 168, 74)
$cCream = [System.Drawing.Color]::FromArgb(243, 230, 200)
$cMuted = [System.Drawing.Color]::FromArgb(176, 150, 118)

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Nettoyer cache RedM'
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.ClientSize = New-Object System.Drawing.Size(460, 320)
$form.BackColor = $cBg
$form.Font = New-Object System.Drawing.Font 'Segoe UI', 9

$title = New-Object System.Windows.Forms.Label
$title.Text = 'Cache RedM'
$title.Font = New-Object System.Drawing.Font 'Georgia', 18, ([System.Drawing.FontStyle]::Bold)
$title.ForeColor = $cGold
$title.Location = New-Object System.Drawing.Point 24, 20
$title.AutoSize = $true
$form.Controls.Add($title)

$desc = New-Object System.Windows.Forms.Label
$desc.Text = "Ferme RedM s'il est ouvert, puis vide Logs, Crashes et Data.`nLe dossier game-storage n'est jamais touche."
$desc.ForeColor = $cCream
$desc.Location = New-Object System.Drawing.Point 24, 64
$desc.Size = New-Object System.Drawing.Size 410, 48
$form.Controls.Add($desc)

$panel = New-Object System.Windows.Forms.Panel
$panel.Location = New-Object System.Drawing.Point 24, 120
$panel.Size = New-Object System.Drawing.Size 410, 88
$panel.BackColor = $cPanel
$form.Controls.Add($panel)

$status = New-Object System.Windows.Forms.Label
$status.Text = 'Pret. Un clic suffit, pas besoin de reinstaller.'
$status.ForeColor = $cMuted
$status.Location = New-Object System.Drawing.Point 14, 16
$status.Size = New-Object System.Drawing.Size 380, 56
$status.Font = New-Object System.Drawing.Font 'Segoe UI', 9
$panel.Controls.Add($status)

$btn = New-Object System.Windows.Forms.Button
$btn.Text = 'Nettoyer maintenant'
$btn.Font = New-Object System.Drawing.Font 'Georgia', 11, ([System.Drawing.FontStyle]::Bold)
$btn.BackColor = $cGold
$btn.ForeColor = $cBg
$btn.FlatStyle = 'Flat'
$btn.FlatAppearance.BorderSize = 0
$btn.Size = New-Object System.Drawing.Size 220, 42
$btn.Location = New-Object System.Drawing.Point 24, 230
$form.Controls.Add($btn)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = 'Fermer'
$btnClose.FlatStyle = 'Flat'
$btnClose.FlatAppearance.BorderColor = $cGold
$btnClose.ForeColor = $cCream
$btnClose.BackColor = $cPanel
$btnClose.Size = New-Object System.Drawing.Size 100, 42
$btnClose.Location = New-Object System.Drawing.Point 334, 230
$btnClose.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.Controls.Add($btnClose)
$form.CancelButton = $btnClose

$hint = New-Object System.Windows.Forms.Label
$hint.Text = 'Raccourci aussi disponible sur le Bureau apres installation.'
$hint.ForeColor = $cMuted
$hint.Location = New-Object System.Drawing.Point 24, 282
$hint.AutoSize = $true
$hint.Font = New-Object System.Drawing.Font 'Segoe UI', 8
$form.Controls.Add($hint)

$btn.Add_Click({
    $btn.Enabled = $false
    $btnClose.Enabled = $false
    $status.ForeColor = $cGold
    $status.Text = 'Nettoyage en cours... RedM va se fermer si necessaire.'
    $form.Refresh()
    [System.Windows.Forms.Application]::DoEvents()

    $log = Join-Path $env:LOCALAPPDATA 'TeamSpeakSaltyChatSetup\clean-redm.log'
    $outFile = Join-Path $env:TEMP ("clean-redm-result-{0}.json" -f [guid]::NewGuid().ToString('N'))
    $args = @(
        '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', $cleaner,
        '-LogPath', $log
    )
    $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $args -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $outFile
    $json = $null
    if (Test-Path $outFile) {
        try { $json = Get-Content $outFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch { }
        Remove-Item $outFile -Force -ErrorAction SilentlyContinue
    }

    $btn.Enabled = $true
    $btnClose.Enabled = $true
    $status.ForeColor = $cCream

    if ($p.ExitCode -ne 0 -and -not $json) {
        $status.ForeColor = [System.Drawing.Color]::FromArgb(200, 80, 60)
        $status.Text = "Echec du nettoyage (code $($p.ExitCode)). Voir:`n$log"
        return
    }

    if (-not $json.FoundRoot) {
        $status.Text = "RedM n'est pas installe sur ce PC.`nRien a nettoyer."
        return
    }

    if (-not $json.Cleaned) {
        $status.Text = 'Cache deja propre. game-storage intact.'
        return
    }

    $mb = $json.MegabytesFreed
    $status.Text = "Termine. Environ $mb Mo liberes.`ngame-storage conserve."
})

[void]$form.ShowDialog()
exit 0
