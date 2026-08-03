extends Node3D

const WORLD_SIZE := 60.0
const HALF := WORLD_SIZE / 2.0

const TREE_SCENES := [
	preload("res://assets/tree_default.glb"),
	preload("res://assets/tree_detailed.glb"),
	preload("res://assets/tree_fat.glb"),
	preload("res://assets/tree_oak.glb"),
	preload("res://assets/tree_simple.glb"),
	preload("res://assets/tree_tall.glb"),
	preload("res://assets/tree_thin.glb"),
	preload("res://assets/tree_cone.glb"),
	preload("res://assets/tree_blocks.glb"),
]
const FENCE_SCENES := [
	preload("res://assets/fence_planks.glb"),
	preload("res://assets/fence_simple.glb"),
]
const ROCK_SCENES := [
	preload("res://assets/rock_smallA.glb"),
	preload("res://assets/rock_smallB.glb"),
	preload("res://assets/rock_smallC.glb"),
	preload("res://assets/rock_smallD.glb"),
	preload("res://assets/rock_largeA.glb"),
	preload("res://assets/rock_largeB.glb"),
]
const CROP_SCENES := [
	preload("res://assets/crop_carrot.glb"),
	preload("res://assets/crop_pumpkin.glb"),
	preload("res://assets/crop_turnip.glb"),
]
const LOG_SCENES := [
	preload("res://assets/log.glb"),
	preload("res://assets/log_large.glb"),
	preload("res://assets/log_stack.glb"),
]
const GRASS_SCENES := [
	preload("res://assets/grass.glb"),
	preload("res://assets/grass_large.glb"),
	preload("res://assets/grass_leafs.glb"),
]

const FARMHOUSE_POS := Vector3(0, 0, -24)
const SHED_POS := Vector3(16, 0, -10)
const TRACTOR_POS := Vector3(10, 0, -20)
const POND_POS := Vector3(-11, 0, -16)
const BIRD_TREE_POS := Vector3(20, 0, -4)
const DUMBLECLAW_POS := Vector3(4, 0, -14)
const MOUSE_POS := Vector3(2, 0, 6.5)

var rng := RandomNumberGenerator.new()
var trees: Array[Node3D] = []
var _shed_portal: Area3D
var _enter_shed_delay := -1.0


func _ready() -> void:
	rng.randomize()
	_build_ground()
	_build_farmhouse(FARMHOUSE_POS)
	_build_shed(SHED_POS)
	_build_tractor()
	_build_pond()
	_build_bird_tree()
	_build_fence_perimeter()
	_build_trees()
	_build_rocks()
	_build_crops()
	_build_logs()
	_build_grass()
	_spawn_pickups()
	_spawn_dumbleclaw()
	_spawn_mouse()
	_spawn_bird()
	_spawn_fish()
	_spawn_player()
	_maybe_screenshot()


func _spawn_player() -> void:
	var pl := get_tree().get_first_node_in_group("player")
	if pl == null:
		return
	if GameState.spawn_near_shed:
		pl.global_position = Vector3(16, 0, -7.2)
		GameState.spawn_near_shed = false


func _maybe_screenshot() -> void:
	var args := OS.get_cmdline_user_args()
	if "--smoketest" in args:
		_run_smoke()
		return
	if not "--screenshot" in args:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var player = get_tree().get_first_node_in_group("player")
	if "--catclose" in args and player != null:
		player.camera_frozen = true
		var head: Vector3 = player.global_position + Vector3(0, 0.42, 0)
		player.camera.look_at_from_position(head + Vector3(0.9, 0.3, 1.1), head, Vector3.UP)
		for i in range(5):
			await get_tree().process_frame
	elif "--flyover" in args and player != null:
		player.camera_frozen = true
		player.camera_holder.position = Vector3(0, 16, 0)
		player.camera.position = Vector3(0, 0, 0)
		player.camera.look_at(Vector3(4, 0, -10), Vector3.UP)
		for i in range(10):
			await get_tree().process_frame
	else:
		for i in range(30):
			await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://screenshot.png")
	print("SCREENSHOT SAVED")
	get_tree().quit()


func _build_ground() -> void:
	var visual := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(WORLD_SIZE, WORLD_SIZE)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.62, 0.3)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	plane.material = mat
	visual.mesh = plane
	add_child(visual)

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var boundary := WorldBoundaryShape3D.new()
	boundary.plane = Plane(0, 1, 0, 0)
	col.shape = boundary
	body.add_child(col)
	add_child(body)


