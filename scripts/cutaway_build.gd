extends Node3D

func _ready() -> void:
	print("CUTAWAY BUILD start")
	global_position = Vector3(0.0, 300.0, 0.0)
	for n in get_tree().root.get_children():
		if n == self:
			continue
		if n is Node3D:
			(n as Node3D).visible = false
		elif n is CanvasLayer:
			(n as CanvasLayer).visible = false
	var pf := FileAccess.open("res://screenshots/pawtest_params.json", FileAccess.READ)
	if pf == null:
		push_error("CUTAWAY no pawtest_params.json")
		get_tree().quit()
		return
	var params: Dictionary = JSON.parse_string(pf.get_as_text())
	pf.close()

	var padlock := _build_padlock()
	padlock.position = Vector3.ZERO
	add_child(padlock)

	var glb: PackedScene = load(str(params["model_glb"]))
	if glb == null:
		push_error("CUTAWAY failed to load model")
		get_tree().quit()
		return
	var model: Node3D = glb.instantiate()
	model.scale = Vector3.ONE * float(params["model_scale"])
	model.rotation.x = deg_to_rad(float(params["model_rot_x_deg"]))
	model.rotation.y = deg_to_rad(float(params["model_rot_y_deg"]))
	model.rotation.z = deg_to_rad(float(params["model_rot_z_deg"]))
	add_child(model)
	await get_tree().process_frame

	var bend_deg := float(params.get("hand_bend_deg", 0.0))
	if absf(bend_deg) > 0.01:
		for sk in model.find_children("*", "Skeleton3D", true, false):
			var hand_i: int = (sk as Skeleton3D).find_bone("Hand.L")
			if hand_i >= 0:
				var rest_q: Quaternion = (sk as Skeleton3D).get_bone_rest(hand_i).basis.get_rotation_quaternion()
				(sk as Skeleton3D).set_bone_pose_rotation(hand_i, rest_q * Quaternion(Vector3.RIGHT, deg_to_rad(bend_deg)))
				await get_tree().process_frame
				break

	var anchor_arr: Array = params.get("anchor", [0.0, 0.3525, -0.0453])
	var anchor_local := Vector3(anchor_arr[0], anchor_arr[1], anchor_arr[2])
	var anchor_world := model.to_global(anchor_local)
	var dial_world := padlock.to_global(Vector3(0.0, -0.005, 0.172))
	model.global_position += dial_world - anchor_world

	for mi in model.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var mat: Material = mi.mesh.surface_get_material(s)
			if mat is StandardMaterial3D:
				var fd: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
				fd.albedo_color = Color(float(params.get("color_r", 0.9777)), float(params.get("color_g", 0.68)), float(params.get("color_b", 0.3492)))
				fd.roughness = 0.9
				fd.metallic = 0.0
				mi.set_surface_override_material(s, fd)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	var bg: Array = params.get("bg", [0.05, 0.06, 0.09])
	env.background_color = Color(bg[0], bg[1], bg[2])
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.6, 0.55)
	env.ambient_light_energy = 0.18
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var co: Array = params.get("cam_offset", [0.0, 0.03, 0.48])
	var lo: Array = params.get("look_at_offset", [0.0, 0.0, 0.0])
	var cam := Camera3D.new()
	cam.current = true
	cam.fov = float(params.get("cam_fov", 42.0))
	add_child(cam)
	cam.global_position = padlock.global_position + Vector3(co[0], co[1], co[2])
	cam.look_at(padlock.global_position + Vector3(lo[0], lo[1], lo[2]), Vector3.UP)

	var key := DirectionalLight3D.new()
	key.light_energy = float(params.get("key_energy", 0.7))
	key.shadow_enabled = false
	key.rotation_degrees = Vector3(float(params.get("key_pitch_deg", -30.0)), 0.0, 0.0)
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_energy = float(params.get("fill_energy", 0.3))
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	add_child(fill)

	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var out_name: String = str(params.get("out", "paw_cutaway.png"))
	img.save_png("res://screenshots/" + out_name)
	print("CUTAWAY saved=res://screenshots/" + out_name)
	get_tree().quit()

