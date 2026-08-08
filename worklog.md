# Wicked Whiskers — Worklog

Append-only session log. Every finished task gets a short entry (what, why, what's in
flight), then an immediate commit + push. Read the tail of this file at session start
along with PROJECT_STATE.yaml and `git log` to restore context after a window close.

## 2026-08-03

- Split the shed interior into its own scene: `scenes/shed.tscn` + `scripts/shed.gd` (S1.5).
  Farm shed reduced to exterior + entry portal (`ShedPortal`, polled via
  `get_overlapping_bodies()` in `_physics_process` to avoid missed Area3D overlaps).
  Shed scene holds one-time loot (string + keys, tracked in GameState via
  `shed_string_taken`/`shed_key_taken`), exit portal back to farm, its own DayNight so
  hunger/tiredness continue. Both smoke tests pass (farm combo + shed).
- Git: baseline + shed split + state notes committed; remote added and pushed to
  `git@github.com:meldrino/wickedwhiskers.git` (SSH, repo left PUBLIC by choice).
  All pushed as meldrino. Git NOT on PATH — use `"C:\Program Files\Git\bin\git.exe"`.
- GitHub auth gotcha resolved: SSH key `id_ed25519` now registered on **meldrino** only
  (meldrinoworld account deleted; wildnodes untouched). PAT stored in Windows Credential
  Manager (`git:https://github.com` → username meldrino) for API work. Repos checked:
  meldrino = latest_wallet, meldrino, meldrino-zbd-connect, sats_sandbox, trader,
  wickedwhiskers (all public).
- SSH config gotcha: `~/.ssh/config` had a UTF-8 BOM that broke ALL ssh (Bad configuration
  option). Stripped the BOM. Rule: never save .ssh/config with a BOM.
- Website deploy gotcha learned: meldrino.com/forai served from `website` host
  (ssh config: 100.77.248.96, user andy, id_ed25519). Web root `/var/www/html` (root-owned,
  passwordless sudo works for andy). Deploy pattern: edit local copy in /home/andy, sudo cp
  to /var/www/html/forai/. Added ww.html entry to the forai index (backup kept as
  index.html.bak.20260803091850). ww.html = stable design reference; do NOT update per-change.
