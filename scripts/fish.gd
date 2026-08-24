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
const GRAV := 9.8
const JUMP_V_H := 2.4
const JUMP_V_V_MIN := 4.6
const JUMP_V_V_MAX := 6.0

var _jump_origin := Vector3.ZERO
var _jump_head := Vector3.ZERO
var _jump_v_v := 0.0
var _jump_airtime := 0.0


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
		var t: float = min(_jump, _jump_airtime)
		var vy: float = _jump_v_v - GRAV * t
		fish.position = _jump_origin + _jump_head * (JUMP_V_H * t) \
				+ Vector3(0.0, _jump_v_v * t - 0.5 * GRAV * t * t, 0.0)
		fish.rotation.y = atan2(_jump_head.x, _jump_head.z)
		fish.rotation.x = -atan2(vy, JUMP_V_H)
		fish.rotation.z = 0.0
		if _jump >= _jump_airtime:
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
		fish.rotation.y = -ang
		fish.rotation.x = 0.0
		fish.rotation.z = sin(swim_t * 3.0) * 0.12


func _start_jump() -> void:
	var ang := swim_t * SWIM_SPEED
	_jump_head = Vector3(-sin(ang), 0.0, cos(ang)).normalized()
	_jump_origin = fish.position
	_jump_v_v = randf_range(JUMP_V_V_MIN, JUMP_V_V_MAX)
	_jump_airtime = 2.0 * _jump_v_v / GRAV
	_jump_dir = Vector3.ZERO
	_jump = 0.001


const FISH_GLB := "res://assets/fish/goldfish_v3.glb"


func _build_fish() -> Node3D:
	var packed: PackedScene = load(FISH_GLB)
	if packed != null:
		var f := Node3D.new()
		var model: Node3D = packed.instantiate()
		model.rotation_degrees.y = 90.0
		model.scale = Vector3.ONE * 0.65
		f.add_child(model)
		return f
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
