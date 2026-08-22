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
        $code = 1
        try { & $vision -Prompt $prompt -Image $images -Model $model -MaxTokens $maxTokens *> "$outDir\work\vision_last.txt"; $code = $LASTEXITCODE } catch { $code = 1 }
        if ($code -eq 0) { return (Get-Content "$outDir\work\vision_last.txt" -Raw) }
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
            if (-not $p.name) { return "part of type '$($p.type)' has no name" }
        }
        return $null
    } catch { return "unparseable JSON: $($_.Exception.Message)" }
}

function Get-Fenced([string]$text) {
    $m = [regex]::Match($text, '(?s)```json\s*(.*?)```')
    if ($m.Success) { return $m.Groups[1].Value }
    return $text
}

function Build-Spec([string]$specFile) {
    $log = & $blender --background --python $buildPy -- $specFile $glb 2>&1 | Out-String
    Set-Content -LiteralPath "$outDir\work\build_last.log" -Value $log -Encoding utf8
    if ($log -notmatch 'ASSET_BUILT') { return @{ ok = $false } }
    $d = ([regex]::Match($log, 'DIMS \(([^)]+)\)').Groups[1].Value)
    $nums = @($d -split ',\s*' | ForEach-Object { [double]$_ })
    return @{ ok = $true; dimsText = $d; dims = $nums }
}

function Approve([string]$tier, [string]$note) {
    New-Item -ItemType Directory -Force -Path "$outDir\approved" | Out-Null
    Get-ChildItem "$outDir\work\views_last" -Filter '*.png' -ErrorAction SilentlyContinue | ForEach-Object { Copy-Item $_.FullName "$outDir\approved\" -Force }
    Copy-Item $glb "$outDir\approved\$Name.glb" -Force
    if ($note) { Add-Content -LiteralPath $report -Value "NOTE: $note" -Encoding utf8 }
    Log "APPROVED ($tier) -> $outDir\approved"
    exit 0
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

    if ($verdict -ne 'FAIL') { Approve $verdict '' }

    # ---- flip-flop guard ----
    $norm = ($mw -replace '[^a-z0-9]', '').ToLower()
    if ($norm.Length -gt 50) { $norm = $norm.Substring(0, 50) }
    for ($h = 0; $h -lt $mostWrongHistory.Count - 1; $h++) {
        $old = $mostWrongHistory[$h]
        if ($old.Length -ge 10 -and ($old.StartsWith($norm) -or $norm.StartsWith($old))) {
            Log "FLIP-FLOP: '$mw' re-raised after being fixed in round $($h + 1)"
            Approve 'PASS-WITH-NOTES' 'flip-flop guard (oscillating judge)'
        }
    }
    $mostWrongHistory += $norm

    # ---- revise spec (minimal patch, guarded) ----
    $prevSpecText = Get-Content -LiteralPath $SpecPath -Raw
    $prevNames = @((($prevSpecText | ConvertFrom-Json).parts) | ForEach-Object { $_.name })
    $baseRevise = @"
You are making a MINIMAL PATCH to the JSON part-spec of a stylized low-poly game asset '$Name'.
BRIEF: $Brief
HARD RULES:
- Keep EVERY existing part, with its EXACT name. Do NOT remove, rename or repurpose parts.
- Touch ONLY what MOST_WRONG requires. Leave every other part's numbers untouched.
- You may ADD new parts if something is missing.
CURRENT SPEC:
$prevSpecText
JUDGE CRITIQUE (fix MOST_WRONG first):
$(($judgement -replace '``````', '').Substring(0, [Math]::Min(1400, $judgement.Length)))
Schema: top-level materials dict (color [r g b], roughness) + parts array; part types allowed ONLY: $($allowedTypes -join ',').
Return the COMPLETE corrected JSON (every part) in one ``````json code block and nothing else.
"@
    $accepted = $false
    for ($tryN = 1; $tryN -le 2 -and -not $accepted; $tryN++) {
        $revised = Get-Fenced (Invoke-Vision $baseRevise @() 4000)
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
                $err = 'patched spec fails to build; revert to previous geometry and apply a smaller change'
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
