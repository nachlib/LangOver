<#
.SYNOPSIS
    Generates all MSIX store assets and screenshots for LangOver.
    Run from the repo root: powershell -ExecutionPolicy Bypass -File scripts\generate-store-assets.ps1
#>

param(
    [string]$OutputDir = (Join-Path (Join-Path (Join-Path $PSScriptRoot "..") "msix") "Assets"),
    [string]$ScreenshotDir = (Join-Path (Join-Path (Join-Path $PSScriptRoot "..") "store") "screenshots")
)

Add-Type -AssemblyName System.Drawing

# Helpers
function New-Bitmap([int]$w, [int]$h) { New-Object System.Drawing.Bitmap $w, $h }
function Save-Png([System.Drawing.Bitmap]$bmp, [string]$path) {
    $dir = Split-Path $path -Parent
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "  Created: $path"
}

function Get-Font([string]$family, [float]$size, [System.Drawing.FontStyle]$style = "Regular") {
    New-Object System.Drawing.Font($family, $size, $style, [System.Drawing.GraphicsUnit]::Pixel)
}

function Draw-RoundedRect([System.Drawing.Graphics]$g, [System.Drawing.Brush]$brush,
                          [float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $path.AddArc($x, $y, $d, $d, 180, 90)
    $path.AddArc(($x+$w-$d), $y, $d, $d, 270, 90)
    $path.AddArc(($x+$w-$d), ($y+$h-$d), $d, $d, 0, 90)
    $path.AddArc($x, ($y+$h-$d), $d, $d, 90, 90)
    $path.CloseFigure()
    $g.FillPath($brush, $path)
    $path.Dispose()
}

function Draw-RoundedRectOutline([System.Drawing.Graphics]$g, [System.Drawing.Pen]$pen,
                                  [float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $path.AddArc($x, $y, $d, $d, 180, 90)
    $path.AddArc(($x+$w-$d), $y, $d, $d, 270, 90)
    $path.AddArc(($x+$w-$d), ($y+$h-$d), $d, $d, 0, 90)
    $path.AddArc($x, ($y+$h-$d), $d, $d, 90, 90)
    $path.CloseFigure()
    $g.DrawPath($pen, $path)
    $path.Dispose()
}

# Colors
$bgColor      = [System.Drawing.Color]::FromArgb(255, 8, 9, 13)
$surfaceColor = [System.Drawing.Color]::FromArgb(255, 16, 18, 26)
$cardColor    = [System.Drawing.Color]::FromArgb(255, 22, 24, 32)
$borderColor  = [System.Drawing.Color]::FromArgb(255, 30, 33, 48)
$accentBlue   = [System.Drawing.Color]::FromArgb(255, 79, 142, 247)
$accentPurple = [System.Drawing.Color]::FromArgb(255, 139, 92, 246)
$greenColor   = [System.Drawing.Color]::FromArgb(255, 34, 211, 160)
$textWhite    = [System.Drawing.Color]::White
$textMuted    = [System.Drawing.Color]::FromArgb(255, 107, 114, 128)
$redColor     = [System.Drawing.Color]::FromArgb(255, 239, 68, 68)

$bgBrush      = New-Object System.Drawing.SolidBrush $bgColor
$surfaceBrush = New-Object System.Drawing.SolidBrush $surfaceColor
$cardBrush    = New-Object System.Drawing.SolidBrush $cardColor
$borderPen    = New-Object System.Drawing.Pen $borderColor, 1
$accentBrush  = New-Object System.Drawing.SolidBrush $accentBlue
$purpleBrush  = New-Object System.Drawing.SolidBrush $accentPurple
$greenBrush   = New-Object System.Drawing.SolidBrush $greenColor
$whiteBrush   = New-Object System.Drawing.SolidBrush $textWhite
$mutedBrush   = New-Object System.Drawing.SolidBrush $textMuted
$redBrush     = New-Object System.Drawing.SolidBrush $redColor

# ===================================================================
#  PART 1: MSIX Logo Assets
# ===================================================================
Write-Host "`n=== Generating MSIX Logo Assets ===" -ForegroundColor Cyan

$logoSizes = @(
    @{ Name="StoreLogo.png";          W=50;  H=50  },
    @{ Name="Square44x44Logo.png";    W=44;  H=44  },
    @{ Name="Square44x44Logo.scale-200.png"; W=88;  H=88  },
    @{ Name="Square71x71Logo.png";    W=71;  H=71  },
    @{ Name="Square150x150Logo.png";  W=150; H=150 },
    @{ Name="Square310x310Logo.png";  W=310; H=310 },
    @{ Name="LargeTitle.png";         W=310; H=310 },
    @{ Name="Wide310x150Logo.png";    W=310; H=150 }
)

foreach ($logo in $logoSizes) {
    $w = $logo.W; $h = $logo.H
    $bmp = New-Bitmap $w $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = "HighQuality"
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    $gradBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.Point 0, 0),
        (New-Object System.Drawing.Point $w, $h),
        $accentBlue, $accentPurple
    )
    $g.FillRectangle($gradBrush, 0, 0, $w, $h)

    $fontSize = [Math]::Max(10, [int]($h * 0.38))
    $font = Get-Font "Segoe UI" $fontSize "Bold"
    $text = [char]0x05E2 + "A"
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = "Center"
    $sf.LineAlignment = "Center"
    $rect = New-Object System.Drawing.RectangleF 0, 0, $w, $h
    $g.DrawString($text, $font, $whiteBrush, $rect, $sf)

    $g.Dispose(); $gradBrush.Dispose(); $font.Dispose(); $sf.Dispose()
    Save-Png $bmp (Join-Path $OutputDir $logo.Name)
}

