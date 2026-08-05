# Scene 1 (Farm Garden) - Required Assets

Ground truth: `main.gd` + `PROJECT_STATE.yaml`. The player-interactable set-pieces are
still primitive boxes/cylinders/spheres with flat colours - THAT is why the scene looks
"blocky". Nature filler is already Quaternius CC0 glbs and looks fine.

## Already good - no action
- `assets/` nature kit: trees x15, rocks x6, grass x3, logs x3, fences x6, crops x5,
  sign, stumps x2, WW.glb (hero cat).
- Full Kenney Nature Kit on disk at `C:\crypto\world\kenneys nature kit\Models\GLTF format`
  (CC0) - contains MORE trees incl. dark/fall variants, flowers, mushrooms, bushes, lily
  pads, path tiles (ground_path*), grass tiles (ground_grass), bridge, tent, campfire,
  pots, canoes, stone/rock variants. Not yet imported into the project.

## Priority list (new work)

### P0 - buildings (currently box builds in main.gd)
- [ ] Farmhouse @ (0,0,-24) - replace box+box-gable+box-roof with a proper cottage model
- [ ] Shed exterior @ (16,0,-10) - replace box with wooden garden shed

### P1 - interactive set-pieces (currently primitives)
- [ ] Tractor @ (10,0,-20) - red tractor, plate must stay readable (combo reveals on it)
- [ ] Mouse - cute, small, replace primitive
- [ ] Bird - perched robin-size, replace primitive
- [ ] Fish - goldfish for the pond, replace primitive

### P2 - props / dressing
- [ ] Dumbleclaw wizard-cat - CUSTOM Blender build (gen_ww.py style) - no realistic CC0
      wizard cat exists; build alongside hero-cat pipeline
- [ ] Pickups: ball of string, sticks, tractor key, padlock, catfood
- [ ] Shed interior: crates, hay pile, lantern, rake, rope coil, boot-with-sprout, mousetrap
- [ ] Pond dressing: lily pads, reeds, stones (lily_large/small + flowers ALREADY in Kenney kit)
- [ ] Ground: replace flat green plane with Kenney ground_grass + ground_path* tiles (local)
- [ ] Variety pass: tree dark/fall variants, flowers, mushrooms, plant_bush (local Kenney kit)

## Rules
- Prefer CC0 (Kenney, Quaternius, Poly Haven, OpenGameArt, Sketchfab CC0 filter).
- Find ONE model at a time -> Qwen Vision (qwen2.5vl:7b) reviews fit/scale/colour/style ->
  big-pickle tweaks in Blender -> import to Godot.
- Keep Kenney scale variance in mind (known_issues: per-model tuning needed).
- GLB format preferred for Godot 4.7.
