extends Area3D

const STICK_SCENES: Array[PackedScene] = [
	preload("res://assets/sticks/stick_base.glb"),
	preload("res://assets/sticks/stick_a.glb"),
	preload("res://assets/sticks/stick_b.glb"),
	preload("res://assets/sticks/stick_c.glb"),
	preload("res://assets/sticks/stick_d.glb"),
]

const STONE_SCENES: Array[PackedScene] = [
	preload("res://assets/stones/stone_v1.glb"),
	preload("res://assets/stones/stone_v2.glb"),
	preload("res://assets/stones/stone_v3.glb"),
	preload("res://assets/stones/stone_v4.glb"),
	preload("res://assets/stones/stone_v5.glb"),
	preload("res://assets/stones/stone_v6.glb"),
	preload("res://assets/stones/stone_v7.glb"),
]

@export var kind := "string"
@export var amount := 1
@export var loot_id := ""


func _ready() -> void:
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.9
	col.shape = sphere
	add_child(col)
	body_entered.connect(_collect)
	_build_mesh()


func _collect(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	var name := "string"
	match kind:
		"string":
			GameState.add_string(amount)
			name = "a coil of string"
		"stick":
			GameState.add_sticks(amount)
			name = "a stick"
		"stone":
			GameState.add_stones(amount)
			name = "a stone"
		"food":
			GameState.add_food(amount)
			name = "a tasty scrap"
		"key":
			GameState.has_keys = true
			name = "the spare tractor keys"
	if loot_id == "shed_string":
		GameState.shed_string_taken = true
	elif loot_id == "shed_key":
		GameState.shed_key_taken = true
	Hud.toast("Picked up %s" % name)
	queue_free()


func _build_mesh() -> void:
	var mi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	var mesh: Mesh
	match kind:
		"string":
			var cm := CylinderMesh.new()
			cm.top_radius = 0.2
			cm.bottom_radius = 0.2
			cm.height = 0.07
			mesh = cm
			mat.albedo_color = Color(0.95, 0.9, 0.75)
		"stick":
			var scene: PackedScene = STICK_SCENES[randi() % STICK_SCENES.size()]
			var inst: Node3D = scene.instantiate()
			inst.rotation = Vector3(0.0, randf() * TAU, 0.06)
			inst.scale = Vector3.ONE * 1.5
			add_child(inst)
			return
		"stone":
			var sscene: PackedScene = STONE_SCENES[randi() % STONE_SCENES.size()]
			var sinst: Node3D = sscene.instantiate()
			sinst.rotation = Vector3(0.0, randf() * TAU, 0.0)
			sinst.scale = Vector3.ONE * 1.4
			add_child(sinst)
			return
		"food":
			var sm := SphereMesh.new()
			sm.radius = 0.16
			sm.height = 0.32
			mesh = sm
			mat.albedo_color = Color(0.95, 0.55, 0.25)
		"key":
			var cm := CylinderMesh.new()
			cm.top_radius = 0.05
			cm.bottom_radius = 0.05
			cm.height = 0.22
			mesh = cm
			mat.albedo_color = Color(0.95, 0.75, 0.15)
			mat.metallic = 0.6
			mat.roughness = 0.3
			mi.rotation = Vector3(0, 0, 1.1)
	mi.mesh = mesh
	mesh.material = mat
	mi.position = Vector3(0, 0.25, 0)
	add_child(mi)