func _build_farmhouse(home: Vector3) -> void:
	var house := Node3D.new()
	house.position = home
	house.name = "Farmhouse"
	add_child(house)

	# walls
	_add_mesh(house, "box", Vector3(9.0, 4.5, 6.5), Vector3(0, 2.25, 0), Color(0.93, 0.88, 0.74))
	# gable roof
	_add_mesh(house, "box", Vector3(10.4, 0.3, 3.9), Vector3(0, 5.125, 1.85), Color(0.62, 0.28, 0.2), Vector3(-0.326, 0, 0))
	_add_mesh(house, "box", Vector3(10.4, 0.3, 3.9), Vector3(0, 5.125, -1.85), Color(0.62, 0.28, 0.2), Vector3(0.326, 0, 0))
	_add_mesh(house, "box", Vector3(10.4, 0.4, 0.9), Vector3(0, 5.9, 0), Color(0.55, 0.24, 0.16))
	# gable ends
	_add_mesh(house, "box", Vector3(0.25, 1.25, 6.5), Vector3(-4.55, 5.125, 0), Color(0.85, 0.78, 0.6))
	_add_mesh(house, "box", Vector3(0.25, 1.25, 6.5), Vector3(4.55, 5.125, 0), Color(0.85, 0.78, 0.6))
	# porch slab + posts (front, +Z)
	_add_mesh(house, "box", Vector3(4.2, 0.2, 1.6), Vector3(0, 1.15, 3.45), Color(0.55, 0.4, 0.28))
	_add_mesh(house, "box", Vector3(0.22, 2.1, 0.22), Vector3(-1.6, 2.25, 3.6), Color(0.75, 0.68, 0.55))
	_add_mesh(house, "box", Vector3(0.22, 2.1, 0.22), Vector3(1.6, 2.25, 3.6), Color(0.75, 0.68, 0.55))
	# door + frame (named so door.gd can find it)
	var door_mesh := _mesh("box", Vector3(1.5, 2.3, 0.15), Color(0.5, 0.33, 0.2))
	door_mesh.name = "Door"
	door_mesh.position = Vector3(0, 1.15, 3.28)
	house.add_child(door_mesh)
	_add_mesh(house, "box", Vector3(1.15, 2.0, 0.2), Vector3(0, 1.1, 3.2), Color(0.32, 0.2, 0.12))
	# windows (front + both sides)
	_add_mesh(house, "box", Vector3(0.95, 0.95, 0.2), Vector3(-2.3, 2.5, 3.28), Color(0.78, 0.85, 0.92))
	_add_mesh(house, "box", Vector3(0.95, 0.95, 0.2), Vector3(2.3, 2.5, 3.28), Color(0.78, 0.85, 0.92))
	_add_mesh(house, "box", Vector3(0.2, 0.95, 0.95), Vector3(-4.5, 2.5, -1.2), Color(0.78, 0.85, 0.92))
	_add_mesh(house, "box", Vector3(0.2, 0.95, 0.95), Vector3(-4.5, 2.5, 1.2), Color(0.78, 0.85, 0.92))
	_add_mesh(house, "box", Vector3(0.2, 0.95, 0.95), Vector3(4.5, 2.5, -1.2), Color(0.78, 0.85, 0.92))
	_add_mesh(house, "box", Vector3(0.2, 0.95, 0.95), Vector3(4.5, 2.5, 1.2), Color(0.78, 0.85, 0.92))
	# chimney
	_add_mesh(house, "box", Vector3(0.7, 1.6, 0.7), Vector3(2.8, 5.5, -1.0), Color(0.5, 0.44, 0.38))
	_add_mesh(house, "box", Vector3(0.85, 0.3, 0.85), Vector3(2.8, 6.3, -1.0), Color(0.4, 0.35, 0.3))
	# step
	_add_mesh(house, "box", Vector3(1.8, 0.25, 0.6), Vector3(0, 0.12, 3.7), Color(0.6, 0.5, 0.38))

	_add_collider(house, Vector3(9.0, 4.5, 6.5), Vector3(0, 2.25, 0))
	_add_collider(house, Vector3(1.3, 2.1, 0.2), Vector3(0, 1.05, 3.28))

	var door := _make_door("farmhouse")
	door.position = Vector3(0, 1.0, 3.28)
	house.add_child(door)


