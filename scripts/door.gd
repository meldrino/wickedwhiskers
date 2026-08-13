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
		if _padlock != null and get_tree().current_scene != null:
			Hud.toast("The dials click into place...")
			var cw: Node3D = (preload("res://scripts/cutaway.gd") as Script).new()
			get_tree().current_scene.add_child(cw)
			cw.play_padlock_unlock(self, _finish_unlock)
		else:
			_finish_unlock()
	else:
		Hud.toast("The padlock stays stubborn. (Hint: the number's on the tractor's plate.)")


func _finish_unlock() -> void:
	Hud.toast("CLICK! The padlock springs open. The shed is yours!")
	if _door_mesh != null:
		var t := create_tween()
		t.tween_property(_door_mesh, "rotation:y", 2.4, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _padlock != null:
		_padlock.queue_free()
	Hud.toast("Step inside to reach the string and the spare tractor keys.")


func _build_padlock() -> void:
	# Latch hardware sits ON the door at ~1.0m world height - exactly where the
	# click interaction point is - so the padlock reads as locking the door.
	# The door Area3D pivot is at world y=1.0, so local y 0 = the click height.
	_padlock = Node3D.new()
	_padlock.position = Vector3(0.40, 0.0, 0.12)
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
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.12, 0.12, 0.14)
	black.metallic = 0.4
	black.roughness = 0.5
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.97, 0.96, 0.9)

	# mounting plate - a vertical strap bolted to the door edge (straddles the
	# door edge at x 0.40, the door is 0.9 wide so the edge is at 0.45)
	var plate := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.13, 0.46, 0.025)
	pm.material = steel
	plate.mesh = pm
	plate.position = Vector3(0, 0, 0.02)
	_padlock.add_child(plate)

	# door staple - the loop the shackle passes through (bolted to the plate)
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
	_padlock.add_child(staple)

	# shackle - loop standing above the body, through the door staple
	var shackle := MeshInstance3D.new()
	shackle.name = "Shackle"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.045
	torus.outer_radius = 0.07
	torus.rings = 20
	torus.ring_segments = 10
	torus.material = brass_dark
	shackle.mesh = torus
	shackle.position = Vector3(0, 0.215, 0.10)
	shackle.rotation = Vector3(PI / 2.0, 0, 0)
	_padlock.add_child(shackle)

	# lock body - rounded slab with a raised front panel, sitting on the plate
	var body := MeshInstance3D.new()
	body.name = "LockBody"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.24, 0.34, 0.12)
	bm.material = brass
	body.mesh = bm
	body.position = Vector3(0, -0.03, 0.10)
	_padlock.add_child(body)

	# three rotating dials on the front face, with number grooves
	for i in range(3):
		var dial := MeshInstance3D.new()
		dial.name = "Dial%d" % i
		var dm := CylinderMesh.new()
		dm.top_radius = 0.05
		dm.bottom_radius = 0.05
		dm.height = 0.035
		dm.radial_segments = 18
		dm.material = brass_dark
		dial.mesh = dm
		dial.position = Vector3(-0.06 + i * 0.06, -0.005, 0.172)
		dial.rotation = Vector3(PI / 2.0, 0, 0)
		_padlock.add_child(dial)
		var groove := MeshInstance3D.new()
		var gm := CylinderMesh.new()
		gm.top_radius = 0.047
		gm.bottom_radius = 0.047
		gm.height = 0.012
		gm.radial_segments = 12
		gm.material = black
		groove.mesh = gm
		groove.position = Vector3(-0.06 + i * 0.06, -0.005, 0.19)
		groove.rotation = Vector3(PI / 2.0, 0, 0)
		_padlock.add_child(groove)

	# keyhole plate at the bottom of the body
	var kp := MeshInstance3D.new()
	var kpm := CylinderMesh.new()
	kpm.top_radius = 0.04
	kpm.bottom_radius = 0.04
	kpm.height = 0.01
	kpm.radial_segments = 16
	kpm.material = white
	kp.mesh = kpm
	kp.position = Vector3(0, -0.14, 0.172)
	kp.rotation = Vector3(PI / 2.0, 0, 0)
	_padlock.add_child(kp)
	var hole := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.014
	hm.bottom_radius = 0.014
	hm.height = 0.02
	hm.radial_segments = 10
	hm.material = black
	hole.mesh = hm
	hole.position = Vector3(0, -0.14, 0.21)
	hole.rotation = Vector3(PI / 2.0, 0, 0)
	_padlock.add_child(hole)

	# jamb staple - the matching loop on the frame post (post at door-local
	# x +-0.55; the padlock node is at x 0.40 so the staple sits 0.15 over)
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
	_padlock.add_child(jamb)

	# Clickable surface: raycast pick (bodies only) hits this, then walks up to
	# the door Interactable. On collision_layer 2 so the player (mask layer 1)
	# walks through the doorway without bumping it.
	var cb := StaticBody3D.new()
	cb.name = "PadlockHit"
	cb.collision_layer = 2
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.3, 0.42, 0.2)
	cs.shape = shape
	cb.add_child(cs)
	_padlock.add_child(cb)

	add_child(_padlock)