func _build_padlock() -> Node3D:
	var p := Node3D.new()
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.95, 0.75, 0.15)
	brass.metallic = 0.7
	brass.roughness = 0.28
	var brass_dark := StandardMaterial3D.new()
	brass_dark.albedo_color = Color(0.85, 0.65, 0.1)
	brass_dark.metallic = 0.7
	brass_dark.roughness = 0.32
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.55, 0.58, 0.62)
	steel.metallic = 0.8
	steel.roughness = 0.35
	var blk := StandardMaterial3D.new()
	blk.albedo_color = Color(0.12, 0.12, 0.14)
	blk.metallic = 0.4
	blk.roughness = 0.5
	var wht := StandardMaterial3D.new()
	wht.albedo_color = Color(0.97, 0.96, 0.9)

	var plate := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.13, 0.46, 0.025)
	pm.material = steel
	plate.mesh = pm
	plate.position = Vector3(0, 0, 0.02)
	p.add_child(plate)

	var staple := MeshInstance3D.new()
	var sm := TorusMesh.new()
	sm.inner_radius = 0.035
	sm.outer_radius = 0.055
	sm.rings = 12
	sm.ring_segments = 8
	sm.material = steel
	staple.mesh = sm
	staple.position = Vector3(0, 0.185, 0.055)
	staple.rotation = Vector3(PI / 2.0, 0, 0)
	p.add_child(staple)

	var shackle := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.045
	torus.outer_radius = 0.07
	torus.rings = 20
	torus.ring_segments = 10
	torus.material = brass_dark
	shackle.mesh = torus
	shackle.position = Vector3(0, 0.215, 0.10)
	shackle.rotation = Vector3(PI / 2.0, 0, 0)
	p.add_child(shackle)

	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.24, 0.34, 0.12)
	bm.material = brass
	body.mesh = bm
	body.position = Vector3(0, -0.03, 0.10)
	p.add_child(body)

	for i in range(3):
		var dial := MeshInstance3D.new()
		var dm := CylinderMesh.new()
		dm.top_radius = 0.05
		dm.bottom_radius = 0.05
		dm.height = 0.035
		dm.radial_segments = 18
		dm.material = brass_dark
		dial.mesh = dm
		dial.position = Vector3(-0.06 + i * 0.06, -0.005, 0.172)
		dial.rotation = Vector3(PI / 2.0, 0, 0)
		p.add_child(dial)
		var groove := MeshInstance3D.new()
		var gm := CylinderMesh.new()
		gm.top_radius = 0.047
		gm.bottom_radius = 0.047
		gm.height = 0.012
		gm.radial_segments = 12
		gm.material = blk
		groove.mesh = gm
		groove.position = Vector3(-0.06 + i * 0.06, -0.005, 0.19)
		groove.rotation = Vector3(PI / 2.0, 0, 0)
		p.add_child(groove)

	var kp := MeshInstance3D.new()
	var kpm := CylinderMesh.new()
	kpm.top_radius = 0.04
	kpm.bottom_radius = 0.04
	kpm.height = 0.01
	kpm.radial_segments = 16
	kp.mesh = kpm
	kp.position = Vector3(0, -0.14, 0.172)
	kp.rotation = Vector3(PI / 2.0, 0, 0)
	p.add_child(kp)
	var hole := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.014
	hm.bottom_radius = 0.014
	hm.height = 0.02
	hm.radial_segments = 10
	hole.mesh = hm
	hole.position = Vector3(0, -0.14, 0.21)
	hole.rotation = Vector3(PI / 2.0, 0, 0)
	p.add_child(hole)

	var jamb := MeshInstance3D.new()
	var jm := TorusMesh.new()
	jm.inner_radius = 0.035
	jm.outer_radius = 0.055
	jm.rings = 12
	jm.ring_segments = 8
	jm.material = steel
	jamb.mesh = jm
	jamb.position = Vector3(0.15, 0.0, 0.06)
	jamb.rotation = Vector3(PI / 2.0, 0, 0)
	p.add_child(jamb)

	return p
