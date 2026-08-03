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

## In flight / next

- Manual playtest of farm -> shed -> farm transition + camera feel inside the shed
  (programmatic smoke tests pass, hand test still outstanding).
- flag to user: screenshot_catclose.png crop only shows cat eyes/ears.
