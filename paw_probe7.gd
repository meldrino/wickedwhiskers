extends SceneTree

var settings: Dictionary
var VW := 1280
var VH := 720

func _init() -> void:
	print("PROBE7 start")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--cfg="):
			settings = _load_json(a.trim_prefix("--cfg="))
	if settings.is_empty():
		print("PROBE7 ERROR no cfg")
		quit(1)
		return
	_go()

func _go() -> void:
	var glb_path: String = settings.get("model_glb", "res://assets/paw_ai_v4.glb")
	var glb := load(glb_path) as PackedScene
	if glb == null:
		print("PROBE7 ERROR load ", glb_path)
		quit(1)
		return
	var model: Node3D = glb.instantiate()
	var mi: MeshInstance3D = null
	for c in model.find_children("*", "MeshInstance3D", true, false):
		mi = c
		break
	var mesh: ArrayMesh = mi.mesh
	var aabb := mesh.get_aabb()
	print("PROBE7 meshAABB center=", aabb.get_center(), " size=", aabb.size)

	var scale_v := float(settings.get("model_scale", 0.34))
	var rot_x := deg_to_rad(float(settings.get("model_rot_x_deg", -90.0)))
	var rot_y := deg_to_rad(float(settings.get("model_rot_y_deg", 180.0)))
	model.scale = Vector3.ONE * scale_v
	model.rotation = Vector3(rot_x, rot_y, 0.0)
	model.rotation_order = int(settings.get("rotation_order", 2))

	var tgt_off: Vector3 = Vector3(
		float(settings.get("target_offset", [])[0]),
		float(settings.get("target_offset", [])[1]),
		float(settings.get("target_offset", [])[2]))

	var padlock := Node3D.new()
	padlock.position = Vector3(16.4, 1.0, -8.7)
	root.add_child(padlock)
	root.add_child(model)

	var target: Vector3
	if settings.has("model_anchor"):
		var ma: Array = settings["model_anchor"]
		var anchor_w: Vector3 = model.global_transform * Vector3(float(ma[0]), float(ma[1]), float(ma[2]))
		model.position = padlock.global_position + tgt_off - anchor_w
		print("PROBE7 anchor used ma=", ma, " anchor_w=", anchor_w)
	else:
		var pcenter: Vector3 = model.global_transform * mesh.get_aabb().get_center()
		model.position = padlock.global_position + tgt_off - pcenter
		print("PROBE7 aabb anchor pcenter=", pcenter)
	print("PROBE7 model.position=", model.position)
	print("PROBE7 hand_center_world=", model.global_transform * Vector3(0, 0, 0.135))

	var dial0 := Node3D.new()
	dial0.position = Vector3(16.34, 0.995, -8.528)
	var dial1 := Node3D.new()
	dial1.position = Vector3(16.4, 0.995, -8.528)
	var dial2 := Node3D.new()
	dial2.position = Vector3(16.46, 0.995, -8.528)
	root.add_child(dial0)
	root.add_child(dial1)
	root.add_child(dial2)

	var cam := Camera3D.new()
	var cam_off: Vector3 = Vector3(
		float(settings.get("cam_offset", [])[0]),
		float(settings.get("cam_offset", [])[1]),
		float(settings.get("cam_offset", [])[2]))
	cam.position = padlock.global_position + cam_off
	cam.look_at(Vector3(16.4, 1.0, -8.7), Vector3.UP)
	cam.fov = float(settings.get("cam_fov", 42.0))
	root.add_child(cam)

	print("PROBE7 cam.position=", cam.position)
	print("PROBE7 cam basis=", cam.global_transform.basis)

	var pts := {
		"hand_center": model.global_transform * Vector3(0, 0, 0.135),
		"finger_mid_tip": model.global_transform * Vector3(0, 0, 0.185),
		"finger_edge_tip": model.global_transform * Vector3(0.07, 0, 0.185),
		"palm_top": model.global_transform * Vector3(0, 0, 0.11),
		"arm_bottom": model.global_transform * Vector3(0, 0, -0.884),
		"dial0": dial0.global_position,
		"dial1": dial1.global_position,
		"dial2": dial2.global_position,
		"padlock_body_center": Vector3(16.4, 0.97, -8.7),
		"shackle_top": Vector3(16.4, 1.18, -8.7),
	}
	for k in pts:
		var w: Vector3 = pts[k]
		var s: Vector2 = cam.unproject_position(w)
		print("PROBE7 pt ", k, " world=", w, " screen=", s, " on=%s" % (s.x >= 0 and s.x <= VW and s.y >= 0 and s.y <= VH))

	print("PROBE7 done")
	quit(0)

func _load_json(p: String) -> Dictionary:
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {}
	return JSON.parse_string(f.get_as_text())
