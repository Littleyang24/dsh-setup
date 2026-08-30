# make-icon.ps1 - generate D:\DSH\assets\dsh.ico (256x256 PNG-compressed ICO)
# ASCII-only on purpose: this script may be parsed by Windows PowerShell 5.1
# under a non-UTF8 system code page, where multi-byte comments can break parsing.
Add-Type -AssemblyName System.Drawing

$outDir = 'D:\DSH\assets'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$pngPath = Join-Path $outDir 'dsh-icon.png'
$icoPath = Join-Path $outDir 'dsh.ico'

$size = 256
$bmp = New-Object System.Drawing.Bitmap($size, $size)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

# rounded-square background (DeepSeek blue)
$blue = [System.Drawing.Color]::FromArgb(255, 77, 107, 254)
$bgBrush = New-Object System.Drawing.SolidBrush($blue)
$radius = 52
$d = $radius * 2
$gp = New-Object System.Drawing.Drawing2D.GraphicsPath
$gp.AddArc(0, 0, $d, $d, 180, 90)
$gp.AddArc($size - $d, 0, $d, $d, 270, 90)
$gp.AddArc($size - $d, $size - $d, $d, $d, 0, 90)
$gp.AddArc(0, $size - $d, $d, $d, 90, 90)
$gp.CloseFigure()
$g.FillPath($bgBrush, $gp)

# white DSH text
$font = New-Object System.Drawing.Font('Segoe UI', 92, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$sf = New-Object System.Drawing.StringFormat
$sf.Alignment = [System.Drawing.StringAlignment]::Center
$sf.LineAlignment = [System.Drawing.StringAlignment]::Center
$rect = New-Object System.Drawing.RectangleF(0, 0, $size, $size)
$g.DrawString('DSH', $font, [System.Drawing.Brushes]::White, $rect, $sf)

$g.Dispose()
$bmp.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

# wrap PNG into a single-entry ICO (PNG entries supported on Windows Vista+)
$pngBytes = [System.IO.File]::ReadAllBytes($pngPath)
$header = New-Object byte[] 22
[BitConverter]::GetBytes([uint16]0).CopyTo($header, 0)
[BitConverter]::GetBytes([uint16]1).CopyTo($header, 2)
[BitConverter]::GetBytes([uint16]1).CopyTo($header, 4)
$header[6] = 0
$header[7] = 0
$header[8] = 0
$header[9] = 0
[BitConverter]::GetBytes([uint16]1).CopyTo($header, 10)
[BitConverter]::GetBytes([uint16]32).CopyTo($header, 12)
[BitConverter]::GetBytes([uint32]$pngBytes.Length).CopyTo($header, 14)
[BitConverter]::GetBytes([uint32]22).CopyTo($header, 18)
$icoBytes = New-Object byte[] ($header.Length + $pngBytes.Length)
$header.CopyTo($icoBytes, 0)
$pngBytes.CopyTo($icoBytes, $header.Length)
[System.IO.File]::WriteAllBytes($icoPath, $icoBytes)

Write-Output "ICO written: $icoPath ($($icoBytes.Length) bytes)"
