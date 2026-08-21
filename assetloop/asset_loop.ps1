# ASSET LOOP (not to be confused with the Meldrino Forge character-generator product).
# gemini writes bpy -> blender headless builds GLB -> Godot pawstudio screenshots it ->
# gemini judges -> iterate. See worklog 2026-08-21.
[CmdletBinding()]
param(
    [string]$SpecFile = "C:\crypto\wicked whiskers\assetloop\paw_spec.txt",
    [string]$ReferenceImage = "",
    [string]$OutDir = "",
    [int]$MaxIters = 6,
    [string]$Model = 'gemini-flash-latest',
    [string]$AssetName = 'paw',
    [double]$CamDist = 1.1,
    [double]$CamPitch = -10.0,
    [double]$TargetY = 0.0,
    [double]$ModelScale = 1.5,
    [string]$FallbackModel = 'gemini-3.1-flash-lite'
)

$ErrorActionPreference = 'Stop'
$script:CurrentModel = $Model
$styleSheet = Join-Path (Split-Path $PSCommandPath) 'style_sheet.txt'
$blender = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
$godot = "C:\crypto\tools\Godot_v4.7.1-stable_win64_console.exe"
$wwProject = "C:\crypto\wicked whiskers"
$tick = "C:\crypto\bigpickle\heartbeat-tick.ps1"
$inbox = "C:\crypto\bigpickle\inbox-append.ps1"

if (-not (Test-Path $SpecFile)) { Write-Error "SpecFile not found: $SpecFile" }
$key = $env:GEMINI_API_KEY
if ([string]::IsNullOrWhiteSpace($key)) { Write-Error 'GEMINI_API_KEY not set.' }

if (-not $OutDir) { $OutDir = "C:\crypto\wicked whiskers\assetloop\runs\$(Get-Date -Format 'yyyyMMdd_HHmmss')" }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$spec = ''
if (Test-Path $styleSheet) { $spec += (Get-Content -LiteralPath $styleSheet -Raw) + "`n`n" }
$assetBrief = Get-Content -LiteralPath $SpecFile -Raw
$spec += $assetBrief
$report = New-Object System.Collections.Generic.List[string]
$report.Add("# asset loop run $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  model=$Model spec=$(Split-Path $SpecFile -Leaf)")

function Tick([string]$note) {
    try { & $tick -src big-pickle | Out-Null } catch {}
    $line = "$(Get-Date -Format 'HH:mm:ss') $note"
    $report.Add($line)
    Write-Output $line
}

function Log-Inbox([string]$text) {
    try { & $inbox -Expert gemini-assetloop -Project 'wicked whiskers' -Type result -Text $text | Out-Null } catch {}
}

function Invoke-Gemini {
    param([string]$Prompt, [string[]]$Images = @(), [int]$MaxTokens = 32000)
    $parts = @(@{ text = $Prompt })
    foreach ($img in $Images) {
        if ($img -and (Test-Path -LiteralPath $img)) {
            $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path $img)))
            $mime = 'image/png'
            if ($img -like '*.jpg' -or $img -like '*.jpeg') { $mime = 'image/jpeg' }
            if ($img -like '*.webp') { $mime = 'image/webp' }
            $parts += @{ inline_data = @{ mime_type = $mime; data = $b64 } }
        }
    }
    $body = @{
        contents         = @(@{ parts = $parts })
        generationConfig = @{ temperature = 0.5; maxOutputTokens = $MaxTokens }
    } | ConvertTo-Json -Depth 8
    for ($attempt = 1; $attempt -le 6; $attempt++) {
        try {
            $resp = Invoke-RestMethod -Uri "https://generativelanguage.googleapis.com/v1beta/models/$($script:CurrentModel):generateContent?key=$key" `
                -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 300
            return ($resp.candidates[0].content.parts.text -join "`n")
        }
        catch {
            $msg = $_.Exception.Message
            if ($msg -match '429' -or $msg -match 'RESOURCE_EXHAUSTED' -or $msg -match '503' -or $msg -match 'UNAVAILABLE') {
                $wait = 30 * $attempt
                Tick "gemini busy ($($script:CurrentModel)), waiting ${wait}s (attempt $attempt/6)"
                Start-Sleep -Seconds $wait
                # after 3 failed attempts on the primary, drop to the fallback model
                if ($attempt -ge 3 -and $FallbackModel -and $script:CurrentModel -ne $FallbackModel) {
                    $script:CurrentModel = $FallbackModel
                    Tick "switching to fallback model $($script:CurrentModel)"
                }
            }
            else { throw }
        }
    }
    Write-Error 'Gemini failed after retries.'
}

