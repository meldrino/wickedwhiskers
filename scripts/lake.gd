extends Node3D

const RIPPLE_INTERVAL := 0.5
const RIPPLE_LIFE := 2.0

var water_level := 0.0
var _water: MeshInstance3D = null
var _water_mat: StandardMaterial3D = null
var _surface_r := 0.0
var _swim_t := 0.0
var _ripple_t := 0.0
var _ripples: Array = []
var _ripple_origin := Vector2.ZERO
var _ripple_max_scale := 4.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	var lake := Terrain.lake
	var c: Vector2 = lake.center
	var depth: float = lake.depth
	water_level = Terrain.water_level
	_build_water()
	_build_shore_wall()
	_build_fish()
	var src_dir := Vector2(0.45, -0.89).normalized()
	_ripple_origin = c + src_dir * (_surface_r - 0.7)
	_ripple_max_scale = (_surface_r * 1.1) / 0.6


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
		ring.scale = Vector3.ONE * lerpf(0.35, _ripple_max_scale, k)
		mat.albedo_color.a = r["start_a"] * (1.0 - k)
		if k >= 1.0:
			ring.queue_free()
			_ripples.erase(r)


func _spawn_ripple() -> void:
	_make_ripple(_ripple_origin, 0.4)


func _make_ripple(at: Vector2, start_a: float) -> void:
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
	ring.position = Vector3(at.x, water_level + 0.015, at.y)
	add_child(ring)
	mat.albedo_color.a = start_a
	_ripples.append({"mesh": ring, "mat": mat, "t": 0.0, "life": RIPPLE_LIFE, "start_a": start_a})


func splash(at: Vector3) -> void:
	var pos := Vector2(at.x, at.z)
	_make_ripple(pos, 0.7)
	_make_ripple(pos, 0.6)
	_make_droplets(at)


func _make_droplets(at: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.98, 1.0, 0.95)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var sm := SphereMesh.new()
	sm.radius = 0.045
	sm.height = 0.09
	sm.material = mat
	var p := CPUParticles3D.new()
	p.mesh = sm
	p.one_shot = true
	p.emitting = true
	p.amount = 26
	p.lifetime = 0.85
	p.direction = Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 3.4
	p.gravity = Vector3(0, -10.0, 0)
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.4
	p.position = at
	add_child(p)
	get_tree().create_timer(p.lifetime + 1.0).timeout.connect(p.queue_free)


func _build_shore_wall() -> void:
	var wall := StaticBody3D.new()
	wall.name = "ShoreWall"
	wall.collision_layer = 1
	wall.collision_mask = 1
	var n := 48
	var segs: Array[Vector2] = []
	for i in range(n):
		var ang := i * TAU / n
		var dir := Vector2(cos(ang), sin(ang))
		var r := Terrain.shore_distance(dir)
		segs.append(dir * r)
	for i in range(n):
		var a := segs[i]
		var b := segs[(i + 1) % n]
		var mid := (a + b) * 0.5
		var len := a.distance_to(b)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.4, 4.0, len + 0.2)
		cs.shape = box
		cs.position = Vector3(mid.x, water_level + 0.2, mid.y)
		cs.rotation = Vector3(0, -atan2(b.x - a.x, b.y - a.y), 0)
		wall.add_child(cs)
	add_child(wall)


func _build_fish() -> void:
	var f: Node3D = preload("res://scripts/fish.gd").new()
	f.name = "Fish"
	add_child(f)
