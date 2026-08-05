extends Node3D

const RIPPLE_INTERVAL := 1.3
const RIM := 1.4 * Terrain.CAT

var water_level := 0.0
var _water: MeshInstance3D = null
var _water_mat: StandardMaterial3D = null
var _surface_r := 0.0
var _swim_t := 0.0
var _ripple_t := 0.0
var _ripples: Array = []
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	var lake := Terrain.lake
	var c: Vector2 = lake.center
	var depth: float = lake.depth
	water_level = Terrain.height_at(c.x, c.y) + depth - RIM
	_build_water()


func _water_radius() -> float:
	var lake := Terrain.lake
	var c: Vector2 = lake.center
	var radius: float = lake.radius
	var r_max := 0.0
	for a in range(8):
		var ang := a * TAU / 8.0
		var dir := Vector2(cos(ang), sin(ang))
		var r := 0.25
		while r < radius + 3.0:
			var p: Vector2 = c + dir * r
			if Terrain.height_at(p.x, p.y) >= water_level:
				break
			r += 0.25
		r_max = maxf(r_max, r)
	return r_max + 0.5


func _build_water() -> void:
	_water_mat = StandardMaterial3D.new()
	_water_mat.albedo_color = Color(0.32, 0.6, 0.8)
	_water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water_mat.albedo_color.a = 0.6
	_water_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	_water_mat.metallic = 0.1
	_water_mat.roughness = 0.08
	_water_mat.normal_scale = 0.15
	var nt := NoiseTexture2D.new()
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.09
	noise.seed = 1337
	nt.noise = noise
	nt.as_normal_map = true
	nt.width = 256
	nt.height = 256
	_water_mat.normal_map = nt
	_water_mat.refraction_enabled = true
	_water_mat.refraction_texture = nt
	_water_mat.refraction_scale = 0.07

	_water = MeshInstance3D.new()
	var wm := CylinderMesh.new()
	_surface_r = _water_radius()
	wm.top_radius = _surface_r
	wm.bottom_radius = _surface_r
	wm.height = 0.07
	wm.material = _water_mat
	_water.mesh = wm
	_water.position = Vector3(0, water_level, 0)
	add_child(_water)


func _physics_process(delta: float) -> void:
	_swim_t += delta

	# Gentle heave + the normal-map pattern drifting = rolling wave shimmer.
	if _water != null:
		_water.position.y = water_level + sin(_swim_t * 1.1) * 0.01
	if _water_mat != null:
		_water_mat.uv1_offset = Vector3(_swim_t * 0.04, _swim_t * 0.026, 0)

	# Expanding, fading ripples dotting the surface.
	_ripple_t -= delta
	if _ripple_t <= 0.0:
		_ripple_t = RIPPLE_INTERVAL
		_spawn_ripple()
	for r in _ripples:
		var life: float = r["life"]
		r["t"] += delta
		var k: float = r["t"] / life
		var ring: MeshInstance3D = r["mesh"]
		var mat: StandardMaterial3D = r["mat"]
		ring.scale = Vector3.ONE * (1.0 + k * 3.2)
		mat.albedo_color.a = r["start_a"] * (1.0 - k)
		if k >= 1.0:
			ring.queue_free()
			_ripples.erase(r)


func _spawn_ripple() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.97, 1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var tm := TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.5
	tm.rings = 8
	tm.ring_segments = 48
	tm.material = mat
	var ring := MeshInstance3D.new()
	ring.mesh = tm
	var a := rng.randf_range(0, TAU)
	var rad := rng.randf_range(0.5, maxf(_surface_r - 0.5, 0.5))
	ring.position = Vector3(cos(a) * rad, water_level + 0.015, sin(a) * rad)
	add_child(ring)
	mat.albedo_color.a = 0.45
	_ripples.append({"mesh": ring, "mat": mat, "t": 0.0, "life": 2.4, "start_a": 0.45})
