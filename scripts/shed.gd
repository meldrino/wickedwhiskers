extends Node3D

const SHED_SPAWN := Vector3(0, 0, 0.6)


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
	var wood := Color(0.45, 0.3, 0.18)
	_add_mesh("box", Vector3(4.6, 0.2, 3.4), Vector3(0, -0.1, 0), wood)
	_add_collider(Vector3(4.6, 0.2, 3.4), Vector3(0, -0.1, 0))


func _build_walls() -> void:
	var wood := Color(0.45, 0.3, 0.18)
	var wood_dark := Color(0.36, 0.24, 0.14)
	var half_w := 2.3
	var half_d := 1.7
	var wall_h := 3.0
	var wall_t := 0.2
	var gap := 0.8

	# Back, left, right
	_add_mesh("box", Vector3(half_w * 2.0, wall_h, wall_t), Vector3(0, wall_h / 2.0, -half_d + wall_t / 2.0), wood)
	_add_collider(Vector3(half_w * 2.0, wall_h, wall_t), Vector3(0, wall_h / 2.0, -half_d + wall_t / 2.0))
	_add_mesh("box", Vector3(wall_t, wall_h, half_d * 2.0), Vector3(-half_w + wall_t / 2.0, wall_h / 2.0, 0), wood)
	_add_collider(Vector3(wall_t, wall_h, half_d * 2.0), Vector3(-half_w + wall_t / 2.0, wall_h / 2.0, 0))
	_add_mesh("box", Vector3(wall_t, wall_h, half_d * 2.0), Vector3(half_w - wall_t / 2.0, wall_h / 2.0, 0), wood)
	_add_collider(Vector3(wall_t, wall_h, half_d * 2.0), Vector3(half_w - wall_t / 2.0, wall_h / 2.0, 0))

	# Front wall with a doorway gap (x in [-gap, gap], up to y=2.2) — the way out
	var front_z := half_d - wall_t / 2.0
	var seg_w := half_w - wall_t / 2.0 - gap
	var seg_cx := gap + seg_w / 2.0
	_add_mesh("box", Vector3(seg_w, wall_h, wall_t), Vector3(-seg_cx, wall_h / 2.0, front_z), wood)
	_add_collider(Vector3(seg_w, wall_h, wall_t), Vector3(-seg_cx, wall_h / 2.0, front_z))
	_add_mesh("box", Vector3(seg_w, wall_h, wall_t), Vector3(seg_cx, wall_h / 2.0, front_z), wood)
	_add_collider(Vector3(seg_w, wall_h, wall_t), Vector3(seg_cx, wall_h / 2.0, front_z))
	var lint_h := wall_h - 2.2
	_add_mesh("box", Vector3(gap * 2.0 + wall_t, lint_h, wall_t), Vector3(0, 2.2 + lint_h / 2.0, front_z), wood_dark)
	_add_collider(Vector3(gap * 2.0 + wall_t, lint_h, wall_t), Vector3(0, 2.2 + lint_h / 2.0, front_z))
	_add_mesh("box", Vector3(wall_t * 0.8, 2.2, wall_t * 0.8), Vector3(-gap - 0.12, 1.1, half_d - 0.04), wood_dark)
	_add_mesh("box", Vector3(wall_t * 0.8, 2.2, wall_t * 0.8), Vector3(gap + 0.12, 1.1, half_d - 0.04), wood_dark)


func _build_roof() -> void:
	var roof_col := Color(0.3, 0.2, 0.12)
	_add_mesh("box", Vector3(5.1, 0.5, 3.9), Vector3(0, 3.25, 0), roof_col)
	_add_mesh("box", Vector3(5.1, 0.3, 0.7), Vector3(0, 3.65, 0), roof_col)


func _build_light() -> void:
	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.2, 0)
	light.light_color = Color(1.0, 0.9, 0.65)
	light.light_energy = 1.6
	light.omni_range = 7.0
	add_child(light)


