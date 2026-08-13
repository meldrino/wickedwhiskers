extends Node3D

var fish: Node3D
var swim_t := 0.0
var _jump := 0.0
var _jump_wait := 0.0
var _jump_dir := Vector3.ZERO

const SWIM_RADIUS := 0.8
const SWIM_SPEED := 1.1
const SUBMERGE := 0.45
const JUMP_WAIT_MIN := 3.5
const JUMP_WAIT_MAX := 6.0
const JUMP_DUR := 1.1
const JUMP_HEIGHT := 2.2
const JUMP_ARC := 0.8


func _ready() -> void:
	fish = _build_fish()
	add_child(fish)
	fish.add_to_group("fish")
	fish.set_meta("school", self)
	_jump_wait = randf_range(JUMP_WAIT_MIN, JUMP_WAIT_MAX)


func taunt(f: Node3D) -> void:
	_jump = 0.05
	_jump_wait = JUMP_WAIT_MAX


func _physics_process(delta: float) -> void:
	swim_t += delta
	var wl := Terrain.water_level

	if _jump > 0.0:
		_jump += delta
		var p := clamp(_jump / JUMP_DUR, 0.0, 1.0)
		var rise := sin(p * PI) * JUMP_HEIGHT
		fish.position = Vector3(_jump_dir.x * p * JUMP_ARC, wl - SUBMERGE + rise, _jump_dir.z * p * JUMP_ARC)
		fish.rotation.y = _jump_dir_angle()
		fish.rotation.z = sin(p * PI) * 0.35
		if _jump >= JUMP_DUR:
			_jump = 0.0
			_jump_wait = randf_range(JUMP_WAIT_MIN, JUMP_WAIT_MAX)
	else:
		_jump_wait -= delta
		if _jump_wait <= 0.0:
			_start_jump()
		var ang := swim_t * SWIM_SPEED
		var cx := cos(ang) * SWIM_RADIUS
		var cz := sin(ang) * SWIM_RADIUS
		var bob := sin(swim_t * 1.6) * 0.08
		fish.position = Vector3(cx, wl - SUBMERGE + bob, cz)
		fish.rotation.y = ang + PI * 0.5
		fish.rotation.z = sin(swim_t * 3.0) * 0.12


func _jump_dir_angle() -> float:
	return atan2(-_jump_dir.z, _jump_dir.x)


func _start_jump() -> void:
	var a := randf_range(0.0, TAU)
	_jump_dir = Vector3(cos(a), 0.0, sin(a))
	_jump = 0.001


func _build_fish() -> Node3D:
	var orange := StandardMaterial3D.new()
	orange.albedo_color = Color(0.98, 0.72, 0.42)
	orange.metallic = 0.25
	orange.roughness = 0.4
	var fin := StandardMaterial3D.new()
	fin.albedo_color = Color(0.9, 0.55, 0.25)
	fin.metallic = 0.15
	fin.roughness = 0.5

	var f := Node3D.new()
	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.42
	sm.material = orange
	body.mesh = sm
	f.add_child(body)

	var tail := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.06, 0.2, 0.2)
	tm.material = fin
	tail.mesh = tm
	tail.position = Vector3(0, 0, -0.24)
	f.add_child(tail)

	var fin_up := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.03, 0.18, 0.16)
	fm.material = fin
	fin_up.mesh = fm
	fin_up.position = Vector3(0, 0.2, 0.02)
	fin_up.rotation.x = -0.3
	f.add_child(fin_up)

	f.scale = Vector3.ONE * 1.15
	return f
