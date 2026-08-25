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
    [string]$FallbackModel = 'gemini-3.1-flash-lite',
    [string[]]$RefImages = @(),
    [int]$SharpEdgeLimit = 60
)

$ErrorActionPreference = 'Stop'
$script:CurrentModel = $Model
$script:SharpEdgeLimit = $SharpEdgeLimit
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
# evolving rulebook: inject [UNIVERSAL] + this asset's family rules
$rulesPath = Join-Path (Split-Path $PSCommandPath) 'rules.txt'
if (Test-Path $rulesPath) {
    $fam = if ($assetBrief -match '(?m)^FAMILY:\s*(\S+)') { $Matches[1] } else { '' }
    $rulesText = Get-Content -LiteralPath $rulesPath -Raw
    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine("========== EVOLVING RULEBOOK (scope: universal$(if ($fam) { " + family:$fam" })) ==========")
    foreach ($sec in [regex]::Matches($rulesText, '(?ms)^\[([^\]]+)\]\r?\n(.*?)(?=^\[|\z)')) {
        $name = $sec.Groups[1].Value.Trim()
        if ($name -eq 'UNIVERSAL' -or ($fam -and $name -eq "FAMILY:$fam") -or $name -eq ((Split-Path $SpecFile -Leaf) -replace '\.txt$', '')) {
            $null = $sb.AppendLine($sec.Groups[2].Value.Trim())
        }
    }
    $spec += $sb.ToString() + "`n`n"
}
$spec += $assetBrief
$isBuilder = $spec -match '(?m)^MODE:\s*builder'
$famName = if ($assetBrief -match '(?m)^FAMILY:\s*(\S+)') { $Matches[1] } else { '' }
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

function Get-AssetJson([string]$Text) {
    foreach ($m in [regex]::Matches($Text, '(?s)```(?:json)?\s*(\{.*?\})\s*```')) {
        try { $null = $m.Groups[1].Value | ConvertFrom-Json; return $m.Groups[1].Value } catch {}
    }
    $i = $Text.IndexOf('{'); $j = $Text.LastIndexOf('}')
    if ($i -ge 0 -and $j -gt $i) {
        $cand = $Text.Substring($i, $j - $i + 1)
        try { $null = $cand | ConvertFrom-Json; return $cand } catch {}
    }
    return $null
}

function Test-AssetJson([string]$Json) {
    $errs = @()
    try { $o = $Json | ConvertFrom-Json } catch { return @("JSON parse error: $($_.Exception.Message)") }
    if (-not $o.parts -or @($o.parts).Count -eq 0) { $errs += "parts must be a non-empty list" }
    $valid = 'bent_cylinder', 'cylinder', 'cone_tip', 'splintered_tip', 'box', 'sphere', 'rock'
    $k = 0
    foreach ($p in @($o.parts)) {
        if ($valid -notcontains $p.type) { $errs += "part ${k}: unknown type '$($p.type)' (valid: $($valid -join ', '))" }
        elseif ($p.type -eq 'bent_cylinder' -and @($p.waypoints).Count -lt 2) { $errs += "part ${k}: bent_cylinder needs >= 2 waypoints" }
        $k++
    }
    return $errs
}

function Invoke-BuilderBuild([string]$jsonPath, [string]$glbPath, [int]$attempt = 0) {
    $builderPy = Join-Path (Split-Path $PSCommandPath) 'builders\build_asset.py'
    Push-Location $OutDir
    try { $log = & $blender --background --python $builderPy -- $jsonPath $glbPath 2>&1 } finally { Pop-Location }
    $logText = $log | Out-String
    $suffix = if ($attempt -gt 0) { "_repair$attempt" } else { "" }
    Set-Content -LiteralPath "$OutDir\builder$suffix.log" -Value $logText -Encoding utf8
    return @{
        ok    = ((Test-Path $glbPath) -and $logText -match 'ASSET_BUILT')
        log   = $logText
        dims  = if ($logText -match 'DIMS \(([^)]*)\)') { $Matches[1] } else { '' }
        error = if ($logText -match 'BUILD_ERROR: (.*)') { $Matches[1].Trim() } else { '' }
    }
}

