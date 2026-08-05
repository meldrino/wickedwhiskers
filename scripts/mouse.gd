extends Interactable

var rng := RandomNumberGenerator.new()
var speed := 1.4
var state := "wander"
var wander_t := 0.0
var wander_dir := Vector3.ZERO
var flee_t := 0.0
var chase_t := 0.0
var center := Vector3.ZERO
var radius := 12.0
var lure_target: Node3D = null

const FLEE_DISTANCE := 4.0
const TRAP_DISTANCE := 1.8
const CHASE_DURATION := 4.5


func _ready() -> void:
	super()
	prompt = "Click — A mouse"
	interaction_box = Vector3(0.7, 0.6, 1.0)
	interaction_center = Vector3(0, 0.25, 0)
	rng.randomize()
	center = global_position
	wander_dir = Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
	_build_mouse()


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var to_player: Vector3 = global_position - player.global_position
	to_player.y = 0
	var dist: float = to_player.length()

	_check_trap()

	match state:
		"chase":
			chase_t -= delta
			var away := to_player.normalized()
			var wig := sin(chase_t * 9.0) * 1.1
			var dir := away.rotated(Vector3.UP, wig)
			_move(dir * speed * 3.6, delta)
			if player.has_method("walk_to"):
				player.walk_to(global_position)
			if chase_t <= 0.0:
				_end_chase(player)
		"to_trap":
			if lure_target == null or not is_instance_valid(lure_target):
				state = "wander"
			else:
				var to_trap: Vector3 = (lure_target as Node3D).global_position - global_position
				to_trap.y = 0
				if to_trap.length() < 0.6:
					_move(Vector3.ZERO, delta)
				else:
					_move(to_trap.normalized() * speed * 2.0, delta)
		"flee":
			flee_t -= delta
			if flee_t <= 0.0 or dist > 9.0:
				state = "wander"
			else:
				_move(to_player.normalized() * speed * 2.2, delta)
		_:
			if dist < FLEE_DISTANCE:
				state = "flee"
				flee_t = 2.5
			else:
				wander_t -= delta
				if wander_t <= 0.0:
					wander_t = rng.randf_range(1.5, 3.5)
					var ang := rng.randf_range(0, TAU)
					wander_dir = Vector3(cos(ang), 0, sin(ang)).normalized()
				_move(wander_dir * speed, delta)


func _move(vel: Vector3, delta: float) -> void:
	var p := global_position + vel * delta
	var to_center := p - center
	to_center.y = 0
	if to_center.length() > radius:
		wander_dir = -to_center.normalized()
		p = global_position
	position = p
	if vel.length() > 0.1:
		rotation.y = atan2(vel.x, vel.z)


func _check_trap() -> void:
	for trap in get_tree().get_nodes_in_group("traps"):
		if global_position.distance_to((trap as Node3D).global_position) < TRAP_DISTANCE:
			_catch()
			return


func _catch() -> void:
	GameState.mouse_caught = true
	GameState.add_food(1)
	if GameState.quest == "meet":
		GameState.quest = "trade"
	Hud.toast("SNAP! The convoluted mouse trap got him! Food +1")
	queue_free()


func interact() -> void:
	if Hud.any_panel_open():
		return
	if GameState.mouse_caught:
		Hud.show_dialogue([
			"The fields are quiet now — you already caught the only mouse.",
		])
		return
	Hud.show_choices("A plump field mouse twitches its whiskers at you:", [
		"Chase the mouse!",
		"Make a convoluted mouse trap",
		"Leave it",
	], _on_choice)


func _on_choice(i: int) -> void:
	match i:
		0:
			_start_chase()
		1:
			_make_trap()
		2:
			pass


func _start_chase() -> void:
	if GameState.chase_active:
		return
	GameState.chase_active = true
	state = "chase"
	chase_t = CHASE_DURATION
	Hud.toast("Prowl-prowl-prowl... the mouse bolts! Here we go!")


func _end_chase(player: Node3D) -> void:
	GameState.chase_active = false
	state = "wander"
	if player != null and player.has_method("stop_walk"):
		player.stop_walk()
	Hud.toast("The mouse zigzags, you pounce, and — WHUMP — you face-plant into the grass. It dives down a hole. (You can't catch a mouse by chasing!)")


func _make_trap() -> void:
	if GameState.trap_placed:
		Hud.toast("Your mouse trap is already out there waiting.")
		return
	match GameState.materials_status():
		"none":
			Hud.toast("You don't have the right materials — a trap needs string and sticks.")
		"half":
			Hud.toast("You only have half the materials you need for the trap.")
		"full":
			GameState.spend_trap()
			GameState.trap_placed = true
			var trap := preload("res://scripts/trap.gd").new()
			trap.position = global_position + Vector3(1.2, 0, 0.8)
			trap.position.y = Terrain.height_at(trap.position.x, trap.position.z)
			get_tree().current_scene.add_child(trap)
			lure_target = trap
			state = "to_trap"
			Hud.toast("You bolt together a gloriously overengineered trap. The mouse noses toward it...")


func _build_mouse() -> void:
	var brown := StandardMaterial3D.new()
	brown.albedo_color = Color(0.55, 0.42, 0.32)
	var pink := StandardMaterial3D.new()
	pink.albedo_color = Color(0.85, 0.6, 0.55)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.15, 0.12, 0.1)

	var body := _mesh("sphere", Vector3(0.34, 0.26, 0.52), brown)
	body.position = Vector3(0, 0.2, 0)
	add_child(body)

	var head := _mesh("sphere", Vector3(0.22, 0.2, 0.2), brown)
	head.position = Vector3(0, 0.27, 0.28)
	add_child(head)

	for x in [-0.1, 0.1]:
		var ear := _mesh("sphere", Vector3(0.11, 0.03, 0.11), pink)
		ear.position = Vector3(x, 0.37, 0.26)
		add_child(ear)

	for x in [-0.035, 0.035]:
		var eye := _mesh("sphere", Vector3(0.05, 0.05, 0.04), dark)
		eye.position = Vector3(x, 0.3, 0.44)
		add_child(eye)

	var nose := _mesh("sphere", Vector3(0.05, 0.04, 0.05), pink)
	nose.position = Vector3(0, 0.26, 0.47)
	add_child(nose)

	var tail := _mesh("box", Vector3(0.02, 0.02, 0.5), pink)
	tail.position = Vector3(0, 0.14, -0.4)
	tail.rotation = Vector3(0.3, 0, 0)
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
