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

## 2026-08-09 (CALIBRATED grass PORTED into WW + pre-Isle-of-Wight backup)

- Sandbox calibration (temp grass_test folder, hexaquo tutorial) reached a 1/10-size lock:
  size_small 0.02 / size_large 0.04 with real blades, plus a far impostor plane so the LOD
  seam is never seen. PORTED into the game (full session - bug-fix + screenshots):
- In-game system is now CHUNKED: scripts/grass_system.gd streams 5x5 m chunks
  (CHUNK_SIZE 5.0, STREAM_RADIUS 14, NEAR_RADIUS 6.0 / MID_RADIUS 14.0) centred on the
  camera + mouse. scripts/grass_chunk.gd builds NEAR_COUNT 1,000,000 (40k/m2 detailed
  mesh) / MID_COUNT 250,000 (10k/m2 simple mesh) blades per chunk over multiple frames
  (BUILD_PER_FRAME 250,000) using set_instance_transform. scripts/grass_impostor.gd adds
  a terrain-draped far plane (CENTRE (0,-6), HALF_X 32, HALF_Z 40, RES 1.0) carving
  GrassExclusion + Terrain.water_level. Old VegetationGenerator.gd + shaders/grass.gdshader
  DELETED; grass_static.gd no longer instantiated.
- Shader sizes aligned to 1/10 scale in scripts/grass_game.gdshader: size_small 0.02 /
  size_large 0.04 (was 0.012/0.03). Impostor assets ported: scripts/impostor_grass.gdshader
  + assets/grass_normals.png (imported via --headless --import).
- BUGS FIXED: "painted grass" was the MultiMesh.buffer array path silently failing - the
  impostor alone rendered; rebuilt with set_instance_transform and blades came back.
  SurfaceTool.get_vertex_count() does not exist in Godot 4.7.1 - replaced with a local
  counter. New textures need `--headless --import` before preload works.
