extends Node

const CAT := TerrainConfig.CAT

var config: TerrainConfig
var heights := PackedFloat32Array()
var lake := { "center": Vector2.ZERO, "radius": 0.0, "depth": 0.0 }


func _ready() -> void:
	config = TerrainConfig.whiskers()
	heights = TerrainGenerator.generate(config)
	if not config.lakes.is_empty():
		lake = config.lakes[0]
	_build_world()


func height_at(x: float, z: float) -> float:
	return TerrainGenerator.height_at(heights, config, x, z)


func _build_world() -> void:
	var size := config.size
	var cell := config.extent * 2.0 / float(size - 1)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in range(size):
		var z := -config.extent + iz * cell
		for ix in range(size):
			var x := -config.extent + ix * cell
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
	mat.albedo_color = Color(0.42, 0.62, 0.3)
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
