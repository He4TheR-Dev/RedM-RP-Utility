#Requires -Version 5.1
# Clics UI pour l'installeur TS3, la licence client et SaltyChat.

if (-not ('Win32Ui' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;

public class Win32Ui {
  public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr h, EnumProc cb, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowEnabled(IntPtr h);
  [DllImport("user32.dll")] public static extern bool EnableWindow(IntPtr h, bool e);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
  public const uint BM_CLICK = 0x00F5;
  public const uint BM_GETCHECK = 0x00F0;
  public const uint BM_SETCHECK = 0x00F1;
  public const uint WM_CLOSE = 0x0010;
  public const uint WM_VSCROLL = 0x0115;
  public const uint WM_KEYDOWN = 0x0100;
  public const uint WM_KEYUP = 0x0101;
  public const int BST_UNCHECKED = 0;
  public const int BST_CHECKED = 1;
  public const int SB_BOTTOM = 7;
  public const int VK_END = 0x23;
  public const int VK_NEXT = 0x22;
  public static string Text(IntPtr h) {
    var sb = new StringBuilder(1024);
    GetWindowText(h, sb, 1024);
    return sb.ToString();
  }
  public static string Class(IntPtr h) {
    var sb = new StringBuilder(256);
    GetClassName(h, sb, 256);
    return sb.ToString();
  }
}
'@
}

function Get-TopWindows {
    $script:UiTopList = New-Object System.Collections.Generic.List[object]
    $cb = [Win32Ui+EnumProc] {
        param($h, $l)
        $wndPid = [uint32]0
        [void][Win32Ui]::GetWindowThreadProcessId($h, [ref]$wndPid)
        $script:UiTopList.Add([pscustomobject]@{
            Hwnd  = $h
            Pid   = [int]$wndPid
            Title = [Win32Ui]::Text($h)
            Class = [Win32Ui]::Class($h)
        })
        $true
    }
    [Win32Ui]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
    $script:UiTopList
}

function Get-ChildWindows([IntPtr]$Parent) {
    $script:UiChildList = New-Object System.Collections.Generic.List[object]
    $cb = [Win32Ui+EnumProc] {
        param($h, $l)
        $script:UiChildList.Add([pscustomobject]@{
            Hwnd  = $h
            Title = [Win32Ui]::Text($h)
            Class = [Win32Ui]::Class($h)
        })
        $true
    }
    [Win32Ui]::EnumChildWindows($Parent, $cb, [IntPtr]::Zero) | Out-Null
    $script:UiChildList
}

function Test-TextMatch([string]$Text, [string[]]$Patterns) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    foreach ($p in $Patterns) {
        if ($Text -match $p) { return $true }
    }
    return $false
}

function Send-Click([IntPtr]$Hwnd) {
    if ($Hwnd -eq [IntPtr]::Zero) { return }
    [void][Win32Ui]::EnableWindow($Hwnd, $true)
    [void][Win32Ui]::PostMessage($Hwnd, [Win32Ui]::BM_CLICK, [IntPtr]::Zero, [IntPtr]::Zero)
}

function Set-Checkbox([IntPtr]$Hwnd, [bool]$Checked) {
    $want = if ($Checked) { [Win32Ui]::BST_CHECKED } else { [Win32Ui]::BST_UNCHECKED }
    [void][Win32Ui]::SendMessage($Hwnd, [Win32Ui]::BM_SETCHECK, [IntPtr]$want, [IntPtr]::Zero)
    $state = [Win32Ui]::SendMessage($Hwnd, [Win32Ui]::BM_GETCHECK, [IntPtr]::Zero, [IntPtr]::Zero).ToInt32()
    if (($Checked -and $state -eq 0) -or ((-not $Checked) -and $state -ne 0)) {
        Send-Click $Hwnd
    }
}

function Send-ScrollEnd([IntPtr]$Hwnd) {
    [void][Win32Ui]::SendMessage($Hwnd, [Win32Ui]::WM_VSCROLL, [IntPtr][Win32Ui]::SB_BOTTOM, [IntPtr]::Zero)
    foreach ($vk in @([Win32Ui]::VK_NEXT, [Win32Ui]::VK_NEXT, [Win32Ui]::VK_END)) {
        [void][Win32Ui]::PostMessage($Hwnd, [Win32Ui]::WM_KEYDOWN, [IntPtr]$vk, [IntPtr]::Zero)
        [void][Win32Ui]::PostMessage($Hwnd, [Win32Ui]::WM_KEYUP, [IntPtr]$vk, [IntPtr]::Zero)
    }
}