func _build_props() -> void:
	var wood := Color(0.62, 0.48, 0.3)
	var wood_dark := Color(0.45, 0.33, 0.2)
	var hay := Color(0.85, 0.75, 0.4)
	var brown := Color(0.42, 0.28, 0.17)
	var green := Color(0.3, 0.55, 0.25)
	var straw := Color(0.75, 0.65, 0.45)

	# Loot crates (string + keys spawn on top of these once the shed is unlocked)
	_add_mesh("box", Vector3(0.6, 0.6, 0.6), Vector3(-1.1, 0.3, -1.1), wood)
	_add_collider(Vector3(0.6, 0.6, 0.6), Vector3(-1.1, 0.3, -1.1))
	_add_mesh("box", Vector3(0.4, 0.4, 0.4), Vector3(-1.1, 0.85, -1.1), wood_dark)
	_add_mesh("box", Vector3(0.6, 0.6, 0.6), Vector3(1.1, 0.3, -1.1), wood)
	_add_collider(Vector3(0.6, 0.6, 0.6), Vector3(1.1, 0.3, -1.1))

	# An old boot with a sprout growing out of it
	_add_mesh("box", Vector3(0.3, 0.34, 0.58), Vector3(-1.7, 0.17, 1.0), brown, Vector3(0.15, 0, 0.3))
	_add_mesh("cylinder", Vector3(0.16, 0.24, 0.16), Vector3(-1.66, 0.4, 1.04), brown)
	_add_mesh("cylinder", Vector3(0.03, 0.3, 0.03), Vector3(-1.62, 0.62, 1.1), green)
	_add_mesh("sphere", Vector3(0.1, 0.14, 0.1), Vector3(-1.62, 0.78, 1.1), green)

	# Hay pile in the front-right corner
	_add_mesh("box", Vector3(0.6, 0.3, 0.6), Vector3(1.55, 0.15, 1.25), hay, Vector3(0, 0.25, 0))
	_add_mesh("box", Vector3(0.5, 0.3, 0.5), Vector3(1.2, 0.42, 1.05), hay, Vector3(0, -0.2, 0))
	_add_mesh("box", Vector3(0.45, 0.28, 0.45), Vector3(1.5, 0.72, 1.15), hay, Vector3(0, 0.35, 0))

	# Sprung mousetrap on the floor — the last mouse won
	_add_mesh("box", Vector3(0.26, 0.03, 0.12), Vector3(0.35, 0.015, 0.8), wood)
	_add_mesh("cylinder", Vector3(0.012, 0.14, 0.012), Vector3(0.42, 0.1, 0.8), Color(0.7, 0.7, 0.72))
	_add_mesh("box", Vector3(0.09, 0.025, 0.09), Vector3(0.26, 0.03, 0.8), Color(0.95, 0.8, 0.3))

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
	lantern.position = Vector3(0.5, 1.8, -1.5)
	add_child(lantern)
	_add_mesh("box", Vector3(0.3, 0.05, 0.05), Vector3(0.5, 1.95, -1.5), wood_dark)
	_add_mesh("box", Vector3(0.06, 0.3, 0.06), Vector3(0.5, 1.05, -1.5), wood_dark)

	# Rake leaning against the wall
	_add_mesh("cylinder", Vector3(0.03, 1.4, 0.03), Vector3(-0.7, 0.7, -1.45), wood, Vector3(0.2, 0, 0.6))
	_add_mesh("box", Vector3(0.2, 0.05, 0.55), Vector3(-0.78, 0.2, -1.3), wood, Vector3(0, 0, 0.12))

	# Coil of rope on a peg
	_add_mesh("cylinder", Vector3(0.2, 0.07, 0.2), Vector3(1.7, 1.25, -1.5), straw)
	_add_mesh("cylinder", Vector3(0.05, 0.12, 0.05), Vector3(1.7, 1.05, -1.5), wood_dark)


func _spawn_loot() -> void:
	if not GameState.shed_unlocked:
		return
	if not GameState.shed_string_taken:
		_spawn_pickup("string", "shed_string", Vector3(-1.1, 1.1, -1.1))
	if not GameState.shed_key_taken:
		_spawn_pickup("key", "shed_key", Vector3(1.1, 0.68, -1.1))


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
	box.size = Vector3(1.6, 2.2, 0.5)
	col.shape = box
	portal.add_child(col)
	portal.position = Vector3(0, 1.1, 1.55)
	portal.body_entered.connect(_on_exit)
	add_child(portal)


var _leaving := false


func _on_exit(body: Node3D) -> void:
	if not body.is_in_group("player") or _leaving:
		return
	_leaving = true
	GameState.spawn_near_shed = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")


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
