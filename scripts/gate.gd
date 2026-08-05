extends Interactable

const FENCE := preload("res://assets/fence2.glb")

var _pivot: Node3D
var _open := false
var _busy := false

const WOOD := Color(0.5, 0.35, 0.2)
const WOOD_DARK := Color(0.38, 0.26, 0.15)
const POST_H := 1.5
const GATE_W := 2.9


func _ready() -> void:
	prompt = "Click — gate"
	interaction_box = Vector3(3.4, 1.4, 0.6)
	interaction_center = Vector3(0, 0.6, 0)
	super()
	_build_gate()


func _build_gate() -> void:
	# Fills: short fence sections either side of the opening (scaled fence2).
	_add_fill(-2.345)
	_add_fill(2.355)
	# Gateposts flank the opening (they do NOT rotate).
	_add_post(-1.595)
	_add_post(1.605)

	# The gate itself: hinged at the west post inner edge, swings into the yard.
	_pivot = Node3D.new()
	_pivot.position = Vector3(-1.445, 0, 0)
	add_child(_pivot)

	var rails := [
		[Vector3(1.45, 0.92, 0), Vector3(GATE_W, 0.09, 0.12), Vector3.ZERO],
		[Vector3(1.45, 0.13, 0), Vector3(GATE_W, 0.11, 0.12), Vector3.ZERO],
		[Vector3(1.45, 0.55, 0), Vector3(GATE_W, 0.07, 0.1), Vector3.ZERO],
		[Vector3(1.45, 0.53, 0), Vector3(2.85, 0.07, 0.1), Vector3(0, 0, 0.285)],
		[Vector3(0.35, 0.53, 0), Vector3(0.06, 0.82, 0.1), Vector3.ZERO],
		[Vector3(1.45, 0.53, 0), Vector3(0.06, 0.82, 0.1), Vector3.ZERO],
		[Vector3(2.55, 0.53, 0), Vector3(0.06, 0.82, 0.1), Vector3.ZERO],
	]
	for r in rails:
		_add_box(_pivot, r[1], r[0], WOOD, r[2])
	# Latch (meets the east post when closed)
	_add_box(_pivot, Vector3(0.16, 0.18, 0.12), Vector3(1.4, 0.95, 0), WOOD_DARK)

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GATE_W, 1.0, 0.12)
	col.shape = box
	col.position = Vector3(1.45, 0.5, 0)
	body.add_child(col)
	_pivot.add_child(body)


func _add_fill(x: float) -> void:
	var fill: Node3D = FENCE.instantiate()
	fill.position = Vector3(x, 0, 0)
	fill.scale = Vector3(1.2 / 5.89, 1.0, 1.0)
	add_child(fill)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 1.1, 0.17)
	col.shape = box
	col.position = Vector3(0, 0.55, 0)
	body.add_child(col)
	fill.add_child(body)


func _add_post(x: float) -> void:
	_add_box(self, Vector3(0.3, POST_H, 0.3), Vector3(x, POST_H / 2.0, 0), WOOD_DARK)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, POST_H, 0.3)
	col.shape = box
	col.position = Vector3(x, POST_H / 2.0, 0)
	body.add_child(col)
	add_child(body)


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)


func interact() -> void:
	if _busy:
		return
	_busy = true
	var tween := create_tween()
	tween.tween_property(_pivot, "rotation:y", PI / 2.0 if not _open else 0.0, 0.9) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(_on_swing_done)


func _on_swing_done() -> void:
	_open = not _open
	_busy = false
	Hud.toast("The gate swings open." if _open else "The gate swings shut.")
