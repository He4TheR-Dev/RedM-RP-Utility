#Requires -Version 5.1
param(
    [Parameter(Mandatory = $true)][string]$OutFile
)

try {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class NativeConsole {
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("kernel32.dll")] public static extern bool FreeConsole();
}
'@ -ErrorAction SilentlyContinue
    $hwnd = [NativeConsole]::GetConsoleWindow()
    if ($hwnd -ne [IntPtr]::Zero) {
        [void][NativeConsole]::ShowWindow($hwnd, 0)
        [void][NativeConsole]::FreeConsole()
    }
} catch { }

if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    $p = Start-Process -FilePath 'powershell.exe' -ArgumentList @(
        '-NoLogo','-NoProfile','-WindowStyle','Hidden','-STA','-ExecutionPolicy','Bypass',
        '-File', $MyInvocation.MyCommand.Path,
        '-OutFile', $OutFile
    ) -Wait -WindowStyle Hidden -PassThru
    exit $p.ExitCode
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

if (-not ('AudioDefaults' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class AudioDefaults {
  [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
  private class MMDeviceEnumeratorCom { }

  [Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  private interface IMMDeviceEnumerator {
    int NotImpl1();
    [PreserveSig] int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice ppDevice);
  }

  [Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  private interface IMMDevice {
    [PreserveSig] int Activate(ref Guid iid, int dwClsCtx, IntPtr pActivationParams, out IntPtr ppInterface);
    [PreserveSig] int OpenPropertyStore(int stgmAccess, out IntPtr ppProperties);
    [PreserveSig] int GetId([MarshalAs(UnmanagedType.LPWStr)] out string ppstrId);
  }

  public static string GetDefaultId(bool capture, int role) {
    try {
      var en = (IMMDeviceEnumerator)(object)new MMDeviceEnumeratorCom();
      IMMDevice dev;
      int hr = en.GetDefaultAudioEndpoint(capture ? 1 : 0, role, out dev);
      if (hr != 0 || dev == null) return null;
      string id;
      hr = dev.GetId(out id);
      if (hr != 0) return null;
      return id;
    } catch { return null; }
  }
}
'@
}

function Get-PropString([Microsoft.Win32.RegistryKey]$Props, [string]$Name) {
    try {
        $v = $Props.GetValue($Name)
        if ($v -is [string] -and $v.Trim().Length -gt 0) { return [string]$v }
    } catch { }
    return $null
}

function Get-AudioDevices([bool]$Capture) {
    $flow = if ($Capture) { 'Capture' } else { 'Render' }
    $prefix = if ($Capture) { '{0.0.1.00000000}.' } else { '{0.0.0.00000000}.' }
    $list = New-Object System.Collections.Generic.List[object]
    $list.Add([pscustomobject]@{
        Title    = 'Par defaut (Windows)'
        Adapter  = 'Utilise le peripherique par defaut du systeme'
        Status   = 'Recommande si tu ne sais pas'
        Label    = 'Par defaut (Windows)'
        Name     = 'Par defaut (Windows)'
        Id       = ''
        SortKey  = '0'
        IsDefault = $true
    })

    $defConsole = $null
    $defComm = $null
    try {
        $defConsole = [AudioDefaults]::GetDefaultId($Capture, 0)
        $defComm = [AudioDefaults]::GetDefaultId($Capture, 2)
    } catch { }

    $root = "SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\$flow"
    try {
        $hive = [Microsoft.Win32.Registry]::LocalMachine
        $flowKey = $hive.OpenSubKey($root)
        if ($flowKey) {
            try {
                foreach ($guid in $flowKey.GetSubKeyNames()) {
                    $devKey = $flowKey.OpenSubKey($guid)
                    if (-not $devKey) { continue }
                    $state = 0
                    $props = $null
                    try {
                        $state = [int]($devKey.GetValue('DeviceState'))
                        if (($state -band 1) -ne 1) { continue }
                        $props = $devKey.OpenSubKey('Properties')
                        if (-not $props) { continue }
                        $title = Get-PropString $props '{a45c254e-df1c-4efd-8020-67d146a850e0},2'
                        $adapter = Get-PropString $props '{b3f8fa53-0004-438e-9003-51a46e139bfc},6'
                        if (-not $title) { continue }
                        $wasapi = if ($Capture) { "{0.0.1.00000000}.$guid" } else { "{0.0.0.00000000}.$guid" }

                        $isDef = $false
                        $isComm = $false
                        if ($defConsole -and ($defConsole -match [regex]::Escape($guid))) { $isDef = $true }
                        if ($defComm -and ($defComm -match [regex]::Escape($guid))) { $isComm = $true }

                        $statusParts = New-Object System.Collections.Generic.List[string]
                        if ($isDef) { [void]$statusParts.Add('Appareil par defaut') }
                        if ($isComm) { [void]$statusParts.Add('Appareil de communication par defaut') }
                        if ($statusParts.Count -eq 0) { [void]$statusParts.Add('Active') }
                        $status = ($statusParts -join ' | ')

                        if (-not $adapter) { $adapter = 'Peripherique audio' }
                        $label = "$title - $adapter"
                        if ($isDef -or $isComm) { $label = "$label [$status]" }
                        $displayName = if ($adapter) { "$title ($adapter)" } else { $title }
                        $sort = if ($isDef) { '1' } elseif ($isComm) { '2' } else { '3' }

                        $list.Add([pscustomobject]@{
                            Title     = $title
                            Adapter   = $adapter
                            Status    = $status
                            Label     = $label
                            Name      = $displayName
                            Id        = $wasapi
                            SortKey   = $sort
                            IsDefault = $false
                        })
                    } finally {
                        if ($props) { $props.Close() }
                        $devKey.Close()
                    }
                }
            } finally { $flowKey.Close() }
        }
    } catch { }

    $ordered = New-Object System.Collections.Generic.List[object]
    $ordered.Add($list[0])
    $list | Select-Object -Skip 1 | Sort-Object SortKey, Title, Adapter | ForEach-Object { [void]$ordered.Add($_) }
    return $ordered
}

$mics = Get-AudioDevices $true
$spks = Get-AudioDevices $false

$script:PttVk = 0
$script:PttName = ''
$script:PttKind = 'Keyboard'
$script:Waiting = $false

$fontTitle = 'Georgia'
$fontUi = 'Segoe UI'
$cBg     = [System.Drawing.Color]::FromArgb(20, 12, 6)
$cGold   = [System.Drawing.Color]::FromArgb(212, 168, 74)
$cCream  = [System.Drawing.Color]::FromArgb(243, 230, 200)
$cMuted  = [System.Drawing.Color]::FromArgb(176, 150, 118)
$cRust   = [System.Drawing.Color]::FromArgb(139, 40, 22)
$cPanel  = [System.Drawing.Color]::FromArgb(42, 24, 14)
$cInk    = [System.Drawing.Color]::FromArgb(20, 12, 6)
$cRow    = [System.Drawing.Color]::FromArgb(32, 20, 12)
$cRowSel = [System.Drawing.Color]::FromArgb(64, 40, 18)

$form = New-Object System.Windows.Forms.Form
$form.Text = 'RedM RP Utility'
$form.Size = New-Object System.Drawing.Size(720, 680)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'None'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.BackColor = $cBg
$form.ForeColor = $cCream
$form.KeyPreview = $true
$form.TopMost = $true
$form.DoubleBuffered = $true

# Same background as the main app (relative Assets next to tools or app root)
$bgCandidates = @(
    (Join-Path (Split-Path $PSScriptRoot -Parent) 'Assets\background_redm.png'),
    (Join-Path $PSScriptRoot '..\Assets\background_redm.png'),
    (Join-Path $PSScriptRoot 'background_redm.png')
)
foreach ($bgPath in $bgCandidates) {
    if (Test-Path $bgPath) {
        try {
            $form.BackgroundImage = [System.Drawing.Image]::FromFile($bgPath)
            $form.BackgroundImageLayout = 'Zoom'
            break
        } catch { }
    }
}

function New-Label($text, $x, $y) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text
    $l.Location = New-Object System.Drawing.Point($x, $y)
    $l.AutoSize = $true
    $l.Font = New-Object System.Drawing.Font($fontTitle, 10, [System.Drawing.FontStyle]::Bold)
    $l.ForeColor = $cGold
    return $l
}

function New-DeviceList($x, $y, $w, $h, $items) {
    $lb = New-Object System.Windows.Forms.ListBox
    $lb.Location = New-Object System.Drawing.Point($x, $y)
    $lb.Size = New-Object System.Drawing.Size($w, $h)
    $lb.DrawMode = 'OwnerDrawFixed'
    $lb.ItemHeight = 46
    $lb.IntegralHeight = $false
    $lb.BorderStyle = 'FixedSingle'
    $lb.BackColor = $cPanel
    $lb.ForeColor = $cCream
    $lb.Font = New-Object System.Drawing.Font($fontUi, 9.5)
    foreach ($it in $items) { [void]$lb.Items.Add($it) }

    $lb.Add_DrawItem({
        param($sender, $e)
        if ($e.Index -lt 0) { return }
        $item = $sender.Items[$e.Index]
        $selected = (($e.State -band [System.Windows.Forms.DrawItemState]::Selected) -ne 0)
        $bg = if ($selected) { $cRowSel } else { $cRow }
        $e.Graphics.FillRectangle((New-Object System.Drawing.SolidBrush $bg), $e.Bounds)
        $pad = 8
        $titleRect = New-Object System.Drawing.Rectangle(($e.Bounds.X + $pad), ($e.Bounds.Y + 4), ($e.Bounds.Width - 16), 20)
        $subRect = New-Object System.Drawing.Rectangle(($e.Bounds.X + $pad), ($e.Bounds.Y + 24), ($e.Bounds.Width - 16), 18)
        $titleFont = New-Object System.Drawing.Font($fontUi, 10, [System.Drawing.FontStyle]::Bold)
        $subFont = New-Object System.Drawing.Font($fontUi, 8.5)
        $titleBrush = New-Object System.Drawing.SolidBrush $cCream
        $subBrush = New-Object System.Drawing.SolidBrush $(if ($selected) { $cGold } else { $cMuted })
        $titleText = [string]$item.Title
        $subText = ("{0}  |  {1}" -f $item.Adapter, $item.Status)
        [System.Windows.Forms.TextRenderer]::DrawText($e.Graphics, $titleText, $titleFont, $titleRect, $cCream, [System.Windows.Forms.TextFormatFlags]::EndEllipsis)
        [System.Windows.Forms.TextRenderer]::DrawText($e.Graphics, $subText, $subFont, $subRect, $(if ($selected) { $cGold } else { $cMuted }), [System.Windows.Forms.TextFormatFlags]::EndEllipsis)
        $e.DrawFocusRectangle()
    })
    return $lb
}

$title = New-Object System.Windows.Forms.Label
$title.Text = 'Micro, casque et touche Push-To-Talk'
$title.Location = New-Object System.Drawing.Point(24, 16)
$title.Size = New-Object System.Drawing.Size(670, 28)
$title.Font = New-Object System.Drawing.Font($fontTitle, 13, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = $cGold

$hint = New-Object System.Windows.Forms.Label
$hint.Text = 'Meme detail que Windows : nom + materiel + statut. Choisis bien Game / Voice / Mic pour ne pas te tromper.'
$hint.Location = New-Object System.Drawing.Point(24, 44)
$hint.Size = New-Object System.Drawing.Size(670, 22)
$hint.Font = New-Object System.Drawing.Font($fontUi, 8.5)
$hint.ForeColor = $cMuted

$lstMic = New-DeviceList 24 96 670 150 $mics
$lstSpk = New-DeviceList 24 286 670 150 $spks

function Select-Preferred($listBox, $items, $patterns) {
    foreach ($pattern in $patterns) {
        for ($i = 0; $i -lt $items.Count; $i++) {
            $hay = "$($items[$i].Title) $($items[$i].Adapter) $($items[$i].Name)"
            if ($hay -match $pattern) {
                $listBox.SelectedIndex = $i
                return
            }
        }
    }
    if ($listBox.Items.Count -gt 0) { $listBox.SelectedIndex = 0 }
}
Select-Preferred $lstMic $mics @('A50.*Chat', 'A50.*Mic', 'Microphone.*A50', 'A50 X')
Select-Preferred $lstSpk $spks @('A50.*Voice', 'Casque pour t.+phone.*A50', 'A50.*Game')

$btnPtt = New-Object System.Windows.Forms.Button
$btnPtt.Location = New-Object System.Drawing.Point(24, 470)
$btnPtt.Size = New-Object System.Drawing.Size(670, 40)
$btnPtt.FlatStyle = 'Flat'
$btnPtt.FlatAppearance.BorderColor = $cGold
$btnPtt.BackColor = $cPanel
$btnPtt.ForeColor = $cGold
$btnPtt.Font = New-Object System.Drawing.Font($fontTitle, 10, [System.Drawing.FontStyle]::Bold)
$btnPtt.Text = 'Cliquer ici, puis appuyer sur la touche Push-To-Talk'

$lblPtt = New-Object System.Windows.Forms.Label
$lblPtt.Location = New-Object System.Drawing.Point(24, 516)
$lblPtt.Size = New-Object System.Drawing.Size(670, 28)
$lblPtt.Font = New-Object System.Drawing.Font($fontUi, 10)
$lblPtt.ForeColor = $cMuted
$lblPtt.Text = 'Aucune touche assignee'

$btnOk = New-Object System.Windows.Forms.Button
$btnOk.Text = 'Continuer'
$btnOk.Location = New-Object System.Drawing.Point(464, 558)
$btnOk.Size = New-Object System.Drawing.Size(110, 34)
$btnOk.FlatStyle = 'Flat'
$btnOk.BackColor = $cGold
$btnOk.ForeColor = $cInk
$btnOk.Font = New-Object System.Drawing.Font($fontTitle, 10, [System.Drawing.FontStyle]::Bold)
$btnOk.Enabled = $false

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = 'Annuler'
$btnCancel.Location = New-Object System.Drawing.Point(584, 558)
$btnCancel.Size = New-Object System.Drawing.Size(110, 34)
$btnCancel.FlatStyle = 'Flat'
$btnCancel.BackColor = $cRust
$btnCancel.ForeColor = $cCream
$btnCancel.Font = New-Object System.Drawing.Font($fontUi, 10)

function Update-OkEnabled {
    $btnOk.Enabled = ($lstMic.SelectedIndex -ge 0 -and $lstSpk.SelectedIndex -ge 0 -and $script:PttVk -gt 0)
}

function Set-Ptt($vk, $name, $kind) {
    $script:PttVk = [int]$vk
    $script:PttName = $name
    $script:PttKind = $kind
    $script:Waiting = $false
    $lblPtt.Text = "Touche : $name"
    $lblPtt.ForeColor = $cGold
    $btnPtt.Text = 'Changer la touche Push-To-Talk'
    Update-OkEnabled
    $form.Cursor = [System.Windows.Forms.Cursors]::Default
}

$lstMic.Add_SelectedIndexChanged({ Update-OkEnabled })
$lstSpk.Add_SelectedIndexChanged({ Update-OkEnabled })

$btnPtt.Add_Click({
    $script:Waiting = $true
    $btnPtt.Text = 'En attente... appuie sur une touche ou un bouton souris'
    $form.Cursor = [System.Windows.Forms.Cursors]::Cross
    $btnPtt.Focus()
})

$form.Add_KeyDown({
    param($sender, $e)
    if (-not $script:Waiting) { return }
    if ($e.KeyCode -eq 'Escape') {
        $script:Waiting = $false
        $btnPtt.Text = 'Cliquer ici, puis appuyer sur la touche Push-To-Talk'
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        return
    }
    Set-Ptt ([int]$e.KeyCode) $e.KeyCode.ToString() 'Keyboard'
    $e.Handled = $true
})

$mouseHandler = {
    param($sender, $e)
    if (-not $script:Waiting) { return }
    $map = @{
        Left     = @{ Vk = 1; Name = 'Souris gauche'; Kind = 'MouseButton1' }
        Right    = @{ Vk = 2; Name = 'Souris droite'; Kind = 'MouseButton2' }
        Middle   = @{ Vk = 4; Name = 'Souris molette'; Kind = 'MouseButton3' }
        XButton1 = @{ Vk = 5; Name = 'Souris laterale 4'; Kind = 'MouseButton4' }
        XButton2 = @{ Vk = 6; Name = 'Souris laterale 5'; Kind = 'MouseButton5' }
    }
    $info = $map[$e.Button.ToString()]
    if ($info) { Set-Ptt $info.Vk $info.Name $info.Kind }
}

$btnOk.Add_Click({
    if ($lstMic.SelectedIndex -lt 0 -or $lstSpk.SelectedIndex -lt 0 -or $script:PttVk -le 0) { return }
    $mic = $mics[$lstMic.SelectedIndex]
    $spk = $spks[$lstSpk.SelectedIndex]
    $ini = @"
MicName=$($mic.Name)
MicId=$($mic.Id)
SpkName=$($spk.Name)
SpkId=$($spk.Id)
PttVk=$($script:PttVk)
PttName=$($script:PttName)
PttKind=$($script:PttKind)
"@
    [IO.File]::WriteAllText($OutFile, $ini, [Text.UTF8Encoding]::new($false))
    $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Close()
})
$btnCancel.Add_Click({ $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel; $form.Close() })

$form.Controls.AddRange(@(
    $title, $hint,
    (New-Label 'Microphone' 24 72), $lstMic,
    (New-Label 'Casque / sortie' 24 262), $lstSpk,
    (New-Label 'Push-To-Talk' 24 446), $btnPtt, $lblPtt,
    $btnOk, $btnCancel
))
$form.AcceptButton = $btnOk
$form.CancelButton = $btnCancel
$form.Add_MouseDown($mouseHandler)
foreach ($ctrl in @($form.Controls)) { $ctrl.Add_MouseDown($mouseHandler) }

$result = $form.ShowDialog()
if ($result -eq [System.Windows.Forms.DialogResult]::OK) { exit 0 } else { exit 1 }