# ===================================================================
#  PART 2: Store Screenshots (1920 x 1080)
# ===================================================================
Write-Host "`n=== Generating Store Screenshots ===" -ForegroundColor Cyan

$SW = 1920; $SH = 1080

# -- Screenshot 1: Hero - Before and After -------------------------
Write-Host "  Screenshot 1: Before and After..."
$bmp = New-Bitmap $SW $SH
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = "HighQuality"
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.FillRectangle($bgBrush, 0, 0, $SW, $SH)

$titleFont  = Get-Font "Segoe UI" 64 "Bold"
$subFont    = Get-Font "Segoe UI" 28
$codeFont   = Get-Font "Consolas" 44
$labelFont  = Get-Font "Segoe UI" 22
$smallFont  = Get-Font "Segoe UI" 20
$arrowFont  = Get-Font "Segoe UI" 72 "Bold"
$sf = New-Object System.Drawing.StringFormat
$sf.Alignment = "Center"

$g.DrawString("LangOver", $titleFont, $whiteBrush, (New-Object System.Drawing.RectangleF 0, 60, $SW, 80), $sf)
$g.DrawString("Typed in the wrong language? One click to fix it.", $subFont, $mutedBrush, (New-Object System.Drawing.RectangleF 0, 145, $SW, 50), $sf)

$cardW = 680; $cardH = 500; $leftX = 130; $cardY = 260

Draw-RoundedRect $g $cardBrush $leftX $cardY $cardW $cardH 16
$redPen = New-Object System.Drawing.Pen $redColor, 2
Draw-RoundedRectOutline $g $redPen $leftX $cardY $cardW $cardH 16; $redPen.Dispose()
$g.DrawString("BEFORE", $labelFont, $redBrush, ($leftX + 30), ($cardY + 25))

$editorY = $cardY + 75
Draw-RoundedRect $g $surfaceBrush ($leftX+30) $editorY ($cardW-60) 380 8

$wrongLines = @("aktu", "nv aknlj?", "hpr ,uc atu")
$lineY = $editorY + 30
foreach ($line in $wrongLines) {
    $g.DrawString($line, $codeFont, $redBrush, ($leftX + 60), $lineY)
    $lineY += 65
}
$g.DrawString("_", $codeFont, $mutedBrush, ($leftX + 60), $lineY)

$arrowX = $leftX + $cardW + 35
$g.DrawString([char]0x27A1, $arrowFont, $accentBrush, (New-Object System.Drawing.RectangleF $arrowX, 420, 130, 100), $sf)
$g.DrawString("Middle Click", $smallFont, $mutedBrush, (New-Object System.Drawing.RectangleF $arrowX, 520, 130, 40), $sf)

