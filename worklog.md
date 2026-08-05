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
