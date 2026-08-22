# POLISH LOOP - the asset protocol from PROJECT_STATE.yaml, mechanised.
# build -> render -> gemini-vision judge -> on FAIL gemini rewrites the builder JSON
# -> rebuild -> re-judge. Guards against a perfectionist judge:
#   * hard iteration cap (-MaxRounds, default 4) -> exit 2 "needs human", stages renders
#   * flip-flop detector -> if the judge re-raises an issue it retired >=2 rounds ago,
#     we approve the current round as PASS-WITH-NOTES instead of chasing our tail
# Exit codes: 0 approved (PASS or PASS-WITH-NOTES), 1 broken (build/revision failure),
# 2 round cap reached without approval.
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Name,
    [Parameter(Mandatory)] [string]$SpecPath,
    [Parameter(Mandatory)] [string]$Brief,
    [int]$MaxRounds = 4,
    [string]$JudgeModel = 'gemini-flash-latest',
    [string]$OutRoot = ''
)

$ErrorActionPreference = 'Stop'
$ww = 'C:\crypto\wicked whiskers'
$blender = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
$buildPy = "$ww\assetloop\builders\build_asset.py"
$renderPy = "$ww\assetloop\builders\render_asset.py"
$vision = 'C:\crypto\bigpickle\gemini-vision.ps1'
$allowedTypes = @('bent_cylinder', 'cylinder', 'cone_tip', 'splintered_tip', 'box', 'sphere', 'rock')
if (-not $OutRoot) { $OutRoot = "$ww\assetloop\polish" }
$outDir = Join-Path $OutRoot $Name
New-Item -ItemType Directory -Force -Path $outDir, "$outDir\work" | Out-Null
$glb = "$outDir\work\$Name.glb"
$report = "$outDir\polish_report.txt"
$verdictHistory = @()
$mostWrongHistory = @()

function Log([string]$m) {
    $line = "$(Get-Date -Format 'HH:mm:ss') $m"
    Write-Output $line
    Add-Content -LiteralPath $report -Value $line -Encoding utf8
}

function Invoke-Vision([string]$prompt, [string[]]$images, [int]$maxTokens = 2000) {
    $model = $JudgeModel
    for ($a = 1; $a -le 3; $a++) {
        & $vision -Prompt $prompt -Image $images -Model $model -MaxTokens $maxTokens *> "$outDir\work\vision_last.txt"
        if ($LASTEXITCODE -eq 0) { return (Get-Content "$outDir\work\vision_last.txt" -Raw) }
        $wait = 10 * $a
        Log "gemini-vision attempt $a failed ($model), retrying in ${wait}s"
        Start-Sleep -Seconds $wait
        if ($a -ge 2) { $model = 'gemini-3.1-flash-lite' }
    }
    throw 'gemini-vision failed after retries'
}

function Test-Spec([string]$jsonText) {
    try {
        $spec = $jsonText | ConvertFrom-Json
        if (-not $spec.parts -or @($spec.parts).Count -eq 0) { return 'parts empty/missing' }
        if (-not $spec.materials -or @($spec.materials.PSObject.Properties).Count -eq 0) { return 'materials empty/missing' }
        foreach ($p in $spec.parts) {
            if ($allowedTypes -notcontains $p.type) { return "unknown part type '$($p.type)' (valid: $($allowedTypes -join ','))" }
        }
        return $null
    } catch { return "unparseable JSON: $($_.Exception.Message)" }
}

function Get-Fenced([string]$text) {
    $m = [regex]::Match($text, '(?s)```json\s*(.*?)```')
    if ($m.Success) { return $m.Groups[1].Value }
    return $text
}

Log "POLISH START $Name spec=$SpecPath briefLen=$($Brief.Length) maxRounds=$MaxRounds"