func _build_shed(shed_pos: Vector3) -> void:
	var shed := Node3D.new()
	shed.position = shed_pos
	shed.name = "Shed"
	add_child(shed)

	var wood := Color(0.45, 0.3, 0.18)
	var wood_dark := Color(0.36, 0.24, 0.14)
	var roof_col := Color(0.3, 0.2, 0.12)
	var half_w := 2.3
	var half_d := 1.7
	var wall_h := 3.0

	# Solid exterior box (the interior now lives in its own scene: scenes/shed.tscn)
	_add_mesh(shed, "box", Vector3(half_w * 2.0, wall_h, half_d * 2.0), Vector3(0, wall_h / 2.0, 0), wood)
	_add_collider(shed, Vector3(half_w * 2.0, wall_h, half_d * 2.0), Vector3(0, wall_h / 2.0, 0))
	# Roof (overhang) + ridge cap
	_add_mesh(shed, "box", Vector3(half_w * 2.0 + 0.5, 0.5, half_d * 2.0 + 0.5), Vector3(0, wall_h + 0.25, 0), roof_col)
	_add_mesh(shed, "box", Vector3(half_w * 2.0 + 0.5, 0.3, 0.7), Vector3(0, wall_h + 0.65, 0), roof_col)
	# Door frame + dark door (door mesh swings open on unlock)
	_add_mesh(shed, "box", Vector3(1.9, 2.2, 0.15), Vector3(0, 1.1, half_d - 0.05), wood_dark)
	var door_mesh := _mesh("box", Vector3(1.7, 2.0, 0.1), Color(0.1, 0.08, 0.06))
	door_mesh.name = "Door"
	door_mesh.position = Vector3(0, 1.1, half_d - 0.02)
	shed.add_child(door_mesh)

	var door := _make_door("shed")
	door.position = Vector3(0, 1.0, half_d - 0.02)
	shed.add_child(door)

	_build_shed_portal(shed)


func _build_shed_portal(shed: Node3D) -> void:
	var portal := Area3D.new()
	portal.name = "ShedPortal"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.7, 2.2, 0.7)
	col.shape = box
	portal.add_child(col)
	portal.position = Vector3(0, 1.0, 2.0)
	_shed_portal = portal
	shed.add_child(portal)


func _physics_process(delta: float) -> void:
	if _enter_shed_delay > 0.0:
		_enter_shed_delay -= delta
		if _enter_shed_delay <= 0.0:
			get_tree().change_scene_to_file("res://scenes/shed.tscn")
		return
	if not GameState.shed_unlocked or _shed_portal == null:
		return
	# Poll overlaps every frame (self-healing - no body_entered can be missed).
	for body in _shed_portal.get_overlapping_bodies():
		if body.is_in_group("player"):
			# Small beat so the padlock CLICK + door swing register before the cut.
			_enter_shed_delay = 0.7
			return


func _make_door(kind: String) -> Node3D:
	var door: Node3D = preload("res://scripts/door.gd").new()
	door.door_kind = kind
	door.name = "Door_%s" % kind
	return door