$rightX = $arrowX + 170
Draw-RoundedRect $g $cardBrush $rightX $cardY $cardW $cardH 16
$greenPen = New-Object System.Drawing.Pen $greenColor, 2
Draw-RoundedRectOutline $g $greenPen $rightX $cardY $cardW $cardH 16; $greenPen.Dispose()
$g.DrawString("AFTER", $labelFont, $greenBrush, ($rightX + 30), ($cardY + 25))

$editorY2 = $cardY + 75
Draw-RoundedRect $g $surfaceBrush ($rightX+30) $editorY2 ($cardW-60) 380 8

$hebrewFont = Get-Font "Segoe UI" 44
$correctLines = @(
    [string]([char]0x05E9 + [char]0x05DC + [char]0x05D5 + [char]0x05DD),
    [string]([char]0x05DE + [char]0x05D4 + " " + [char]0x05E9 + [char]0x05DC + [char]0x05D5 + [char]0x05DE + [char]0x05DA + "?"),
    [string]([char]0x05D4 + [char]0x05E4 + [char]0x05E8 + " " + [char]0x05D8 + [char]0x05D5 + [char]0x05D1 + " " + [char]0x05E9 + [char]0x05DC + [char]0x05D9)
)
$sfRtl = New-Object System.Drawing.StringFormat
$sfRtl.FormatFlags = [System.Drawing.StringFormatFlags]::DirectionRightToLeft
$lineY2 = $editorY2 + 30
foreach ($line in $correctLines) {
    $g.DrawString($line, $hebrewFont, $greenBrush, ($rightX + $cardW - 60), $lineY2, $sfRtl)
    $lineY2 += 65
}

$g.DrawString("Free  |  Open Source  |  Zero Dependencies  |  MIT License", $smallFont, $mutedBrush,
    (New-Object System.Drawing.RectangleF 0, 820, $SW, 40), $sf)
$g.FillRectangle($accentBrush, 0, ($SH - 4), $SW, 4)

$g.Dispose(); $titleFont.Dispose(); $subFont.Dispose(); $codeFont.Dispose()
$labelFont.Dispose(); $smallFont.Dispose(); $arrowFont.Dispose(); $hebrewFont.Dispose()
$sf.Dispose(); $sfRtl.Dispose()
Save-Png $bmp (Join-Path $ScreenshotDir "screenshot-1-before-after.png")


# -- Screenshot 2: How It Works - 3 Steps -------------------------
Write-Host "  Screenshot 2: How It Works..."
$bmp = New-Bitmap $SW $SH
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = "HighQuality"
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.FillRectangle($bgBrush, 0, 0, $SW, $SH)

$titleFont = Get-Font "Segoe UI" 56 "Bold"
$stepTitleFont = Get-Font "Segoe UI" 32 "Bold"
$stepDescFont = Get-Font "Segoe UI" 22
$iconFont = Get-Font "Segoe UI" 80
$sf = New-Object System.Drawing.StringFormat
$sf.Alignment = "Center"

$g.DrawString("How It Works", $titleFont, $whiteBrush, (New-Object System.Drawing.RectangleF 0, 70, $SW, 80), $sf)
$g.DrawString("Three simple steps. No configuration needed.", $stepDescFont, $mutedBrush, (New-Object System.Drawing.RectangleF 0, 150, $SW, 40), $sf)

$steps = @(
    @{ Num="1"; Icon=[string][char]0x2328; Title="Select Text"; Desc="Highlight the text that`nwas typed in the`nwrong language" },
    @{ Num="2"; Icon=[string][char]0x25CE; Title="Middle Click"; Desc="Press the mouse`nwheel button on`nthe selected text" },
    @{ Num="3"; Icon=[string][char]0x2714; Title="Done!"; Desc="Text is instantly`nconverted to the`ncorrect language" }
)

$stepCardW = 480; $stepCardH = 560; $stepGap = 50
$totalW = ($stepCardW * 3) + ($stepGap * 2)
$startX = ($SW - $totalW) / 2
$stepY = 260