function Invoke-Audit([string]$glbPath) {
    $issues = @()
    $pyPath = "$OutDir\audit.py"
    $py = @"
import bpy
bpy.ops.wm.read_homefile(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r"$glbPath")
minz = 999.0
mins = [999.0]*3; maxs = [-999.0]*3
for o in bpy.context.scene.objects:
    if o.type != 'MESH': continue
    for v in o.data.vertices:
        w = o.matrix_world @ v.co
        p = (w.x, w.y, w.z)
        for k in range(3):
            if p[k] < mins[k]: mins[k] = p[k]
            if p[k] > maxs[k]: maxs[k] = p[k]
    zs = [(o.matrix_world @ v.co).z for v in o.data.vertices]
    if not zs: continue
    omin = min(zs)
    print("AUDITOBJ", o.name, round(omin, 4))
    minz = min(minz, omin)
print("AUDITMINZ", round(minz, 4))
print("AUDITBBOX", round(maxs[0]-mins[0],4), round(maxs[1]-mins[1],4), round(maxs[2]-mins[2],4))
"@
    Set-Content -LiteralPath $pyPath -Value $py -Encoding utf8
    $log = & $blender --background --python $pyPath 2>&1 | Out-String
    $miny = if ($log -match 'AUDITMINZ (-?[\d.]+)') { [double]$Matches[1] } else { $null }
    if ($null -eq $miny) { return @("AUDIT FAILED: could not measure model") }
    $objNames = @([regex]::Matches($log, 'AUDITOBJ (\S+)') | ForEach-Object { $_.Groups[1].Value })
    $touchTxt = if ([Math]::Abs($miny) -le 0.005) { "model RESTS EXACTLY ON the ground plane (lowest point z=$miny - it is NOT floating)" } else { "lowest point z=$miny" }
    if ($log -match 'AUDITBBOX ([\d.]+) ([\d.]+) ([\d.]+)') {
        $script:AuditFacts = "bounding box $($Matches[1]) x $($Matches[2]) x $($Matches[3]) metres (X x Y x Z-height); $touchTxt; mesh parts present: $($objNames -join ', ')"
    } else { $script:AuditFacts = '' }
    if ($miny -lt -0.005) { $issues += ("GROUND: model extends below ground (lowest point z={0}). Rebuild so the whole model sits exactly on z=0, nothing buried." -f $miny) }
    elseif ($miny -gt 0.02) { $issues += ("GROUND: model floats above the ground (lowest point z={0}). It must rest exactly on z=0." -f $miny) }
    if ($assetBrief -match '(?i)lying flat|lies flat|lying along|long axis horizontal') {
        if ($log -match 'AUDITBBOX ([\d.]+) ([\d.]+) ([\d.]+)') {
            $dx = [double]$Matches[1]; $dy = [double]$Matches[2]; $dz = [double]$Matches[3]
            $longestH = [Math]::Max($dx, $dy)
            if ($longestH -gt 0.01 -and $dz -gt 0.5 * $longestH) {
                $issues += ("ORIENTATION: model is standing UPRIGHT (height {0} vs longest horizontal extent {1}). It must LIE FLAT - long axis horizontal on the ground plane, height ~= thickness. In build space the ground plane is XY and up is +Z." -f $dz, $longestH)
            }
        }
    }
    foreach ($m in [regex]::Matches($log, 'AUDITOBJ (\S*(?:Leg|Wheel|Foot)\S*) (-?[\d.]+)')) {
        $ly = [double]$m.Groups[2].Value
        if ($ly -gt 0.02 -or $ly -lt -0.01) { $issues += ("GROUND CONTACT: part '{0}' bottom is y={1}; every leg/wheel must touch y=0." -f $m.Groups[1].Value, $ly) }
    }
    return $issues
}