func _run_smoke() -> void:
	for i in range(30):
		await get_tree().process_frame
	print("SMOKE start: is_day=%s combo=%03d hunger=%.2f energy=%.2f" % [GameState.is_day, GameState.combo, GameState.hunger, GameState.tiredness])

	var dc := get_node("Dumbleclaw")
	dc.interact()
	Hud.close_dialogue()
	print("SMOKE quest_after_meet=%s" % GameState.quest)

	GameState.add_string(1)
	GameState.add_sticks(2)
	var shed_door := get_node("Shed/Door_shed")
	shed_door._on_combo(GameState.combo)
	print("SMOKE shed_unlocked=%s has_keys=%s string=%d" % [GameState.shed_unlocked, GameState.has_keys, GameState.string_count])

	var mouse := get_node("Mouse")
	mouse._on_choice(1)
	var caught := false
	for i in range(300):
		await get_tree().process_frame
		if GameState.mouse_caught:
			caught = true
			break
	print("SMOKE mouse_caught=%s (caught=%s) food=%d trap_placed=%s" % [GameState.mouse_caught, caught, GameState.food_count, GameState.trap_placed])

	GameState.add_string(1)
	GameState.add_sticks(2)
	var fish := get_node("Fish")
	fish._on_choice(1)
	print("SMOKE fish_caught=%s food=%d rod_placed=%s" % [GameState.fish_caught, GameState.food_count, GameState.rod_placed])

	GameState.add_string(1)
	GameState.add_sticks(2)
	var bird := get_node("Bird")
	bird._on_choice(1)
	print("SMOKE bird_caught=%s food=%d ladder_placed=%s" % [GameState.bird_caught, GameState.food_count, GameState.ladder_placed])

	var tractor := get_node("Tractor")
	tractor._on_choice(0)
	Hud.close_dialogue()
	tractor._on_choice(1)

	var dc2 := get_node("Dumbleclaw")
	dc2._on_choice(1)
	print("SMOKE after_trade food=%d gold=%d" % [GameState.food_count, GameState.gold])

	var farmhouse_door := get_node("Farmhouse/Door_farmhouse")
	farmhouse_door.interact()
	Hud.close_dialogue()
	GameState.day_time = 0.75 * GameState.DAY_SECONDS
	for i in range(3):
		await get_tree().process_frame
	farmhouse_door.interact()
	Hud.close_dialogue()
	print("SMOKE is_day=%s catfood_used=%s food=%d" % [GameState.is_day, GameState.catfood_used, GameState.food_count])
	print("SMOKE DONE")
	get_tree().quit()


func _build_tractor() -> void:
	var tractor: Node3D = preload("res://scripts/tractor.gd").new()
	tractor.name = "Tractor"
	tractor.position = TRACTOR_POS
	tractor.rotation = Vector3(0, 0.7, 0)
	add_child(tractor)


func _build_pond() -> void:
	var fish: Node3D = preload("res://scripts/fish.gd").new()
	fish.name = "Fish"
	fish.position = POND_POS
	add_child(fish)


func _build_bird_tree() -> void:
	var scene: PackedScene = preload("res://assets/tree_detailed.glb")
	var tree: Node3D = scene.instantiate()
	tree.position = BIRD_TREE_POS
	tree.scale = Vector3.ONE * 4.0
	add_child(tree)
	tree.add_to_group("trees")
	trees.append(tree)
	_add_collider(tree, Vector3(0.9, 2.4, 0.9), Vector3(0, 1.2, 0))


func _build_fence_perimeter() -> void:
	var dist := HALF - 2.0
	for edge in range(4):
		var along := (dist * 2.0) / 2.6
		for i in range(int(along)):
			var fence: Node3D
			if i == 0 or i == int(along) - 1:
				fence = FENCE_SCENES[0].instantiate()
			else:
				fence = FENCE_SCENES[rng.randi_range(0, FENCE_SCENES.size() - 1)].instantiate()
			var pos := Vector3.ZERO
			var rot := 0.0
			match edge:
				0:
					pos = Vector3(-dist + i * 2.6, 0, -dist)
					rot = 0.0
				1:
					pos = Vector3(dist, 0, -dist + i * 2.6)
					rot = PI / 2.0
				2:
					pos = Vector3(dist - i * 2.6, 0, dist)
					rot = PI
				3:
					pos = Vector3(-dist, 0, dist - i * 2.6)
					rot = -PI / 2.0
			fence.position = pos
			fence.rotation = Vector3(0, rot, 0)
			add_child(fence)


func _build_trees() -> void:
	for i in range(20):
		var scene: PackedScene = TREE_SCENES[rng.randi_range(0, TREE_SCENES.size() - 1)]
		var tree: Node3D = scene.instantiate()
		var pos := _random_pos(3.0)
		if _too_close_to_landmarks(pos):
			continue
		tree.position = pos
		tree.rotation = Vector3(0, rng.randf_range(0, TAU), 0)
		var scale := rng.randf_range(2.6, 4.4)
		tree.scale = Vector3(scale, scale, scale)
		add_child(tree)
		tree.add_to_group("trees")
		trees.append(tree)
		_add_collider(tree, Vector3(0.6, 2.0, 0.6), Vector3(0, 1.0, 0))


func _build_rocks() -> void:
	for i in range(12):
		var scene: PackedScene = ROCK_SCENES[rng.randi_range(0, ROCK_SCENES.size() - 1)]
		var rock: Node3D = scene.instantiate()
		var pos := _random_pos(2.0)
		if _too_close_to_landmarks(pos):
			continue
		rock.position = pos
		var scale := rng.randf_range(0.7, 1.8)
		rock.scale = Vector3(scale, scale, scale)
		add_child(rock)


