Add-Type -AssemblyName System.Drawing
$assets = Split-Path -Parent $MyInvocation.MyCommand.Path
$iconTs = [System.Drawing.Image]::FromFile("$assets\icon-ts.png")
$iconRedm = [System.Drawing.Image]::FromFile("$assets\icon-redm.png")

function Get-RoundRect([int]$x, [int]$y, [int]$rw, [int]$rh, [int]$r) {
  $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $r * 2
  $gp.AddArc($x, $y, $d, $d, 180, 90)
  $gp.AddArc($x + $rw - $d, $y, $d, $d, 270, 90)
  $gp.AddArc($x + $rw - $d, $y + $rh - $d, $d, $d, 0, 90)
  $gp.AddArc($x, $y + $rh - $d, $d, $d, 90, 90)
  $gp.CloseFigure()
  return $gp
}

function New-Card(
  [string]$OutFile,
  [System.Drawing.Image]$Icon,
  [string]$Title,
  [string]$Desc,
  [bool]$On
) {
  $w = 560
  $h = 92
  $bmp = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.Clear([System.Drawing.Color]::FromArgb(20, 12, 8))

  $bg = [System.Drawing.Color]::FromArgb(18, 12, 8)
  $border = if ($On) {
    [System.Drawing.Color]::FromArgb(197, 155, 79)
  } else {
    [System.Drawing.Color]::FromArgb(70, 55, 42)
  }
  $titleC = if ($On) {
    [System.Drawing.Color]::FromArgb(220, 185, 110)
  } else {
    [System.Drawing.Color]::FromArgb(180, 165, 145)
  }
  $descC = if ($On) {
    [System.Drawing.Color]::FromArgb(200, 190, 175)
  } else {
    [System.Drawing.Color]::FromArgb(120, 110, 100)
  }

  $card = Get-RoundRect 2 2 ($w - 4) ($h - 4) 14
  $g.FillPath((New-Object System.Drawing.SolidBrush $bg), $card)
  $g.DrawPath((New-Object System.Drawing.Pen $border, 2), $card)

  $ix = 18; $iy = 21; $isz = 50
  $g.FillEllipse(
    (New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(28, 20, 14))),
    ($ix - 2), ($iy - 2), ($isz + 4), ($isz + 4))
  $g.DrawEllipse((New-Object System.Drawing.Pen $border, 1.5), ($ix - 2), ($iy - 2), ($isz + 4), ($isz + 4))

  $clip = New-Object System.Drawing.Drawing2D.GraphicsPath
  $clip.AddEllipse($ix, $iy, $isz, $isz)
  $state = $g.Save()
  $g.SetClip($clip)
  $g.DrawImage($Icon, $ix, $iy, $isz, $isz)
  $g.Restore($state)
  $clip.Dispose()

  $fontTitle = New-Object System.Drawing.Font 'Georgia', 11, ([System.Drawing.FontStyle]::Bold)
  $fontDesc = New-Object System.Drawing.Font 'Segoe UI', 8
  $g.DrawString($Title, $fontTitle, (New-Object System.Drawing.SolidBrush $titleC), 80, 18)
  $sf = New-Object System.Drawing.StringFormat
  $sf.Trimming = [System.Drawing.StringTrimming]::EllipsisWord
  $rect = New-Object System.Drawing.RectangleF 80, 44, ($w - 180), 40
  $g.DrawString($Desc, $fontDesc, (New-Object System.Drawing.SolidBrush $descC), $rect, $sf)

  $badgeText = if ($On) { 'ACTIVE' } else { 'OFF' }
  $badgeBg = if ($On) {
    [System.Drawing.Color]::FromArgb(197, 155, 79)
  } else {
    [System.Drawing.Color]::FromArgb(48, 38, 30)
  }
  $badgeFg = if ($On) {
    [System.Drawing.Color]::FromArgb(18, 12, 8)
  } else {
    [System.Drawing.Color]::FromArgb(140, 130, 120)
  }
  $fontBadge = New-Object System.Drawing.Font 'Segoe UI', 8, ([System.Drawing.FontStyle]::Bold)
  $sz = $g.MeasureString($badgeText, $fontBadge)
  $bw = [int]($sz.Width + 16)
  $bh = [int]($sz.Height + 6)
  $bx = $w - $bw - 14
  $by = 12
  $badge = Get-RoundRect $bx $by $bw $bh 8
  $g.FillPath((New-Object System.Drawing.SolidBrush $badgeBg), $badge)
  $g.DrawString($badgeText, $fontBadge, (New-Object System.Drawing.SolidBrush $badgeFg), ($bx + 8), ($by + 3))
  $badge.Dispose()
  $card.Dispose()

  $pngPath = Join-Path $assets $OutFile
  $bmp.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Save([IO.Path]::ChangeExtension($pngPath, '.bmp'), [System.Drawing.Imaging.ImageFormat]::Bmp)
  $g.Dispose()
  $bmp.Dispose()
  Write-Host "Wrote $pngPath"
}

New-Card 'card-ts-on.png' $iconTs 'Anciennes versions' 'Desinstalle TeamSpeak, SaltyChat et Overwolf pour repartir propre.' $true
New-Card 'card-ts-off.png' $iconTs 'Anciennes versions' 'Desinstalle TeamSpeak, SaltyChat et Overwolf pour repartir propre.' $false
New-Card 'card-redm-on.png' $iconRedm 'Cache RedM' 'Vide Logs, Crashes et Data. Ferme RedM si ouvert. Conserve game-storage.' $true
New-Card 'card-redm-off.png' $iconRedm 'Cache RedM' 'Vide Logs, Crashes et Data. Ferme RedM si ouvert. Conserve game-storage.' $false

$iconTs.Dispose()
$iconRedm.Dispose()
Get-ChildItem $assets -Filter 'card-*' | Format-Table Name, Length
