class_name VegetationGenerator
extends Node

const VEG_GRASS := {
	"name": "grass",
	"footprint": 0.22,
	"spacing_factor": 0.9,
	"edge": 3.0,
	"slope_max": 1.0,
	"water_allowed": false,
	"outer": 10,
	"inner": 5,
	"min_h": 0.035,
	"max_h": 0.065,
	"base": Color(0.24, 0.42, 0.16),
	"tip": Color(0.55, 0.78, 0.34),
	"scale_min": 0.85,
	"scale_max": 1.25,
	"seed": 4242,
}

const FULL := {
	"x0": -60.0, "z0": -60.0,
	"x1": 60.0, "z1": 60.0,
	"cluster": 1,
}

# Tuning for shaders/grass.gdshader (hexaquo grass series parts 2+3).
# IMPORTANT: our blades are already meter-scaled (~0.035-0.065 m), so bend/wind
# offsets are in meters - the tutorial's values (blade_bend 0.35, wind_strength
# 0.12) assume UNIT-height blades and fling short blades out sideways. Scale
# them to ~40-50% of blade height.
const GRASS_SHADER := {
	"patch_scale": 6.0,
	"size_small": 0.95,
	"size_large": 1.05,
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

var terrain: Node = null
var ground_body: Node = null
var container: Node3D = null
var rng := RandomNumberGenerator.new()


func setup(t: Node, g: Node, c: Node3D) -> void:
	terrain = t
	ground_body = g
	container = c
	_clear_container(container)


func regen() -> void:
	if terrain == null or container == null:
		return
	_clear_container(container)
	_build_species(VEG_GRASS, FULL)


func _clear_container(c: Node3D) -> void:
	for child in c.get_children():
		child.queue_free()


func _make_grass_material(spec: Dictionary) -> ShaderMaterial:
	var s := GRASS_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/grass.gdshader")
	mat.set_shader_parameter("color_small", spec["base"])
	mat.set_shader_parameter("color_large", spec["tip"])
	mat.set_shader_parameter("patch_scale", s["patch_scale"])
	mat.set_shader_parameter("size_small", s["size_small"])
	mat.set_shader_parameter("size_large", s["size_large"])
	mat.set_shader_parameter("blade_bend", s["blade_bend"])
	mat.set_shader_parameter("wind_strength", s["wind_strength"])
	mat.set_shader_parameter("wind_scale", s["wind_scale"])
	mat.set_shader_parameter("wind_ao_affect", s["wind_ao_affect"])
	mat.set_shader_parameter("wind_direction", s["wind_direction"])
	mat.set_shader_parameter("patch_noise", _noise_texture(
		s["patch_noise_seed"], true, FastNoiseLite.TYPE_PERLIN,
		FastNoiseLite.FRACTAL_FBM, s["patch_noise_freq"]))
	mat.set_shader_parameter("wind_noise", _noise_texture(
		s["wind_noise_seed"], false, FastNoiseLite.TYPE_SIMPLEX_SMOOTH,
		FastNoiseLite.FRACTAL_RIDGED, s["wind_noise_freq"]))
	return mat


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


func _build_species(spec: Dictionary, region: Dictionary) -> void:
	var cluster_n: int = region.get("cluster", 1)
	var mesh := _build_cluster_mesh(spec, cluster_n) if cluster_n > 1 else _build_tuft_mesh(spec)
	if mesh == null:
		return
	var mat := _make_grass_material(spec)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	rng.seed = spec["seed"]

	var tuft_spacing: float = spec["footprint"] * spec["spacing_factor"]
	var spacing: float = tuft_spacing * sqrt(float(cluster_n))
	var space := terrain.get_viewport().world_3d.direct_space_state
	var q := PhysicsRayQueryParameters3D.new()
	q.collide_with_bodies = true
	q.collide_with_areas = false
	var h_max: float = terrain.config.rock_start + 0.3
	var slope_max: float = spec["slope_max"]
	var water_allowed: bool = spec["water_allowed"]
	var placed: Array[Transform3D] = []

	var c_h := 0
	var c_slope := 0
	var c_wr := 0
	var c_wl := 0
	var c_nohit := 0
	var c_wrongcol := 0
	var c_yhi := 0
	var c_mismatch := 0
	var min_y := INF
	var max_y := -INF

	var x: float = region["x0"]
	while x <= region["x1"]:
		var z: float = region["z0"]
		while z <= region["z1"]:
			var px := x + rng.randf_range(-spacing * 0.35, spacing * 0.35)
			var pz := z + rng.randf_range(-spacing * 0.35, spacing * 0.35)
			if _spot_ok(px, pz, h_max, slope_max, water_allowed):
				q.from = Vector3(px, 60.0, pz)
				q.to = Vector3(px, -2.0, pz)
				var hit := space.intersect_ray(q)
				if hit.is_empty():
					c_nohit += 1
				elif (hit["collider"] as Node) != ground_body:
					c_wrongcol += 1
				else:
					var y: float = (hit["position"] as Vector3).y
					var hy: float = terrain.height_at(px, pz)
					if absf(y - hy) > 0.1:
						c_mismatch += 1
					if y <= h_max:
						var t := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)), Vector3(px, y - 0.006, pz))
						placed.append(t.scaled(Vector3.ONE * rng.randf_range(spec["scale_min"], spec["scale_max"])))
						min_y = minf(min_y, y)
						max_y = maxf(max_y, y)
					else:
						c_yhi += 1
			else:
				if terrain.height_at(px, pz) > h_max:
					c_h += 1
				elif TerrainGenerator.slope_at(terrain.heights, terrain.config, px, pz) > slope_max:
					c_slope += 1
				elif terrain.water_radius > 0.0 and Vector2(px, pz).distance_to(terrain.lake.center) < terrain.water_radius + 0.05:
					c_wr += 1
				elif terrain.height_at(px, pz) < terrain.water_level + 0.06:
					c_wl += 1
			z += spacing
		x += spacing

	mm.instance_count = placed.size()
	for i in range(placed.size()):
		mm.set_instance_transform(i, placed[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.name = "Grass"
	container.add_child(mmi)
	print("GRASS clusters=%d tufts=%d spacing=%.3f patch=(%.1f..%.1f, %.1f..%.1f)" % [placed.size(), placed.size() * cluster_n, spacing, region["x0"], region["x1"], region["z0"], region["z1"]])
	print("DBG h=%d slope=%d waterR=%d waterL=%d nohit=%d wrongcol=%d yhi=%d mismatch=%d ymin=%.3f ymax=%.3f" % [c_h, c_slope, c_wr, c_wl, c_nohit, c_wrongcol, c_yhi, c_mismatch, min_y, max_y])


func _spot_ok(px: float, pz: float, h_max: float, slope_max: float, water_allowed: bool) -> bool:
	if terrain.height_at(px, pz) > h_max:
		return false
	if TerrainGenerator.slope_at(terrain.heights, terrain.config, px, pz) > slope_max:
		return false
	if not water_allowed:
		if terrain.water_radius > 0.0 and Vector2(px, pz).distance_to(terrain.lake.center) < terrain.water_radius + 0.05:
			return false
		if terrain.height_at(px, pz) < terrain.water_level + 0.06:
			return false
	return true


func _build_tuft_mesh(spec: Dictionary) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = spec["seed"] + 7
	_add_tuft(st, spec, rng2, Vector3.ZERO, 0)
	st.generate_normals()
	return st.commit()


func _build_cluster_mesh(spec: Dictionary, n: int) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = spec["seed"] + 11
	var tuft_spacing: float = spec["footprint"] * spec["spacing_factor"]
	var cols := int(ceil(sqrt(float(n))))
	var rows := int(ceil(float(n) / float(cols)))
	var base_idx := 0
	for i in range(n):
		var col := i % cols
		var row := i / cols
		var ox := (float(col) - float(cols - 1) * 0.5) * tuft_spacing + rng2.randf_range(-0.02, 0.02)
		var oz := (float(row) - float(rows - 1) * 0.5) * tuft_spacing + rng2.randf_range(-0.02, 0.02)
		base_idx = _add_tuft(st, spec, rng2, Vector3(ox, 0.0, oz), base_idx)
	st.generate_normals()
	return st.commit()


func _add_tuft(st: SurfaceTool, spec: Dictionary, rng2: RandomNumberGenerator, origin: Vector3, base_idx: int) -> int:
	var base: Color = spec["base"]
	var tip: Color = spec["tip"]
	var outer: int = spec["outer"]
	# Solid base under the tuft so the lawn reads as fully covered from above;
	# blades on top add the 3D texture. (Sward disc = UV.x 2 marker in the shader.)
	base_idx = _add_sward_disc(st, origin, 0.11, base, base_idx)
	for b in range(outer):
		var len := rng2.randf_range(spec["min_h"], spec["max_h"])
		var ang := b * TAU / outer + rng2.randf_range(-0.35, 0.35)
		var bx := cos(ang) * rng2.randf_range(0.055, 0.115)
		var bz := sin(ang) * rng2.randf_range(0.055, 0.115)
		var w := rng2.randf_range(0.014, 0.019)
		base_idx = _add_blade(st, origin + Vector3(bx, 0.0, bz), w, len, rng2.randf_range(0.6, 0.95), ang, base, tip, base_idx)
	var inner: int = spec["inner"]
	for b in range(inner):
		var len := rng2.randf_range(spec["min_h"] * 0.6, spec["max_h"] * 0.85)
		var ang := rng2.randf_range(0.0, TAU)
		var bx := cos(ang) * rng2.randf_range(0.0, 0.03)
		var bz := sin(ang) * rng2.randf_range(0.0, 0.03)
		base_idx = _add_blade(st, origin + Vector3(bx, 0.0, bz), rng2.randf_range(0.009, 0.013), len, rng2.randf_range(-0.25, 0.25), ang, base, tip, base_idx)
	return base_idx


# A flat fan of triangles under the tuft. Dark vertex colour = undergrowth, and
# UV.x = 2 tells the shader to keep it flat, fully lit and wind-still.
func _add_sward_disc(st: SurfaceTool, o: Vector3, radius: float, color: Color, base_idx: int) -> int:
	var segs := 10
	var dark := color * 0.6
	var center := o + Vector3(0.0, 0.016, 0.0)
	st.set_uv(Vector2(2.0, 1.0))
	st.set_color(dark)
	st.add_vertex(center)
	for i in range(segs + 1):
		var a := float(i) / float(segs) * TAU
		st.set_uv(Vector2(2.0, 1.0))
		st.set_color(dark)
		st.add_vertex(center + Vector3(cos(a) * radius, 0.0, sin(a) * radius))
	for i in range(segs):
		st.add_index(base_idx)
		st.add_index(base_idx + i + 1)
		st.add_index(base_idx + i + 2)
	return base_idx + segs + 2


# A thin ribbon blade (4 vertex rings = 6 triangles, half the old box) so the
# vertex shader can bend it smoothly. UV.y = 1 at the base, 0 at the tip - the
# shader derives its bottom_to_top factor and blade gradient from that.
func _add_blade(st: SurfaceTool, o: Vector3, w: float, h: float, lean: float, yaw: float, base: Color, tip: Color, base_idx: int) -> int:
	var segs := 3
	var half := w * 0.5
	var rot := Basis(Vector3.UP, yaw)
	var count := (segs + 1) * 2
	var verts: Array[Vector3] = []
	verts.resize(count)
	for ring in range(segs + 1):
		var t := float(ring) / float(segs)
		verts[ring * 2] = rot * (o + Vector3(lean * h * t - half, 0.02 + h * t, 0.0))
		verts[ring * 2 + 1] = rot * (o + Vector3(lean * h * t + half, 0.02 + h * t, 0.0))
	for v in range(count):
		var t := float(v / 2) / float(segs)
		st.set_uv(Vector2(0.0, 1.0 - t))
		st.set_color(base.lerp(tip, t))
		st.add_vertex(verts[v])
	for seg in range(segs):
		var a := base_idx + seg * 2
		var b := a + 1
		var c := a + 2
		var d := a + 3
		st.add_index(a)
		st.add_index(c)
		st.add_index(b)
		st.add_index(b)
		st.add_index(c)
		st.add_index(d)
	return base_idx + count