function Get-Script([string]$Text) {
    $matches2 = [regex]::Matches($Text, '(?s)```python\s*(.*?)```')
    foreach ($m in $matches2) { if ($m.Groups[1].Value -match 'bpy') { return $m.Groups[1].Value } }
    $any = [regex]::Matches($Text, '(?s)```\s*(.*?)```')
    foreach ($m in $any) { if ($m.Groups[1].Value -match 'bpy') { return $m.Groups[1].Value } }
    # unfenced fallback: gemini sometimes returns bare code
    $idx = $Text.IndexOf('import bpy')
    if ($idx -ge 0) {
        $code = $Text.Substring($idx)
        $lastPrint = $code.LastIndexOf('print(')
        if ($lastPrint -gt 0) {
            $lineEnd = $code.IndexOf("`n", $lastPrint)
            if ($lineEnd -gt 0) { $code = $code.Substring(0, $lineEnd) }
        }
        return $code
    }
    return $null
}

function Repair-KnownApiBreaks([string]$code) {
    # Blender 5 renamed create_cone diameter1/diameter2 -> radius1/radius2.
    $code = $code -replace 'diameter1\s*=', 'radius1=' -replace 'diameter2\s*=', 'radius2='
    # missing imports gemini keeps forgetting
    if ($code -match '\bmath\.' -and $code -notmatch '(?m)^\s*(import|from)\s+math\b') { $code = "import math`n$code" }
    if ($code -match '\bmathutils\b' -and $code -notmatch '(?m)^\s*(import|from)\s+mathutils\b') { $code = "import mathutils`nfrom mathutils import Vector, Matrix, Euler`n$code" }
    return $code
}

function Run-BlenderBuild([string]$pyPath, [string]$glbPath, [int]$attempt = 0) {
    $py = Get-Content -LiteralPath $pyPath -Raw
    $py = $py.Replace('__GLB_OUT__', ($glbPath -replace '\\', '\\'))
    Set-Content -LiteralPath $pyPath -Value $py -Encoding utf8
    $log = $null
    Push-Location (Split-Path $pyPath)
    try { $log = & $blender --background --python $pyPath 2>&1 } finally { Pop-Location }
    $logText = ($log | Out-String)
    $logSuffix = if ($attempt -gt 0) { "_repair$attempt" } else { "" }
    Set-Content -LiteralPath ($pyPath -replace '\.py$', "${logSuffix}_blender.log") -Value $logText -Encoding utf8
    return @{
        ok     = ((Test-Path $glbPath) -and $logText -match 'ASSET_BUILT|PAW_BUILT|TRACTOR_BUILT')
        log    = $logText
        dims   = if ($logText -match 'DIMS \(([^)]*)\)') { $Matches[1] } elseif ($logText -match 'DIMS Vector\(([^)]*)\)') { $Matches[1] } else { '' }
    }
}

Tick "run dir: $OutDir"

$scriptText = $null
$critique = ''
$verdict = 'FAIL'

