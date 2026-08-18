extends Node3D

func _ready() -> void:
	global_position = Vector3(0.0, 300.0, 0.0)
	for n in get_tree().root.get_children():
		if n == self:
			continue
		if n is Node3D:
			(n as Node3D).visible = false
		elif n is CanvasLayer:
			(n as CanvasLayer).visible = false

	var padlock := _build_padlock()
	padlock.position = Vector3.ZERO
	add_child(padlock)

	var glb: PackedScene = load("res://assets/paw.glb")
	if glb == null:
		push_error("STUDIO failed to load paw.glb")
		get_tree().quit()
		return

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.6, 0.55)
	env.ambient_light_energy = 0.18
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var key := DirectionalLight3D.new()
	key.light_energy = 0.6
	key.shadow_enabled = false
	key.rotation_degrees = Vector3(-35.0, 20.0, 0.0)
	add_child(key)

	var rotations := [
		[0.0, 180.0, "rx0_ry180"],
		[-45.0, 180.0, "rx45n_ry180"],
		[-90.0, 180.0, "rx90n_ry180"],
		[-90.0, 0.0, "rx90n_ry0"],
	]

	for rot in rotations:
		var root := Node3D.new()
		root.position = Vector3(0.0, 300.0, 0.0)
		get_tree().root.add_child(root)

		var model: Node3D = glb.instantiate()
		model.scale = Vector3.ONE * 0.55
		model.rotation.x = deg_to_rad(rot[0])
		model.rotation.y = deg_to_rad(rot[1])
		root.add_child(model)

		for mi in model.find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				var mat: Material = mi.mesh.surface_get_material(s)
				if mat is StandardMaterial3D:
					var fd: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
					fd.albedo_color = Color(0.9777, 0.68, 0.3492)
					fd.roughness = 0.9
					fd.metallic = 0.0
					mi.set_surface_override_material(s, fd)

		await get_tree().process_frame
		await get_tree().process_frame

		var img := get_viewport().get_texture().get_image()
		img.save_png("res://screenshots/sheet_rot_%s.png" % rot[2])
		print("SHEET saved rot=%s" % rot[2])

		root.queue_free()
		await get_tree().process_frame

	print("ALL SHEETS DONE")
	get_tree().quit()

func _build_padlock() -> Node3D:
	var p := Node3D.new()
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.95, 0.75, 0.15)
	brass.metallic = 0.7
	brass.roughness = 0.28
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.24, 0.34, 0.12)
	bm.material = brass
	body.mesh = bm
	body.position = Vector3(0, -0.03, 0.10)
	p.add_child(body)
	return p
