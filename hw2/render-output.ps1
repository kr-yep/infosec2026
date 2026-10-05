# Render the untouched ASCII output; this is not a terminal screenshot.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$rows = [IO.File]::ReadAllLines((Join-Path $PSScriptRoot 'output/ascii-art.txt'))
$font = [Drawing.Font]::new('Consolas', 14, [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Pixel)
$bitmap = [Drawing.Bitmap]::new(870, 820)
$graphics = [Drawing.Graphics]::FromImage($bitmap)
$format = [Drawing.StringFormat]::GenericTypographic.Clone()
try {
    $graphics.Clear([Drawing.Color]::White)
    $graphics.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $format.FormatFlags = $format.FormatFlags -bor [Drawing.StringFormatFlags]::MeasureTrailingSpaces
    for ($i = 0; $i -lt $rows.Count; $i++) {
        $graphics.DrawString($rows[$i], $font, [Drawing.Brushes]::Black, [Drawing.PointF]::new(15, (10 + $i * 16)), $format)
    }
    $bitmap.Save((Join-Path $PSScriptRoot 'output/ascii-art.png'), [Drawing.Imaging.ImageFormat]::Png)
} finally {
    $format.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
    $font.Dispose()
}