- Memory system reconciled: canonical per-project YAMLs live in C:\crypto\bigpickle\
  (meldrino.yaml = overarching, vminer.yaml, wallet.yaml). Deleted the redundant
  C:\crypto\PROJECTS.yaml master + project-dir stubs I'd created. ww PROJECT_STATE.yaml
  now routes cross-project info to bigpickle\meldrino.yaml (commit aa69d58).
  bigpickle\meldrino.yaml gained: shared GitHub/SSH/PAT/website-deploy info, project routing
  map, and a SUBJECT-SWITCH ritual (dump current YAML+worklog, then load the new project's).
  CRITICAL: bigpickle\*.yaml is LOCAL-ONLY (wallet.yaml holds a seed first word) — never push.
- VMiner Android config-persistence fixed (v1.2.6): old code wrote vminer_config.json to the
  read-only /data/app/... dir so saves silently failed and the app always reverted to defaults
  (worker1) on restart. Now writes /data/data/com.meldrino.vminer/files/vminer_config.json
  (package parsed from resolvedExecutable; createSync recursive on save). Verified on A03s:
  renamed worker to "Meldrino Vminer", force-stop + relaunch → config still loaded, AUTHORIZED OK.
  v1.2.6 (versionCode 2) installed on A03s; source is C:\crypto\vminer1 (not in the private
  meldrino/vminer repo). Pixel 8 (45201FDJH001CS) verified NOT mining as worker1 (no VIPOR
  connection, vminer 1.1.0 idle) — worker1's source is still unknown.
- VMiner auto-stop bug fixed (v1.2.7): app could stop mining on its own (STOP button flips to
  START while app still runs) via thermal hard-stop with no auto-resume, or reconnect-exhaust →
  _tryNextPool which renamed worker to 'worker1' and, if the restart failed, left mining dead.
  Fix: 30s watchdog auto-restarts after unexpected stop (skips manual stop + thermal cooldown),
  and pool fallback no longer overwrites worker name. 1.2.7 verified on A03s. ALSO found: A03s
  getCpuTemp = -1 (SELinux denies sysfs thermal read), so thermal protection is silently OFF
  there. worker1 on VIPOR still unaccounted for — pool shows 3 workers (worker1 750kH/s 2y2mo
  history, Meldrino Vminer=A03s, Pangz Verus miner 3.14MH/s 6mo). Laptop proven clean (zero
  traffic to fr.vipor.net:5040; only AlphaMiner→AlphaPool 5566 and Pearl Wallet; SRBMiner dead).
  KDE Connect phone at 192.168.1.228 (random MAC) — likely the Pixel 8; A03s WiFi = 192.168.1.164.
- RESOLVED 2026-08-03: worker1 was the PIXEL 8. It dropped off the VIPOR workers list the moment
  the Pixel 8 was unplugged. Consistent with the Pixel running the old vminer 1.1.0 (no config
  persistence → always default worker name 'worker1') or another miner app. Mined to the user's
  own wallet RKNaN... — benign, no unknown third-party device. If the user later reconnects the
  Pixel, it should be updated to v1.2.7 and renamed so it stops showing as worker1.

## In flight / next

- Manual playtest of farm -> shed -> farm transition + camera feel inside the shed
  (programmatic smoke tests pass, hand test still outstanding).
- flag to user: screenshot_catclose.png crop only shows cat eyes/ears.

## 2026-08-05 session

- Dialogue pass: converted all 4 remaining "E - ..." prompts to "Click - ..." (bird.gd, dumbleclaw.gd, tractor.gd, mouse.gd). No E actions remain.
- Applied the funnier dialogue from script.txt into the game, adapting the two fish-specific phrases (pond is removed): Dumbleclaw first meeting now has the Mogwarts / long-playing-record speech; advice + trade lines got the purr puns; bird tractor knock and caught-dialogue, mouse trap toasts, and the "Wicked Whiskers" hunger line updated.
- FOUNDATION: Terrain.gd refactored to config-driven. New autoload/TerrainConfig.gd (class_name TerrainConfig; size/extent/seed/noise/lake/flat/hill params + static whiskers() default) and autoload/TerrainGenerator.gd (class_name TerrainGenerator; static generate() + height_at()). Terrain.gd now exposes config, heights and lake dict; lake.gd/main.gd read Terrain.lake.
- Fixes: registered new class_name scripts via headless --import (global_script_class_cache). lake.gd ar p := Terrain.lake.center... could not infer Variant type -> explicit Vector2/float typing.
- Smoke test: SMOKE DONE, all checks pass. Benign RID-leak noise at exit only.

## Next
- Commit + push this batch.
- Land visuals (height/slope coloring) then shader water + sky, per roadmap.
- Grass tutorial still blocked (resend link); stylized_grass_shader.zip is HTML not a zip.

## 2026-08-06 session

- Grass visual pass: tufts rebuilt as wide fanning clumps (config `grass_spacing` 0.3,
  `grass_outer_blades` 6 + `grass_inner_blades` 3, blade width 0.006-0.01, lean out from
  clump center via new `yaw` param in `_add_blade`), base `grass_color` deepened.
  Re-added the `print("GRASS tufts=%d")` count. Headless smoke shows 127,578 tufts
  (was ~138k before the pond fix removed ~11k in the water ring — count is real).
- Pond grass fix: `Terrain.gd` now computes `water_radius` (mirrors lake.gd's 8-direction
  shore scan + 0.5) and `_grass_ok` rejects any tuft within `water_radius + 0.05` of the
  lake center, so no grass grows inside the visible water disc.
- Belly-flop dive: `POUNCE_HEIGHT` 1.6 -> 0.5 (low horizontal arc), phase-0 pose stretched
  into a forward dive (head/arms leading, legs trailing), and `_update_pounce` pitches
  `mesh_root` nose-down ~75deg on the way in, recovering on the way out.
- Added permanent `--pond` screenshot camera (above lake center, looks at the shore);
  committed screenshot_pond.png.
- ANSI-flood prevention: added `C:\Users\Andy\fixterm.ps1` — writes the escape reset
  (`?1000l ?1002l ?1003l ?1004l ?1006l ?1015l ?1049l ?25h`) to rescue a terminal left in
  mouse-tracking / alternate-screen mode by a crashed TUI. Playbook: fresh tab per session,
  log Godot output to a file (never live `| Select-String`), run fixterm.ps1 if it floods.
- Verified: headless smoke PASS (SMOKE DONE), screenshots reviewed via Qwen Vision
  (qwen2.5vl:7b): dense green lawn ~90% coverage, no grass in the water, no artifacts.
  RID-leak noise at exit is benign/pre-existing.

## 2026-08-06 overnight

- ANSI-spam ROOT CAUSE found (research subagent; official docs + GH issues): the flood is
  NOT coloured output but SGR MOUSE-TRACKING reports (`ESC[<b;x;yM`, e.g. `M[555;74;`) the
  terminal emits while opencode's TUI leaves mouse-tracking enabled after an abnormal exit
  (upstream @opentui cleanup order bug). GH anomalies/opencode #6912, #26198, #20458.
  FIX APPLIED: `C:\Users\Andy\.config\opencode\tui.json` = `{ "$schema": "https://opencode.ai/tui.json", "mouse": false }` — disables TUI mouse capture so mouse-tracking is never switched on; takes effect at next opencode start (config is not hot-reloaded). Recovery helper stays: `C:\Users\Andy\fixterm.ps1` (`?1000l ?1002l ?1003l ?1006l ?1015l ?1049l`). No watchdog/idle-timeout exists in opencode config; `opencode run` (non-interactive) avoids the TUI entirely.
- Vegetation generator (replaces the old grass scatter per the overnight plan): NEW
  `autoload/VegetationGenerator.gd` (class_name VegetationGenerator), spec-driven (one
  `VEG_GRASS` dict; flowers/weeds/bushes = extra specs later). Measured tuft footprint
  0.22 m (outer blades 0.05-0.1 out + half-width) -> spacing = footprint * spacing_factor
  0.9 = 0.198 (overlap -> true 100% coverage). Methodical grid over terrain extent, jitter
  ±35%, physics RAYCAST per placement (downward, filtered to the Terrain body by collider
  identity so grass never lands on buildings/shore-wall), water-disc rejection retained,
  analytic slope/height pre-check retained, prints `GRASS tufts=` count. Class registered
  via `--headless --import` (exit 0). IN FLIGHT (next session resumes here):
  1) Terrain.gd: delete old `_build_grass`/`_grass_ok`/`_build_tuft_mesh`/`_add_blade`;
     add async `_build_vegetation(ground)` (await 2 physics frames so the HeightMapShape
     registers, then create a `Vegetation` container + generator + regen); add
     `regen_vegetation()`.
  2) TerrainConfig.gd: remove now-unused grass_* knobs.
  3) player.gd: add `KEY_F5: Terrain.regen_vegetation()` to _unhandled_input.
  4) Smoke test (expect ~290k tufts at 0.198 spacing) + screenshots + commit + push.