for ($i = 0; $i -lt $steps.Count; $i++) {
    $sx = $startX + ($i * ($stepCardW + $stepGap))
    $step = $steps[$i]

    Draw-RoundedRect $g $cardBrush $sx $stepY $stepCardW $stepCardH 16
    Draw-RoundedRectOutline $g $borderPen $sx $stepY $stepCardW $stepCardH 16

    $circleSize = 64
    $circleX = $sx + ($stepCardW - $circleSize) / 2
    $circleY2 = $stepY + 35
    $g.FillEllipse($accentBrush, $circleX, $circleY2, $circleSize, $circleSize)
    $numFont = Get-Font "Segoe UI" 36 "Bold"
    $numY = $circleY2 + 2
    $numRect = New-Object System.Drawing.RectangleF $circleX, $numY, $circleSize, $circleSize
    $g.DrawString($step.Num, $numFont, $whiteBrush, $numRect, $sf)
    $numFont.Dispose()

    $iconY = $circleY2 + 90
    $iconRect = New-Object System.Drawing.RectangleF $sx, $iconY, $stepCardW, 100
    $g.DrawString($step.Icon, $iconFont, $mutedBrush, $iconRect, $sf)

    $tY = $circleY2 + 240
    $tRect = New-Object System.Drawing.RectangleF $sx, $tY, $stepCardW, 50
    $g.DrawString($step.Title, $stepTitleFont, $whiteBrush, $tRect, $sf)

    $sfCenter = New-Object System.Drawing.StringFormat
    $sfCenter.Alignment = "Center"
    $sfCenter.LineAlignment = "Near"
    $descY = $circleY2 + 305
    $descRect = New-Object System.Drawing.RectangleF ($sx+20), $descY, ($stepCardW-40), 200
    $g.DrawString($step.Desc, $stepDescFont, $mutedBrush, $descRect, $sfCenter)
    $sfCenter.Dispose()

    if ($i -lt 2) {
        $arrowX2 = $sx + $stepCardW + ($stepGap/2)
        $arrowFont2 = Get-Font "Segoe UI" 36 "Bold"
        $arrowY2 = $stepY + ($stepCardH/2) - 20
        $arrowRect = New-Object System.Drawing.RectangleF ($arrowX2-25), $arrowY2, 50, 50
        $g.DrawString([char]0x27A1, $arrowFont2, $accentBrush, $arrowRect, $sf)
        $arrowFont2.Dispose()
    }
}

$g.FillRectangle($accentBrush, 0, ($SH - 4), $SW, 4)
$g.Dispose(); $titleFont.Dispose(); $stepTitleFont.Dispose(); $stepDescFont.Dispose()
$iconFont.Dispose(); $sf.Dispose()
Save-Png $bmp (Join-Path $ScreenshotDir "screenshot-2-how-it-works.png")


# -- Screenshot 3: Features Overview ------------------------------
Write-Host "  Screenshot 3: Features..."
$bmp = New-Bitmap $SW $SH
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = "HighQuality"
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.FillRectangle($bgBrush, 0, 0, $SW, $SH)

$titleFont = Get-Font "Segoe UI" 52 "Bold"
$featTitleFont = Get-Font "Segoe UI" 26 "Bold"
$featDescFont = Get-Font "Segoe UI" 19
$featIconFont = Get-Font "Segoe UI" 40
$sf = New-Object System.Drawing.StringFormat
$sf.Alignment = "Center"

$g.DrawString("LangOver Features", $titleFont, $whiteBrush, (New-Object System.Drawing.RectangleF 0, 60, $SW, 80), $sf)

