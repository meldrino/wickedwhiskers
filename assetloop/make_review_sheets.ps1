# Render unseen GLBs through pawstudio and compose two contact-sheet PNGs.
$ErrorActionPreference = 'Continue'
$ww = "C:\crypto\wicked whiskers"
$godot = "C:\crypto\tools\Godot_v4.7.1-stable_win64_console.exe"
$stage = "$ww\assetloop\review_stage"
Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $stage | Out-Null

$models = @(
    @{ n = 'mouse_1';  f = "$ww\assetloop\runs\20260821_011033\mouse_1.glb"; dist = 0.7;  pitch = -20; ty = 0.05 },
    @{ n = 'mouse_2';  f = "$ww\assetloop\runs\20260821_011033\mouse_2.glb"; dist = 0.7;  pitch = -20; ty = 0.05 },
    @{ n = 'mouse_3';  f = "$ww\assetloop\runs\20260821_011033\mouse_3.glb"; dist = 0.7;  pitch = -20; ty = 0.05 },
    @{ n = 'mouse_4';  f = "$ww\assetloop\runs\20260821_011033\mouse_4.glb"; dist = 0.7;  pitch = -20; ty = 0.05 },
    @{ n = 'fish_1';   f = "$ww\assetloop\runs\20260821_011546\fish_1.glb";  dist = 1.0;  pitch = -20; ty = 0.12 },
    @{ n = 'fish_2';   f = "$ww\assetloop\runs\20260821_011546\fish_2.glb";  dist = 1.0;  pitch = -20; ty = 0.12 },
    @{ n = 'fish_3';   f = "$ww\assetloop\runs\20260821_011546\fish_3.glb";  dist = 1.0;  pitch = -20; ty = 0.12 },
    @{ n = 'fish_4';   f = "$ww\assetloop\runs\20260821_011546\fish_4.glb";  dist = 1.0;  pitch = -20; ty = 0.12 },
    @{ n = 'tractor_A';f = "$ww\assetloop\runs\20260821_005426\tractor_1.glb"; dist = 5.5; pitch = -15; ty = 0.9 },
    @{ n = 'tractor_B';f = "$ww\assetloop\runs\20260821_010507\tractor_1.glb"; dist = 5.5; pitch = -15; ty = 0.9 },
    @{ n = 'tractor_C';f = "$ww\assetloop\runs\20260821_010507\tractor_2.glb"; dist = 5.5; pitch = -15; ty = 0.9 },
    @{ n = 'tractor_D';f = "$ww\assetloop\runs\20260821_010507\tractor_3.glb"; dist = 5.5; pitch = -15; ty = 0.9 },
    @{ n = 'tractor_E';f = "$ww\assetloop\runs\20260821_010507\tractor_4.glb"; dist = 5.5; pitch = -15; ty = 0.9 },
    @{ n = 'tractor_F';f = "$ww\assetloop\runs\20260821_010507\tractor_5.glb"; dist = 5.5; pitch = -15; ty = 0.9 }
)

$shot = "$ww\screenshots\assetloop_latest.png"
$done = @()
foreach ($m in $models) {
    if (-not (Test-Path $m.f)) { Write-Output "SKIP $($m.n) (no glb)"; continue }
    $resGlb = 'res://assetloop/runs/' + (Split-Path (Split-Path $m.f) -Leaf) + '/' + (Split-Path $m.f -Leaf)
    @{ model_glb = $resGlb; model_scale = 1.0
       model_rot_x_deg = 0.0; model_rot_y_deg = 0.0; model_rot_z_deg = 0.0
       cam_yaw_deg = 0.0; cam_pitch_deg = $m.pitch; cam_dist = $m.dist; cam_fov = 40.0
       target = @(0, $m.ty, 0.0); bg = @(0.05, 0.06, 0.09)
       key_energy = 1.2; key_yaw_deg = 35.0; key_pitch_deg = -40.0
       fill_energy = 0.5; fill_yaw_deg = 160.0; fill_pitch_deg = -8.0
       rim_energy = 0.6; rim_yaw_deg = -70.0; rim_pitch_deg = 6.0
       control_sphere = $false; out = "assetloop_latest.png" } |
      ConvertTo-Json | Set-Content -LiteralPath "$ww\screenshots\pawstudio_params.json" -Encoding utf8
    Remove-Item -LiteralPath $shot -Force -ErrorAction SilentlyContinue
    $null = & $godot --path $ww "res://scenes/pawstudio.tscn" 2>&1
    if (Test-Path $shot) { Copy-Item $shot "$stage\$($m.n).png" -Force; $done += $m.n; Write-Output "OK $($m.n)" }
    else { Write-Output "FAIL $($m.n)" }
}

# compose contact sheets: 6 tiles per sheet, grid 3x2, tile 420x340 (image 420x300 + label strip)
Add-Type -AssemblyName System.Drawing
function Make-Sheet([object[]]$tiles, [string]$outPath, [string]$title) {
    $tw = 420; $th = 340
    $cols = [Math]::Min(3, $tiles.Count); $rows = [Math]::Ceiling($tiles.Count / $cols)
    $bmp = New-Object System.Drawing.Bitmap ($cols * $tw), (($rows * $th) + 50)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::White)
    $g.DrawString($title, (New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::Black, 10, 10)
    for ($i = 0; $i -lt $tiles.Count; $i++) {
        $x = ($i % $cols) * $tw; $y = [int][Math]::Floor($i / $cols) * $th + 50
        try {
            $img = [System.Drawing.Image]::FromFile($tiles[$i].p)
            $g.DrawImage($img, $x, $y, 420, 300); $img.Dispose()
        } catch {}
        $g.DrawString($tiles[$i].n, (New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)), [System.Drawing.Brushes]::DarkRed, $x + 10, $y + 305)
    }
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    Write-Output "SHEET $outPath"
}
$sheets = @()
for ($s = 0; $s -lt 3; $s++) {
    $tiles = @()
    foreach ($n in ($done | Select-Object -Skip ($s * 6) -First 6)) { $tiles += @{ n = $n; p = "$stage\$n.png" } }
    if ($tiles.Count -eq 0) { continue }
    $out = "$ww\assetloop\review_$($s + 1).png"
    Make-Sheet $tiles $out "WW asset review sheet $($s + 1)/3"
    $sheets += $out
}
Write-Output "DONE: $($done.Count) rendered -> $($sheets -join ', ')"