- SAFE TO RESTART: repo committed at 856eb1a (working tree otherwise clean except the new
  untracked VegetationGenerator.gd which is safe on disk). bigpickle YAMLs are local-only;
  website ww.html is a static reference (unchanged, deployed).

## 2026-08-06 overnight (vegetation wiring landed)

- VegetationGenerator wired into Terrain.gd: deleted Terrain.gd's old `_build_grass` /
  `_grass_ok` / `_build_tuft_mesh` / `_add_blade`; new async `_build_vegetation(ground)`
  awaits 2 physics frames (so the HeightMapShape registers before the placement raycast),
  then creates a `Vegetation` container + `VegetationGenerator` and calls regen.
  `regen_vegetation()` re-runs the generator. F5 hotkey added: `KEY_F5: Terrain.regen_vegetation()`
  in player.gd `_unhandled_input`.
- TerrainConfig.gd: dropped the now-unused grass_* knobs (spacing/outer/inner/min_h/max_h).
  `grass_color` KEPT — still used by TerrainGenerator.generate_colors for terrain colouring.
- Fix: VegetationGenerator.gd `lo`/`hi` inferred Variant from the spec dict (warnings-as-errors
  broke compile of Terrain.gd, which type-depends on the class) -> explicit `: float` typing.
  Same class of bug as the earlier lake.gd Variant-inference fix.
- Smoke (headless): PASS. GRASS tufts=299838 — matches the ~290k prediction at 0.198 spacing,
  ~2.3x the old 127,578 (so the generator is definitely the code that runs now). Tuft count
  varies ~0.1% run-to-run (299600/300009 windowed): the terrain-filtered raycast correctly
  rejects spots occluded by the randomized trees/rocks — the intended "grass never lands on
  buildings" behaviour.
