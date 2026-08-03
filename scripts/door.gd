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
			prompt = "E — Combination padlock"
			_build_padlock()
		"farmhouse":
			prompt = "E — Farmhouse door"
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
		var block := get_parent().get_node_or_null("DoorBlock")
		if block != null:
			block.queue_free()
		_spawn_shed_loot()
	else:
		Hud.toast("The padlock stays stubborn. (Hint: the number's on the tractor's plate.)")


func _spawn_shed_loot() -> void:
	var shed := get_parent()
	var s := preload("res://scripts/pickup.gd").new()
	s.kind = "string"
	s.position = shed.global_position + Vector3(-1.1, 1.1, -1.1)
	shed.add_child(s)
	var k := preload("res://scripts/pickup.gd").new()
	k.kind = "key"
	k.position = shed.global_position + Vector3(1.1, 0.68, -1.1)
	shed.add_child(k)


func _build_padlock() -> void:
	_padlock = Node3D.new()
	_padlock.position = Vector3(0, 0.85, 0.12)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22, 0.3, 0.1)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.75, 0.15)
	mat.metallic = 0.6
	mat.roughness = 0.3
	bm.material = mat
	body.mesh = bm
	_padlock.add_child(body)
	var shackle := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.85, 0.65, 0.1)
	smat.metallic = 0.6
	smat.roughness = 0.3
	sm.material = smat
	shackle.mesh = sm
	shackle.position = Vector3(0, 0.2, 0)
	_padlock.add_child(shackle)
	add_child(_padlock)
