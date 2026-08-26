extends Node3D

const SHED_SPAWN := Vector3(0, 0, 0.2)


func _ready() -> void:
	_build_floor()
	_build_walls()
	_build_roof()
	_build_light()
	_build_props()
	_spawn_loot()
	_build_exit_portal()
	_run_smoke_check()


func _build_floor() -> void:
	# Flush wooden planks with procedural wood grain + dark seam lines
	var plank_w := 0.25
	var plank_d := 2.4
	var plank_h := 0.04
	var plank_count := 12
	var floor_y := 0.05
	var start_x := -(plank_count * plank_w) / 2.0 + plank_w / 2.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# Base slab underneath (no gaps for grass to show through)
	_add_mesh("box", Vector3(3.0, 0.05, plank_d), Vector3(0, floor_y - 0.06, 0), Color(0.2, 0.14, 0.08))
	_add_collider(Vector3(3.0, 0.25, plank_d), Vector3(0, floor_y - 0.08, 0))
	for i in range(plank_count):
		var t := rng.randf()
		# 8 distinct wood colours, randomly assigned
		var palette := [
			Color(0.75, 0.58, 0.35),  # pale pine
			Color(0.65, 0.48, 0.28),  # light oak
			Color(0.55, 0.38, 0.20),  # warm oak
			Color(0.48, 0.30, 0.15),  # mid brown
			Color(0.40, 0.25, 0.12),  # dark walnut
			Color(0.35, 0.22, 0.10),  # aged teak
			Color(0.60, 0.42, 0.22),  # honey
			Color(0.30, 0.18, 0.08),  # very dark
		]
		var c: Color = palette[int(t * palette.size()) % palette.size()]
		var x := start_x + i * plank_w
		var mi := _add_mesh("box", Vector3(plank_w, plank_h, plank_d), Vector3(x, floor_y, 0), c)
		# Material with wood grain
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		mat.roughness = 0.75 + t * 0.15
		mi.set_surface_override_material(0, mat)
		# Dark seam strip on each side of plank (visual gap without actual gap)
		var seam := Color(0.15, 0.10, 0.05)
		var seam_w := 0.008
		if i > 0:
			_add_mesh("box", Vector3(seam_w, plank_h + 0.001, plank_d), Vector3(x - plank_w / 2.0, floor_y + 0.001, 0), seam)
		if i == plank_count - 1:
			_add_mesh("box", Vector3(seam_w, plank_h + 0.001, plank_d), Vector3(x + plank_w / 2.0, floor_y + 0.001, 0), seam)


func _build_walls() -> void:
	var wood := Color(0.45, 0.3, 0.18)
	var wood_dark := Color(0.36, 0.24, 0.14)
	var half_w := 1.5
	var half_d := 1.2
	var wall_h := 2.5
	var wall_t := 0.2
	var gap := 0.5

	# Back, left, right
	_add_mesh("box", Vector3(half_w * 2.0, wall_h, wall_t), Vector3(0, wall_h / 2.0, -half_d + wall_t / 2.0), wood)
	_add_collider(Vector3(half_w * 2.0, wall_h, wall_t), Vector3(0, wall_h / 2.0, -half_d + wall_t / 2.0))
	_add_mesh("box", Vector3(wall_t, wall_h, half_d * 2.0), Vector3(-half_w + wall_t / 2.0, wall_h / 2.0, 0), wood)
	_add_collider(Vector3(wall_t, wall_h, half_d * 2.0), Vector3(-half_w + wall_t / 2.0, wall_h / 2.0, 0))
	_add_mesh("box", Vector3(wall_t, wall_h, half_d * 2.0), Vector3(half_w - wall_t / 2.0, wall_h / 2.0, 0), wood)
	_add_collider(Vector3(wall_t, wall_h, half_d * 2.0), Vector3(half_w - wall_t / 2.0, wall_h / 2.0, 0))

	# Front wall with a doorway gap (x in [-gap, gap], up to y=2.0) — the way out
	var front_z := half_d - wall_t / 2.0
	var seg_w := half_w - wall_t / 2.0 - gap
	var seg_cx := gap + seg_w / 2.0
	_add_mesh("box", Vector3(seg_w, wall_h, wall_t), Vector3(-seg_cx, wall_h / 2.0, front_z), wood)
	_add_collider(Vector3(seg_w, wall_h, wall_t), Vector3(-seg_cx, wall_h / 2.0, front_z))
	_add_mesh("box", Vector3(seg_w, wall_h, wall_t), Vector3(seg_cx, wall_h / 2.0, front_z), wood)
	_add_collider(Vector3(seg_w, wall_h, wall_t), Vector3(seg_cx, wall_h / 2.0, front_z))
	var lint_h := wall_h - 2.0
	_add_mesh("box", Vector3(gap * 2.0 + wall_t, lint_h, wall_t), Vector3(0, 2.0 + lint_h / 2.0, front_z), wood_dark)
	_add_collider(Vector3(gap * 2.0 + wall_t, lint_h, wall_t), Vector3(0, 2.0 + lint_h / 2.0, front_z))
	_add_mesh("box", Vector3(wall_t * 0.8, 2.0, wall_t * 0.8), Vector3(-gap - 0.12, 1.0, half_d - 0.04), wood_dark)
	_add_mesh("box", Vector3(wall_t * 0.8, 2.0, wall_t * 0.8), Vector3(gap + 0.12, 1.0, half_d - 0.04), wood_dark)


