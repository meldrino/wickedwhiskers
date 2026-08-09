extends Node3D

const CHUNK_SIZE := 5.0
const NEAR_RADIUS := 6.0
const MID_RADIUS := 14.0
const STREAM_RADIUS := 14.0

var _material: ShaderMaterial
var _impostor_material: ShaderMaterial
var _chunks := {}


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = preload("res://scripts/grass_game.gdshader")
	_material.set_shader_parameter("patch_noise", _make_noise(_patch_noise(), true))
	_material.set_shader_parameter("wind_noise", _make_noise(_wind_noise(), true))

	_impostor_material = ShaderMaterial.new()
	_impostor_material.shader = preload("res://scripts/impostor_grass.gdshader")
	_impostor_material.set_shader_parameter("color_small", Color(0.25, 0.55, 0.12))
	_impostor_material.set_shader_parameter("color_large", Color(0.4, 0.65, 0.15))
	_impostor_material.set_shader_parameter("ground_color", Color(0.06, 0.12, 0.04))
	_impostor_material.set_shader_parameter("patch_noise", _make_noise(_patch_noise(), true))
	_impostor_material.set_shader_parameter("patch_scale", 7.0)
	_impostor_material.set_shader_parameter("high_frequency_noise", _make_noise(_high_frequency_noise(), false))
	_impostor_material.set_shader_parameter("baked_normals", preload("res://assets/grass_normals.png"))
	_impostor_material.set_shader_parameter("wind_noise", _make_noise(_wind_noise(), true))
	_impostor_material.set_shader_parameter("wind_strength", 0.04)
	_impostor_material.set_shader_parameter("wind_direction", Vector2(1, 0))
	_impostor_material.set_shader_parameter("wind_bend_strength", 2.0)
	_impostor_material.set_shader_parameter("wind_ao_affect", 1.5)

	var impostor: MeshInstance3D = preload("res://scripts/grass_impostor.gd").new()
	impostor.name = "GrassImpostor"
	impostor.material_override = _impostor_material
	add_child(impostor)


func _patch_noise() -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = 101
	return n


func _wind_noise() -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_gain = 0.45
	n.seed = 202
	return n


func _high_frequency_noise() -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.frequency = 0.1
	return n


func _make_noise(n: FastNoiseLite, seamless: bool) -> NoiseTexture2D:
	var t := NoiseTexture2D.new()
	t.seamless = seamless
	t.noise = n
	return t


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
				var dist := Vector2((cx + 0.5) * CHUNK_SIZE - c.x, (cz + 0.5) * CHUNK_SIZE - c.z).length()
				if dist <= STREAM_RADIUS + CHUNK_SIZE:
					desired["%d,%d" % [cx, cz]] = true
	for key in desired:
		if not _chunks.has(key):
			_spawn(key)
	for key in _chunks.keys():
		if not desired.has(key):
			_chunks[key].queue_free()
			_chunks.erase(key)


func _spawn(key: String) -> void:
	var parts := key.split(",")
	var cell := Vector2i(int(parts[0]), int(parts[1]))
	var chunk: Node3D = preload("res://scripts/grass_chunk.gd").new()
	chunk.name = "Chunk_%s" % key
	add_child(chunk)
	chunk.setup(cell, _material)
	_chunks[key] = chunk


func _update_tiers(centers: Array) -> void:
	for key in _chunks:
		var chunk: Node3D = _chunks[key]
		var cpos := chunk.position + Vector3(CHUNK_SIZE * 0.5, 0, CHUNK_SIZE * 0.5)
		var best := INF
		for c in centers:
			var d := Vector2(c.x - cpos.x, c.z - cpos.z).length()
			best = minf(best, d)
		var tier := 1
		if best <= NEAR_RADIUS:
			tier = 0
		chunk.set_tier(tier)
