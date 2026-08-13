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