function Invoke-UiaAccept {
    try {
        Add-Type -AssemblyName UIAutomationClient -ErrorAction Stop
        Add-Type -AssemblyName UIAutomationTypes -ErrorAction Stop
        $root = [System.Windows.Automation.AutomationElement]::RootElement
        $wins = $root.FindAll(
            [System.Windows.Automation.TreeScope]::Children,
            [System.Windows.Automation.Condition]::TrueCondition
        )
        foreach ($w in $wins) {
            $name = ''
            try { $name = $w.Current.Name } catch { continue }
            $isTsLicense = Test-TextMatch $name @(
                'Accord de licence', 'License Agreement', 'Privacy statement',
                'Privacy Statement', 'Terms & Conditions'
            )
            $isSalty = Test-TextMatch $name @(
                'Privacy Policy and Terms of Use', 'Salty Chat', 'SaltyChat'
            )
            if (-not $isTsLicense -and -not $isSalty) { continue }

            $all = $w.FindAll(
                [System.Windows.Automation.TreeScope]::Descendants,
                [System.Windows.Automation.Condition]::TrueCondition
            )
            foreach ($el in $all) {
                $id = ''
                $elName = ''
                $ctype = $null
                try {
                    $id = $el.Current.AutomationId
                    $elName = $el.Current.Name
                    $ctype = $el.Current.ControlType
                } catch { continue }

                if ($isSalty -and ($id -eq 'AcceptBox' -or $elName -match 'I read the privacy|Datenschutz|accept the terms')) {
                    try {
                        $tg = $el.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
                        if ($tg.Current.ToggleState -ne [System.Windows.Automation.ToggleState]::On) { $tg.Toggle() }
                    } catch { }
                }
                if ($id -eq 'AcceptButton' -or ($ctype -eq [System.Windows.Automation.ControlType]::Button -and (Test-TextMatch $elName @(
                    "^J'accepte$", '^I accept$', '^I Agree$', '^Accept$', '^OK$', '^Continuer$'
                )))) {
                    try {
                        $hwnd = [IntPtr]$el.Current.NativeWindowHandle
                        if ($hwnd -ne [IntPtr]::Zero) { [void][Win32Ui]::EnableWindow($hwnd, $true) }
                    } catch { }
                    try {
                        $inv = $el.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
                        $inv.Invoke()
                    } catch { }
                }
                if ($ctype -eq [System.Windows.Automation.ControlType]::Document -or $ctype -eq [System.Windows.Automation.ControlType]::Edit) {
                    try {
                        $hwnd = [IntPtr]$el.Current.NativeWindowHandle
                        if ($hwnd -ne [IntPtr]::Zero) { Send-ScrollEnd $hwnd }
                    } catch { }
                }
            }
        }
    } catch { }
}

function Invoke-Ts3SetupUi {
    param([int]$SetupPid)
    $refuse = @('Cancel', 'Annuler', 'Je refuse', 'I Do Not', 'Decline', 'Refuse', 'Back', 'Precedent', 'Précédent')
    $agree  = @('I Agree', "J'accepte", 'I accept', 'Ich stimme zu')
    $install = @('^&?Install$', '^&?Installer$')
    $finish = @('Finish', 'Terminer', 'Fermer')
    $next   = @('Next', 'Suivant', 'Continue')
    $overlay = @('Overwolf', 'overlay', 'Overlay')

    foreach ($w in Get-TopWindows) {
        $title = $w.Title
        if (Test-TextMatch $title @('Overwolf', 'TeamSpeak Overlay', 'OWInstaller')) {
            [void][Win32Ui]::PostMessage($w.Hwnd, [Win32Ui]::WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
            continue
        }
        if (-not (Test-TextMatch $title @('TeamSpeak 3 Client', '^TeamSpeak 3$', 'TeamSpeak 3 Client Setup', 'Installation de TeamSpeak'))) { continue }

        [void][Win32Ui]::ShowWindow($w.Hwnd, 0)
        $children = Get-ChildWindows $w.Hwnd
        foreach ($c in $children) {
            if ($c.Class -match 'Edit|RichEdit|SysListView|SysTreeView') { Send-ScrollEnd $c.Hwnd }
            if ($c.Class -eq 'Button' -and (Test-TextMatch $c.Title $overlay)) {
                Set-Checkbox $c.Hwnd $false
            }
        }
        $clicked = $false
        foreach ($group in @($agree, $install, $finish, $next)) {
            foreach ($c in $children) {
                if ($c.Class -ne 'Button') { continue }
                if (Test-TextMatch $c.Title $refuse) { continue }
                if (Test-TextMatch $c.Title $overlay) { continue }
                if (Test-TextMatch $c.Title $group) {
                    Send-Click $c.Hwnd
                    $clicked = $true
                    break
                }
            }
            if ($clicked) { break }
        }
    }
}

function Test-FirstRunDialogsOpen {
    foreach ($w in Get-TopWindows) {
        if (Test-TextMatch $w.Title @(
            'Accord de licence', 'License Agreement', 'Privacy statement', 'Privacy Statement',
            'Privacy Policy and Terms of Use', 'Salty Chat'
        )) { return $true }
    }
    return $false
}

function Invoke-AcceptFirstRunUi {
    Invoke-UiaAccept
    $refuse = @('^Je refuse$', '^I (Do Not|Decline|Refuse)', '^Cancel$', '^Annuler$', 'navigateur', 'browser')
    $accept = @("^J'accepte$", '^I accept$', '^I Agree$', '^Accept$', '^OK$', '^Continuer$')
    $check  = @('I read the privacy', 'accept the terms', 'Datenschutz', 'Nutzungsbedingungen')

    foreach ($w in Get-TopWindows) {
        $title = $w.Title
        $isTs = Test-TextMatch $title @('Accord de licence', 'License Agreement', 'Privacy statement', 'Privacy Statement', 'Terms & Conditions')
        $isSalty = Test-TextMatch $title @('Privacy Policy and Terms of Use', 'Salty Chat')
        if (-not $isTs -and -not $isSalty) { continue }

        [void][Win32Ui]::SetForegroundWindow($w.Hwnd)
        $children = Get-ChildWindows $w.Hwnd
        if ($children.Count -eq 0) { $children = @([pscustomobject]@{ Hwnd = $w.Hwnd; Title = $title; Class = $w.Class }) }
        foreach ($c in $children) {
            if ($c.Class -match 'Edit|RichEdit|Qt|Scroll') { Send-ScrollEnd $c.Hwnd }
            if (Test-TextMatch $c.Title $check) { Set-Checkbox $c.Hwnd $true }
        }
        foreach ($c in $children) {
            if (Test-TextMatch $c.Title $refuse) { continue }
            if (Test-TextMatch $c.Title $accept) { Send-Click $c.Hwnd }
        }
    }
}