function Remove-JunkObjects([string]$glbPath) {
    $py = @"
import bpy
bpy.ops.wm.read_homefile(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r"$glbPath")
junk = [o for o in list(bpy.context.scene.objects) if o.name.split('.')[0] in ('Cube', 'Plane', 'Circle', 'Sphere')]
if junk:
    for o in junk: bpy.data.objects.remove(o)
    bpy.ops.export_scene.gltf(filepath=r"$glbPath", export_format='GLB')
    print('JUNK_REMOVED')
else:
    print('JUNK_NONE')
"@
    $pyPath = "$OutDir\dejunk.py"
    Set-Content -LiteralPath $pyPath -Value $py -Encoding utf8
    $log = & $blender --background --python $pyPath 2>&1 | Out-String
    if ($log -match 'JUNK_REMOVED') { Tick "stripped leftover default objects from GLB" }
}

function Invoke-SelfRender([string]$glbPath, [int]$iter) {
    $dir = "$OutDir\selfrender_iter$iter"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $py = Join-Path (Split-Path $PSCommandPath) 'builders\render_asset.py'
    $log = & $blender --background --python $py -- $glbPath $dir 2>&1 | Out-String
    Set-Content -LiteralPath "$dir\render.log" -Value $log -Encoding utf8
    return @(Get-ChildItem $dir -Filter view*.png -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object { $_.FullName })
}

