# Hoja de contactos de las capturas de una prueba: tools\sheet.ps1 -Dir logs\<tag> [-Cols 10] [-From 0 -To 999]
param([string]$Dir, [int]$Cols = 10, [double]$From = 0, [double]$To = 9999, [int]$W = 256, [int]$H = 144)
Add-Type -AssemblyName System.Drawing
$files = Get-ChildItem $Dir -Filter "shot_*.png" | Where-Object { $t = [double]($_.BaseName -replace 'shot_', ''); $t -ge $From -and $t -le $To } | Sort-Object Name
$rows = [math]::Ceiling($files.Count / $Cols)
$sheet = New-Object System.Drawing.Bitmap ($Cols * $W), ($rows * ($H + 16))
$g = [System.Drawing.Graphics]::FromImage($sheet)
$g.Clear([System.Drawing.Color]::Black)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBilinear
$font = New-Object System.Drawing.Font "Consolas", 9
$i = 0
foreach ($f in $files) {
    $img = [System.Drawing.Image]::FromFile($f.FullName)
    $x = ($i % $Cols) * $W; $y = [math]::Floor($i / $Cols) * ($H + 16)
    $g.DrawImage($img, $x, $y + 16, $W, $H)
    $g.DrawString(($f.BaseName -replace 'shot_', '') + "s", $font, [System.Drawing.Brushes]::Yellow, $x + 2, $y + 1)
    $img.Dispose(); $i++
}
$out = Join-Path $Dir "sheet.png"
$sheet.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $sheet.Dispose()
$out
