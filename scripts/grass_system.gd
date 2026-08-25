extends Node3D

const CHUNK_SIZE := 5.0
const FENCE_HALF := 25.0
const STREAM_RADIUS := 92.0
const TERRAIN_CELLS := 12

# Restored 026850c GRASS_SHADER params (bend/wind offsets are meters - the
# blades are only ~1-2 cm, so the tutorial's unit-height values would fling
# them out sideways).
const PARAMS := {
	"patch_scale": 6.0,
	"size_small": 1.0,
	"size_large": 1.15,
	"blade_bend": 0.02,
	"wind_strength": 0.01,
	"wind_scale": 9.0,
	"wind_ao_affect": 0.35,
	"wind_direction": Vector2(0.7, -0.5),
	"patch_noise_seed": 2027,
	"patch_noise_freq": 0.22,
	"wind_noise_seed": 31337,
	"wind_noise_freq": 0.6,
}

var _material: ShaderMaterial
var _full_mesh: Mesh
var _disc_mesh: Mesh
var _chunks := {}


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/grass.gdshader")
	_material.set_shader_parameter("color_small", Color(0.24, 0.42, 0.16))
	_material.set_shader_parameter("color_large", Color(0.55, 0.78, 0.34))
	_material.set_shader_parameter("patch_scale", PARAMS["patch_scale"])
	_material.set_shader_parameter("size_small", PARAMS["size_small"])
	_material.set_shader_parameter("size_large", PARAMS["size_large"])
	_material.set_shader_parameter("blade_bend", PARAMS["blade_bend"])
	_material.set_shader_parameter("wind_strength", PARAMS["wind_strength"])
	_material.set_shader_parameter("wind_scale", PARAMS["wind_scale"])
	_material.set_shader_parameter("wind_ao_affect", PARAMS["wind_ao_affect"])
	_material.set_shader_parameter("wind_direction", PARAMS["wind_direction"])
	_material.set_shader_parameter("patch_noise", _noise_texture(
		PARAMS["patch_noise_seed"], true, FastNoiseLite.TYPE_PERLIN,
		FastNoiseLite.FRACTAL_FBM, PARAMS["patch_noise_freq"]))
	_material.set_shader_parameter("wind_noise", _noise_texture(
		PARAMS["wind_noise_seed"], false, FastNoiseLite.TYPE_SIMPLEX_SMOOTH,
		FastNoiseLite.FRACTAL_RIDGED, PARAMS["wind_noise_freq"]))
	var chunk_script: GDScript = preload("res://scripts/grass_chunk.gd")
	var hscale := 1.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hscale="):
			hscale = float(a.get_slice("=", 1))
	_full_mesh = chunk_script.build_full_mesh(hscale)
	_disc_mesh = chunk_script.build_disc_mesh()


func _noise_texture(seed_n: int, seamless: bool, type_i: int, fractal: int, freq: float) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.seed = seed_n
	n.noise_type = type_i
	n.frequency = freq
	n.fractal_type = fractal
	n.fractal_octaves = 3
	n.fractal_gain = 0.5
	var tex := NoiseTexture2D.new()
	tex.noise = n
	tex.seamless = seamless
	tex.width = 256
	tex.height = 256
	return tex


func _process(_delta: float) -> void:
	var centers := _centers()
	_update_chunks(centers)
	_update_tiers(centers)


func _centers() -> Array:
	var out: Array = []
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		out.append(cam.global_position)
	var mouse := get_node_or_null("../Mouse")
	if mouse != null and is_instance_valid(mouse):
		out.append(mouse.global_position)
	return out


func _update_chunks(centers: Array) -> void:
	var desired := {}
	var r := int(ceil(STREAM_RADIUS / CHUNK_SIZE)) + 1
	for c in centers:
		var ccx := int(floor(c.x / CHUNK_SIZE))
		var ccz := int(floor(c.z / CHUNK_SIZE))
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				var cx := ccx + dx
				var cz := ccz + dz
				if cx < -TERRAIN_CELLS or cx > TERRAIN_CELLS - 1:
					continue
				if cz < -TERRAIN_CELLS or cz > TERRAIN_CELLS - 1:
					continue
				# No grass outside the farm: only chunks whose center is inside
				# the 50x50 fence (kills all tier-1 discs; outside = bare terrain).
				var chunk_cx := (cx + 0.5) * CHUNK_SIZE
				var chunk_cz := (cz + 0.5) * CHUNK_SIZE
				if absf(chunk_cx) > FENCE_HALF or absf(chunk_cz) > FENCE_HALF:
					continue
				var dist := Vector2((cx + 0.5) * CHUNK_SIZE - c.x, (cz + 0.5) * CHUNK_SIZE - c.z).length()
				if dist <= STREAM_RADIUS + CHUNK_SIZE:
					desired["%d,%d" % [cx, cz]] = true
	var cam: Vector3 = centers[0] if centers.size() > 0 else Vector3.ZERO
	var missing: Array[String] = []
	for key in desired:
		if not _chunks.has(key):
			missing.append(key)
	missing.sort_custom(func(a: String, b: String) -> bool:
		return _key_dist(a, cam) < _key_dist(b, cam))
	for key in missing:
		_spawn(key)
	for key in _chunks.keys():
		if not desired.has(key):
			_chunks[key].queue_free()
			_chunks.erase(key)


func _key_dist(key: String, cam: Vector3) -> float:
	var parts := key.split(",")
	var cx := int(parts[0])
	var cz := int(parts[1])
	return Vector2((cx + 0.5) * CHUNK_SIZE - cam.x, (cz + 0.5) * CHUNK_SIZE - cam.z).length()


func _spawn(key: String) -> void:
	var parts := key.split(",")
	var cell := Vector2i(int(parts[0]), int(parts[1]))
	var chunk: Node3D = preload("res://scripts/grass_chunk.gd").new()
	chunk.name = "Chunk_%s" % key
	add_child(chunk)
	chunk.setup(cell, CHUNK_SIZE, _material, _full_mesh, _full_mesh, _disc_mesh)
	_chunks[key] = chunk


func _update_tiers(_centers: Array) -> void:
	for key in _chunks:
		var chunk: Node3D = _chunks[key]
		var cpos := chunk.position + Vector3(CHUNK_SIZE * 0.5, 0, CHUNK_SIZE * 0.5)
		var tier := 1
		if absf(cpos.x) <= FENCE_HALF and absf(cpos.z) <= FENCE_HALF:
			tier = 0
		chunk.set_tier(tier)



