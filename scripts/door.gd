extends Interactable

@export var door_kind := "shed"

var unlocked := false
var _door_mesh: MeshInstance3D = null
var _padlock: Node3D = null


func _ready() -> void:
	interaction_box = Vector3(1.9, 2.3, 0.5)
	super()
	match door_kind:
		"shed":
			prompt = "Click — Combination padlock"
			_build_padlock()
		"farmhouse":
			prompt = "Click — Farmhouse door"
	_door_mesh = get_parent().get_node_or_null("Door") as MeshInstance3D


func interact() -> void:
	if Hud.any_panel_open():
		return
	match door_kind:
		"shed":
			if GameState.shed_unlocked:
				Hud.show_dialogue([
					"The shed door stands open. Step inside — a coil of string and the spare tractor keys are waiting in here.",
				])
			else:
				Hud.show_combo(_on_combo)
		"farmhouse":
			if not GameState.is_day:
				Hud.show_dialogue([
					"You can't get in here till morning. The door is bolted tight.",
				])
			elif not GameState.catfood_used:
				GameState.catfood_used = true
				GameState.add_food(1)
				Hud.show_dialogue([
					"The farmer's wife smiles and slides a bowl of catfood under the door.",
					"Food +1 — that'll keep you going for a full day.",
				])
			else:
				Hud.show_dialogue([
					"The kitchen's quiet now. Best not to push your luck with the humans.",
					"(Scene 2 — inside the farmhouse — is coming soon!)",
				])


func _on_combo(val: int) -> void:
	if val == GameState.combo:
		unlocked = true
		GameState.shed_unlocked = true
		Hud.toast("CLICK! The padlock springs open. The shed is yours!")
		if _door_mesh != null:
			var t := create_tween()
			t.tween_property(_door_mesh, "rotation:y", 2.4, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if _padlock != null:
			_padlock.queue_free()
		Hud.toast("Step inside to reach the string and the spare tractor keys.")
	else:
		Hud.toast("The padlock stays stubborn. (Hint: the number's on the tractor's plate.)")


func _build_padlock() -> void:
	_padlock = Node3D.new()
	_padlock.position = Vector3(0, 1.05, 0.14)
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.95, 0.75, 0.15)
	brass.metallic = 0.7
	brass.roughness = 0.28
	var brass_dark := StandardMaterial3D.new()
	brass_dark.albedo_color = Color(0.85, 0.65, 0.1)
	brass_dark.metallic = 0.7
	brass_dark.roughness = 0.32
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.12, 0.12, 0.14)
	black.metallic = 0.4
	black.roughness = 0.5
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.97, 0.96, 0.9)

	# shackle — a torus loop standing above the body (lower half hidden in the case)
	var shackle := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.09
	torus.outer_radius = 0.13
	torus.rings = 20
	torus.ring_segments = 12
	torus.material = brass_dark
	shackle.mesh = torus
	shackle.position = Vector3(0, 0.16, -0.03)
	_padlock.add_child(shackle)

	# lock body — rounded slab with a raised front panel
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.26, 0.34, 0.12)
	bm.material = brass
	body.mesh = bm
	_padlock.add_child(body)

	# three rotating dials on the front face, with number grooves
	for i in range(3):
		var dial := MeshInstance3D.new()
		var dm := CylinderMesh.new()
		dm.top_radius = 0.055
		dm.bottom_radius = 0.055
		dm.height = 0.035
		dm.radial_segments = 18
		dm.material = brass_dark
		dial.mesh = dm
		dial.position = Vector3(-0.065 + i * 0.065, 0.02, 0.065)
		dial.rotation = Vector3(PI / 2.0, 0, 0)
		_padlock.add_child(dial)
		var groove := MeshInstance3D.new()
		var gm := CylinderMesh.new()
		gm.top_radius = 0.052
		gm.bottom_radius = 0.052
		gm.height = 0.012
		gm.radial_segments = 12
		gm.material = black
		groove.mesh = gm
		groove.position = Vector3(-0.065 + i * 0.065, 0.02, 0.082)
		groove.rotation = Vector3(PI / 2.0, 0, 0)
		_padlock.add_child(groove)

	# keyhole plate at the bottom centre
	var plate := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.045
	pm.bottom_radius = 0.045
	pm.height = 0.01
	pm.radial_segments = 16
	pm.material = white
	plate.mesh = pm
	plate.position = Vector3(0, -0.12, 0.062)
	plate.rotation = Vector3(PI / 2.0, 0, 0)
	_padlock.add_child(plate)
	var hole := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.016
	hm.bottom_radius = 0.016
	hm.height = 0.02
	hm.radial_segments = 10
	hm.material = black
	hole.mesh = hm
	hole.position = Vector3(0, -0.12, 0.072)
	hole.rotation = Vector3(PI / 2.0, 0, 0)
	_padlock.add_child(hole)

	add_child(_padlock)