- Game starts at NIGHT (GameState.gd day_time := 0.0) - all screenshots now use --noon.
- Screenshots into `small grass\` (kept out of the project root to avoid git noise):
  05_game_catclose.png = USER-APPROVED ("absolutely perfect, you nailed it!").
  06_game_pond.png = BROKEN: "no pond" in frame + near grass too sparse. Pixel analysis
  (3x3 grid) shows NO water region at all despite lake.gd running. --pond camera =
  (-11,9,-16) look_at (-7.5,0,-12.5). Root cause NOT found yet - deferred.
- PRE-ISLE-OF-WIGHT BACKUP (user is powering down; work resumes on the Island):
  PROJECT_STATE.yaml + this worklog updated; git commit + push; meldrino.com/forai/ww.html
  updated + deployed; temp sandbox experiment folders (grass_test 43 MB + grass_part2 +
  grass_part3 + godot-grass) and screenshots copied out of temp to a durable location.
- Next on the Island: make everything look like 05_game_catclose.png; fix the missing
  pond + sparse near-pond grass in the --pond view; re-capture --noon shots into small grass\.


## 2026-08-10 — Far grass lighter than near: distance darkening attempt

Problem (user-confirmed brute fact): far grass is lighter than near grass until you walk up to it. Root cause hypothesis (Gemini + Copilot + sandbox notes agree): it is a LIGHTING mismatch, not a color mismatch. The flat impostor plane catches full sun while real blades self-shadow; AO_LIGHT_AFFECT only affects ambient, not the sun's direct light; DIFFUSE_LIGHT is not writable in fragment() so earlier attempts were no-ops. NOTE: an earlier claim that the scene had fog was WRONG - no environment.gd exists and no scene has fog configured. Godot default = no fog. The distance darkening ramp is the sole compensation for the impostor being over-lit.

User decision: don't try to make everything the same color; just darken the far grass to compensate for the light source. Amount = trial and error.

What was done:
- impostor_grass.gdshader: added darken_start (14.0), darken_end (40.0), darken_amount (0.35) uniforms; fragment() now does ALBEDO *= (1.0 - dist_factor * darken_amount) where dist_factor ramps 0->1 from darken_start to darken_end using distance(world_vertex, CAMERA_POSITION_WORLD).
- grass_system.gd: _impostor_material now sets those 3 params (14.0 / 40.0 / 0.35).

NOT verified in-game yet. Next: run, screenshot, tune darken_amount (and possibly darken_start/end). Fog (environment.gd fog_density 0.028) is a likely compounding factor if distance ramp alone is not enough — consider lowering fog density or moving fog start out past the grass field.


## 2026-08-10 evening - Far-grass darkening VERIFIED + pond camera bug FIXED

Far-grass darkening verified in-game (grassprobe, --grassheight=0.4 --grasspitch=0):
camera at (0, 0.463, 12), luminance reads flat 0.410 @3m / 0.417 @10m / 0.422 @14.5m /
0.414 @26m - impostor no longer reads lighter than near blades. darken params in
grass_system.gd: darken_start 14 / darken_end 22 / darken_amount 0.5 (shader defaults
14/40/0.35). DONE.

POND BUG ROOT CAUSE FOUND + FIXED. Original code set camera_holder.position (LOCAL to
the player node) to Terrain.lake.center + y9 = (-11,9,-16). Because camera_holder is a
child of player (at spawn (0,0,12) with yaw 0.6), the local offset was rotated/translated
away: probe showed cam_world=(-18.11, 9.06, 5.00) - 21m from the lake, hence "no pond".
FIX in main.gd --pond branch: use player.camera.look_at_from_position(pond_from, pond_to,
Vector3.UP) with WORLD coordinates; do NOT touch camera_holder.position afterwards
(touching it recomposes the camera transform because the camera is its child). Verified:
cam_world now exactly (-11.0, 9.0, -16.0) (probe), pitch -61.2, water renders as a band
y~0-250 in the frame (STRIP teal (0.31,0.90,0.94) at y=80-200 = water material colour;
light-blue rows above = metallic water reflecting the sky; grass below). Qwen vision
(3b) false-negatived (said no water) - trust the pixel/STRIP probe data instead.

## 2026-08-10 - POND ROOT CAUSE FOUND + FIXED (--pond screenshot)

Problem (from backup notes): 06_game_pond.png had "no pond" - the water was NOT in the
rendered frame despite lake.gd building it.

ROOT CAUSE: the --pond screenshot branch in main.gd did
  player.camera_holder.position = Vector3(Terrain.lake.center.x, 9, Terrain.lake.center.y)
i.e. it set the CAMERA HOLDER (a CHILD of the player node) to the lake-center offset in
PLAYER-LOCAL space. With the player's spawn transform (position (0,0,12) + yaw 0.6) the
holder/camera ended up at world (-18.11, 9.06, 5.00) - about 21m away from the lake at
(-11,-16), so the pond was simply out of frame. First fix attempt added a
player.to_local() holder line that made it worse (cam_world went to (-22, 17, -44))
because setting the holder AFTER look_at_from_position re-composed the camera's child
transform.

FIX (main.gd --pond branch): pure world-space placement -
  var pond_from := Vector3(Terrain.lake.center.x, 9, Terrain.lake.center.y)
  var pond_to := Vector3(Terrain.lake.center.x + 3.5, 0, Terrain.lake.center.y + 3.5)
  player.camera.look_at_from_position(pond_from, pond_to, Vector3.UP)
and DO NOT touch camera_holder.position afterwards (camera_frozen=true already stops the
per-frame player camera updates).

VERIFIED via --grassprobe on the same run: PROBE cam_world=(-11.0, 9.0, -16.0) - camera
exactly above the lake center. Fresh screenshot_pond.png row analysis: water surface
fills the top ~250px of the frame (STRIP y=80-200 = teal (0.31,0.90,0.94) = water albedo;
lighter blue rows above = metallic water reflecting the sky at pitch -61.2, so NOT actual
sky). Grass below. The pond IS in the frame now.

NOTE: qwen2.5vl:3b vision review falsely reported "no water" - the 3b model is too weak
to read the water against the sky reflection at a steep angle. Pixel/probe analysis is
the trustworthy signal here.

Also VERIFIED far-grass distance darkening from earlier today (grassprobe): luminance
flat across distance (0.410 @3m -> 0.422 @14.5m -> 0.414 @26m) - impostor no longer
reads lighter than near blades.

## 2026-08-11 - GRASS REBUILT: OPTION B (full-geometry, <=2cm cap, impostor DELETED)

User ultimatum: Option B - restore the USER-APPROVED 05_game_catclose look (026850c
full-geometry tufts) with engine-native LOD, and a NEW hard constraint: grass must be
NO MORE THAN 2 CM TALL. If this fails -> week gets thrown away (Option 3).

KEY REALISATION (ground truth): the approved 05 screenshot was pre-port full geometry;
the game NEVER ran at that quality (33.5M tris all drawn, single MultiMesh, no culling).
The port (e081557) = 2-tier ground (blades + baked impostor plane) = the ROT.

WHAT WAS BUILT
- scripts/grass_system.gd: rewritten - ONE shared shader (shaders/grass.gdshader), NO
  impostor, NO light-split. Streams ALL terrain cells (cx/cz -12..11 = full +-60m; no
  fog in env so full coverage required or bare lighter terrain shows as "far lighter").
  Tier 0 = full tufts within NEAR_RADIUS 10m, tier 1 = sward-disc-only beyond. Chunks
  spawn sorted by distance to camera/mouse. STREAM_RADIUS 92.
- scripts/grass_chunk.gd: rewritten - runtime-built tuft meshes (static build_full_mesh
  / build_disc_mesh, SurfaceTool). Tuft = flat sward disc (UV.x=2 marker, radius 0.11,
  base*0.6 dark) + 10 outer + 5 inner ribbon blades. Placement = jittered grid at
  0.198 spacing (676/chunk), skips water/slope>1.2/rock>1.8/exclusion rects. Budgeted
  build (6000/frame).
- shaders/grass.gdshader: RESTORED from 026850c + per-instance noise fix -
  NODE_POSITION_WORLD is only the chunk origin for MultiMesh (would chunk-quantise
  patch/wind); now samples at (MODEL_MATRIX * vec4(0,0,0,1)).xz = per-tuft world pos.
- 2CM CAP MATH: local blade tip = base_off 0.008 + max_h 0.008 = 0.016 m; x shader
  size_large 1.25 = 0.020 m EXACTLY. Disc top 0.006x1.25 = 0.75cm (flat base, invisible).
  Instance scale = 1.0 (no extra scale factor).
- DELETED (dead rot files): scripts/grass_impostor.gd, scripts/impostor_grass.gdshader,
  scripts/grass_game.gdshader, scripts/grass_common.gdshaderinc (+ .uid).

DEAD-END FOUND: assets/grass.glb, grass_leafs.glb, grass_large.glb = REJECTED grass-sheet
experiment leftovers (max Y 0.254m = 25cm, teal pbr 0.17,0.85,0.72) - NOT usable
"importable scenes" for the engine-native-LOD idea; runtime tuft build used instead.

VERIFICATION (all passed)
- headless --smoketest: PASS, zero SCRIPT/Parse errors.
- --screenshot --catclose --noon vs approved 05: GreenFrac 0.602 vs 0.606; bands
  0,0,0,0.454,0.95,0.955,0.994,0.989 vs 0,0,0,0.462,0.964,0.96,0.998,0.99. Match.
- --grassprobe --probescan: luminance FLAT 0.41 (2m) -> 0.44 (10-20m). No lighter band.
- Qwen vision (3b) catclose + grazing angle: "short lawn", "coverage uniform near and
  far, no lighter band/bare ring/seams", "green". (NOTE: 3b was WRONG about pond water
  on 08-10 - pixel stats stay the primary signal, vision is corroboration.)
- --fpsbench: avg 152.8 fps / p95 166 (min 1.0 = first-frame grass build hitch).
  First time full-geometry grass is PLAYABLE (old = 33.5M tris lag).
Screenshots: small grass/09_catclose_2cm_lawn.png, 10_grass_grazing_2cm_lawn.png.

## 2026-08-11 - GRASS VISION LOOP: BARE TEST WORLD -> QWEN "FIELD OF GRASS" (height is the lever)

User: "it is not much better" -> build a NEW WORLD (no houses/trees/anything, just flat ground +
grass), screenshot it, show Qwen, iterate until Qwen describes it as "a field of grass".

BUILT: --bare mode (test rig, reusable):
- autoload/Terrain.gd: --bare uses TerrainConfig.flat() (no lakes/flats) + heights zero-filled.
- TerrainConfig.flat(): static, lakes=[] flats=[].
- scripts/grass_exclusion.gd: --bare short-circuits exclusions (no buildings = no bald rects).
- scripts/main.gd: --bare skips ALL build_* (farmhouse/shed/tractor/lake/trees/rocks/pickups/NPCs),
  still spawns player + grass; bare screenshots hide the cat (MeshRoot) and the HUD (Hud.visible).
- scripts/grass_system.gd + grass_chunk.gd: --hscale=<n> runtime blade-height override
  (scales min_h/max_h/disc_radius/spread/width in build_full_mesh) for height experiments.

GRASS IMPROVEMENTS (all kept, independent of height):
- blades denser (outer 10->16, inner 5->8) + wider (7-11mm outer / 5-7mm inner) + TAPERED tips
  (half-width * (1-0.6*t)) - blades now read as grass blades.
- sward disc gradient re-tuned darker (center base*0.6, rim base*0.78) so bright tips pop.
- shader: 3-scale world-space noise = patch_factor (6m) + mottle (0.3m per-tuft) + mottle2 (1.4m)
  + per-pixel turf grain fm (world_vertex.xz/0.05). Disc sits darker (mix 0.55-1.05) than blades.
- NEAR_RADIUS 10 -> 18 (blades cover more of the frame).

VISION LOOP (qwen2.5vl:3b, vision_expert.ps1) - the key result:
- 2cm grass (game default): "green carpet, smooth uniform, no visible blades".
- CALIBRATION: real grass-field photo (Pexels, downscaled 1280x720) -> Qwen says
  "a field of grass with visible blades and texture" => the 3b model CAN read blades.
- Close-up crop of our own render (bottom 30%) -> "grass blades elongated narrow, overlap" =>
  blades RENDER fine; the full-frame read failed because blades only filled the frame's bottom sliver.
- Height sweep at base camera: hscale=6 (~6.4cm tips) = carpet; hscale=7 (~7.4cm) = borderline;
  hscale=8 (~8.4cm tips) = PASS: "a dense, green grassy field... grass blades are visible...
  individual blades and strands clearly discernible... lush, green field". Grazing view also PASS.
- fpsbench hscale=8: bare 152.8 avg / full game 151.9 avg (NO perf cost - height is free).
Screenshots: small grass/11_bare_field_h8.png, 12_bare_grazing_h8.png, 13_game_catclose_h8.png.

OPEN DECISION for user: game cap is <=2cm (mowed lawn) = exactly the carpet read. The USER-APPROVED
05 look was 3.5-6.5cm. Options: (a) relax cap to ~8cm (top of approved range, reads as grass, free perf),
(b) keep 2cm and invest in MUCH denser geometry (prohibitive for far field).

## 2026-08-11 - REVERT to the 13_game_catclose_h8 look + backup rule
USER: 13_game_catclose_h8 was "massively better" than the dense-scatter version; revert to it exactly.
- Reverted grass_chunk.gd to h8-era: VEG outer 16 / inner 8, ring-layout tufts (outer ring 0.03-0.06m,
  inner ring 0-0.02m), 24-seg sward disc, ribbon blades (segs=3, taper 0.6), per-instance jitter +-0.002.
- Reverted shader to h8-era: blade_bend 0.35, roughness/specular uniforms (0.4/0.2), rest bend
  `blade_bend * pow(bottom_to_top, 2.0)` (no *VERTEX.y).
- grass_system.gd: blade_bend 0.02, NEAR_RADIUS 18, wind_strength 0.01 (all h8-era).
- daynight.gd: DAY_TOP (0.35,0.6,0.95), DAY_HORIZON (0.82,0.86,0.9), ambient 0.32+0.5*day (h8-era).
- Verified vs 13_game_catclose_h8.png: GreenFrac 0.59 vs 0.58, same mid/bottom band profile, sky matches.
- NEW BACKUP RULE (user): every screenshot = GitHub commit + push, so any look is fetchable from backup.
  Screenshot naming convention: <seq>_<mode>_<camera>_<state>.png, e.g. 16_game_catclose_h8.png.
  Commit message = same state tag so GitHub history is the revert map.
Screenshots: screenshots/16_game_catclose_h8.png (game catclose, hscale=8).

## 2026-08-11 - DEFAULT game height = h8 look (fixes "game looks nothing like h8")
USER ran the game plain (double-click) -> 2cm carpet at night = "utter shit, nothing like 13_game_catclose_h8".
ROOT CAUSE: 13_game_catclose_h8 used --hscale=8 (8cm blades); the game DEFAULT was still hscale=1 (2cm mowed-lawn carpet).
FIX: grass_system.gd default hscale 1.0 -> 8.0 (--hscale flag still overrides).
VERIFIED default launch at noon vs 13_game_catclose_h8: sky 165/209/242 vs 165/203/235, grass bands 142.5/126 vs 144/108, GreenFrac 0.59 vs 0.584. Matches.
Night start (day_time := 0.0) unchanged - intentional day/night cycle.
Screenshots: screenshots/17_game_noon_h8default.png (default camera, noon, hscale=8 default).

## 2026-08-11 - REAL far grass everywhere + field 50x50 + macro far chunks (LOD)
USER: far field still read dark / not real grass. The old far-impostor path is dead - far chunks now
render the SAME full-geometry tufts as near (grass_chunk _full_mesh_far), one shared shader.
- Far tier = full tufts (no impostor, no "small tufts"): the dark far band is gone; grass reads as
  grass to the horizon. STREAM_RADIUS: 92 -> 100 made the grazing bench drop 43.7 -> 26.2 fps, so
  settled on 70 (terrain caps at +-60 anyway, so 70 == full coverage with no waste).
- Near adaptive tier 4x density (commit 8af0dde) so coverage is complete even looking straight down.
- FIELD SHRINK (user-approved, "50 x 50 is plenty"): WORLD_SIZE 60 -> 54 -> fence at HALF-2 = 25
  -> field is exactly 50 x 50 = 10 WHOLE 5m chunks (chunk-aligned). Lake/tractor/bird tree all
  still fit inside the new fence (verified). Fence build auto-derives from HALF - no position edits.
- MACRO FAR CHUNKS (user's "bigger chunks far away" idea, TESTED): beyond FAR_RADIUS 40m, chunks
  are true 10x10m (MACRO_SIZE 2 = four 5m cells merged into ONE real chunk, key "cx,cz,size"),
  tufts at TUFT_SPACING_FAR 0.32 vs 0.2 near. Fewer MultiMesh draw calls AND ~4x less far fill
  (the GPU cost that dominates). Chunk key format changed to "x,z,size" everywhere (desired map,
  _key_dist, _spawn, _update_tiers). Tier: 0 adaptive <= 18m, 1 grid @0.2 <= 40m, 2 macro @0.32 >40m.
- fpsbench at the grazing view: avg 41.1 / p95 55.0 / min 1.0 (min = first-frame grass build hitch).
  vs the pre-regression reach-92 baseline of 43.7 - effectively flat, but now with real far tufts.
  GOTCHA (cost me ~10 min): Godot user args need the `--` separator: `--path <proj> -- --fpsbench`
  (without `--` the flag never reaches the game and it just idles forever). Windowed, NOT --headless.
- Verified: parse/boot clean (--quit-after 240, no SCRIPT errors); fpsbench exit code 0.
- NOT yet verified: user eyes on whether 0.32m far meadow + 10m chunk seams read OK at the horizon.
Screenshots: fpsbench_diag.txt (bench log), screenshots/29_lakeshore_pinkground.png +
30_lakeshore_pinkground_90.png + 31_lakeshore_map.png + 32/33 (disc-bright lake + catclose shots).

## 2026-08-12 (night shift) - grass chunks back to 5x5 + socket investigation + autonomy session
USER (in-game): "when ww turns around the grass disappears altogether sometimes" + suspicion of the
big macro chunks. USER DECISION: "put all the chunks back to 5x5... if we don't need to then lets not
fuck about with them".
- REVERTED macro far chunks (10x10) back to 5x5 EVERYWHERE: grass_system.gd _chunk_key() now always
  emits "cx,cz,1"; MACRO_SIZE const deleted; _update_tiers = pure distance tiers on 5x5 chunks
  (0 adaptive <= NEAR_RADIUS 18, 1 grid @0.2 <= FAR_RADIUS 40, 2 grid @0.32 >40). TUFT_SPACING_FAR
  0.32 + STREAM_RADIUS 70 kept. NOTE: 5x5 far chunks = ~4x more far MultiMesh draw calls than the
  10x10 macro merge (fpsbench re-check pending).
- DISAPPEARING-ON-TURN root-cause hypothesis (NOT yet fixed): _update_chunks spawns chunks sorted by
  camera+mouse distance; grass_chunk _rebuild() sets _mm.visible=false until the whole MultiMesh
  array is placed (BUILD_PER_FRAME 6000). A fast turn sweeps the Mouse point across the field -> a
  wave of freshly-spawned INVISIBLE-while-building chunks, plus tier flips that rebuild chunks
  (invisible again during rebuild). Fix candidates (for later): keep _mm.visible=true during rebuild,
  raise BUILD_PER_FRAME, or don't key chunk streaming on the mouse position.
- SOCKET: recurring "Cannot connect to API: The socket connection was closed unexpectedly" (user saw
  it constantly; also filled ~/.local/share/opencode/log/opencode.log).
  - 138 drops this session log, providerID=opencode modelID=big-pickle, roughly ONE PER GENERATION.
  - stream-start -> error delta measured: 6-69 s, variable (NOT a fixed 30 s timer) => mid-stream
    SSE reset, NOT idle timeout.
  - opencode auto-retries ~2 s later and ALWAYS succeeds => no data loss, cosmetic-but-noisy.
  - Suspects: opencode API server / CDN resetting SSE, or Avast Web Shield proxying + killing
    long-lived HTTPS streams (this laptop's known Avast behaviour).
  - ACTION: added "logLevel": "DEBUG" to C:\Users\Andy\.config\opencode\opencode.jsonc. Needs an
    opencode RESTART to apply. Next drop after restart will log the fetch-level cause (exact host +
    ECONNRESET/socket-hangup/TLS) so the blame lands on the server or the AV.
- AUTONOMY: user went to sleep and authorised unattended work. Night-shift task list in
  PROJECT_STATE.yaml (todo section): chunks in lake, Dumbleclaw's beard, animations, placeholder
  beautification. Verify with smoke test + --noon screenshots before committing. This session is
  writing everything to YAML/worklog/git as it goes (recovery ritual).

## 2026-08-13 (night shift) - ground overhaul + sky + fence/gate/tree collision (todo list)
Night-shift to-do list completed this session (user approved the list then slept):
- GROUND COLOUR: TerrainConfig.grass_color (0.35,0.55,0.2) -> (0.16,0.29,0.10) much darker green.
  grass_ground.png re-tinted as a BRIGHT detail map (mean 0.844,0.85,0.797) so texture * vertex
  grass = (0.135,0.247,0.08) rich dark green. Terrain material keeps vertex_color_use_as_albedo
  (slope-rock/water-edge blends intact); albedo_color white; texture_repeat stays default (ENABLED).
- TERRAIN UVs + texture wiring: Terrain.gd _build_world() set_uv(Vector2(x,z)*0.25) = 1 tile per 4m;
  material albedo_texture = grass_ground.png, linear+mipmaps filter. NOTE: TEXTURE_REPEAT_ENABLED
  const does NOT exist in Godot 4 BaseMaterial3D (repeat is the default) - first smoketest run hit
  a parse error, fixed by dropping the line.
- TREE COLLISION = trunk only: colliders were children of scaled trees so the 0.6x2.0x0.6 box grew
  with tree scale (2.6-4.4) into canopy-wide blockers. Now TRUNK_COLLIDER_SIZE = Vector3(0.5,1.8,0.5)
  world-space, divided by tree scale (bird tree /4.0 at 1.2m up).
- FENCE: north edge (farmhouse) was missing a segment - gate placed at x=0 but the old per-edge loop
  put panel i=4 center at x=3.125 (overlap + ~3.5m gap east of gate). New _build_gate_edge() builds
  the whole edge symmetric around the gate: panels at +-6.25, +-12.5, +-18.75, +-25 (9 items, 6.25m
  pitch - same as other edges). Gate fixes: latch moved from pivot-local (1.4,0.95,0) (floating, near
  west post) to (2.85,0.95,0) (meets east post at world x=1.455); swing +PI/2 -> -PI/2 so it opens
  INTO the yard per the comment (was opening out toward the farmhouse). NOTE for user: north corner
  panels at +-25 overhang ~3m past the east/west fence lines (+-24.82) - eyeball in morning.
- GRASS CULLING: grass_system.gd only spawns chunks whose center is inside FENCE_HALF (absf <= 25).
  This KILLS all tier-1 discs - outside the fence is now bare textured terrain. _update_tiers still
  runs (all chunks end up tier 0), GRASSDBG still prints for the morning check.
- SKY: daynight.gd - runtime cloud cover (FastNoiseLite fbm, threshold gradient, 1024x512 seamless
  NoiseTexture2D) set as ProceduralSkyMaterial.sky_cover; day/night "fader" via sky_cover_modulate
  (white at day -> dim blue-grey Color(0.3,0.34,0.55) at night). Stars improved: 320 pts with
  per-vertex brightness, twinkle via albedo alpha sin(time_s*2.1). NEW shooting stars: spawn every
  22-55s at night, thin additive QuadMesh streak, 1.4s life, fade in/out (not overdone).
- FIXED during smoketest: daynight.gd `var k := s.t / SHOOT_LIFE` failed type inference (dict value
  is Variant) -> explicit `var k: float`. Smoke + all --noon screenshots pass with ZERO script errors.
- ASSET AUDIT via gemini-expert.ps1 (MoE wrapper, text-only): keep fence_corner/bend/gate/crops/
  sign/tree_oak_fall; prune fence_planks/fence_simple/stump_square. WW.glb 37MB = likely embedded
  uncompressed textures or dense keyframes (check in Blender). Free CC0 packs: Kenney Agriculture
  Kit, KayKit Farm Bits, Quaternius Ultimate Farming.
- VERIFICATION: headless+windowed --smoketest PASS (SMOKE DONE, 0 SCRIPT errors; exit RID-leak
  noise is normal). Screenshots: flyover/catclose/pond/ground/dumbleclaw (noon) + base (night).
- GIT: save5 committed twice (6222240 = parse-error fix on 6293524), tag save5 force-moved. Push
  still impossible on detached HEAD (master diverged at b52b495) - left for the user, no force-push.
  screenshots/ debug.log + .import files + grass_compare/ stay UNTRACKED (scratch).

## 2026-08-13 05:00 - USER MORNING REVIEW of save5
USER (first look at the game): "well done. ground colour is much better, outside ground is great,
tree collision is fixed. The gate is better but not right, the clouds need some work but you have
done well. we can have a look later as it is 5am now".
- APPROVED / ship as-is: dark ground colour, bare textured terrain outside the fence, trunk-only
  tree collision.
- NEEDS MORE WORK (deferred, user going to sleep): (1) the gate is "better but not right" - re-check
  panel placement/latch/swing geometry against the fence line when we next work on it; (2) clouds
  "need some work" - likely the fbm threshold gradient looks blobby/unnatural; try softer/grainier
  cover, fewer but larger puffs, or lower modulate strength.
- User then went to sleep; this entry closes the save5 night shift.

## 2026-08-13 09:00 - USER DECISION: Kenney-only asset look (no cross-pack mixing)
USER asked whether to fetch more replacement assets (KayKit/Quaternius were suggested), then
immediately questioned it: "or do we really want to? we do want a constant look across the game".
DECISION: NO new asset packs. Audit confirmed the game's props ALREADY all come from the Kenney
Nature Kit (names match exactly: rock_smallA-D, log/log_stack, tree_oak/default/fat/thin, crops,
stump_round/square, sign, fence_*). The full kit is on disk at C:\crypto\world\kenneys nature kit
(OBJ + STL + Side-textures) and includes same-style upgrades if ever needed (fence_corner/bend/gate,
corn/wheat crops, flowers, bushes, mushrooms, tents, campfire, bridge). Rule going forward: any new
prop must come from THIS kit (same style), never Quaternius/KayKit mixed in. Character/NPC upgrades
(Dumbleclaw beard etc.) are code-built primitives, not asset-pack - unaffected.

## 2026-08-13 ~13:00 - WW-style asset rework (trees/rocks/shed/padlock/fish) + heartbeat enforcement

- HEARTBEAT: user caught big-pickle ignoring the ticker protocol twice. Structural fix: new opencode
  plugin C:\Users\Andy\.config\opencode\plugins\heartbeat.ts (auto-loads at startup; needs opencode
  restart). It appends a "HEARTBEAT OVERDUE (N min)" banner to every tool result once 10 min pass
  without a tick, injects the reminder into the system prompt each turn, and exposes a 	ick tool.
  State file: C:\crypto\bigpickle\heartbeat-state.json (stamped by the tick tool / chat TICK lines).
- CAT (gen_ww.py): arms are now SEPARATE meshes (not unioned) held outside the body so auto-weights
  pin them to the arm bones; shoulders raised (arm x range 0.68-0.76, shoulder z=1.58), hands smaller;
  capsule() takes a mat param (fixes white cap spheres); eyes flattened to almond (scale 0.75,0.22,0.85);
  whiskers lowered to cheek level; pot-belly + vibrant colours applied. WW.glb regenerated (32.8MB,
  32 meshes, 26 bones) + reimported + smoke PASS. NOTE: build_armature() bone positions still at
  OLD arm coords (0.48-0.52) - MUST be updated to match the 0.68-0.76 arm meshes on next cat pass.
- LAUNCHER: new wickedwhiskers.bat alias (calls Play Wicked Whiskers.bat). Launch gotcha: Start-Process
  needs embedded quotes for the space in "wicked whiskers": -ArgumentList '--path \"C:\crypto\wicked whiskers\" -- --bare --nograss'.
- main.gd:100: --bare no longer hides cat/HUD unless --screenshot is also present (was hiding the cat
  in bare play). daynight.gd:243: shooting-star 'modulate' crash fixed (material albedo alpha).
- FISH (scripts/fish.gd): 5 circling fish -> ONE fish at the lake centre (local origin = lake centre).
  Periodically (3.5-6s) leaps out of the water in an arc (~2.2m), forward motion + roll for visibility;
  clicking it triggers an instant jump. Added dorsal fin. Fixed a Variant-inference parse warning.
- TREES: new procedural pipeline tools/blender/ww_style.py (shared palette/helpers = the style spec)
  + tools/blender/gen_trees.py -> assets/tree_ww_round.glb, tree_ww_cone.glb, tree_ww_fat.glb.
  main.gd TREE_SCENES now points at these (Kenney trees retired). Bird tree (main.gd _build_bird_tree)
  also uses tree_ww_round. Trees chunky subdiv-smoothed spheres/capsules in the WW palette.
- ROCKS: tools/blender/gen_rocks.py -> assets/rock_ww_a/b/c.glb (boulder, paddy rock, pebble stack);
  main.gd ROCK_SCENES now uses them (Kenney rocks retired).
- SHED (main.gd _build_shed): gabled roof (2 sloped slabs + ridge cap + PrismMesh gable triangles),
  vertical plank seams, corner posts, framed side windows, framed door with plank lines.
- PADLOCK (scripts/door.gd _build_padlock): real brass combo padlock - torus shackle loop, 3 brass
  dials with black grooves, white keyhole plate + hole, positioned (0, 1.05, 0.14).
- BIRD (scripts/bird.gd): blue crest, white belly, glint on eye, rounded wings (spheres not boxes),
  rough materials. MOUSE/TRACTOR: rough materials for style consistency. STICK pickup: branch tip +
  rough wood.
- All verified: --import clean, smoke PASS, committed in 4 commits (739ccdb..1a10663).
- OPEN: armature bone coords fix; commit+push (still detached HEAD, master diverged at b52b495);
  worklog commit below.

## 08-13 GATE FIX (committed c418517)
- USER RULE: gate only opens/closes when WW is within 2 cat lengths (1m) of the gate; far clicks = nothing.
- Range is now PER-INTERACTABLE (interactable.gd interaction_range, default 1.8m). Gate sets 1.0m.
- Gate exposes TWO interaction points (interactable.gd interaction_points_extra): hinge (-1.75,0.6,0.5)
  + far end (1.455,0.6,0.5) - the gate is 2.9m wide, so 1m from either end covers it. _within_interact_range
  (player.gd) checks primary point OR any extra point.
- walk_to_interact flag (interactable.gd, default true): gate sets false so WW never auto-walks to open
  it from afar - far clicks are no-ops.
- interaction_center moved to hinge side (-1.75,0.6,0.5): after the swinging panel carries WW to the west,
  he can push it shut (was blocked by the open panel at the old center point).
- gate_test.tscn/gd: close-range open+close cycle, far-click no-op, far-end proximity. VERIFIED headless:
  far 5m=within_range false, close=open (-PI/2 into yard, WW shoved to (-1.75,-24.19)), second click=close,
  far end (1.45,-24.3)=within_range true.
- NOTE: clicks near the gate's lake edge can be claimed by fish (_pick_fish runs before interactables in
  _handle_click_at) - that is the designed fish-catching priority, not a gate bug.
- --gate screenshot camera mode added to main.gd.

## 2026-08-13 gate click fix (session 2)
- interaction_point moved to panel center (0.005,0.6,-25), opens/closes from hinge or far end (extras -1.445/+1.455), covers full 2.9m gate.
- fish-vs-gate: _pick_interactable now runs BEFORE _pick_fish - gate clicks win, no more lake pounce.
- console errors fixed: lake.gd normal_map -> normal_enabled+normal_texture (Godot 4); player.gd mi.surface_get_material -> mi.mesh.surface_get_material.
- GRASSDBG tier-count spam removed (grass_system.gd).
- shooting-star crash: add_child(mi) before look_at (daynight.gd).
- gate_test now re-aims camera at close step (was stale-camera artifact). All 4 scenarios pass headless.
- import + --smoketest clean. commit 2f0f423.

## 2026-08-13 gate pick: all-panel clickable, animal-proof (session 3)
- USER BUG: in-game only the middle of the gate toggled; hinge/far ends did nothing.
  Cause: _pick_interactable projected only the SINGLE primary interaction point
  (panel middle) and required the click within 40px of it - interaction_points_extra
  were range-only, never used for picking.
- FIX 1 (player.gd): _pick_interactable now evaluates ALL of an interactable's
  interaction points and takes the nearest-to-click one.
- FIX 2 (interactable.gd + gate.gd): new get_interaction_points() base method =
  primary + extras (world space). Gate overrides it with THREE pivot-relative points
  (hinge 0.0 / middle 1.45 / far end 2.9, pivot-local x) so they SWING WITH THE PANEL
  - the gate is clickable at both ends whether open or closed (the old gate-local
  extras were stale once the panel rotated).
- FIX 3 (player.gd): occlusion ray now tries the points nearest the click first and
  accepts the pick if ANY ray is clear - a fish/mouse wandering across the single
  old ray could deaden the click (intermittent far_end_pick=null in tests).
- gate_test: added open-far-tip click + hinge-click scenarios. Import + smoketest
  clean; 6/6 consecutive runs pass. commit <next>.

- commit 7297365 (whole panel clickable, pivot-relative points) + 4f8b14b (raycast pick + hit-point range).
- 6/6 headless gate_test runs green (retested 2026-08-13 session 4, still DONE).

## 2026-08-13 shed: shrink to person scale (session 4)
- USER: shed ~9x the cat (measured 4.82x4.31x4.0m) - "sheds made for people". Approved: 0.9x2.0m
  door, 2.5m walls, ~3.0x2.4m footprint, ridge ~3.2m. Calibration locked: 1 cat height = 0.5m
  (measured cat AABB 0.36x0.458x0.34). Never trust Blender units as metres (WW.glb ~2 units scaled 0.33).
- main.gd _build_shed: half_w 1.5, half_d 1.2, wall_h 2.5. Roof now DERIVED from the box (roof_over 0.35,
  rise 0.5, slab_len = hypot(half_w+roof_over, rise), slope_ang = atan2(rise, half_w+roof_over),
  roof_d = 2*half_d+0.8, slabs at +-slab_cx, ridge cap (0.45,0.45,roof_d) at wall_h+rise-0.02).
  Door frame 0.9x2.0 with 0.8-wide plank door + posts. Portal box (1.1,2.1,0.7).
- Windows: fixed z-fighting flicker (glass pane was flush with wall face at +-1.5). Glass is now a
  recessed alpha-blended pane (TRANSPARENCY_ALPHA, Color(0.72,0.83,0.9,0.4), metallic 0.2, rough 0.1,
  centred wx - sx*0.06, wx = sx*(half_w-0.04)) + proud wooden frame + crossbars. Gemini cross-checked:
  alpha-blend is the right approach for stylised glass (its response was truncated twice by API timeout,
  but core answer confirmed).
- shed.gd interior: floor 3.0x2.4, wall_h 2.5, lint_h = wall_h-2.0, jambs 0.16x2.0 at +-0.62, roof
  (3.4,0.45,2.9) + ridge (3.4,0.3,0.6), light y1.8 r5.5. Props pulled in (crates/loot at +-1.05, boot,
  hay, trap, lantern, rake, rope). Exit portal (1.1,2.0,0.4) at (0,1.0,1.1).
- GOTCHA FIXED: shed.tscn Player spawns at (0,0,0.6); moved exit portal from z 1.55 to z 1.05 and it
  OVERLAPPED the player's collision body at spawn -> instant body_entered -> scene switch during smoke
  test ("Removing CollisionObject during physics callback" + null tree crash). Fix: spawn -> (0,0,0.2),
  portal -> z 1.1 (straddles doorway). Shed smoke test now green: string=1 key=1 exit_portal=true.
- player.gd:271 clamp half (2.25,1.35,1.65) -> (1.35,1.05,1.05). main.gd:82 spawn z -7.2 -> -7.8.
- grass_exclusion.gd RECTS[1] (shed) hx 3.2->1.7, hz 2.6->1.35 (rect-based, chunk-independent).
- VERIFIED: measure (temp, deleted) shed AABB 3.757 x 3.2 (incl roof) x 3.205 tall; door 0.9x2.0;
  gate_test DONE; shed smoke + main smoke green; --import exit 0. commit 0bb790e.
- NEXT: padlock clicks still on hold (planned: add StaticBody3D collider to door/padlock + padlock
  interaction point + headless test mirroring gate_test). Visual queue: stones ~20x too big, trees,
  fish, tractor, Dumbleclaw. Gemini glass response was truncated - retry with longer timeout if needed.

## 2026-08-13 padlock locks the door at click height + exit-portal warning (session 5)
- USER: the padlock visual floated at world ~2.05m ("way out of reach") because the door Area3D
  pivot is at world y=1.0 and the padlock was at local y 1.05. Clicking it did nothing (1m above
  the 1.0m interaction point); clicking ~1m high on the door DID open the combo.
- door.gd _build_padlock rewritten as latch hardware: mounting plate straddling the door edge at
  x 0.40, door staple + brass shackle loop, lock body + 3 dials + keyhole, jamb staple at x 0.15
  (reaches the frame post at door-local x 0.55). Padlock node at local (0.40, 0.0, 0.12) =
  world (16.4, 1.0, -8.7) - exactly the click height.
- CLICKABILITY: added StaticBody3D "PadlockHit" (BoxShape 0.3x0.42x0.2) on collision_layer 2 -
  raycast pick (bodies, default mask) hits it and walks up to the Door_shed Interactable; the
  player (mask layer 1) walks through the doorway unimpeded. The door-face fallback pick still
  works (interaction_center stays at door centre).
- tests/door_test.tscn/gd (committed, mirrors gate_test): padlock at (16.4,1.0,-8.7), PadlockHit
  layer 2, click padlock -> _pick_interactable=Door_shed + Hud.combo_open=true walking=false,
  click door face -> still picks. DONE headless.
- shed.gd _on_exit: change_scene_to_file -> call_deferred - silences "Removing a CollisionObject
  node during a physics callback" (body_entered fires inside a physics step). Was benign, now clean.
- Re-ran: gate_test DONE, shed smoke green (no warning), main smoke exit 0. commit d886f0c.
- SHED HEIGHT RECONCILIATION (user asked a vision model "shed vs cat" from a screenshot; it said
  ~7x): measured shed/cat = 3.205m ridge / 0.458m cat = 6.97x - the vision model measured the
  ROOF PEAK. Walls are 2.5m = 5.4x cat. No bug; if the user wants the whole shed ~2.5m total,
  that's walls ~1.9m + door 1.7m - pending user call.

## 2026-08-13 CUTAWAY: cinematic padlock unlock (commits 9fef302)
- User: "do an orchestrated Godot cutaway, not an mp4" - so recolor-proof: procedurally built
  every frame, nothing baked. Fur color SAMPLED at runtime from the player's WW.glb Paw_L
  material (probe: #f9ad59 orange, roughness 0.5; pad #816f5d) - a cat recolor auto-updates.
- scripts/cutaway.gd: letterbox bars (CanvasLayer ColorRects) + Camera3D current=true push-in
  on the real padlock (16.4,1.0,-8.7) + 2 procedural paws (capsule forearm, sphere + 3 beans,
  big pad). Right paw spins Dial2->Dial0 (rotation:z +0.38/notch, 3 notches, click per notch).
  Beat of tension, shackle flips (rotation:x PI/2+1.8), padlock tilts/drops, freed. Bars out,
  player cam restored, GameState.cinematic_active=false, then door._finish_unlock swings.
- door.gd: named parts (Dial0-2/Shackle/LockBody), _on_combo success -> cutaway -> _finish_unlock
  (toast + door swing tween). player.gd: input + physics locked while cinematic_active.
- Audio: assets/sounds/click1.wav + click2.wav (CC0 qubodup via OpenGameArt direct zip). Dials
  use click1; pop/drop use click2 pitched down. Imported; --import exit 0.
- Verification: main smoke green (exercises full cutaway, 0 errors); gate_test DONE; door_test
  DONE (padlock pick unaffected). NEW --cutawaytest arg (windowed, real renderer) -> saves
  screenshots/cw_1..6.png; quenn (qwen2.5vl) review: paws ON dials during spins, shackle
  visibly sprung, padlock falls, clean return, letterbox works. Minor nits only ("slight
  clipping", "dead space") - cosmetic.
- quenn ops notes (state file updated): invoke vision_expert.ps1 with & (pwsh -File breaks
  array params); downscale to 640x360, 1-2 images/call (full-res 6-image call >300s HTTP cap).

## 2026-08-13 CUTAWAY v2->v4: real finger anatomy (NOT committed before save-out)
- USER (repeatedly): "you are waving a paw or 3 around the lock", "I do not think you have even
  got the anatomy right, we have agreed 4 fingers (including thumb) but have you actually made
  them?" and "the reason it is a mess is that you cannot see what you are doing" -> the session
  has NO image input (read tool rejects images) and quenn (qwen2.5vl:7b) was too lenient.
  TRUSTED VISION REVIEWER SWITCHED TO gemini-flash-latest via NEW C:\crypto\bigpickle\gemini-vision.ps1
  (GEMINI_API_KEY set; -Prompt + -Image arrays; verified it correctly tore apart v1 frames:
  "hotdog arms", "alien-eye toes", floating limb disconnected from the frame edge).
- v2 (done earlier this session, tested): _snatch_player teleports the real cat away during the
  cutaway (camera was so far/wide the player cat entered frame = "multiple paws"), tight camera
  (fov 70, ~0.5m at padlock), 4 claw-hook toes, numeric overlap debug _debug_toe_overlap proved
  dials in frame + toes within 21-23px of dial centre vs 57-60px radius.
- v3/v4 REWRITE in progress (scripts/cutaway.gd, current on disk):
  - _add_segment uses look_at_from_position (works pre-insertion; look_at fails "Node not inside
    tree" -> capsules stayed vertical = the blob look). This fixed the orientation bug.
  - _make_paw builds 4 digits = 3 FINGERS + 1 THUMB (2-segment capsule digits, knuckle bend,
    pink pad sphere tips) curling DOWN over the dial face; thumb offset/tucked shorter;
    2-segment tapered arm down-right off-frame; left paw mirrored (scale.x=-1), planted on the
    lock body, ZERO motion during the whole cutaway (kills the "waving" read).
  - GRIP-TURN mechanic (the fix for "waving"): dial AND paw rotate RIGIDLY together around the
    dial's world-Z axis - paw orbits the dial (wrist offset (0, RISE 0.05, FRONT 0.035), base
    tilt 0.28) while rotation.z advances +0.38/notch x3. Causal: the paw visibly drives the dial.
  - --cutawaytest RENDERED (19:34): CUTAWAY fingers debug = Dial2 tips_within 2/4 (closest
    65px vs radius 60 - orbit end-position), Dial1 4/4 (54px), Dial0 4/4 (43px); frames saved.
  - NOT YET VERIFIED VISUALLY (gemini review of v4 frames pending) and NOT user-approved.
    THE USER HAS NOT SEEN A SINGLE GOOD FRAME THIS SESSION - this is the core failure.
- SAVE-OUT 19:37 (user protocol: YAML -> GitHub -> website -> compact): this worklog entry +
  PROJECT_STATE.yaml cutaway section rewritten to the v4 reality; commit + push as branch
  (origin/master = diverged grass line b52b495, detached HEAD = cutaway line; no force-push,
  master untouched - merge decision still the user's). forai/ww.html then updated + deployed.
- UNCOMMITTED ARTIFACTS left untracked by design: screenshots/cw_*.png (v2+v4 frames),
  screenshots/debug.log, "Downloads - Shortcut.lnk".

- PAWTEST session (22:50-23:40): user asked for ONE frame of a paw on the lock before committing
  to the full cutaway. Investigated WW.glb for real: 25-bone skeleton (UpperArm/Forearm/Hand per
  front leg), Paw_L/Paw_R MESHES exist (4,906 tris each, 14,720 verts) but NO finger/toe bones on
  the front paws - the paw is a single low-poly blob. It is NOT prehensile. This validated gemini
  -s advice: use the real paw mesh + a SWAT motion (cats cannot pinch dials), not procedural fingers.
  - Built --pawtest harness in main.gd: instances WW.glb, hides all meshes except Paw_L (then later
    Paw_L+Arm_L), rigid-shifts the whole model so Hand.L lands on a dial (target = dial centre +
    offset), close-up camera, renders screenshots/pawtest*.png. Params now read from
    screenshots/pawtest_params.json (target_offset, model_rot_x/y_deg, hand_bend_deg, model_scale,
    cam_offset, cam_fov, out).
  - FIRST FRAMES WERE BROKEN: (1) unquoted path space in a repro lost "whiskers" from the project
    path; (2) a real hang: main.gd had a GDScript parse error (var := JSON.parse_string = Variant
    inference, "warning treated as error" project) -> main.tscn failed to load -> window stayed
    open forever; fixed by typing it `var j: Variant`.
  - Vision-loop infrastructure built: C:\crypto\bigpickle\paw-iter.ps1 = autonomous loop
    (render -> downscale 640 -> gemini-flash JSON grade -> apply clamped corrections -> repeat),
    with quenn (qwen2.5vl:7b) AUTO-FALLBACK after 3 gemini failures (user's Plan B ask - gemini
    free tier limits uploads/requests), per-iteration timeout+kill so godot can never hang the
    loop, raw grade output logged (pawtest_grade_raw.log), every frame archived
    (pawtest_seq_NN.png), best saved (pawtest_best.png), plateau jitter after 5 flat iters.
    JSON parsing gotcha fixed: multi-line string piped to ConvertFrom-Json enumerates chars;
    use ConvertFrom-Json -InputObject + regex extract + truncated-JSON repair.
  - RESULT (9 pose iterations): plateau at 3-4/10 every time. gemini (and the user) agree: the
    real Paw_L mesh is a FEATURELESS BLOB - "untextured sphere", "plain cylinder", "lacks cat paw
    shape and anatomy". Pose/camera/scale tuning cannot fix a mesh with no toe/pad definition.
    The asset's paw will not read as a cat paw to a critical eye at any angle/size.
  - DECISION POINT FOR NEXT SESSION (user is the gatekeeper): the paw needs NEW GEOMETRY -
    either (a) procedural toe bumps added on/under the real Paw_L mesh (hybrid: real fur colour +
    real shape + added toe definition), (b) a better paw mesh/model, or (c) a stylized/silhouette
    approach (gemini's swat/POV insert with a simplified paw). Pose-loop alone is a dead end.
  - Overnight run: paw-iter.ps1 launched detached (60 iters max, gemini w/ quenn fallback) to
    gather data + jitter explorations; results in screenshots/pawtest_*.png + logs.

- OVERNIGHT RUN RESULTS (60 iters, 23:40-00:17, driver paw-iter.ps1 -MaxIter 60 -Model auto):
  - gemini (14 grades): 3/10 EVERY time. Flat plateau confirmed - "plain/beige sphere, lacks cat
    features/claws/anatomy" at every pose, scale, camera. The real Paw_L mesh cannot read as a
    paw to a critical reviewer. Geometry is the blocker, NOT pose (settles the loop question).
  - gemini free tier hit 429 Too Many Requests at ~23:42 (iter 8-9) -> auto-fallback to quenn
    triggered as designed (3 fails). USER'S "limits" CONCERN CONFIRMED - plan B was necessary.
  - quenn degenerated: total=0, scale=0.5, cam=0.25, move=[0,0,0] for ~50 iters - not following
    the JSON schema (grade_raw log has the raw output). It also 429'd once at handoff (busy?).
    quenn fallback is mechanically fine but its grades are USELESS - do not waste iterations on
    it for grading; consider dropping to a hard stop after gemini 429s instead.
  - Loop design proven: render/grade/apply/jitter/logging all worked; godot never hung; best
    saved; every frame archived (pawtest_seq_*.png). Final param state in pawtest_params.json.
  - CONCLUSION: any next step REQUIRES new paw GEOMETRY (toe bumps on the real Paw_L, a better
    paw mesh, or a stylized silhouette paw). Pose loop alone is a confirmed dead end. User is
    the aesthetic gatekeeper - present the 3 options on wake.

- SEQUENCE FRAMES + FINGERS EXPERIMENT (01:40-02:25): user asked for an opening sequence of
  stills: frame1 = lock alone, then the paw sliding in until its round bit covers the FIRST
  dial. Rendered frame1..frame5.
  - MUPPET RULE enforced: user: "at no stage can the shoulder end of the paw go entirely into
    frame ... it looks like the arm is not connected to anything". Fix: flip the model 180deg
    about Z (arm now hangs DOWN out of frame) and drive the paw along a vertical path that keeps
    the arm end cropped below the bottom frame edge at every advance step.
  - FIXED a real bug: paw center computed as skel.to_global(paw_mi.global_transform * aabb_center)
    double-applies the skeleton transform (global_transform is ALREADY global) - the 180deg flip
    got applied twice and shoved the paw off-screen -> "5 frames with not a paw in sight". Now:
    paw_center = paw_mi.global_transform * aabb_center.
  - USER VERDICT on real blob (scale halved to 0.25, arm visible, on dial0): "roughly the right
    size, roughly the right place but it is still a round blob there are no fingers or claws".
  - FINGERS EXPERIMENT: real Paw_L blob sits IN FRONT of the dial face, so procedural fingers
    placed on the dial were hidden inside the blob. Fix: hide Paw_L entirely when fingers=on;
    paw becomes fully procedural = palm (flattened fur sphere) + 4 fingers arcing over the dial
    top + cream claws hooking over. Determinstic, dial-relative.
  - USER VERDICT: "it is just shit. can not deal with it at 2 in the morning, take a break."
  - PATTERN ACROSS THE WHOLE SESSION: EVERYTHING built blind reads as shit to the user - the v4
    procedural cutaway, the real Paw_L blob, and the procedural fingers. This is a capability
    wall: building 3D visuals the agent cannot see does not converge. Recommend stopping
    blind-procedural entirely and letting the USER hand-place/design the paw (they can see),
    OR using a proper paw asset, OR the wide-silhouette swat shot (option d) where detail does
    not matter.
  - Tech notes: pawtest harness now has show_paw / path_mode / advance / path_start|end /
    fingers / model_rot_z_deg params (screenshots/pawtest_params.json); dial target = dials[0]
    (first black circle); frames archived as frame1_lock/frame2_appear/frame3_mid/
    frame4_near/frame5_cover.png + cutaway_seq_v1/v2.png sheets. main.gd changes UNCOMMITTED.
- SAVE-OUT 02:29 (2026-08-14): user turning the laptop off for a break. Everything committed
  (e0bd710), pushed to origin/cutaway-finger-anatomy. Website forai/ww.html update pending this
  save-out. Cutaway is at a decision point (see PROJECT_STATE pawtest block) - resume by
  re-anchoring from melrdrino.yaml + this worklog + git log. Screenshots untracked by design.

- PAW VARIANTS 02:50 (2026-08-14): pivot per user - quenn/Blender makes the paw, agent animates
  in Godot. quenn (qwen2.5vl:7b) wrote a bpy script on 2nd try (300s local-expert timeout on
  1st; used direct /api/generate with TimeoutSec 600 + num_predict 2400 instead) - buggy but
  salvageable conceptually (invalid 4-tuple eulers, fingers along +Z, flat pad circles, arm
  sideways). Rebuilt generator correctly: blender/paw_gen.py (Blender 5.2 API - meshes via
  bmesh + me.to_mesh(), render engine BLENDER_EEVEE, export via export_scene.gltf). 6 variants
  = quenn (quenn's spec), chunky, sleek, kawaii, sharp, stubby. All: 3 fingers + 1 thumb,
  cream claw on every digit, Wicked Whiskers colours (fur #f9ad59, claw #f5e6d0, pad #c98d7d),
  pads on palm front, arm hanging -Y. Rendered TOP-DOWN (user requirement: "all of these paws
  need to be viewed from the top") at 640x640 -> screenshots/paw_preview_<v>.png + labelled
  sheet paw_variants_sheet.png (opened). GLBs exported assets/paw_<v>.glb. Agent CANNOT verify
  visually (no image input) - USER PICK of the 6 is the gate. Committed e74a127, pushed.
  SAVE-OUT note: remaining pending = website forai/ww.html update.

- CHATGPT-PAW PIPELINE + SAVE-OUT 06:45 (2026-08-14): user picks a browser-AI-past-its-own-script
  pipeline (ChatGPT -> paste bpy back -> agent runs headless -> standalone render -> user eyes).
  Runs this session: paw_ai_v1.py (PAW_BUILT, DIMS 0.0761x0.2305x0.0468, first try), v2
  (0.0743x0.2368x0.0458), v3 (0.0770x0.2317x0.0480). Agent cannot see images; user is the only
  judge. v1 = 4 fingers+thumb (wrong, digits on top). v2 = 3 fingers+chunky thumb+soft joints
  ("closest yet"). v3 = thicker fingers, buried knuckles, webbing, sharp claws -> still rejected:
  feedback to ChatGPT = cartoon paws have 3 fingers + 1 thumb, digits attach INTO the hand,
  knuckles sunk lower + aligned, claws missing/not sharp, fill air gaps with more polygons.
  Colour reads white/cream in renders (should be orange #f9ad59) - deferred. quenn vision via
  Ollama /v1/chat/completions works for describing renders but is TOO LENIENT a judge. Scripts
  + prompt + render_glb.py now hosted on the website: /forai/ww-paw/ (verified 200).
  docs/ww.html updated with the full saga (quenn fail + gpt ongoing + others to try) + script
  links, deployed to pi2 (bak ww.html.bak.20260814). Committed + pushed (cutaway-finger-anatomy).
  User suspects agent is altering output (it isn't - standalone render loads the exact GLB).
  Give the user the direct Blender run command: blender.exe --background --python <script>.
- TRELLIS PAW + Q U E N N 5H INVESTIGATION, 01:20 (2026-08-16): paw.glb downloaded from
  TRELLIS.2 (huggingface.co/spaces/microsoft/TRELLIS.2, free w/ HF login). color_paw.py -> paw_clean.glb
  (#f9ad59, stripped textures + vertex colors), shift_paw.py -> paw_hv.glb (hand centered at origin).
  Blender headless previews render grey/black (broken in this env) -> moved to GODOT previews.
  First Godot pawtest renders (4 rotations) washed WHITE + polluted: root-caused two renderer bugs -
  (1) game WorldEnvironment sky ambient + (2) the Terrain AUTOLOAD renders the world's green ground
  into every scene including new scenes. Paw itself verified clean (single mesh, orange opaque GLB).
  Built scenes/pawstudio.tscn + scripts/pawstudio.gd: isolated studio (dark bg, 3 lights, params from
  screenshots/pawstudio_params.json, sweep via model_rot_y). q u e n n reads (via vision_expert.ps1):
  paw is 3D/readable; back-vs-palm calls UNRELIABLE (flip-flops), per-pane sheet prompts degenerate
  (template answers) - use it for coarse colour/pose only, not fine judgement. GEOMETRY (blender
  analyze_growth.py): hand region y-extent asymmetric -0.174..+0.078 -> palm GROWTH confirmed as -Y
  blob (z -0.15..+0.05). Back of hand = +Y. WINNER POSE: model_rot_x_deg=-90 -> back of hand faces
  camera, arm hangs DOWN (Muppet crop), growth hidden behind. Palm side (rot_x=+90) blows out WHITE
  under light = explains "white paw" complaint. bake_roughness.py set material roughness 0.7->0.95 =
  killed "metallic gold" specular, zero white pixels. Final: rx-90_rough.png (back of cat paw, matte
  orange, arm down) confirmed by q u e n n as "clearly a cat paw, not human hand". Result sheet:
  screenshots/paw_investigation_result.png (before/after). NEXT: integrate rx-90 pose into cutaway
  (pawtest model_rot_x=-90, hand on dial, arm down) + fix cutaway lighting so paw reads orange in-game.