func _build_roof() -> void:
	var roof_col := Color(0.3, 0.2, 0.12)
	var half_w := 1.5
	var rise := 0.4
	var roof_d := 2.6
	var slab_len := sqrt(half_w * half_w + rise * rise)
	var slope_ang := atan(rise / half_w)
	var slab_cx := half_w / 2.0
	_add_mesh("box", Vector3(slab_len, 0.15, roof_d), Vector3(slab_cx, 2.5 + rise / 2.0, 0), roof_col)
	get_child(-1).rotation.z = -slope_ang
	_add_mesh("box", Vector3(slab_len, 0.15, roof_d), Vector3(-slab_cx, 2.5 + rise / 2.0, 0), roof_col)
	get_child(-1).rotation.z = slope_ang
	_add_mesh("box", Vector3(0.3, 0.3, roof_d), Vector3(0, 2.5 + rise - 0.02, 0), roof_col)


func _build_light() -> void:
	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.8, 0)
	light.light_color = Color(1.0, 0.9, 0.65)
	light.light_energy = 1.6
	light.omni_range = 5.5
	add_child(light)


func _build_props() -> void:
	var wood := Color(0.62, 0.48, 0.3)
	var wood_dark := Color(0.45, 0.33, 0.2)
	var hay := Color(0.85, 0.75, 0.4)
	var brown := Color(0.42, 0.28, 0.17)
	var green := Color(0.3, 0.55, 0.25)
	var straw := Color(0.75, 0.65, 0.45)
	var metal := Color(0.48, 0.48, 0.51)
	var terracotta := Color(0.71, 0.40, 0.11)
	var cream := Color(0.92, 0.89, 0.80)
	var red_stripe := Color(0.65, 0.025, 0.012)

	# Loot crates (string + keys spawn on top of these once the shed is unlocked)
	_add_mesh("box", Vector3(0.6, 0.6, 0.6), Vector3(-1.05, 0.3, -0.9), wood)
	_add_collider(Vector3(0.6, 0.6, 0.6), Vector3(-1.05, 0.3, -0.9))
	_add_mesh("box", Vector3(0.4, 0.4, 0.4), Vector3(-1.05, 0.85, -0.9), wood_dark)
	_add_mesh("box", Vector3(0.6, 0.6, 0.6), Vector3(1.05, 0.3, -0.9), wood)
	_add_collider(Vector3(0.6, 0.6, 0.6), Vector3(1.05, 0.3, -0.9))

	# Workbench against back wall (-Z side)
	var bench_w := 1.2
	var bench_d := 0.5
	var bench_h := 0.85
	var bench_z := -0.95
	_add_mesh("box", Vector3(bench_w, 0.06, bench_d), Vector3(0, bench_h, bench_z), wood)
	# Legs
	for lx in [-0.5, 0.5]:
		_add_mesh("box", Vector3(0.06, bench_h, 0.06), Vector3(lx, bench_h / 2.0, bench_z - 0.18), wood_dark)
		_add_mesh("box", Vector3(0.06, bench_h, 0.06), Vector3(lx, bench_h / 2.0, bench_z + 0.18), wood_dark)
	# Cross-stretcher
	_add_mesh("box", Vector3(1.0, 0.04, 0.04), Vector3(0, 0.25, bench_z), wood_dark)
	# Items on bench: wooden mallet
	_add_mesh("box", Vector3(0.08, 0.06, 0.12), Vector3(-0.35, bench_h + 0.08, bench_z + 0.1), wood)
	_add_mesh("cylinder", Vector3(0.018, 0.22, 0.018), Vector3(-0.35, bench_h + 0.1, bench_z - 0.05), wood_dark)
	# Coil of wire on bench
	_add_mesh("cylinder", Vector3(0.06, 0.03, 0.06), Vector3(0.15, bench_h + 0.05, bench_z), metal)
	# Small hammer on bench
	_add_mesh("box", Vector3(0.1, 0.05, 0.06), Vector3(0.4, bench_h + 0.07, bench_z + 0.05), metal)
	_add_mesh("cylinder", Vector3(0.012, 0.18, 0.012), Vector3(0.4, bench_h + 0.09, bench_z - 0.04), wood_dark)

	# Left wall shelf unit (-X side)
	var shelf_y := 1.2
	_add_mesh("box", Vector3(0.35, 0.04, 0.6), Vector3(-1.3, shelf_y, 0), wood)
	_add_mesh("box", Vector3(0.35, 0.04, 0.6), Vector3(-1.3, shelf_y + 0.45, 0), wood)
	# Brackets
	for bz in [-0.22, 0.0, 0.22]:
		_add_mesh("box", Vector3(0.04, 0.12, 0.04), Vector3(-1.3, shelf_y - 0.06, bz), wood_dark)
		_add_mesh("box", Vector3(0.04, 0.12, 0.04), Vector3(-1.3, shelf_y + 0.45 - 0.06, bz), wood_dark)
	# Seed packets on lower shelf
	for i in range(3):
		_add_mesh("box", Vector3(0.008, 0.1, 0.07), Vector3(-1.22, shelf_y + 0.09, -0.15 + i * 0.15), cream)
		_add_mesh("box", Vector3(0.01, 0.03, 0.07), Vector3(-1.21, shelf_y + 0.09, -0.15 + i * 0.15), red_stripe)
	# Flower pot on upper shelf
	_add_mesh("cylinder", Vector3(0.06, 0.1, 0.07), Vector3(-1.2, shelf_y + 0.45 + 0.07, 0.15), terracotta)
	# Rolled sack on upper shelf
	_add_mesh("cylinder", Vector3(0.04, 0.2, 0.04), Vector3(-1.2, shelf_y + 0.45 + 0.05, -0.15), straw)

	# Right wall tool rack (+X side)
	_add_mesh("box", Vector3(0.04, 1.2, 0.04), Vector3(1.3, 1.6, 0), wood_dark)
	_add_mesh("box", Vector3(0.04, 0.04, 0.8), Vector3(1.3, 2.0, 0), wood_dark)
	# Spade hanging on rack
	_add_mesh("cylinder", Vector3(0.018, 0.7, 0.018), Vector3(1.28, 1.6, -0.15), wood, Vector3(0.1, 0, 0))
	_add_mesh("box", Vector3(0.15, 0.12, 0.02), Vector3(1.26, 1.2, -0.15), metal)
	_add_mesh("box", Vector3(0.18, 0.04, 0.04), Vector3(1.28, 2.05, -0.15), wood)
	# Rake hanging on rack
	_add_mesh("cylinder", Vector3(0.018, 0.8, 0.018), Vector3(1.28, 1.6, 0.2), wood, Vector3(0.1, 0, 0))
	_add_mesh("box", Vector3(0.25, 0.04, 0.08), Vector3(1.26, 1.15, 0.2), wood_dark)
	for t in range(4):
		_add_mesh("box", Vector3(0.015, 0.1, 0.015), Vector3(1.22, 1.1, 0.12 + t * 0.04), metal)

	# An old boot with a sprout growing out of it
	_add_mesh("box", Vector3(0.3, 0.34, 0.58), Vector3(-1.2, 0.17, 0.9), brown, Vector3(0.15, 0, 0.3))
	_add_mesh("cylinder", Vector3(0.16, 0.24, 0.16), Vector3(-1.16, 0.4, 0.94), brown)
	_add_mesh("cylinder", Vector3(0.03, 0.3, 0.03), Vector3(-1.12, 0.62, 1.0), green)
	_add_mesh("sphere", Vector3(0.1, 0.14, 0.1), Vector3(-1.12, 0.78, 1.0), green)

	# Hay pile in the front-right corner
	_add_mesh("box", Vector3(0.6, 0.3, 0.6), Vector3(1.15, 0.15, 1.05), hay, Vector3(0, 0.25, 0))
	_add_mesh("box", Vector3(0.5, 0.3, 0.5), Vector3(0.95, 0.42, 0.9), hay, Vector3(0, -0.2, 0))
	_add_mesh("box", Vector3(0.45, 0.28, 0.45), Vector3(1.1, 0.72, 0.95), hay, Vector3(0, 0.35, 0))

	# Metal bucket on the floor
	_add_mesh("cylinder", Vector3(0.1, 0.2, 0.11), Vector3(0.5, 0.1, 0.8), metal)
	_add_mesh("cylinder", Vector3(0.008, 0.2, 0.008), Vector3(0.5, 0.25, 0.8), metal, Vector3(0, 0, 0.5))

	# Sprung mousetrap on the floor
	_add_mesh("box", Vector3(0.26, 0.03, 0.12), Vector3(0.3, 0.015, 0.5), wood)
	_add_mesh("cylinder", Vector3(0.012, 0.14, 0.012), Vector3(0.37, 0.1, 0.5), Color(0.7, 0.7, 0.72))
	_add_mesh("box", Vector3(0.09, 0.025, 0.09), Vector3(0.21, 0.03, 0.5), Color(0.95, 0.8, 0.3))

	# Folded tarpaulin on the floor
	_add_mesh("box", Vector3(0.5, 0.06, 0.4), Vector3(-0.5, 0.03, 0.6), green, Vector3(0, 0.15, 0))

	# Lantern hanging on the back wall (glows)
	var lantern := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 0.13
	lm.bottom_radius = 0.13
	lm.height = 0.26
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color(1.0, 0.85, 0.55)
	lmat.emission_enabled = true
	lmat.emission = Color(1.0, 0.75, 0.4)
	lmat.emission_energy_multiplier = 2.0
	lm.material = lmat
	lantern.mesh = lm
	lantern.position = Vector3(0.5, 1.6, -1.05)
	add_child(lantern)
	_add_mesh("box", Vector3(0.3, 0.05, 0.05), Vector3(0.5, 1.75, -1.05), wood_dark)
	_add_mesh("box", Vector3(0.06, 0.3, 0.06), Vector3(0.5, 0.95, -1.05), wood_dark)

	# Coil of rope on a peg
	_add_mesh("cylinder", Vector3(0.2, 0.07, 0.2), Vector3(1.25, 1.15, -1.05), straw)
	_add_mesh("cylinder", Vector3(0.05, 0.12, 0.05), Vector3(1.25, 0.95, -1.05), wood_dark)


