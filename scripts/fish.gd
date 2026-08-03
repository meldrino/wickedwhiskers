extends Interactable

var fish_body: MeshInstance3D
var swim_t := 0.0
var caught := false

const POND_RADIUS := 4.4
const SWIM_RADIUS := 2.6


func _ready() -> void:
	interaction_radius = 4.4
	super()
	prompt = "E — The pond"
	_build_pond()


func _build_pond() -> void:
	var mud := StandardMaterial3D.new()
	mud.albedo_color = Color(0.5, 0.42, 0.3)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.3, 0.55, 0.85)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.albedo_color.a = 0.72
	water.roughness = 0.2

	var rim := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = POND_RADIUS + 0.5
	rm.bottom_radius = POND_RADIUS + 0.5
	rm.height = 0.16
	rm.material = mud
	rim.mesh = rm
	rim.position = Vector3(0, 0.02, 0)
	add_child(rim)

	var disc := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = POND_RADIUS
	dm.bottom_radius = POND_RADIUS
	dm.height = 0.12
	dm.material = water
	disc.mesh = dm
	disc.position = Vector3(0, 0.06, 0)
	add_child(disc)

	_build_fish()


func _build_fish() -> void:
	var orange := StandardMaterial3D.new()
	orange.albedo_color = Color(0.95, 0.55, 0.2)
	var fin := StandardMaterial3D.new()
	fin.albedo_color = Color(0.9, 0.4, 0.15)

	fish_body = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.14
	sm.height = 0.3
	sm.material = orange
	fish_body.mesh = sm
	add_child(fish_body)

	var tail := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.05, 0.16, 0.16)
	tm.material = fin
	tail.mesh = tm
	tail.position = Vector3(0, 0, -0.22)
	fish_body.add_child(tail)


func _physics_process(delta: float) -> void:
	if caught:
		return
	swim_t += delta
	var ang := swim_t * 0.8
	var x := cos(ang) * SWIM_RADIUS
	var z := sin(ang) * SWIM_RADIUS
	fish_body.position = Vector3(x, 0.22 + sin(swim_t * 3.0) * 0.06, z)
	fish_body.rotation.y = -ang - PI / 2.0
	fish_body.rotation.z = sin(swim_t * 5.0) * 0.15


func interact() -> void:
	if Hud.any_panel_open():
		return
	if caught:
		Hud.show_dialogue([
			"The pond's quiet now. You already caught your fish — and that's oFISHial!",
		])
		return
	Hud.show_choices("The pond glints in the dark. A fish swims lazily inside:", [
		"Try fishing with your paw",
		"Make a fishing rod",
		"Leave it",
	], _on_choice)


func _on_choice(i: int) -> void:
	match i:
		0:
			Hud.toast("You splash and swat, but the fish just taunts you. You can't reach it with a paw!")
		1:
			_make_rod()
		2:
			pass


func _make_rod() -> void:
	if GameState.rod_placed:
		_catch()
		return
	match GameState.materials_status():
		"none":
			Hud.toast("You don't have the right materials for a rod — you need string and sticks.")
		"half":
			Hud.toast("You only have half the materials you need for a rod.")
		"full":
			GameState.spend_rod()
			GameState.rod_placed = true
			_catch()


func _catch() -> void:
	caught = true
	GameState.fish_caught = true
	GameState.add_food(1)
	if GameState.quest == "meet":
		GameState.quest = "trade"
	Hud.toast("You cast your rod... and reel in a fine fish! That's oFISHial! Food +1")
	fish_body.visible = false
