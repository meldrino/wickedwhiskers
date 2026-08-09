extends MeshInstance3D

const RES := 1.0
const LIFT := 0.01

const CENTER := Vector2(0.0, -6.0)
const HALF_X := 32.0
const HALF_Z := 40.0


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_build()


func _build() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x0 := CENTER.x - HALF_X
	var z0 := CENTER.y - HALF_Z
	var nx := int(HALF_X * 2.0 / RES)
	var nz := int(HALF_Z * 2.0 / RES)
	var wh := Terrain.heights
	var cfg := Terrain.config
	var wl := Terrain.water_level
	var vid := 0
	for iz in range(nz):
		var wz0 := z0 + iz * RES
		for ix in range(nx):
			var wx0 := x0 + ix * RES
			var cwx := wx0 + RES * 0.5
			var cwz := wz0 + RES * 0.5
			var hc := TerrainGenerator.height_at(wh, cfg, cwx, cwz)
			if GrassExclusion.is_excluded(cwx, cwz, hc):
				continue
			var h00 := TerrainGenerator.height_at(wh, cfg, wx0, wz0)
			var h10 := TerrainGenerator.height_at(wh, cfg, wx0 + RES, wz0)
			var h01 := TerrainGenerator.height_at(wh, cfg, wx0, wz0 + RES)
			var h11 := TerrainGenerator.height_at(wh, cfg, wx0 + RES, wz0 + RES)
			if h00 < wl or h10 < wl or h01 < wl or h11 < wl:
				continue
			st.add_vertex(Vector3(wx0, h00 + LIFT, wz0))
			st.add_vertex(Vector3(wx0 + RES, h10 + LIFT, wz0))
			st.add_vertex(Vector3(wx0 + RES, h11 + LIFT, wz0 + RES))
			st.add_vertex(Vector3(wx0, h01 + LIFT, wz0 + RES))
			st.add_index(vid)
			st.add_index(vid + 1)
			st.add_index(vid + 2)
			st.add_index(vid)
			st.add_index(vid + 2)
			st.add_index(vid + 3)
			vid += 4
	st.generate_normals()
	mesh = st.commit()
	custom_aabb = AABB(Vector3(x0, -1.0, z0), Vector3(HALF_X * 2.0, 2.0, HALF_Z * 2.0))
