# POLISH LOOP - the asset protocol from PROJECT_STATE.yaml, mechanised.
# build -> render -> gemini-vision judge -> on FAIL gemini patches the builder JSON
# -> rebuild -> re-judge. Guards:
#   * hard round cap (-MaxRounds 4) -> exit 2 "needs human", renders staged
#   * flip-flop detector -> judge re-raising a retired issue approves as PASS-WITH-NOTES
#   * reviser guards: MINIMAL PATCH rules + part-name preservation + dims regression
#     gate (>35% any axis vs last accepted build => revision rejected and retried)
# Exit codes: 0 approved; 1 broken build/invalid spec; 2 round cap; 4 reviser unstable.
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Name,
    [Parameter(Mandatory)] [string]$SpecPath,
    [Parameter(Mandatory)] [string]$Brief,
    [int]$MaxRounds = 4,
    [string]$JudgeModel = 'gemini-flash-latest',
    [string]$FallbackModel = 'gemini-3.1-flash-lite',
    [string]$OutRoot = ''
)

$ErrorActionPreference = 'Stop'
$ww = 'C:\crypto\wicked whiskers'
$blender = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
$buildPy = "$ww\assetloop\builders\build_asset.py"
$renderPy = "$ww\assetloop\builders\render_asset.py"
$probePy = "$ww\assetloop\builders\probe_geometry.py"
$vision = 'C:\crypto\bigpickle\gemini-vision.ps1'
$allowedTypes = @('bent_cylinder', 'cylinder', 'cone_tip', 'splintered_tip', 'box', 'sphere', 'rock')
if (-not $OutRoot) { $OutRoot = "$ww\assetloop\polish" }
$outDir = Join-Path $OutRoot $Name
New-Item -ItemType Directory -Force -Path $outDir, "$outDir\work" | Out-Null
$glb = "$outDir\work\$Name.glb"
$report = "$outDir\polish_report.txt"
$verdictHistory = @()
$mostWrongHistory = @()
$mostWrongHistoryFull = @()

function Log([string]$m) {
    $line = "$(Get-Date -Format 'HH:mm:ss') $m"
    Write-Output $line
    Add-Content -LiteralPath $report -Value $line -Encoding utf8
}

function Invoke-Vision([string]$prompt, [string[]]$images, [int]$maxTokens = 2000, [double]$temp = 0.4) {
    $model = $JudgeModel
    for ($a = 1; $a -le 3; $a++) {
        $code = 1
        try { & $vision -Prompt $prompt -Image $images -Model $model -MaxTokens $maxTokens -Temp $temp *> "$outDir\work\vision_last.txt"; $code = $LASTEXITCODE } catch { $code = 1 }
        if ($code -eq 0) { return (Get-Content "$outDir\work\vision_last.txt" -Raw) }
        $wait = 10 * $a
        Log "gemini-vision attempt $a failed ($model), retrying in ${wait}s"
        Start-Sleep -Seconds $wait
        if ($a -ge 2) { $model = $FallbackModel }
    }
    throw 'gemini-vision failed after retries'
}

function Test-Spec([string]$jsonText) {
    $requiredKeys = @{
        bent_cylinder  = @('waypoints')
        cylinder       = @('from', 'to')
        cone_tip       = @('base', 'tip', 'radius')
        splintered_tip = @('base')
        box            = @('size', 'center')
        sphere         = @('radius')
        rock           = @('radius')
    }
    try {
        $spec = $jsonText | ConvertFrom-Json
        if (-not $spec.parts -or @($spec.parts).Count -eq 0) { return 'parts empty/missing' }
        if (-not $spec.materials -or @($spec.materials.PSObject.Properties).Count -eq 0) { return 'materials empty/missing' }
        foreach ($p in $spec.parts) {
            if ($allowedTypes -notcontains $p.type) { return "unknown part type '$($p.type)' (valid: $($allowedTypes -join ','))" }
            if (-not $p.name) { return "part of type '$($p.type)' has no name" }
            foreach ($k in $requiredKeys[$p.type]) {
                if (-not ($p.PSObject.Properties.Name -contains $k)) { return "part '$($p.name)' ($($p.type)) missing required key '$k'" }
            }
        }
        return $null
    } catch { return "unparseable JSON: $($_.Exception.Message)" }
}