function Invoke-CreaseAudit([string]$glbPath) {
    $py = Join-Path (Split-Path $PSCommandPath) 'builders\diag_mesh.py'
    $log = & $blender --background --python $py -- $glbPath 2>&1 | Out-String
    Set-Content -LiteralPath "$OutDir\crease_audit.log" -Value $log -Encoding utf8
    $facts = @()
    $issues = @()
    foreach ($m in [regex]::Matches($log, 'OBJ (\S+) polys \d+ smooth \d+\r?\nBUCKETS >90:(\d+) 45-90:(\d+) 25-45:(\d+)')) {
        $obj = $m.Groups[1].Value
        $sharp = [int]$m.Groups[2].Value + [int]$m.Groups[3].Value + [int]$m.Groups[4].Value
        $facts += "$obj sharp-edges(>25deg)=$sharp"
        if ($sharp -gt $script:SharpEdgeLimit) { $issues += ("CREASES: part '{0}' has {1} edges sharper than 25 degrees - that part reads faceted/blocky instead of smooth. Rebuild it with more sides/samples via the library primitives." -f $obj, $sharp) }
    }
    $script:CreaseFacts = $facts -join '; '
    return $issues
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
    if ($isBuilder) {
        $prompt += @"

========== OUTPUT FORMAT - PARAMETER DESIGNER MODE ==========
You do NOT write python or bpy code. The deterministic builder library handles ALL geometry craft (contiguity, smooth shading, taper, tip orientation, ground contact). Your job is ONLY design: which parts, what proportions, where, what colour.
Reply with ONE ``````json block and nothing else. Schema:
{"asset": "<name>", "auto_ground": true,
 "surface_noise": {"frequency": 8-16, "amplitude": 0.001-0.003, "seed": int},
 "materials": {"<name>": {"color": [r, g, b], "roughness": 0.0-1.0}},
 "parts": [
   {"type": "bent_cylinder", "name": "...", "material": "...", "waypoints": [[x,y,z], ...2+ points along the shape's spine], "radii": [one radius per waypoint], "sides": 24},
   {"type": "cylinder", "name": "...", "material": "...", "from": [x,y,z], "to": [x,y,z], "radius": m, "collar": 1.6},
   {"type": "cone_tip", "name": "...", "material": "...", "base": [x,y,z] ON the body, "tip": [x,y,z] pointing OUTWARD, "radius": m},
   {"type": "splintered_tip", "name": "...", "material": "...", "base": [x,y,z] ON the body end, "direction": [x,y,z] pointing OUTWARD, "radius": m, "seed": int, "spikes": 5-9},
   {"type": "box", "name": "...", "material": "...", "center": [x,y,z], "size": [dx,dy,dz], "rot_deg": [rx,ry,rz]},
   {"type": "sphere", "name": "...", "material": "...", "center": [x,y,z], "radius": m},
   {"type": "rock", "name": "...", "material": "...", "center": [x,y,z], "radius": m, "seed": int, "squash": [sx,sy,sz], "lumpiness": 0.1-0.25, "flatten": 0.0-0.6, "facet": 0.0-1.0, "smooth": true|false}]}
Units are METRES. bent_cylinder is ONE continuous swept tube through all waypoints (radii list gives a smooth taper; omit for constant radius). "collar" adds an organic knuckle where a cylinder leaves its parent body - use on every branch/twig. surface_noise adds directional grain over the WHOLE model.
"@
    }
    if ($ReferenceImage -and (Test-Path $ReferenceImage)) {
        $prompt += "`n`n========== STYLE REFERENCE IMAGE ========== `nAn image of the desired look/style is attached. Match this style, quality bar and colour mood. Do not copy its geometry mistakes."
    }
    if ($critique) {
        $modeWord = if ($isBuilder) { 'json parameter list' } else { 'script' }
        $prompt += "`n`n========== YOUR PREVIOUS ATTEMPT FAILED JUDGEMENT ========== `nBelow is the critique of the render your previous attempt produced. Rewrite the COMPLETE $modeWord fixing every listed problem. Keep everything that was not criticised.`n`nCRITIQUE:`n$critique"
    }
    $imgs = @(); foreach ($r in $RefImages) { if ($r -and (Test-Path $r)) { $imgs += $r } }; if ($ReferenceImage) { $imgs += $ReferenceImage }
    if ($critique -and $script:PrevSelfViews) { $imgs += @($script:PrevSelfViews | Where-Object { Test-Path $_ }) }
    if ($critique -and (Test-Path "$OutDir\$AssetName`_$($i-1).png")) { $imgs += "$OutDir\$AssetName`_$($i-1).png" }
    if ($RefImages.Count -gt 0 -and $i -eq 1) { $prompt += "`n`n========== REFERENCE PHOTOS ========== `nReal reference photo(s) of the subject are attached. Match the subject's real anatomy, part placement and proportions (stylised chunky-cartoon, but structurally correct)." }

    if (-not $isBuilder) {
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
    }
    else {
        # ---- builder mode: gemini emits JSON, library builds deterministically ----
        $glbPath = "$OutDir\$AssetName`_$i.glb"
        $jsonPath = "$OutDir\$AssetName`_$i.json"
        $resp = Invoke-Gemini -Prompt $prompt -Images $imgs
        Set-Content -LiteralPath "$OutDir\raw_iter$i.txt" -Value $resp -Encoding utf8
        $jsonText = Get-AssetJson $resp
        $jsonErrs = @()
        if ($jsonText) { $jsonErrs = @(Test-AssetJson $jsonText) }
        $attempts = 0
        while ((-not $jsonText -or $jsonErrs.Count -gt 0) -and $attempts -lt 2) {
            $attempts++
            Tick "invalid json (attempt $attempts): $($jsonErrs -join '; ') - asking for fix"
            $fixP = $prompt + "`n`nYOUR LAST REPLY WAS INVALID:`n$($jsonErrs -join "`n")`n`nPREVIOUS JSON:`n$jsonText`n`nReturn the COMPLETE corrected ```json block, changing as little as possible."
            $resp = Invoke-Gemini -Prompt $fixP -Images $imgs
            Set-Content -LiteralPath "$OutDir\raw_iter${i}_fix$attempts.txt" -Value $resp -Encoding utf8
            $jsonText = Get-AssetJson $resp
            if ($jsonText) { $jsonErrs = @(Test-AssetJson $jsonText) }
        }
        if (-not $jsonText -or $jsonErrs.Count -gt 0) { Tick "ABORT: gemini would not produce valid json: $($jsonErrs -join '; ')"; break }
        Set-Content -LiteralPath $jsonPath -Value $jsonText -Encoding utf8

        Tick "=== iteration $i : builder build ==="
        $build = Invoke-BuilderBuild $jsonPath $glbPath
        $repairs = 0
        while (-not $build.ok -and $repairs -lt 2) {
            $repairs++
            Tick "builder FAILED, sending error to gemini ($repairs/2)"
            $fixP = $prompt + "`n`nTHE BUILDER REJECTED YOUR JSON WITH THIS ERROR:`n$($build.error)`n`nPREVIOUS JSON:`n$jsonText`n`nReturn the COMPLETE corrected ```json block, changing as little as possible."
            $resp = Invoke-Gemini -Prompt $fixP
            Set-Content -LiteralPath "$OutDir\raw_iter${i}_repair${repairs}.txt" -Value $resp -Encoding utf8
            $fixed = Get-AssetJson $resp
            if ($fixed) { $jsonText = $fixed; Set-Content -LiteralPath $jsonPath -Value $jsonText -Encoding utf8; $build = Invoke-BuilderBuild $jsonPath $glbPath $repairs }
        }
        if (-not $build.ok) { Tick "ABORT: builder still failing after repairs"; break }
    }
    # gemini sometimes disobeys the no-.blend rule; a .blend inside the project KILLS godot --import
    Get-ChildItem $OutDir -Filter *.blend* -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Remove-JunkObjects $glbPath
    $auditIssues = @(Invoke-Audit $glbPath)
    Tick "=== iteration $i : self-render + crease audit ==="
    $selfViews = @(Invoke-SelfRender $glbPath $i)
    foreach ($ci in @(Invoke-CreaseAudit $glbPath)) { Tick "AUDIT: $ci"; $auditIssues += $ci }
    if ($script:CreaseFacts) { $script:AuditFacts = "$($script:AuditFacts); edge audit: $($script:CreaseFacts)" }
    if ($selfViews.Count -lt 2) { Tick "warning: self-render produced $($selfViews.Count) view(s)" }
    foreach ($ai in $auditIssues) { Tick "AUDIT: $ai" }
    Tick "built OK, DIMS $($build.dims)"

    if ($selfViews.Count -ge 2) {
        Tick "=== iteration $i : judge sees Blender self-renders (studio skipped) ==="
    }
    else {
    Tick "=== iteration $i : godot studio render (4 angles) ==="
    $png = "$OutDir\$AssetName`_$i.png"
    $shot = "$wwProject\screenshots\assetloop_latest.png"
    $resGlb = "res://assetloop/runs/$(Split-Path $OutDir -Leaf)/$(Split-Path $glbPath -Leaf)"
    & $godot --path $wwProject --headless --import 2>&1 | Out-Null
    $anglePngs = @()
    foreach ($yaw in 0, 90, 180, 270) {
        $studioParams = @{
            model_glb = $resGlb; model_scale = $ModelScale
            model_rot_x_deg = 0.0; model_rot_y_deg = 0.0; model_rot_z_deg = 0.0
            cam_yaw_deg = $yaw; cam_pitch_deg = $CamPitch; cam_dist = $CamDist; cam_fov = 40.0
            target = @(0, $TargetY, 0.0); bg = @(0.05, 0.06, 0.09)
            key_energy = 1.2; key_yaw_deg = 35.0; key_pitch_deg = -40.0
            fill_energy = 0.5; fill_yaw_deg = 160.0; fill_pitch_deg = -8.0
            rim_energy = 0.6; rim_yaw_deg = -70.0; rim_pitch_deg = 6.0
            control_sphere = $false; out = "assetloop_latest.png"
        }
        $studioParams | ConvertTo-Json | Set-Content -LiteralPath "$wwProject\screenshots\pawstudio_params.json" -Encoding utf8
        Remove-Item -LiteralPath $shot -Force -ErrorAction SilentlyContinue
        $null = & $godot --path $wwProject "res://scenes/pawstudio.tscn" 2>&1
        if (Test-Path $shot) {
            Copy-Item $shot "$OutDir\$AssetName`_$i`_yaw$yaw.png" -Force
            $anglePngs += $shot
        } else { Tick "warning: yaw ${yaw} produced no screenshot" }
    }
    if ($anglePngs.Count -lt 2) { Tick "ABORT: studio produced $($anglePngs.Count)/4 angles"; break }
    Add-Type -AssemblyName System.Drawing
    $tileW = 480; $tileH = 360
    $strip = New-Object System.Drawing.Bitmap -ArgumentList ($tileW * $anglePngs.Count), $tileH
    $g = [System.Drawing.Graphics]::FromImage($strip)
    for ($a = 0; $a -lt $anglePngs.Count; $a++) {
        $img = [System.Drawing.Image]::FromFile($anglePngs[$a])
        $g.DrawImage($img, $a * $tileW, 0, $tileW, $tileH)
        $img.Dispose()
    }
    $g.Dispose()
    $strip.Save($png, [System.Drawing.Imaging.ImageFormat]::Png)
    $strip.Dispose()
    }

    Tick "=== iteration $i : judge ==="
    $judgeImages = @()
    foreach ($r in $RefImages) { if ($r -and (Test-Path $r)) { $judgeImages += $r } }
    if ($selfViews.Count -ge 2) {
        $judgeImages += $selfViews
    } else {
        $yawPngs = @(Get-ChildItem "$OutDir\$AssetName`_$i`_yaw*.png" -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object { $_.FullName })
        if ($yawPngs.Count -gt 0) { $judgeImages += $yawPngs } else { $judgeImages += $png }
    }
    if ($RefImages.Count -gt 0) {
        $nRefs = $judgeImages.Count - [Math]::Max($yawPngs.Count, 1)
        $expectedParts = ''
        if ($isBuilder -and $jsonText) {
            try { $expectedParts = "The model was DESIGNED to contain these parts: $((($jsonText | ConvertFrom-Json).parts | ForEach-Object { $_.name }) -join ', '). Do not claim a part is missing unless you also explain why the design fails to read as that part." } catch {}
        }
        $judgePrompt = @"
You are a HARSH 3D art director. The asset being judged is: a $AssetName (see the ASSET BRIEF below). The FIRST $nRefs image(s) are REAL reference photos showing what this thing looks like in reality - they may show it in context. Judge ONLY the subject itself and IGNORE everything else in the photos (foliage, background, surroundings are NOT part of the asset). The remaining images are our game model rendered from four views around it, in order.

MEASURED FACTS from a mechanical audit (ground truth - never contradict these): $script:AuditFacts
$expectedParts

Compare ONLY the subject against the references and list EVERY discrepancy you can find, numbered. Focus on what vision is good at: does it READ as the subject, are proportions/placements/colours convincing, would a player recognise it instantly. Be specific and concrete (name the part, say what is wrong and what it should be).

ASSET BRIEF (the contract for what the model must be):
$($spec.Trim())

Then the last two lines of your reply MUST be exactly:
MOST_WRONG: <the single worst discrepancy to fix first, concrete and actionable>
VERDICT: PASS   (only if the model would fool someone into thinking it was professionally made for the game)
VERDICT: FAIL   (if anything meaningful is wrong)
"@
    }
    else {
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
    }
    $judge = Invoke-Gemini -Prompt $judgePrompt -Images $judgeImages -MaxTokens 2000
    Set-Content -LiteralPath "$OutDir\$AssetName`_$i`_judgement.txt" -Value $judge -Encoding utf8
    if ($judge -match 'VERDICT:\s*PASS') { $verdict = 'PASS'; $critique = ''; Tick "VERDICT PASS on iteration $i" }
    else {
        $verdict = 'FAIL'
        $m = [regex]::Match($judge, '(?m)^MOST_WRONG:\s*(.+)$')
        $critique = $judge.Trim()
        if ($auditIssues.Count -gt 0) { $critique = ($auditIssues -join "`n") + "`n`n" + $critique }
        Tick "VERDICT FAIL on iteration $i -> next iteration carries critique"
    }
    Log-Inbox ("iter ${i}: verdict=$verdict dims=$($build.dims)`nPROMPT-JUDGE: (spec checklist)`nOUTPUT:`n" + $judge.Substring(0, [Math]::Min(700, $judge.Length)))
    if ($verdict -eq 'PASS') { break }
    $script:PrevSelfViews = $selfViews
}

$report.Add("FINAL VERDICT: $verdict")
if ($verdict -eq 'PASS') { $report.Add("WINNER: $OutDir\$AssetName`_$i.glb (+ .png render)") }
Set-Content -LiteralPath "$OutDir\report.md" -Value ($report -join "`r`n") -Encoding utf8
Write-Output "FORGE DONE: $verdict  dir=$OutDir"