func _build_crops() -> void:
	var row := Node3D.new()
	row.position = Vector3(14.5, 0, -6)
	add_child(row)
	for i in range(6):
		var scene: PackedScene = CROP_SCENES[rng.randi_range(0, CROP_SCENES.size() - 1)]
		var crop: Node3D = scene.instantiate()
		crop.position = Vector3(i * 1.6 - 4.0, 0, 0)
		var scale := rng.randf_range(0.8, 1.3)
		crop.scale = Vector3(scale, scale, scale)
		row.add_child(crop)


func _build_logs() -> void:
	for i in range(5):
		var scene: PackedScene = LOG_SCENES[rng.randi_range(0, LOG_SCENES.size() - 1)]
		var log: Node3D = scene.instantiate()
		var pos := _random_pos(2.0)
		if _too_close_to_landmarks(pos):
			continue
		log.position = pos
		log.rotation = Vector3(0, rng.randf_range(0, TAU), 0)
		add_child(log)


func _build_grass() -> void:
	for i in range(35):
		var scene: PackedScene = GRASS_SCENES[rng.randi_range(0, GRASS_SCENES.size() - 1)]
		var tuft: Node3D = scene.instantiate()
		var pos := _random_pos(1.0)
		if _too_close_to_landmarks(pos):
			continue
		tuft.position = pos
		var scale := rng.randf_range(0.6, 1.5)
		tuft.scale = Vector3(scale, scale, scale)
		add_child(tuft)


func _spawn_pickups() -> void:
	var stick_positions := [
		Vector3(1.5, 0.25, 8.0),
		Vector3(2.6, 0.25, 5.2),
		Vector3(-2.2, 0.25, 9.6),
		Vector3(4.2, 0.25, 10.8),
		Vector3(-3.4, 0.25, 6.0),
		Vector3(6.0, 0.25, -3.0),
		Vector3(0.5, 0.25, -1.0),
	]
	for p in stick_positions:
		var st := preload("res://scripts/pickup.gd").new()
		st.kind = "stick"
		st.position = p
		add_child(st)


func _spawn_dumbleclaw() -> void:
	var dc := preload("res://scripts/dumbleclaw.gd").new()
	dc.name = "Dumbleclaw"
	dc.position = DUMBLECLAW_POS
	add_child(dc)


func _spawn_mouse() -> void:
	var m := preload("res://scripts/mouse.gd").new()
	m.name = "Mouse"
	m.position = MOUSE_POS
	add_child(m)


func _spawn_bird() -> void:
	var b := preload("res://scripts/bird.gd").new()
	b.name = "Bird"
	var anchor := BIRD_TREE_POS + Vector3(0, 4.0 * 1.4 + 0.4, 0)
	b.anchor = anchor
	b.position = anchor
	add_child(b)


func _spawn_fish() -> void:
	# fish is built inside fish.gd (pond + fish together)
	pass


func _add_mesh(parent: Node3D, kind: String, size: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := _mesh(kind, size, color)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _mesh(kind: String, size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh: Mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	match kind:
		"box":
			var bm := BoxMesh.new()
			bm.size = size
			mesh = bm
		"cylinder":
			var cm := CylinderMesh.new()
			cm.top_radius = size.x
			cm.bottom_radius = size.x
			cm.height = size.y
			mesh = cm
		"sphere":
			var sm := SphereMesh.new()
			sm.radius = size.x * 0.5
			sm.height = size.y
			mesh = sm
	mesh.material = mat
	mi.mesh = mesh
	return mi


func _add_collider(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	body.add_child(col)
	parent.add_child(body)


func _random_pos(margin: float) -> Vector3:
	var x := rng.randf_range(-HALF + margin + 2.0, HALF - margin - 2.0)
	var z := rng.randf_range(-HALF + margin + 2.0, HALF - margin - 2.0)
	return Vector3(x, 0, z)


func _too_close_to_landmarks(pos: Vector3) -> bool:
	for lm in [FARMHOUSE_POS, SHED_POS, TRACTOR_POS, POND_POS, BIRD_TREE_POS]:
		if pos.distance_to(lm) < 6.0:
			return true
	return pos.distance_to(Vector3(0, 0, 12)) < 3.0
