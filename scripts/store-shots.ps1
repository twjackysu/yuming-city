# Yuming City - Steam store screenshots on a real Windows PC (D-145).
# Usage: unzip the Windows build, then in that folder run
#   powershell -ExecutionPolicy Bypass -File .\store-shots.ps1
# Output: .\store-shots\en\*.png and .\store-shots\zh_TW\*.png (1920x1080, high quality).
# The shot list is store_shots.txt (name, frames, game flags). Comments start with '#'.
param(
    [string]$Exe = (Join-Path $PSScriptRoot "YumingCity.exe"),
    [string]$List = (Join-Path $PSScriptRoot "store_shots.txt"),
    [string]$Out = (Join-Path $PSScriptRoot "store-shots"),
    [string]$Resolution = "1920x1080",
    [string[]]$Locales = @("en", "zh_TW"),
    [int]$Quality = 2
)
$ErrorActionPreference = "Stop"
if (-not (Test-Path $Exe)) { throw "Game not found: $Exe" }
if (-not (Test-Path $List)) { throw "Shot list not found: $List" }

$lines = Get-Content -Path $List -Encoding UTF8 | Where-Object { $_.Trim() -ne "" -and -not $_.Trim().StartsWith("#") }
$failed = 0
foreach ($locale in $Locales) {
    $dir = Join-Path $Out $locale
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    foreach ($line in $lines) {
        $parts = $line.Trim() -split "\s+"
        $name = $parts[0]
        $frames = $parts[1]
        $flags = @()
        if ($parts.Length -gt 2) { $flags = @($parts[2..($parts.Length - 1)]) }
        if (-not ($flags -match "^--quality=")) { $flags += "--quality=$Quality" }
        $flags += "--locale=$locale"
        $png = Join-Path $dir "$name.png"
        if (Test-Path $png) { Remove-Item $png }
        # Game arguments go after '++' (same as the benchmark command in docs/playtest.md).
        $argList = @("--resolution", $Resolution, "++", "--screenshot=`"$png`"", "--frames=$frames") + $flags
        Write-Host "[$locale] $name ..."
        $p = Start-Process -FilePath $Exe -ArgumentList $argList -Wait -PassThru
        if (Test-Path $png) {
            Write-Host "  -> $png"
        } else {
            Write-Warning "  $name failed (exit code $($p.ExitCode))"
            $failed += 1
        }
    }
}
Write-Host ""
Write-Host "Done. Screenshots are in $Out (failed: $failed)."
