extends Node3D

const VIEW_COUNT := 4

var turntable := Node3D.new()


func _ready() -> void:
	_build_floor()
	add_child(turntable)
	var glb_path := _arg_value("view")
	if glb_path.is_empty():
		push_error("Pass --view=<path to .glb>")
		get_tree().quit()
		return
	if not FileAccess.file_exists(glb_path):
		push_error("File not found: " + glb_path)
		get_tree().quit()
		return
	var model := _load_glb(glb_path)
	if model == null:
		push_error("Failed to parse GLB: " + glb_path)
		get_tree().quit()
		return
	turntable.add_child(model)
	_fit(model)
	await get_tree().process_frame
	await get_tree().process_frame
	_save_views()


func _arg_value(key: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + key + "="):
			return a.get_slice("=", 1)
	return ""


func _load_glb(path: String) -> Node:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(path, state)
	if err != OK:
		return null
	return doc.generate_scene(state)


func _fit(model: Node) -> void:
	var box := _aabb(model as Node3D)
	if not box.has_surface():
		return
	var max_dim := maxf(box.size.x, maxf(box.size.y, box.size.z))
	var s := 2.2 / max_dim if max_dim > 0.0 else 1.0
	var center := box.get_center()
	turntable.scale = Vector3(s, s, s)
	turntable.position = Vector3(-s * center.x, -s * box.position.y, -s * center.z)


func _aabb(node: Node3D) -> AABB:
	var acc := AABB()
	if node is MeshInstance3D:
		acc = node.global_transform * (node as MeshInstance3D).get_aabb()
	for c in node.get_children():
		if c is Node3D:
			var sub := _aabb(c as Node3D)
			if sub.has_surface():
				if acc.has_surface():
					acc = acc.merge(sub)
				else:
					acc = sub
	return acc


func _build_floor() -> void:
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 2.6
	cm.bottom_radius = 2.6
	cm.height = 0.04
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.6, 0.56)
	cm.material = mat
	disc.mesh = cm
	disc.position = Vector3(0, -0.02, 0)
	add_child(disc)


func _save_views() -> void:
	for i in range(VIEW_COUNT):
		turntable.rotation.y = float(i) * TAU / float(VIEW_COUNT)
		await get_tree().process_frame
		await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://view_%d.png" % (i + 1))
	print("VIEWS SAVED: " + str(VIEW_COUNT))
	get_tree().quit()
