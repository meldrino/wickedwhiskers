# OVERNIGHT BATCH DRIVER - runs the asset loop across the WW asset queue.
# Writes progress to assetloop\batch_report.md. Stops early if quota looks dead
# (3 consecutive assets producing no GLB at all).
$ErrorActionPreference = 'Continue'
$dir = Split-Path $PSCommandPath
$tick = "C:\crypto\bigpickle\heartbeat-tick.ps1"
$report = "$dir\batch_report.md"
$loop = "$dir\asset_loop.ps1"

function Log([string]$msg) {
    $line = "$(Get-Date -Format 'HH:mm:ss') $msg"
    Add-Content -LiteralPath $report -Value $line -Encoding utf8
    Write-Output $line
}

Set-Content -LiteralPath $report -Value "# overnight batch $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Encoding utf8

$queue = @(
    @{ name = 'tractor';       spec = 'tractor_spec.txt';        dist = 5.5;  pitch = -15; ty = 0.9;  iters = 5 },
    @{ name = 'mouse';         spec = 'mouse_spec.txt';          dist = 0.7;  pitch = -20; ty = 0.05; iters = 4 },
    @{ name = 'fish';          spec = 'fish_spec.txt';           dist = 1.0;  pitch = -20; ty = 0.12; iters = 4 },
    @{ name = 'ball_of_string';spec = 'ball_of_string_spec.txt'; dist = 0.8;  pitch = -20; ty = 0.10; iters = 4 },
    @{ name = 'tractor_keys';  spec = 'tractor_keys_spec.txt';   dist = 0.5;  pitch = -25; ty = 0.04; iters = 4 },
    @{ name = 'stick';         spec = 'stick_spec.txt';          dist = 1.6;  pitch = -25; ty = 0.06; iters = 4 },
    @{ name = 'stone';         spec = 'stone_spec.txt';          dist = 1.2;  pitch = -20; ty = 0.15; iters = 4 },
    @{ name = 'birch';         spec = 'birch_spec.txt';          dist = 8.0;  pitch = -10; ty = 2.0;  iters = 4 },
    @{ name = 'pine';          spec = 'pine_spec.txt';           dist = 9.0;  pitch = -10; ty = 2.2;  iters = 4 },
    @{ name = 'house';         spec = 'house_spec.txt';          dist = 11.0; pitch = -18; ty = 2.2;  iters = 4 },
    @{ name = 'shed_interior'; spec = 'shed_interior_spec.txt';  dist = 5.5;  pitch = -15; ty = 1.0;  iters = 4 }
)

$dryStreak = 0
foreach ($a in $queue) {
    try { & $tick -src big-pickle | Out-Null } catch {}
    Log "=== START $($a.name) ==="
    $out = & pwsh -NoProfile -File $loop `
        -SpecFile "$dir\$($a.spec)" -AssetName $a.name -MaxIters $a.iters `
        -CamDist $a.dist -CamPitch $a.pitch -TargetY $a.ty -ModelScale 1.0 2>&1 |
        Out-String
    $runDir = if ($out -match 'run dir: (\S+)') { $Matches[1] } else { '' }
    $verdict = if ($out -match 'FINAL VERDICT:\s*(\w+)') { $Matches[1] } else { 'NO-VERDICT' }
    $glbCount = 0
    if ($runDir -and (Test-Path $runDir)) { $glbCount = (Get-ChildItem $runDir -Filter *.glb -ErrorAction SilentlyContinue).Count }
    Log "=== DONE $($a.name): verdict=$verdict glbs=$glbCount dir=$runDir ==="
    if ($glbCount -eq 0) { $dryStreak++ } else { $dryStreak = 0 }
    if ($dryStreak -ge 3) { Log "STOPPING: 3 consecutive assets with no GLB - gemini quota likely exhausted."; break }
    Start-Sleep -Seconds 5
}
try { & $tick -src big-pickle | Out-Null } catch {}
Log "BATCH DONE $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