for ($i = 1; $i -le $MaxIters; $i++) {
    Tick "=== iteration $i/$MaxIters : generate ==="
    $prompt = $spec
    if ($ReferenceImage -and (Test-Path $ReferenceImage)) {
        $prompt += "`n`n========== STYLE REFERENCE IMAGE ========== `nAn image of the desired look/style is attached. Match this style, quality bar and colour mood. Do not copy its geometry mistakes."
    }
    if ($critique) {
        $prompt += "`n`n========== YOUR PREVIOUS ATTEMPT FAILED JUDGEMENT ========== `nBelow is the critique of the render your previous script produced. Rewrite the COMPLETE script fixing every listed problem. Keep everything that was not criticised.`n`nCRITIQUE:`n$critique"
    }
    $imgs = @(); if ($ReferenceImage) { $imgs += $ReferenceImage }; if ($critique -and (Test-Path "$OutDir\$AssetName`_$($i-1).png")) { $imgs += "$OutDir\$AssetName`_$($i-1).png" }

    $resp = Invoke-Gemini -Prompt $prompt -Images $imgs
    Set-Content -LiteralPath "$OutDir\raw_iter$i.txt" -Value $resp -Encoding utf8
    $scriptText = Get-Script $resp
    if (-not $scriptText) {
        Tick "no python block returned, retrying generation"
        $resp = Invoke-Gemini -Prompt ($prompt + "`n\nIMPORTANT: your entire reply must be ONE complete ```python code block containing the full bpy script. No prose, no explanations.")
        Set-Content -LiteralPath "$OutDir\raw_iter${i}_retry.txt" -Value $resp -Encoding utf8
        $scriptText = Get-Script $resp
    }
    else {
        $open = ([regex]::Matches($scriptText, '\(')).Count; $close = ([regex]::Matches($scriptText, '\)')).Count
        if ($open -ne $close) {
            Tick "script TRUNCATED (parens $open open / $close close), regenerating"
            $resp = Invoke-Gemini -Prompt ($prompt + "`n\nIMPORTANT: your previous reply was CUT OFF mid-script. Reply with ONE complete ```python code block containing the ENTIRE bpy script from 'import bpy' through the GLB export and final print. Write compact helper-driven code so the whole script fits.")
            Set-Content -LiteralPath "$OutDir\raw_iter${i}_retry.txt" -Value $resp -Encoding utf8
            $scriptText = Get-Script $resp
        }
    }
    if (-not $scriptText) { Tick "ABORT: gemini would not return a script"; break }
    $scriptText = Repair-KnownApiBreaks $scriptText
    $pyPath = "$OutDir\$AssetName`_$i.py"
    $glbPath = "$OutDir\$AssetName`_$i.glb"
    Set-Content -LiteralPath $pyPath -Value $scriptText -Encoding utf8

    Tick "=== iteration $i : blender build ==="
    $build = Run-BlenderBuild $pyPath $glbPath
    $repairs = 0
    while (-not $build.ok -and $repairs -lt 2) {
        $repairs++
        Tick "build FAILED, sending error to gemini for self-repair ($repairs/2)"
        $errTail = $build.log
        if ($errTail.Length -gt 3000) { $errTail = $errTail.Substring($errTail.Length - 3000) }
        $fixPrompt = "This bpy script failed when run headless in Blender 5.2. Fix it and return the COMPLETE corrected script in one ``````python code block.`n`nSCRIPT:`n``````python`n$scriptText`n`````` `n`nBLENDER OUTPUT (tail):`n$errTail"
        if ($build.log -notmatch 'Traceback' -and $build.log -notmatch 'Error') {
            $fixPrompt += "`n\nNOTE: the script produced NO output at all - it probably defines functions without calling them, wraps everything in a condition that never runs, or swallows errors silently. Make sure the top-level code actually builds every part, exports the GLB, and prints ASSET_BUILT."
        }
        $resp = Invoke-Gemini -Prompt $fixPrompt -MaxTokens 32000
        Set-Content -LiteralPath "$OutDir\raw_iter${i}_repair${repairs}.txt" -Value $resp -Encoding utf8
        $fixed = Get-Script $resp
        if ($fixed) { $fixed = Repair-KnownApiBreaks $fixed; $scriptText = $fixed; Set-Content -LiteralPath $pyPath -Value $scriptText -Encoding utf8; $build = Run-BlenderBuild $pyPath $glbPath $repairs }
    }
    if (-not $build.ok) { Tick "ABORT: build still failing after repairs (see $pyPath)"; break }
    Tick "built OK, DIMS $($build.dims)"

    Tick "=== iteration $i : godot studio render ==="
    $png = "$OutDir\$AssetName`_$i.png"
    $resGlb = "res://assetloop/runs/$(Split-Path $OutDir -Leaf)/$(Split-Path $glbPath -Leaf)"
    $studioParams = @{
        model_glb = $resGlb; model_scale = $ModelScale
        model_rot_x_deg = 0.0; model_rot_y_deg = 0.0; model_rot_z_deg = 0.0
        cam_yaw_deg = 0.0; cam_pitch_deg = $CamPitch; cam_dist = $CamDist; cam_fov = 40.0
        target = @(0, $TargetY, 0.0); bg = @(0.05, 0.06, 0.09)
        key_energy = 1.2; key_yaw_deg = 35.0; key_pitch_deg = -40.0
        fill_energy = 0.5; fill_yaw_deg = 160.0; fill_pitch_deg = -8.0
        rim_energy = 0.6; rim_yaw_deg = -70.0; rim_pitch_deg = 6.0
        control_sphere = $false; out = "assetloop_latest.png"
    }
    $studioParams | ConvertTo-Json | Set-Content -LiteralPath "$wwProject\screenshots\pawstudio_params.json" -Encoding utf8
    & $godot --path $wwProject --headless --import 2>&1 | Out-Null
    $slog = & $godot --path $wwProject "res://scenes/pawstudio.tscn" 2>&1 | Out-String
    Set-Content -LiteralPath "$OutDir\$AssetName`_$i`_godot.log" -Value $slog -Encoding utf8
    $shot = "$wwProject\screenshots\assetloop_latest.png"
    if (-not (Test-Path $shot)) { Tick "ABORT: godot produced no screenshot. tail: $($slog.Substring([Math]::Max(0,$slog.Length-500)))"; break }
    Copy-Item $shot $png -Force

    Tick "=== iteration $i : judge ==="
    $mCheck = [regex]::Match($assetBrief, '(?s)JUDGE CHECKLIST\s*={3,}\s*(.*?)(\r?\n={3,}|\z)')
    $checklist = if ($mCheck.Success) { $mCheck.Groups[1].Value.Trim() } else { $assetBrief.Trim() }
    $judgePrompt = @"
You are a HARSH 3D art director judging a screenshot of a game asset that gemini built from its own bpy script. The screenshot is a REAL-TIME render from the GAME ENGINE (Godot) - exactly what players will see - on a dark background.

Judge it against this checklist and answer EVERY point with a number:
$checklist

Then the last two lines of your reply MUST be exactly:
MOST_WRONG: <the single worst thing to fix, concrete and actionable>
VERDICT: PASS   (only if every checklist point is acceptable)
VERDICT: FAIL   (if anything is wrong)
"@
    $judge = Invoke-Gemini -Prompt $judgePrompt -Images @($png) -MaxTokens 1500
    Set-Content -LiteralPath "$OutDir\$AssetName`_$i`_judgement.txt" -Value $judge -Encoding utf8
    if ($judge -match 'VERDICT:\s*PASS') { $verdict = 'PASS'; $critique = ''; Tick "VERDICT PASS on iteration $i" }
    else {
        $verdict = 'FAIL'
        $m = [regex]::Match($judge, '(?m)^MOST_WRONG:\s*(.+)$')
        $critique = if ($m.Success) { $judge.Trim() } else { $judge.Trim() }
        Tick "VERDICT FAIL on iteration $i -> next iteration carries critique"
    }
    Log-Inbox ("iter ${i}: verdict=$verdict dims=$($build.dims)`nPROMPT-JUDGE: (spec checklist)`nOUTPUT:`n" + $judge.Substring(0, [Math]::Min(700, $judge.Length)))
    if ($verdict -eq 'PASS') { break }
}

$report.Add("FINAL VERDICT: $verdict")
if ($verdict -eq 'PASS') { $report.Add("WINNER: $OutDir\$AssetName`_$i.glb (+ .png render)") }
Set-Content -LiteralPath "$OutDir\report.md" -Value ($report -join "`r`n") -Encoding utf8
Write-Output "FORGE DONE: $verdict  dir=$OutDir"
