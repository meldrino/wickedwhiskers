extends Interactable

var wheels: Array[MeshInstance3D] = []
var driving := false
var drive_target := Vector3.ZERO
var drive_cb: Callable = Callable()
var plate_mat: StandardMaterial3D


func _ready() -> void:
	interaction_radius = 3.2
	interaction_box = Vector3(2.6, 1.7, 1.7)
	interaction_center = Vector3(0, 0.8, 0)
	add_to_group("tractor")
	super()
	prompt = "E — Farm tractor"
	_build_tractor()


func _build_tractor() -> void:
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.78, 0.16, 0.12)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.2, 0.2, 0.22)
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.08, 0.08, 0.09)
	plate_mat = StandardMaterial3D.new()
	plate_mat.albedo_color = Color(0.96, 0.95, 0.9)

	_mesh("box", Vector3(2.4, 0.55, 1.5), red, Vector3(0, 0.55, 0.2))
	_mesh("box", Vector3(1.5, 0.85, 1.1), red, Vector3(0, 1.15, -0.35))
	_mesh("box", Vector3(0.8, 0.45, 0.8), dark, Vector3(0, 0.95, 0.85))
	var exhaust := _mesh("cylinder", Vector3(0.08, 0.9, 0.08), black, Vector3(0.9, 1.7, -0.4))
	exhaust.rotation = Vector3(0.15, 0, 0)
	var plate := _mesh("box", Vector3(0.5, 0.22, 0.05), plate_mat, Vector3(0, 1.15, -0.95))
	plate.name = "Plate"
	_add_collider(Vector3(2.4, 1.4, 1.5), Vector3(0, 0.9, 0.1))

	for x in [-1.1, 1.1]:
		var w := _wheel(0.45, 0.38)
		w.position = Vector3(x, 0.45, -0.35)
		wheels.append(w)
	for x in [-1.0, 1.0]:
		var w := _wheel(0.3, 0.3)
		w.position = Vector3(x, 0.3, 0.85)
		wheels.append(w)


func _wheel(radius: float, width: float) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = width
	cm.radial_segments = 16
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.12, 0.14)
	cm.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.rotation = Vector3(0, 0, PI / 2.0)
	add_child(mi)
	return mi


func _mesh(kind: String, size: Vector3, mat: StandardMaterial3D, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh: Mesh
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
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	add_child(mi)
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


func interact() -> void:
	if Hud.any_panel_open():
		return
	if driving:
		Hud.toast("The tractor's already rolling!")
		return
	Hud.show_choices("The farm tractor:", [
		"Read the number plate",
		"Drive to the bird tree",
		"Leave it",
	], _on_choice)


func _on_choice(i: int) -> void:
	match i:
		0:
			Hud.show_dialogue([
				"The tractor's number plate reads: NUM %03d." % GameState.combo,
				"(Remember that — it might open something.)",
			])
		1:
			if not GameState.has_keys:
				Hud.toast("You can't start it — you need the tractor keys! (Spare set's in the shed.)")
			elif GameState.bird_caught:
				Hud.toast("The bird's already caught. No point chugging over there.")
			else:
				var bird = get_tree().get_first_node_in_group("bird")
				if bird == null:
					Hud.toast("The bird must have flown off.")
					return
				Hud.toast("You swing up onto the tractor. Chug... chug... CHUG!")
				_drive_to((bird as Node3D).global_position, func():
					if is_instance_valid(bird):
						bird.knocked_by_tractor())
		2:
			pass


func _drive_to(target: Vector3, cb: Callable) -> void:
	driving = true
	drive_target = target
	drive_target.y = 0.0
	drive_cb = cb


func _physics_process(delta: float) -> void:
	if not driving:
		return
	var to: Vector3 = drive_target - global_position
	to.y = 0.0
	if to.length() < 0.8:
		driving = false
		var cb := drive_cb
		drive_cb = Callable()
		cb.call()
		return
	var dir := to.normalized()
	global_position += dir * 9.0 * delta
	var heading := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, heading, 6.0 * delta)
	for w in wheels:
		w.rotate_z(14.0 * delta)
