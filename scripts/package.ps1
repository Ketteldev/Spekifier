<#
.SYNOPSIS
Packages src/ as an installable Spekifier addon. Does not run tests.
.EXAMPLE
./scripts/package.ps1 -OutputPath ./dist/Spekifier.zip
#>
[CmdletBinding()]
param([string]$OutputPath)

$ErrorActionPreference = 'Stop'
if (-not $OutputPath) {
    $OutputPath = Join-Path $PSScriptRoot '../dist/Spekifier.zip'
}
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$sourcePath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../src')).Path
$archivePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
if ($archivePath.Equals($sourcePath, [StringComparison]::OrdinalIgnoreCase) -or
    $archivePath.StartsWith($sourcePath + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Package output must be outside src/.'
}
if (-not (Test-Path -LiteralPath (Join-Path $sourcePath 'Spekifier.toc') -PathType Leaf)) {
    throw 'src/Spekifier.toc is missing.'
}
$null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($archivePath))
$temporaryPath = $archivePath + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
try {
    $archive = [IO.Compression.ZipFile]::Open($temporaryPath, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($file in Get-ChildItem -LiteralPath $sourcePath -Recurse -File -Force | Sort-Object FullName) {
            $relativePath = $file.FullName.Substring($sourcePath.Length + 1).Replace('\', '/')
            $null = [IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $archive, $file.FullName, 'Spekifier/' + $relativePath,
                [IO.Compression.CompressionLevel]::Optimal)
        }
    } finally {
        $archive.Dispose()
    }
    Move-Item -LiteralPath $temporaryPath -Destination $archivePath -Force
} finally {
    if (Test-Path -LiteralPath $temporaryPath) {
        Remove-Item -LiteralPath $temporaryPath
    }
}
Write-Output "Created $archivePath"
