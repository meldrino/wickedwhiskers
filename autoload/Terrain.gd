extends Node

const CAT := TerrainConfig.CAT

var config: TerrainConfig
var heights := PackedFloat32Array()
var lake := { "center": Vector2.ZERO, "radius": 0.0, "depth": 0.0 }
var water_level := 0.0
var water_radius := 0.0


func _ready() -> void:
	config = TerrainConfig.whiskers()
	heights = TerrainGenerator.generate(config)
	if not config.lakes.is_empty():
		lake = config.lakes[0]
		water_level = height_at(lake.center.x, lake.center.y) + lake.depth - 1.4 * CAT
		water_radius = _compute_water_radius()
	_build_world()


func height_at(x: float, z: float) -> float:
	return TerrainGenerator.height_at(heights, config, x, z)


func shore_distance(dir: Vector2) -> float:
	var c: Vector2 = lake.center
	var r := 0.25
	while r < lake.radius + 4.0:
		var p: Vector2 = c + dir * r
		if height_at(p.x, p.y) >= water_level:
			break
		r += 0.25
	return r


# Radius of the rendered water disc (mirrors lake.gd _water_radius(): the point
# where terrain crosses water level, plus the 0.5 m bank the mesh overshoots).
func _compute_water_radius() -> float:
	var c: Vector2 = lake.center
	var r_max := 0.0
	for a in range(8):
		var ang := a * TAU / 8.0
		var dir := Vector2(cos(ang), sin(ang))
		var r := 0.25
		while r < lake.radius + 3.0:
			var p: Vector2 = c + dir * r
			if height_at(p.x, p.y) >= water_level:
				break
			r += 0.25
		r_max = maxf(r_max, r)
	return r_max + 0.5


func in_water(x: float, z: float) -> bool:
	var c: Vector2 = lake.center
	var d := Vector2(x - c.x, z - c.y)
	if d.length() > lake.radius + 2.0:
		return false
	return height_at(x, z) < water_level


func _build_world() -> void:
	var size := config.size
	var cell := config.extent * 2.0 / float(size - 1)
	var colors := TerrainGenerator.generate_colors(heights, config)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in range(size):
		var z := -config.extent + iz * cell
		for ix in range(size):
			var x := -config.extent + ix * cell
			st.set_color(colors[iz * size + ix])
			st.add_vertex(Vector3(x, heights[iz * size + ix], z))
	for iz in range(size - 1):
		for ix in range(size - 1):
			var a := iz * size + ix
			var b := a + 1
			var c := a + size
			var d := c + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(b)
			st.add_index(d)
			st.add_index(c)
	st.generate_normals()
	var mesh := st.commit()

	var ground := StaticBody3D.new()
	ground.name = "Terrain"
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = "Mesh"
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
	mi.material_override = mat
	ground.add_child(mi)

	var col := CollisionShape3D.new()
	var hs := HeightMapShape3D.new()
	hs.map_width = size
	hs.map_depth = size
	hs.map_data = heights
	col.shape = hs
	ground.add_child(col)

	add_child(ground)
	_build_grass()


func _build_grass() -> void:
	var tuft := _build_tuft_mesh()
	if tuft == null:
		return
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = tuft
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260809
	var placed: Array[Transform3D] = []
	var spacing := config.grass_spacing
	var lo := -config.extent + 3.0
	var hi := config.extent - 3.0
	var x := lo
	while x <= hi:
		var z := lo
		while z <= hi:
			var px := x + rng.randf_range(-spacing * 0.4, spacing * 0.4)
			var pz := z + rng.randf_range(-spacing * 0.4, spacing * 0.4)
			if _grass_ok(px, pz):
				var y := height_at(px, pz)
				var t := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)), Vector3(px, y - 0.006, pz))
				placed.append(t.scaled(Vector3.ONE * rng.randf_range(0.85, 1.25)))
			z += spacing
		x += spacing
	mm.instance_count = placed.size()
	print("GRASS tufts=%d" % placed.size())
	for i in range(placed.size()):
		mm.set_instance_transform(i, placed[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _grass_ok(px: float, pz: float) -> bool:
	var fr := maxf(absf(px), absf(pz))
	if fr > config.extent - 4.0:
		return false
	if height_at(px, pz) > config.rock_start + 0.3:
		return false
	if TerrainGenerator.slope_at(heights, config, px, pz) > 1.0:
		return false
	# Nothing inside the rendered water disc (kills the grass-in-the-pond ring).
	if water_radius > 0.0 and Vector2(px, pz).distance_to(lake.center) < water_radius + 0.05:
		return false
	if height_at(px, pz) < water_level + 0.06:
		return false
	return true


func _build_tuft_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var base := Color(0.22, 0.35, 0.12)
	var tip := Color(0.52, 0.72, 0.34)
	var base_idx := 0
	# Outer ring of blades fanning outward so each clump blankets the ground.
	var outer := config.grass_outer_blades
	for b in range(outer):
		var len := rng.randf_range(config.grass_min_h, config.grass_max_h)
		var ang := b * TAU / outer + rng.randf_range(-0.35, 0.35)
		var bx := cos(ang) * rng.randf_range(0.05, 0.1)
		var bz := sin(ang) * rng.randf_range(0.05, 0.1)
		var w := rng.randf_range(0.006, 0.01)
		_add_blade(st, Vector3(bx, 0.0, bz), w, len, rng.randf_range(0.6, 0.95), ang, base, tip, base_idx)
		base_idx += 8
	# A few upright inner blades for density at the clump's heart.
	for b in range(config.grass_inner_blades):
		var len := rng.randf_range(config.grass_min_h * 0.6, config.grass_max_h * 0.85)
		var ang := rng.randf_range(0.0, TAU)
		var bx := cos(ang) * rng.randf_range(0.0, 0.02)
		var bz := sin(ang) * rng.randf_range(0.0, 0.02)
		_add_blade(st, Vector3(bx, 0.0, bz), rng.randf_range(0.004, 0.007), len, rng.randf_range(-0.25, 0.25), ang, base, tip, base_idx)
		base_idx += 8
	st.generate_normals()
	return st.commit()


func _add_blade(st: SurfaceTool, o: Vector3, w: float, h: float, lean: float, yaw: float, base: Color, tip: Color, base_idx: int) -> void:
	var half := Vector3(w * 0.5, 0.0, w * 0.4)
	var apex := o + Vector3(lean * h, h, 0.0)
	var pts := [
		o + Vector3(-half.x, 0.0, -half.z), o + Vector3(half.x, 0.0, -half.z),
		o + Vector3(half.x, 0.0, half.z), o + Vector3(-half.x, 0.0, half.z),
		apex + Vector3(-half.x, 0.0, -half.z), apex + Vector3(half.x, 0.0, -half.z),
		apex + Vector3(half.x, 0.0, half.z), apex + Vector3(-half.x, 0.0, half.z),
	]
	var rot := Basis(Vector3.UP, yaw)
	for v in range(8):
		pts[v] = rot * pts[v]
	for v in range(8):
		st.set_color(base.lerp(tip, 1.0 if v >= 4 else 0.0))
		st.add_vertex(pts[v])
	var quads := [
		[0, 1, 2, 3], [4, 5, 6, 7],
		[0, 1, 5, 4], [2, 3, 7, 6],
		[1, 2, 6, 5], [3, 0, 4, 7],
	]
	for q in quads:
		st.add_index(base_idx + q[0])
		st.add_index(base_idx + q[1])
		st.add_index(base_idx + q[2])
		st.add_index(base_idx + q[0])
		st.add_index(base_idx + q[2])
		st.add_index(base_idx + q[3])