$features = @(
    @{ Icon=[string][char]0x26A1; Title="Instant Conversion";  Desc="Converts text in under 200ms.`nNo delay, no lag." },
    @{ Icon=[string][char]0x25C9; Title="Smart Detection";     Desc="Automatically detects if text`nis Hebrew or English." },
    @{ Icon=[string][char]0x25CE; Title="Natural Trigger";     Desc="Middle mouse click - does not`nbreak scrolling or other uses." },
    @{ Icon=[string][char]0x2302; Title="Privacy First";       Desc="100% offline. No data leaves`nyour computer. Ever." },
    @{ Icon=[string][char]0x229E; Title="Zero Dependencies";   Desc="Single EXE, no runtime,`nno installation needed." },
    @{ Icon=[string][char]0x2696; Title="MIT Open Source";     Desc="Fully open source. Inspect,`nmodify, contribute." },
    @{ Icon=[string][char]0x2699; Title="Runs in System Tray"; Desc="Silently runs in background.`nMinimal resource usage." },
    @{ Icon=[string][char]0x2714; Title="Sigstore Signed";     Desc="Cryptographically signed builds.`nVerifiable provenance." }
)

$featCardW = 400; $featCardH = 200; $gapX = 40; $gapY = 30
$cols = 4; $rows = 2
$totalFW = ($cols * $featCardW) + (($cols-1) * $gapX)
$startFX = ($SW - $totalFW) / 2
$startFY = 200

for ($r = 0; $r -lt $rows; $r++) {
    for ($c = 0; $c -lt $cols; $c++) {
        $idx = $r * $cols + $c
        if ($idx -ge $features.Count) { continue }
        $feat = $features[$idx]

        $fx = $startFX + ($c * ($featCardW + $gapX))
        $fy = $startFY + ($r * ($featCardH + $gapY))

        Draw-RoundedRect $g $cardBrush $fx $fy $featCardW $featCardH 12
        Draw-RoundedRectOutline $g $borderPen $fx $fy $featCardW $featCardH 12

        $accentPen = New-Object System.Drawing.Pen $accentBlue, 2
        $g.DrawLine($accentPen, ($fx + 12), $fy, ($fx + $featCardW - 12), $fy)
        $accentPen.Dispose()

        $g.DrawString($feat.Icon, $featIconFont, $accentBrush, ($fx + 20), ($fy + 18))
        $g.DrawString($feat.Title, $featTitleFont, $whiteBrush, ($fx + 20), ($fy + 72))
        $g.DrawString($feat.Desc, $featDescFont, $mutedBrush, ($fx + 20), ($fy + 112))
    }
}

$badgeY = $startFY + ($rows * ($featCardH + $gapY)) + 50
$badgeFont = Get-Font "Segoe UI" 20
$g.DrawString("Windows 10/11  |  x64 and x86  |  VirusTotal: 0/95 Clean  |  GitHub Actions CI/CD", $badgeFont, $mutedBrush,
    (New-Object System.Drawing.RectangleF 0, $badgeY, $SW, 40), $sf)

$g.FillRectangle($accentBrush, 0, ($SH - 4), $SW, 4)
$g.Dispose(); $titleFont.Dispose(); $featTitleFont.Dispose(); $featDescFont.Dispose()
$featIconFont.Dispose(); $badgeFont.Dispose(); $sf.Dispose()
Save-Png $bmp (Join-Path $ScreenshotDir "screenshot-3-features.png")


# -- Screenshot 4: Hebrew Hero ------------------------------------
Write-Host "  Screenshot 4: Hebrew Hero..."
$bmp = New-Bitmap $SW $SH
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = "HighQuality"
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.FillRectangle($bgBrush, 0, 0, $SW, $SH)

$titleFont = Get-Font "Segoe UI" 72 "Bold"
$subFont = Get-Font "Segoe UI" 32
$descFont = Get-Font "Segoe UI" 24

$sfRtl = New-Object System.Drawing.StringFormat
$sfRtl.Alignment = "Center"

$heTitle = [string]([char]0x05D4 + [char]0x05E7 + [char]0x05DC + [char]0x05D3 + [char]0x05EA + " " +
           [char]0x05D1 + [char]0x05E9 + [char]0x05E4 + [char]0x05D4 + " " +
           [char]0x05D4 + [char]0x05DC + [char]0x05D0 + " " +
           [char]0x05E0 + [char]0x05DB + [char]0x05D5 + [char]0x05E0 + [char]0x05D4 + "?")

