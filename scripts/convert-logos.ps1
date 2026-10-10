# Refresh game textures after editing the source PNG logos.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$null = New-Item -ItemType Directory -Path (Join-Path $root 'src/Media') -Force
foreach ($size in @(32, 64)) {
    $bitmap = [Drawing.Bitmap]::new((Join-Path $root "assets/logo_$size.png"))
    try {
        if ($bitmap.Width -ne $size -or $bitmap.Height -ne $size) { throw "Expected ${size}x${size} source logo" }
        # Uncompressed BGRA, eight alpha bits, top-left origin.
        $bytes = [Collections.Generic.List[byte]]::new()
        $bytes.AddRange([byte[]]@(0,0,2,0,0,0,0,0,0,0,0,0,$size,0,$size,0,32,40))
        for ($y = 0; $y -lt $size; $y++) {
            for ($x = 0; $x -lt $size; $x++) {
                $pixel = $bitmap.GetPixel($x, $y)
                $bytes.AddRange([byte[]]@($pixel.B, $pixel.G, $pixel.R, $pixel.A))
            }
        }
        [IO.File]::WriteAllBytes((Join-Path $root "src/Media/logo_$size.tga"), $bytes.ToArray())
        Write-Output "Refreshed ${size}x${size} logo texture"
    } finally { $bitmap.Dispose() }
}