function Get-Fenced([string]$text) {
    $m = [regex]::Match($text, '(?s)```json\s*(.*?)```')
    if ($m.Success) { return $m.Groups[1].Value }
    $m = [regex]::Match($text, '(?s)```\s*(\{.*\})\s*```')
    if ($m.Success) { return $m.Groups[1].Value }
    $i = $text.IndexOf('{'); $j = $text.LastIndexOf('}')
    if ($i -ge 0 -and $j -gt $i) { return $text.Substring($i, $j - $i + 1) }
    return $text
}

function Build-Spec([string]$specFile) {
    $log = & $blender --background --python $buildPy -- $specFile $glb 2>&1 | Out-String
    Set-Content -LiteralPath "$outDir\work\build_last.log" -Value $log -Encoding utf8
    if ($log -notmatch 'ASSET_BUILT') { return @{ ok = $false } }
    $d = ([regex]::Match($log, 'DIMS \(([^)]+)\)').Groups[1].Value)
    $nums = @($d -split ',\s*' | ForEach-Object { [double]$_ })
    $probe = ''
    try {
        & $blender --background --python $probePy -- $glb *> "$outDir\work\probe_last.txt"
        $probe = (Get-Content "$outDir\work\probe_last.txt" | Where-Object { $_ -match '^PROBE (parts|inside)' }) -join "`n"
        $warned = @($probe -split "`n" | Where-Object { $_ -match 'DETACHED|BURIED|NO_ROOT|BARELY' })
        if ($warned.Count) { Log "GEOMETRY WARNINGS: $($warned -join ' | ')" }
        else { Log "geometry probe clean ($(@($probe -split "`n").Count) lines)" }
    } catch { Log 'geometry probe failed to run (non-fatal)' }
    return @{ ok = $true; dimsText = $d; dims = $nums; probe = $probe }
}

function Approve([string]$tier, [string]$note) {
    New-Item -ItemType Directory -Force -Path "$outDir\approved" | Out-Null
    Get-ChildItem "$outDir\work\views_last" -Filter '*.png' -ErrorAction SilentlyContinue | ForEach-Object { Copy-Item $_.FullName "$outDir\approved\" -Force }
    Copy-Item $glb "$outDir\approved\$Name.glb" -Force
    if ($note) { Add-Content -LiteralPath $report -Value "NOTE: $note" -Encoding utf8 }
    # MANDATORY SECOND-OPINION GATE (2026-08-22, Andy's ruling): the calibrated loop
    # verdict alone cannot ship. A fresh, uncalibrated harsh judge must agree.
    Log "loop verdict ($tier) - running INDEPENDENT second-opinion gate"
    $rawPrompt = "You are a harsh 3D art director deciding if this model is good enough to ship in a polished game. These are four views around the model (stylized low-poly is the intended medium). Judge ONLY the model. List every real problem concretely (name the part). End with exactly one line: VERDICT: PASS or PASS-WITH-NOTES or FAIL"
    $views2 = @(Get-ChildItem "$outDir\approved" -Filter 'view*.png' | Sort-Object Name | ForEach-Object { $_.FullName })
    try { $raw = Invoke-Vision $rawPrompt $views2 } catch {
        Log 'second-opinion judge unreachable - treating as FAIL (cannot certify without it)'
        Move-Item "$outDir\approved" "$outDir\needs_human_second_opinion" -Force
        exit 2
    }
    Set-Content -LiteralPath "$outDir\second_opinion.txt" -Value $raw -Encoding utf8
    if ($raw -match '(?m)^VERDICT:\s*PASS-WITH-NOTES') { Log 'SECOND OPINION: PASS-WITH-NOTES -> SHIPPED'; exit 0 }
    elseif ($raw -match '(?m)^VERDICT:\s*PASS') { Log 'SECOND OPINION: PASS -> SHIPPED'; exit 0 }
    else {
        Log 'SECOND OPINION: FAIL -> downgraded to needs_human_second_opinion'
        Move-Item "$outDir\approved" "$outDir\needs_human_second_opinion" -Force
        exit 2
    }
}

function Get-LCP([string]$a, [string]$b) {
    $n = [Math]::Min($a.Length, $b.Length)
    $i = 0
    while ($i -lt $n -and $a[$i] -eq $b[$i]) { $i++ }
    return $i
}

Log "POLISH START $Name spec=$SpecPath briefLen=$($Brief.Length) maxRounds=$MaxRounds"

# ---------- round 1 build ----------
$b = Build-Spec $SpecPath
if (-not $b.ok) { Log 'initial BUILD FAILED'; exit 1 }
$lastDims = $b.dims
Log "round 1 built OK dims=($($b.dimsText))"

for ($round = 1; $round -le $MaxRounds; $round++) {

    # ---- render ----
    $viewsDir = "$outDir\work\views_last"
    Remove-Item -Recurse -Force $viewsDir -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $viewsDir | Out-Null
    & $blender --background --python $renderPy -- $glb $viewsDir 2>&1 | Out-Null
    $views = @(Get-ChildItem $viewsDir -Filter 'view*.png' | Sort-Object Name | ForEach-Object { $_.FullName })
    if ($views.Count -lt 4) { Log "round ${round}: render produced <$($views.Count) views"; exit 1 }

    # ---- judge ----
    $historyBlock = if ($verdictHistory.Count) { "`nPREVIOUS ROUNDS:`n" + (($verdictHistory | Select-Object -Last 2 | ForEach-Object { $_.Trim() }) -join "`n---`n") + "`nDo not re-list issues you already retired. Do not escalate complaints that existed since earlier rounds but were not flagged then." } else { '' }
    $judgePrompt = @"
You are a HARSH 3D art director judging game model '$Name'. NO reference photos - rely on your knowledge of the real object.
ASSET BRIEF (the contract): $Brief
MEASURED FACTS from mechanical audit (ground truth): bbox dims in metres = ($($b.dimsText)); all parts passed a sharp-edge audit.
GEOMETRY PROBE (measured part positions - trust this over the images for any inside/outside/floating/buried question):
$($b.probe)
Do NOT claim a part is floating or buried when the probe reports ROOTED_VISIBLE or CHAIN_ROOTED for it.
The images are four views around the model, in order. Judge ONLY the subject.

CALIBRATION (STANDARD RAISED 2026-08-22 by the creative director): stylized low-poly is the medium, but primitives are acceptable ONLY if the assembled model reads as ONE cohesive object. Automatic FAIL if any part reads as an obvious un-integrated primitive - a ball sitting on a surface, a cone/spike slapped on, a flat plane fin, a mechanical pipe connector - or if silhouette/proportions are wrong for the subject.
PASS means you would ship it in a polished indie game without embarrassment. PASS-WITH-NOTES = genuinely good with only minor polish items. FAIL otherwise; be concrete and harsh.
If a previously flagged issue has been fixed adequately you MUST upgrade the verdict; do not retire an old complaint only to invent a fresh one of equal severity.
List discrepancies numbered, be concrete (name the part).
Your reply MUST end with exactly two lines:
MOST_WRONG: <single worst player-visible issue, or 'nothing'>
VERDICT: PASS   or   PASS-WITH-NOTES   or   FAIL$historyBlock
"@
    try { $judgement = Invoke-Vision $judgePrompt $views } catch { Log 'judge unreachable after retries - aborting run'; exit 3 }
    Set-Content -LiteralPath "$outDir\judgement_round$round.txt" -Value $judgement -Encoding utf8
    $mw = [regex]::Match($judgement, '(?m)^MOST_WRONG:\s*(.+)$').Groups[1].Value.Trim()
    $verdict =
        if ($judgement -match 'VERDICT:\s*PASS-WITH-NOTES') { 'PASS-WITH-NOTES' }
        elseif ($judgement -match 'VERDICT:\s*PASS') { 'PASS' }
        else { 'FAIL' }
    $verdictHistory += "round ${round} [$verdict] MOST_WRONG: $mw"
    Log "round ${round}: verdict=$verdict most_wrong='$mw'"

    if ($verdict -ne 'FAIL') { Approve $verdict '' }

    # ---- flip-flop guard ----
    # TRUE oscillation = complaint vanished for >=1 round, then returned.
    # Same complaint in consecutive rounds is PERSISTENCE -> keep iterating.
    # Similarity = char-LCP >= 25 OR >=45% shared significant words (word order changes).
    $norm = ($mw -replace '[^a-z0-9]', '').ToLower()
    if ($norm.Length -gt 50) { $norm = $norm.Substring(0, 50) }
    function Test-Similar([string]$x, [string]$y) {
        if ($x.Length -lt 10 -or $y.Length -lt 10) { return $false }
        if ((Get-LCP $x $y) -ge 25) { return $true }
        $wx = @($x -split '\s+' | Where-Object { $_.Length -gt 3 })
        $wy = @($y -split '\s+' | Where-Object { $_.Length -gt 3 })
        if (-not $wx.Count -or -not $wy.Count) { return $false }
        $shared = @($wx | Where-Object { $wy -contains $_ }).Count
        return ($shared / [Math]::Max($wx.Count, $wy.Count)) -ge 0.45
    }
    $prevNormFull = if ($mostWrongHistoryFull.Count) { $mostWrongHistoryFull[$mostWrongHistoryFull.Count - 1] } else { '' }
    $sameAsPrev = Test-Similar $mw $prevNormFull
    if (-not $sameAsPrev) {
        for ($h = 0; $h -lt $mostWrongHistoryFull.Count - 1; $h++) {
            if (Test-Similar $mw $mostWrongHistoryFull[$h]) {
                Log "FLIP-FLOP observed: judge re-raised a round-$($h + 1) issue. Logged only - approval must come from the judge's own verdict."
                break
            }
        }
    }
    $mostWrongHistory += $norm
    $mostWrongHistoryFull += $mw

    # ---- revise spec (minimal patch, guarded) ----
    $prevSpecText = Get-Content -LiteralPath $SpecPath -Raw
    $prevNames = @((($prevSpecText | ConvertFrom-Json).parts) | ForEach-Object { $_.name })
    $probeWarns = @($b.probe -split "`n" | Where-Object { $_ -match 'DETACHED|BURIED|NO_ROOT|BARELY' })
    $warnBlock = if ($probeWarns.Count) { "MEASURED GEOMETRY WARNINGS (the probe CONFIRMS these - fixing them takes priority over style):`n$($probeWarns -join "`n")`nTo root a detached part: move its first waypoint at least 30% INTO the named body's volume." } else { '' }
    $baseRevise = @"
You are making a MINIMAL PATCH to the JSON part-spec of a stylized low-poly game asset '$Name'.
BRIEF: $Brief
$warnBlock
HARD RULES:
- Keep EVERY existing part, with its EXACT name. Do NOT remove, rename or repurpose parts.
- Touch ONLY what MOST_WRONG requires. Leave every other part's numbers untouched.
- You may ADD new parts if something is missing.
CURRENT SPEC:
$prevSpecText
JUDGE CRITIQUE (fix MOST_WRONG first):
$(($judgement -replace '``````', '').Substring(0, [Math]::Min(1400, $judgement.Length)))
Schema: top-level materials dict (color [r g b], roughness) + parts array; part types allowed ONLY: $($allowedTypes -join ',').
EXACT SCHEMA (required keys per type; all coords [x,y,z] metres, Z-up, whole numbers of the model scale):
- cylinder: from, to, radius_start, radius_end (or single "radius")
- bent_cylinder: waypoints (list of >=2 points), radii (same length as waypoints) or radius_start/radius_end; optional "cap_style": "round" (rounded pole ends - use it to avoid flat stumps), optional cross_section
- cone_tip: base, tip, radius
- splintered_tip: base, direction, radius (optional seed, spikes)
- box: size ([w,d,h]), center, optional rot_deg ([rx,ry,rz] degrees)
- sphere: center, radius
- rock: center, radius (optional squash, lumpiness, seed)
OPTIONAL KEYS you may use/tune:
- any swept part may add "cross_section": [n_scale, b_scale] - flattens the tube elliptically; fins use e.g. [1.0, 0.08] (tall, thin). n is up-ish, b is sideways.
- top-level "fuse": { "enabled": true|false } - joins all parts via boolean union. For creatures built from organic swept parts leave it FALSE: deep-rooted overlaps plus smooth shading read as one creature, while union can slice material boundaries (jagged two-tone artifacts). If used, "skip": [names] keeps listed parts separate.
Return the COMPLETE corrected JSON (every part) in one ``````json code block and nothing else.
OUTPUT DISCIPLINE: no narration, no planning text, no commentary before or after - ONLY the json code block. If your reply contains any sentence outside the code block the patch is void.
"@
    $accepted = $false
    for ($tryN = 1; $tryN -le 3 -and -not $accepted; $tryN++) {
        $revised = Get-Fenced (Invoke-Vision $baseRevise @() 6000 0.75)
        $err = Test-Spec $revised
        if (-not $err) {
            $newNames = @((($revised | ConvertFrom-Json).parts) | ForEach-Object { $_.name })
            $missing = @($prevNames | Where-Object { $newNames -notcontains $_ })
            if ($missing.Count -gt 0) { $err = "revision DROPPED parts: $($missing -join ', '). Restore them." }
        }
        if (-not $err) {
            Copy-Item $SpecPath "$outDir\spec_round${round}_pre.bak.json" -Force
            Set-Content -LiteralPath $SpecPath -Value $revised -Encoding utf8
            $b2 = Build-Spec $SpecPath
            if (-not $b2.ok) {
                $berr = ([regex]::Match((Get-Content "$outDir\work\build_last.log" -Raw), 'BUILD_ERROR:\s*(.+)')).Groups[1].Value.Trim()
                $err = "patched spec fails to build (error: $berr). Revert to previous geometry and apply a smaller change."
                Copy-Item "$outDir\spec_round${round}_pre.bak.json" $SpecPath -Force
            }
            elseif ($lastDims.Count -eq 3) {
                $bad = $false
                for ($k = 0; $k -lt 3; $k++) {
                    if ([Math]::Abs($b2.dims[$k] - $lastDims[$k]) / [Math]::Max($lastDims[$k], 0.01) -gt 0.35) { $bad = $true }
                }
                if ($bad) {
                    $err = "patch implausibly changed overall proportions from ($($lastDims -join ', ')) to ($($b2.dimsText)). Revert unrelated changes."
                    Copy-Item "$outDir\spec_round${round}_pre.bak.json" $SpecPath -Force
                }
                else { $accepted = $true; $b = $b2; $lastDims = $b2.dims }
            }
            else { $accepted = $true; $b = $b2; $lastDims = $b2.dims }
        }
        if (-not $accepted) { Log "round ${round}: revision rejected (attempt ${tryN}): $err"; $baseRevise = "$baseRevise`nYOUR LAST PATCH WAS REJECTED: $err" }
    }
    if (-not $accepted) { Log "round ${round}: reviser unstable after retries"; exit 4 }
    Log "round ${round}: patch accepted, dims=($($b.dimsText))"
}

Log "ROUND CAP reached without approval - staging last views for human review"
New-Item -ItemType Directory -Force -Path "$outDir\needs_human" | Out-Null
Get-ChildItem "$outDir\work\views_last" -Filter '*.png' | ForEach-Object { Copy-Item $_.FullName "$outDir\needs_human\" -Force }
exit 2
