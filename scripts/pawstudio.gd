extends Node3D


func _ready() -> void:
	print("PAWSTUDIO start")
	global_position = Vector3(0.0, 300.0, 0.0)
	for n in get_tree().root.get_children():
		if n == self:
			continue
		if n is Node3D:
			(n as Node3D).visible = false
		elif n is CanvasLayer:
			(n as CanvasLayer).visible = false
	var params := {
		"model_glb": "res://assets/paw_hv.glb",
		"model_scale": 1.0,
		"model_rot_x_deg": 0.0,
		"model_rot_y_deg": 0.0,
		"model_rot_z_deg": 0.0,
		"cam_yaw_deg": 0.0,
		"cam_pitch_deg": -10.0,
		"cam_dist": 0.55,
		"cam_fov": 40.0,
		"target": [0.0, 0.0, 0.0],
		"bg": [0.05, 0.06, 0.09],
		"key_energy": 1.7,
		"key_yaw_deg": 35.0,
		"key_pitch_deg": -40.0,
		"fill_energy": 0.35,
		"fill_yaw_deg": 160.0,
		"fill_pitch_deg": -8.0,
		"rim_energy": 0.55,
		"rim_yaw_deg": -70.0,
		"rim_pitch_deg": 6.0,
		"control_sphere": false,
		"out": "pawstudio.png",
	}
	var pf := FileAccess.open("res://screenshots/pawstudio_params.json", FileAccess.READ)
	if pf != null:
		var j: Variant = JSON.parse_string(pf.get_as_text())
		if j is Dictionary:
			for k in j:
				params[k] = j[k]
		pf.close()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	var bg: Array = params["bg"]
	env.background_color = Color(bg[0], bg[1], bg[2])
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	var we := WorldEnvironment.new()
	we.name = "StudioEnv"
	we.environment = env
	add_child(we)
	var control_sphere: bool = bool(params["control_sphere"])
	if control_sphere:
		var sm := SphereMesh.new()
		sm.radius = 0.09
		sm.height = 0.18
		sm.material = StandardMaterial3D.new()
		(sm.material as StandardMaterial3D).albedo_color = Color("#f9ad59")
		(sm.material as StandardMaterial3D).roughness = 0.6
		var smi := MeshInstance3D.new()
		smi.name = "ControlSphere"
		smi.mesh = sm
		add_child(smi)
	else:
		var glb: PackedScene = load(str(params["model_glb"]))
		if glb == null:
			push_error("PAWSTUDIO failed to load model_glb=" + str(params["model_glb"]))
			get_tree().quit()
			return
		var model := glb.instantiate()
		model.scale = Vector3.ONE * float(params["model_scale"])
		model.rotation.x = deg_to_rad(float(params["model_rot_x_deg"]))
		model.rotation.y = deg_to_rad(float(params["model_rot_y_deg"]))
		model.rotation.z = deg_to_rad(float(params["model_rot_z_deg"]))
		add_child(model)
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).visible = true
	var key := DirectionalLight3D.new()
	key.name = "Key"
	key.light_energy = float(params["key_energy"])
	key.shadow_enabled = true
	key.rotation_degrees = Vector3(float(params["key_pitch_deg"]), float(params["key_yaw_deg"]), 0.0)
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.light_energy = float(params["fill_energy"])
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(float(params["fill_pitch_deg"]), float(params["fill_yaw_deg"]), 0.0)
	add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.name = "Rim"
	rim.light_energy = float(params["rim_energy"])
	rim.shadow_enabled = false
	rim.rotation_degrees = Vector3(float(params["rim_pitch_deg"]), float(params["rim_yaw_deg"]), 0.0)
	add_child(rim)
	var cam := Camera3D.new()
	cam.name = "StudioCam"
	cam.current = true
	cam.fov = float(params["cam_fov"])
	add_child(cam)
	var yaw := deg_to_rad(float(params["cam_yaw_deg"]))
	var pitch := deg_to_rad(float(params["cam_pitch_deg"]))
	var dist := float(params["cam_dist"])
	var target_arr: Array = params["target"]
	var target := global_position + Vector3(target_arr[0], target_arr[1], target_arr[2])
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	cam.global_position = target - dir * dist
	cam.look_at(target, Vector3.UP)
	for i in range(4):
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var p := "res://screenshots/" + str(params["out"])
	img.save_png(p)
	print("PAWSTUDIO saved=" + p)
	get_tree().quit()
