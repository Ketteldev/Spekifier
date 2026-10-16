[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$Path)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Path).Path)
try {
    $names = @($archive.Entries | Where-Object { -not $_.FullName.EndsWith('/') } | ForEach-Object { $_.FullName })
    if ($names -cnotcontains 'Spekifier/Spekifier.toc') {
        throw 'Package must contain Spekifier/Spekifier.toc directly under one addon folder.'
    }
    foreach ($name in $names) {
        if ($name -cnotmatch '^Spekifier/[^/]' -or
            $name -match '\\|(^|/)\.\.?(/|$)|\.zip$|^Spekifier/(Spekifier|src)/') {
            throw "Invalid package entry: $name"
        }
    }
    if (@($names | Select-Object -Unique).Count -ne $names.Count) {
        throw 'Package contains duplicate file entries.'
    }
    $reader = [IO.StreamReader]::new($archive.GetEntry('Spekifier/Spekifier.toc').Open())
    try { $manifest = $reader.ReadToEnd() } finally { $reader.Dispose() }
    foreach ($line in ($manifest -split '\r?\n')) {
        $line = $line.Trim()
        if ($line -and -not $line.StartsWith('#')) {
            $entry = 'Spekifier/' + $line.Replace('\', '/')
            if ($names -cnotcontains $entry) { throw "Missing manifest file: $entry" }
        }
    }
    Write-Output "Validated $Path ($($names.Count) files)"
} finally {
    $archive.Dispose()
}