for ($round = 1; $round -le $MaxRounds; $round++) {

    # ---- build ----
    $buildLog = & $blender --background --python $buildPy -- $SpecPath $glb 2>&1 | Out-String
    Set-Content -LiteralPath "$outDir\work\build_round$round.log" -Value $buildLog -Encoding utf8
    $dims = ([regex]::Match($buildLog, 'DIMS \(([^)]+)\)').Groups[1].Value)
    if ($buildLog -notmatch 'ASSET_BUILT') {
        Log "round ${round}: BUILD FAILED, asking gemini for repair"
        $errTail = $buildLog.Substring([Math]::Max(0, $buildLog.Length - 1200))
        $fixPrompt = @"
The bpy library script failed building this JSON spec for '$Name':
$(Get-Content -LiteralPath $SpecPath -Raw)
ERROR TAIL:
$errTail
Return the COMPLETE corrected JSON in one ``````json code block. Same schema: materials dict + parts array using ONLY types $($allowedTypes -join ',').
"@
        $fixed = Get-Fenced (Invoke-Vision $fixPrompt @() 3000)
        $err = Test-Spec $fixed
        if ($err) { Log "round ${round}: repaired spec invalid ($err)"; exit 1 }
        Copy-Item $SpecPath "$outDir\spec_round$($round)_pre.bak.json" -Force
        Set-Content -LiteralPath $SpecPath -Value $fixed -Encoding utf8
        continue
    }
    Log "round ${round}: built OK dims=($dims)"

    # ---- render ----
    $viewsDir = "$outDir\work\views_round$round"
    New-Item -ItemType Directory -Force -Path $viewsDir | Out-Null
    & $blender --background --python $renderPy -- $glb $viewsDir 2>&1 | Out-Null
    $views = @(Get-ChildItem $viewsDir -Filter 'view*.png' | Sort-Object Name | ForEach-Object { $_.FullName })
    if ($views.Count -lt 4) { Log "round ${round}: render produced <$($views.Count) views"; exit 1 }

    # ---- judge ----
    $historyBlock = if ($verdictHistory.Count) { "`nPREVIOUS ROUNDS:`n" + (($verdictHistory | Select-Object -Last 2 | ForEach-Object { $_.Trim() }) -join "`n---`n") } else { '' }
    $judgePrompt = @"
You are a HARSH 3D art director judging game model '$Name'. NO reference photos - rely on your knowledge of the real object.
ASSET BRIEF (the contract): $Brief
MEASURED FACTS from mechanical audit (ground truth): bbox dims in metres = ($dims); all parts passed a sharp-edge audit.
The images are four views around the model, in order. Judge ONLY the subject.

CALIBRATION: harsh about real problems, NOT a perfectionist. Stylized low-poly cozy cat-game asset - it does NOT need realism.
PASS-WITH-NOTES = reads correctly at a glance; minor items noted but non-blocking.
FAIL only if a player would spot the problem within ~2 seconds in-game.
If a previously flagged issue has been fixed adequately you MUST upgrade the verdict; do not retire an old complaint only to invent a fresh one of equal severity.
List discrepancies numbered, be concrete (name the part).
Your reply MUST end with exactly two lines:
MOST_WRONG: <single worst player-visible issue, or 'nothing'>
VERDICT: PASS   or   PASS-WITH-NOTES   or   FAIL$historyBlock
"@
    $judgement = Invoke-Vision $judgePrompt $views
    Set-Content -LiteralPath "$outDir\judgement_round$round.txt" -Value $judgement -Encoding utf8
    $mw = [regex]::Match($judgement, '(?m)^MOST_WRONG:\s*(.+)$').Groups[1].Value.Trim()
    $verdict =
        if ($judgement -match 'VERDICT:\s*PASS-WITH-NOTES') { 'PASS-WITH-NOTES' }
        elseif ($judgement -match 'VERDICT:\s*PASS') { 'PASS' }
        else { 'FAIL' }
    $verdictHistory += "round ${round} [$verdict] MOST_WRONG: $mw"
    Log "round ${round}: verdict=$verdict most_wrong='$mw'"

    if ($verdict -ne 'FAIL') {
        New-Item -ItemType Directory -Force -Path "$outDir\approved" | Out-Null
        $views | ForEach-Object { Copy-Item $_ "$outDir\approved\" -Force }
        Copy-Item $glb "$outDir\approved\$Name.glb" -Force
        Log "APPROVED ($verdict) on round $round -> $outDir\approved"
        exit 0
    }

    # ---- flip-flop guard ----
    $norm = ($mw -replace '[^a-z0-9]', '').ToLower().Substring(0, [Math]::Min(50, ($mw -replace '[^a-z0-9]', '').Length))
    for ($h = 0; $h -le $mostWrongHistory.Count - 2; $h++) {
        if ($mostWrongHistory[$h] -and $mostWrongHistory[$h].Length -ge 10 -and $norm.StartsWith($mostWrongHistory[$h]) -or ($mostWrongHistory[$h] -and $mostWrongHistory[$h].StartsWith($norm))) {
            Log "FLIP-FLOP: '$mw' re-raised after being fixed in round $($h + 1); approving current as PASS-WITH-NOTES"
            New-Item -ItemType Directory -Force -Path "$outDir\approved" | Out-Null
            $views | ForEach-Object { Copy-Item $_ "$outDir\approved\" -Force }
            Copy-Item $glb "$outDir\approved\$Name.glb" -Force
            Add-Content -LiteralPath $report -Value "NOTE: approved via flip-flop guard (oscillating judge)" -Encoding utf8
            exit 0
        }
    }
    $mostWrongHistory += $norm

    # ---- revise spec ----
    $revisePrompt = @"
You are revising the JSON part-spec of a stylized low-poly game asset '$Name'.
BRIEF: $Brief
CURRENT SPEC:
$(Get-Content -LiteralPath $SpecPath -Raw)
JUDGE CRITIQUE (fix MOST_WRONG first):
$((($judgement -replace '`{`{`|`}`}', '')).Substring(0, [Math]::Min(1400, $judgement.Length)))
Schema: top-level materials dict (color [r g b], roughness) + parts array; part types allowed ONLY: $($allowedTypes -join ',').
Keep everything that already works. Return the COMPLETE corrected JSON in one ``````json code block and nothing else.
"@
    $revised = Get-Fenced (Invoke-Vision $revisePrompt @() 4000)
    $err = Test-Spec $revised
    if ($err) {
        $revised2 = Get-Fenced (Invoke-Vision "$revisePrompt`nYour previous block was invalid: $err. Return the complete corrected JSON again." @() 4000)
        $err = Test-Spec $revised2
        $revised = $revised2
    }
    if ($err) { Log "round ${round}: revised spec invalid ($err)"; exit 1 }
    Copy-Item $SpecPath "$outDir\spec_round$($round)_pre.bak.json" -Force
    Set-Content -LiteralPath $SpecPath -Value $revised -Encoding utf8
    Log "round ${round}: spec revised by judge feedback"
}

Log "ROUND CAP reached without approval - staging last views for human review"
New-Item -ItemType Directory -Force -Path "$outDir\needs_human" | Out-Null
Get-ChildItem "$outDir\work\views_round$MaxRounds" -Filter '*.png' | ForEach-Object { Copy-Item $_.FullName "$outDir\needs_human\" -Force }
exit 2