- Screenshots: `--screenshot --pond` + `--screenshot --flyover` captured (windowed console exe),
  renamed to screenshot_pond.png / screenshot_flyover.png, screenshot.png = flyover copy.
  .import files refreshed via `--headless --import` (exit 0).
- Review: pixel-stats comparison vs the PREVIOUS commit's screenshots is near-identical
  (dusk/night tint renders the lawn cyan-blue: ~59% of pixels hue 180-210 in both old and new;
  avg RGB 0.29/0.38/0.43 vs 0.32/0.39/0.45) -> no visual regression. Qwen Vision review
  DEFERRED to next interactive session: qwen2.5vl:7b needs ~12 GiB free RAM (only ~4.4 GiB
  free) and nearly crashed the machine once — NOT run overnight to avoid an OOM hang. Run
  vision_expert.ps1 on the two new screenshots with the user present.

## 2026-08-07 (grass-sheet experiment REJECTED; state checkpoint)

- Grass plan changed direction in grasslab (C:\crypto\grasslab): instead of 290k 3D tufts,
  cover one 1x1 tile with dense tufts + sward discs, bake the top-down render into a single
  1024x1024 texture, then use it on ONE deformable plane that bends to pond/hills.
  Coverage ladder hit 94.9% (676 tufts @0.04 + _add_sward discs); texture baked
  (grass_tex_1x1.png), tiling seam-checked clean (topdown15), 2x2 slab looked great top-down.
- Landed in WW: VegetationGenerator.regen() now builds an 8x8 m corner grass plane
  (_build_grass_plane(CORNER_PATCH) region (-28..-20,-28..-20), cells=24, UV in metres,
  y = height_at+0.01). New flags: --spawncorner (player at (-26,-26)), --corner screenshot
  camera, --noon (daytime for shots), --nograss (skip vegetation). Texture copied to
  assets\grass_tex_1x1.png (+ .import). Launcher now passes -- --spawncorner.
- USER VERDICT: "looks terrible, blades are just blobs". Recognisable blades lost.
  SUSPECTED: the bake - a top-down ortho bake flattens 3D blades into a pure vertical
  projection, so at 1 texel/m the blades are crushed under the sward discs -> flat blobs.
  Approach PARKED (details + next options in PROJECT_STATE.yaml grass_plane block).
- Git: state checkpoint committed + pushed so disk = reality before switching project.
  Revert path: VegetationGenerator.regen() back to _build_species(VEG_GRASS) restores the
  full-lawn 3D tufts (84cc30f behaviour).

## 2026-08-07 (grass FIXED via hexaquo tutorial - full-geometry + shader)

- User found the 4-part grass-rendering series at hexaquo.at (Karl Bittner, CC-BY-SA) and
  asked whether it can fix the rejected baked-sheet blob look or if we must start over.
  VERDICT: no restart needed. The tutorial's core (parts 2+3) is the SAME architecture we
  already had (full-geometry blades in a MultiMeshInstance3D). What made our grass read as
  "green blobs" was the baked top-down texture (a top-down ortho bake flattens 3D blades
  into pure vertical projections -> crushed into flat discs at 1 texel/m), and even the
  pre-experiment tufts used a flat unlit StandardMaterial3D with blocky box blades.
