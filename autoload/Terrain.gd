extends Node

const CAT := TerrainConfig.CAT

var config: TerrainConfig
var heights := PackedFloat32Array()
var lake := { "center": Vector2.ZERO, "radius": 0.0, "depth": 0.0 }
var water_level := 0.0
var water_radius := 0.0

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	config = TerrainConfig.flat() if "--bare" in args else TerrainConfig.whiskers()
	heights = TerrainGenerator.generate(config)
	if "--bare" in args or "--flat" in args:
		heights.fill(0.0)
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
			st.set_uv(Vector2(x, z) * 0.25)
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
	mat.albedo_texture = preload("res://assets/grass_ground.png")
	mat.texture_repeat = BaseMaterial3D.TEXTURE_REPEAT_ENABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
