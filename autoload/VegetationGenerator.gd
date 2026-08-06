class_name VegetationGenerator
extends Node

const VEG_GRASS := {
	"name": "grass",
	"footprint": 0.22,
	"spacing_factor": 0.9,
	"edge": 3.0,
	"slope_max": 1.0,
	"water_allowed": false,
	"outer": 6,
	"inner": 3,
	"min_h": 0.022,
	"max_h": 0.052,
	"base": Color(0.22, 0.35, 0.12),
	"tip": Color(0.52, 0.72, 0.34),
	"scale_min": 0.85,
	"scale_max": 1.25,
	"seed": 4242,
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
	_build_species(VEG_GRASS)


func _clear_container(c: Node3D) -> void:
	for child in c.get_children():
		child.queue_free()


func _build_species(spec: Dictionary) -> void:
	var mesh := _build_tuft_mesh(spec)
	if mesh == null:
		return
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	rng.seed = spec["seed"]

	var spacing: float = spec["footprint"] * spec["spacing_factor"]
	var lo := -terrain.config.extent + spec["edge"]
	var hi := terrain.config.extent - spec["edge"]
	var space := terrain.get_viewport().world_3d.direct_space_state
	var q := PhysicsRayQueryParameters3D.new()
	q.collide_with_bodies = true
	q.collide_with_areas = false
	var h_max: float = terrain.config.rock_start + 0.3
	var slope_max: float = spec["slope_max"]
	var water_allowed: bool = spec["water_allowed"]
	var placed: Array[Transform3D] = []

	var x := lo
	while x <= hi:
		var z := lo
		while z <= hi:
			var px := x + rng.randf_range(-spacing * 0.35, spacing * 0.35)
			var pz := z + rng.randf_range(-spacing * 0.35, spacing * 0.35)
			if _spot_ok(px, pz, h_max, slope_max, water_allowed):
				q.from = Vector3(px, 60.0, pz)
				q.to = Vector3(px, -2.0, pz)
				var hit := space.intersect_ray(q)
				if not hit.is_empty() and (hit["collider"] as Node) == ground_body:
					var y: float = (hit["position"] as Vector3).y
					if y <= h_max:
						var t := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)), Vector3(px, y - 0.006, pz))
						placed.append(t.scaled(Vector3.ONE * rng.randf_range(spec["scale_min"], spec["scale_max"])))
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
	mmi.name = "Grass"
	container.add_child(mmi)


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
	var base: Color = spec["base"]
	var tip: Color = spec["tip"]
	var base_idx := 0
	var outer: int = spec["outer"]
	for b in range(outer):
		var len := rng2.randf_range(spec["min_h"], spec["max_h"])
		var ang := b * TAU / outer + rng2.randf_range(-0.35, 0.35)
		var bx := cos(ang) * rng2.randf_range(0.05, 0.1)
		var bz := sin(ang) * rng2.randf_range(0.05, 0.1)
		var w := rng2.randf_range(0.006, 0.01)
		_add_blade(st, Vector3(bx, 0.0, bz), w, len, rng2.randf_range(0.6, 0.95), ang, base, tip, base_idx)
		base_idx += 8
	var inner: int = spec["inner"]
	for b in range(inner):
		var len := rng2.randf_range(spec["min_h"] * 0.6, spec["max_h"] * 0.85)
		var ang := rng2.randf_range(0.0, TAU)
		var bx := cos(ang) * rng2.randf_range(0.0, 0.02)
		var bz := sin(ang) * rng2.randf_range(0.0, 0.02)
		_add_blade(st, Vector3(bx, 0.0, bz), rng2.randf_range(0.004, 0.007), len, rng2.randf_range(-0.25, 0.25), ang, base, tip, base_idx)
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
