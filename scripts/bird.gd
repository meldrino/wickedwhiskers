extends Interactable

var rng := RandomNumberGenerator.new()
var anchor := Vector3.ZERO
var hover := 0.0
var head_turn := 0.0


func _ready() -> void:
	interaction_radius = 4.5
	add_to_group("bird")
	super()
	prompt = "E — A bird in the tree"
	rng.randomize()
	_build_bird()


func _physics_process(delta: float) -> void:
	hover += delta
	position = anchor + Vector3(0, sin(hover * 2.0) * 0.06, 0)
	rotation.y = sin(hover * 0.6) * 0.35


func interact() -> void:
	if Hud.any_panel_open():
		return
	if GameState.bird_caught:
		Hud.show_dialogue([
			"The tree's empty — you already caught that bird.",
		])
		return
	Hud.show_choices("A cheeky bird preens in the high branches:", [
		"Climb the tree yourself",
		"Use a ladder",
		"Hit it with the tractor",
		"Leave it",
	], _on_choice)


func _on_choice(i: int) -> void:
	match i:
		0:
			Hud.toast("You scramble up... wobble... and land SQUARE on your head. The bird cackles. (No low branches — you'll never catch it by climbing.)")
		1:
			_use_ladder()
		2:
			_use_tractor()
		3:
			pass


func _use_ladder() -> void:
	if GameState.ladder_placed:
		_catch()
		return
	match GameState.materials_status():
		"none":
			Hud.toast("You don't have the right materials for a ladder — you need string and sticks.")
		"half":
			Hud.toast("You only have half the materials you need for a ladder.")
		"full":
			GameState.spend_ladder()
			GameState.ladder_placed = true
			Hud.toast("You lash a ladder together, prop it against the trunk, and scramble up...")
			_catch()


func _use_tractor() -> void:
	if not GameState.has_keys:
		Hud.toast("The tractor won't start — you need the keys! (Spare set's in the shed.)")
		return
	var tractor = get_tree().get_first_node_in_group("tractor")
	if tractor == null:
		Hud.toast("The tractor seems to have wandered off.")
		return
	Hud.toast("You swing up, turn the key, and point the tractor at the tree. Chugga-chugga...")
	tractor._drive_to(global_position, func():
		_knocked_by_tractor())


func _knocked_by_tractor() -> void:
	Hud.toast("WHAM! The tractor rattles the tree and the bird tumbles out, dizzy. Food +1")
	_catch(true)


func _catch(by_tractor := false) -> void:
	if GameState.bird_caught:
		return
	GameState.bird_caught = true
	GameState.add_food(1)
	if GameState.quest == "meet":
		GameState.quest = "trade"
	if not by_tractor:
		Hud.toast("Gotcha! The bird is caught. Food +1")
	queue_free()


func _build_bird() -> void:
	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color(0.3, 0.5, 0.85)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.95, 0.95, 0.92)
	var orange := StandardMaterial3D.new()
	orange.albedo_color = Color(0.95, 0.6, 0.2)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.1, 0.1, 0.1)

	var body := _mesh("sphere", Vector3(0.24, 0.2, 0.28), blue)
	body.position = Vector3(0, 0, 0)
	add_child(body)

	var head := _mesh("sphere", Vector3(0.16, 0.15, 0.16), blue)
	head.position = Vector3(0, 0.14, 0.12)
	add_child(head)

	var beak := _mesh("box", Vector3(0.04, 0.035, 0.09), orange)
	beak.position = Vector3(0, 0.14, 0.24)
	add_child(beak)

	var eye := _mesh("sphere", Vector3(0.045, 0.045, 0.03), dark)
	eye.position = Vector3(0.05, 0.18, 0.19)
	add_child(eye)

	for x in [-1, 1]:
		var wing := _mesh("box", Vector3(0.3, 0.03, 0.14), white)
		wing.position = Vector3(x * 0.22, 0.02, 0.0)
		wing.rotation = Vector3(0, 0, x * 0.25)
		add_child(wing)

	var tail := _mesh("box", Vector3(0.06, 0.03, 0.2), white)
	tail.position = Vector3(0, 0.04, -0.24)
	tail.rotation = Vector3(-0.2, 0, 0)
	add_child(tail)


func _mesh(kind: String, size: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh: Mesh
	match kind:
		"box":
			var bm := BoxMesh.new()
			bm.size = size
			mesh = bm
		"sphere":
			var sm := SphereMesh.new()
			sm.radius = size.x * 0.5
			sm.height = size.y
			mesh = sm
	mesh.material = mat
	mi.mesh = mesh
	return mi
