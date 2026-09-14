# make_icon.ps1 — генерирует иконку: силуэт T-Rex + круг таймера (BMP-кадры 16/32/48/256)
Add-Type -AssemblyName System.Drawing

$Script:Scale = 1.0
function S([int]$v) { [int][Math]::Round($v * $Script:Scale) }

function Draw-Icon([int]$px) {
    $Script:Scale = $px / 256.0
    $bmp = New-Object System.Drawing.Bitmap($px, $px)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.Clear([System.Drawing.Color]::Transparent)

    # тёмная скруглённая плитка
    $tile = New-Object System.Drawing.Drawing2D.GraphicsPath
    $r = S 48; $x = S 8; $y = S 8; $w = S 240; $h = S 240
    $tile.AddArc($x, $y, $r, $r, 180, 90); $tile.AddArc(($x + $w - $r), $y, $r, $r, 270, 90)
    $tile.AddArc(($x + $w - $r), ($y + $h - $r), $r, $r, 0, 90); $tile.AddArc($x, ($y + $h - $r), $r, $r, 90, 90)
    $tile.CloseFigure()
    $g.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 32, 32, 40))), $tile)

    # силуэт T-Rex (смотрит вправо): морда-спина-хвост-ноги-лапка-челюсть
    $raw = @(
        150,45,  112,42,  96,55,  78,72,  40,66,  14,58,  34,88,  64,96,
        58,116,  52,150,  72,150,  66,116,  84,120,  88,146,  106,146,  98,118,
        104,96,  114,88,  126,92,  118,100,  112,104,  124,72,  148,62
    )
    $pts = New-Object 'System.Drawing.PointF[]' ($raw.Count / 2)
    for ($i = 0; $i -lt $pts.Count; $i++) {
        $pts[$i] = New-Object System.Drawing.PointF((S $raw[$i * 2]), (S $raw[$i * 2 + 1]))
    }
    $dino = New-Object System.Drawing.Drawing2D.GraphicsPath
    $dino.AddPolygon($pts)
    $accent = [System.Drawing.Color]::FromArgb(255, 127, 180, 255)
    $g.FillPath((New-Object System.Drawing.SolidBrush($accent)), $dino)
    # глаз
    $eyePx = [Math]::Max(3, (S 10))
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 32, 32, 40))), (S 116), (S 50), $eyePx, $eyePx)

    # таймер обратного отсчёта: белый круг + оранжевые стрелки
    $penWhite = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 235, 235, 240), [Math]::Max(2, (S 7)))
    $penHand  = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 255, 179, 102), [Math]::Max(2, (S 6)))
    $g.DrawEllipse($penWhite, (S 150), (S 110), (S 96), (S 96))
    $cx = S 198; $cy = S 158
    $g.DrawLine($penHand, $cx, $cy, $cx, (S 126))          # минутная вверх
    $g.DrawLine($penHand, $cx, $cy, (S 224), (S 170))      # часовая вправо-вниз
    $dotPx = [Math]::Max(3, (S 8))
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 255, 179, 102))), (S 194), (S 154), $dotPx, $dotPx)

    $g.Dispose()
    return $bmp
}

function Frame-Bytes([System.Drawing.Bitmap]$bmp) {
    $w = $bmp.Width; $h = $bmp.Height
    $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
    $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $stride = $data.Stride
    $raw = [byte[]]::new($stride * $h)
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $raw, 0, $raw.Length)
    $bmp.UnlockBits($data)

    $andRow = [Math]::Floor(($w + 31) / 32) * 4
    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)
    $bw.Write([uint32]40); $bw.Write([int32]$w); $bw.Write([int32]($h * 2))
    $bw.Write([uint16]1); $bw.Write([uint16]32); $bw.Write([uint32]0)
    $bw.Write([uint32]($h * $andRow))
    $bw.Write([int32]0); $bw.Write([int32]0); $bw.Write([uint32]0); $bw.Write([uint32]0)
    for ($yy = $h - 1; $yy -ge 0; $yy--) {
        for ($xx = 0; $xx -lt $w; $xx++) {
            $o = $yy * $stride + $xx * 4
            $bw.Write($raw[$o]); $bw.Write($raw[$o + 1]); $bw.Write($raw[$o + 2]); $bw.Write($raw[$o + 3])
        }
    }
    $zeros = [byte[]]::new($andRow * $h)
    $bw.Write($zeros)
    $bw.Flush()
    return , ($ms.ToArray())
}

$sizes = @(16, 32, 48, 256)
$frames = @()
foreach ($s in $sizes) {
    $bytes = Frame-Bytes (Draw-Icon $s)
    $frames += , @{ W = $s; Data = $bytes }
}

$out = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter($out)
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$frames.Count)
$offset = 6 + 16 * $frames.Count
for ($i = 0; $i -lt $frames.Count; $i++) {
    $f = $frames[$i]
    $dim = if ($f.W -ge 256) { 0 } else { $f.W }
    $bw.Write([byte]$dim); $bw.Write([byte]$dim); $bw.Write([byte]0); $bw.Write([byte]0)
    $bw.Write([uint16]1); $bw.Write([uint16]32)
    $bw.Write([uint32]$f.Data.Length); $bw.Write([uint32]$offset)
    $offset += $f.Data.Length
}
foreach ($f in $frames) { $bw.Write($f.Data) }

$bw.Flush()
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
[IO.File]::WriteAllBytes((Join-Path $dir 'T-REX.ico'), $out.ToArray())
Write-Output ("ico: " + (Get-Item (Join-Path $dir 'T-REX.ico')).Length + " bytes")