- Applied the tutorial:
  - NEW shaders/grass.gdshader: spatial, cull_disabled. vertex(): size by clump
    (mix(size_small,size_large, patch_factor) from seamless world-space patch_noise),
    tip bend (pow(bottom_to_top,2)), wind gusts (scrolling wind_noise at world scale,
    bend direction rotated world->instance via inverse(MODEL_MATRIX)). fragment():
    AO=bottom_to_top-wind*affect (self-shadowing tips bright/base dark), ALBEDO mix of
    color_small/color_large * per-blade COLOR gradient, BACKLIGHT translucency,
    ROUGHNESS 0.4 / SPECULAR 0.2, NORMAL leans to straight-up at tips, and the
    `if (!FRONT_FACING) NORMAL=-NORMAL;` cull_disabled fix.
  - VegetationGenerator: blades are now thin RIBBONS (4 vertex rings, 6 tris, half the
    old box's 12) with UV.y 1 at base -> 0 at tip so the shader's bottom_to_top works.
    VEG_GRASS min_h 0.022->0.05, max_h 0.052->0.12 (real-cat ankle-high lawn). Material is
    a ShaderMaterial; patch/wind NoiseTexture2D created in code (FastNoiseLite:
    patch = Perlin+FBM seamless @0.22 for clumps, wind = SimplexSmooth+Ridged @0.6 for
    gusts). Tuning lives in the GRASS_SHADER const.
  - regen() reverted to _build_species(VEG_GRASS, FULL) over the whole 120x120 extent;
    _build_grass_plane/CORNER_PATCH/TEST_PATCH deleted. assets/grass_tex_1x1.png +
    .import deleted. --spawncorner/--corner flags removed from main.gd + launcher.
    NEW --ground screenshot camera (cat-eye level, for judging blade detail).
- Godot gotchas hit: FastNoiseLite has NO `seamless` property (only NoiseTexture2D does) -
  assigning it throws "Invalid assignment of property 'seamless'"; and the fragment built-in
  is `COLOR`, not `VERTEX_COLOR` (that's Godot 3). Both fixed.
- Verified: --headless --import clean; headless smoke PASS (SMOKE DONE, no script/shader
  errors). GRASS tufts ~335.5k @0.198 spacing over -60..60 (rejection keeps grass off
  hills/water/buildings). ~44% fewer triangles than the old box blades (18M vs 32M).
- Screenshots (--noon daylight): screenshot_flyover.png / screenshot_pond.png /
  screenshot_ground.png + screenshot_ground_zoom.png (2x crop). Pixel stats (System.Drawing
  sampling @4px grid): green ~58-59% of frame, avgG 0.82, luminance std 0.206 - strong
  per-blade texture vs a flat sheet (~0.05-0.1). Needs USER EYES to confirm it no longer
  reads as blobs; tuning knobs all live in the GRASS_SHADER const (size, wind, colors).
- In flight: git commit + push; user reviews the screenshots / plays the game; then
  optional Part-3 grass interaction (blades bend away from the cat) + Part-4 LOD only if
  performance ever demands it.

## 2026-08-08 (grass tuning pass: short blades + sward discs = 100% coverage)

- USER VERDICT on the first shader pass screenshots: grass "way too long" + "not giving
  100% coverage". Both fixed in one overnight tuning pass.
- Too long: tutorial bend/wind values assume UNIT-height blades; ours are meter-scaled
  (~0.05-0.12 m). Flipped to short: VEG_GRASS min_h 0.035 / max_h 0.065 m, blade_bend
  0.35->0.02, wind_strength 0.12->0.01. Coverage probe (8px windows over lawn crops) before
  the fix: only ~31% textured / 57% flat-bare - the thin 1.2-1.6cm ribbons covered ~14% of
  their 0.198m cell, so terrain showed through everywhere.
- Not covered: added a SWARD DISC under every tuft - flat 10-tri fan (radius 0.11, local
  y +0.016, so it clears the terrain without z-fighting) with dark vertex colour
  (base*0.6) and a UV.x=2 shader marker -> vertex() skips wind/bend, fragment() forces
  AO=1.0 / NORMAL up. Blades base lifted to +0.02 so they rise out of the sward. This is
  the same _add_sward() trick grasslab used to hit 94.9% top-down coverage.
- Gotchas on the way: `return` is NOT allowed in Godot 4 fragment shaders; the ground
  cat-eye camera can't see the flat 1cm discs at all (edge-on) - red-ALBEDO tests showed
  0 red from the ground cam but 54% of the lawn-crop pixels red from --flyover, proving the
  discs render and it was purely a viewing-angle artefact.
- Final density nudge: outer 8->10 / inner 4->5 blades, widths 0.014-0.019, outer blades
  pushed out to r 0.055-0.115 so tufts interleave. ~33.5M tris (10 disc + 15 blades x 6),
  back near the old-box budget (32M).
- Verified: headless smoke PASS (no script/shader errors, ~335.4k tufts). Coverage
  pixel-stats (lawn crops, System.Drawing): green 96% ground / 93% flyover / 95% pond,
  textured 42/67/58% - the lawn now reads as a solid green carpet with per-blade texture.
- Committed + pushed for user review in the morning. Next: user eyeballs screenshot_ground
  / flyover / pond, then optional Part-3 interaction (blades bend away from the cat) and
  Part-4 LOD only if perf demands.