$g.DrawString($heTitle, $titleFont, $whiteBrush, (New-Object System.Drawing.RectangleF 0, 120, $SW, 100), $sfRtl)

$heSub = "LangOver " + [string]([char]0x05DE + [char]0x05EA + [char]0x05E7 + [char]0x05DF + " " +
         [char]0x05D0 + [char]0x05EA + " " +
         [char]0x05D6 + [char]0x05D4 + " " +
         [char]0x05D1 + [char]0x05DC + [char]0x05D7 + [char]0x05D9 + [char]0x05E6 + [char]0x05D4)
$g.DrawString($heSub, $subFont, $mutedBrush, (New-Object System.Drawing.RectangleF 0, 240, $SW, 60), $sfRtl)

$boxW = 900; $boxH = 420
$boxX = ($SW - $boxW) / 2; $boxY = 360
Draw-RoundedRect $g $surfaceBrush $boxX $boxY $boxW $boxH 20
Draw-RoundedRectOutline $g $borderPen $boxX $boxY $boxW $boxH 20

$wrongFont = Get-Font "Consolas" 48
$g.DrawString("aktu", $wrongFont, $redBrush, ($boxX + 60), ($boxY + 40))
$g.DrawString("ctqw rtc", $wrongFont, $redBrush, ($boxX + 60), ($boxY + 110))
$g.DrawString("nv qtwv", $wrongFont, $redBrush, ($boxX + 60), ($boxY + 180))

$arrowFont3 = Get-Font "Segoe UI" 36 "Bold"
$g.DrawString([char]0x2193, $arrowFont3, $accentBrush, (New-Object System.Drawing.RectangleF $boxX, ($boxY + 245), $boxW, 50), $sfRtl)
$arrowFont3.Dispose()

$correctFont = Get-Font "Segoe UI" 48
$sfRight = New-Object System.Drawing.StringFormat
$sfRight.FormatFlags = [System.Drawing.StringFormatFlags]::DirectionRightToLeft

$hebrew1 = [string]([char]0x05E9 + [char]0x05DC + [char]0x05D5 + [char]0x05DD)
$hebrew2 = [string]([char]0x05D1 + [char]0x05D5 + [char]0x05E7 + [char]0x05E8 + " " + [char]0x05D8 + [char]0x05D5 + [char]0x05D1)
$hebrew3 = [string]([char]0x05DE + [char]0x05D4 + " " + [char]0x05E7 + [char]0x05D5 + [char]0x05E8 + [char]0x05D4)

$g.DrawString($hebrew1, $correctFont, $greenBrush, ($boxX + $boxW - 60), ($boxY + 290), $sfRight)
$g.DrawString($hebrew2, $correctFont, $greenBrush, ($boxX + $boxW - 60), ($boxY + 350), $sfRight)

$heBottom = [string]([char]0x05D7 + [char]0x05D9 + [char]0x05E0 + [char]0x05DE + [char]0x05D9) +
            "  |  " + [string]([char]0x05E7 + [char]0x05D5 + [char]0x05D3 + " " + [char]0x05E4 + [char]0x05EA + [char]0x05D5 + [char]0x05D7) +
            "  |  MIT"
$g.DrawString($heBottom, $descFont, $mutedBrush, (New-Object System.Drawing.RectangleF 0, 860, $SW, 40), $sfRtl)

$g.FillRectangle($accentBrush, 0, ($SH - 4), $SW, 4)
$g.Dispose(); $titleFont.Dispose(); $subFont.Dispose(); $descFont.Dispose()
$wrongFont.Dispose(); $correctFont.Dispose(); $sfRtl.Dispose(); $sfRight.Dispose()
Save-Png $bmp (Join-Path $ScreenshotDir "screenshot-4-hebrew-hero.png")

# Cleanup
$bgBrush.Dispose(); $surfaceBrush.Dispose(); $cardBrush.Dispose()
$borderPen.Dispose(); $accentBrush.Dispose(); $purpleBrush.Dispose()
$greenBrush.Dispose(); $whiteBrush.Dispose(); $mutedBrush.Dispose(); $redBrush.Dispose()

Write-Host "`n=== All assets generated! ===" -ForegroundColor Green