func _spawn_loot() -> void:
	if not GameState.shed_unlocked:
		return
	if not GameState.shed_string_taken:
		_spawn_pickup("string", "shed_string", Vector3(-1.05, 1.1, -0.9))
	if not GameState.shed_key_taken:
		_spawn_pickup("key", "shed_key", Vector3(1.05, 0.68, -0.9))


func _spawn_pickup(kind: String, loot_id: String, pos: Vector3) -> void:
	var p := preload("res://scripts/pickup.gd").new()
	p.kind = kind
	p.loot_id = loot_id
	p.position = pos
	add_child(p)


func _build_exit_portal() -> void:
	var portal := Area3D.new()
	portal.name = "ShedExitPortal"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.1, 2.0, 0.4)
	col.shape = box
	portal.add_child(col)
	portal.position = Vector3(0, 1.0, 1.1)
	portal.body_entered.connect(_on_exit)
	add_child(portal)


var _leaving := false


func _on_exit(body: Node3D) -> void:
	if not body.is_in_group("player") or _leaving:
		return
	_leaving = true
	GameState.spawn_near_shed = true
	get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")


func _run_smoke_check() -> void:
	if not "--smoketest" in OS.get_cmdline_user_args():
		return
	GameState.shed_unlocked = true
	_spawn_loot()
	for i in range(5):
		await get_tree().process_frame
	var strings := 0
	var keys := 0
	for c in get_children():
		if c.has_method("_collect"):
			if c.get("kind") == "string":
				strings += 1
			elif c.get("kind") == "key":
				keys += 1
	print("SHED SMOKE unlocked=1 string_pickups=%d key_pickups=%d exit_portal=%s spawn=%s" % [
		strings, keys, has_node("ShedExitPortal"), str(SHED_SPAWN)])
	get_tree().quit()


func _add_mesh(kind: String, size: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := _mesh(kind, size, color)
	mi.position = pos
	mi.rotation = rot
	add_child(mi)
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


func _add_collider(size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	body.add_child(col)
	add_child(body)
