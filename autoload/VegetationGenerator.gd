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

const TEST_PATCH := {
	"x0": -27.5, "z0": -27.5,
	"x1": -15.5, "z1": -15.5,
	"cluster": 8,
}

const CORNER_PATCH := {
	"x0": -28.0, "z0": -28.0,
	"x1": -20.0, "z1": -20.0,
	"cells": 24,
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
	_build_grass_plane(CORNER_PATCH)


func _clear_container(c: Node3D) -> void:
	for child in c.get_children():
		child.queue_free()


func _build_grass_plane(region: Dictionary) -> void:
	var x0: float = region["x0"]
	var z0: float = region["z0"]
	var x1: float = region["x1"]
	var z1: float = region["z1"]
	var cells: int = region["cells"]
	var tex: Texture2D = load("res://assets/grass_tex_1x1.png")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := cells + 1
	for iz in range(n):
		var z := z0 + (z1 - z0) * float(iz) / float(cells)
		for ix in range(n):
			var x := x0 + (x1 - x0) * float(ix) / float(cells)
			var y: float = terrain.height_at(x, z)
			st.set_uv(Vector2(x - x0, z - z0))
			st.add_vertex(Vector3(x, y + 0.01, z))
	for iz in range(cells):
		for ix in range(cells):
			var a := iz * n + ix
			var b := a + 1
			var c := a + n
			var d := c + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(b)
			st.add_index(d)
			st.add_index(c)
	st.generate_normals()
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.name = "Grass"
	container.add_child(mi)
	print("GRASS plane %.0fx%.0f m region=(%.0f..%.0f, %.0f..%.0f) cells=%d" % [x1 - x0, z1 - z0, x0, x1, z0, z1, cells])


func _build_species(spec: Dictionary, region: Dictionary) -> void:
	var cluster_n: int = region.get("cluster", 1)
	var mesh := _build_cluster_mesh(spec, cluster_n) if cluster_n > 1 else _build_tuft_mesh(spec)
	if mesh == null:
		return
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
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
	for b in range(outer):
		var len := rng2.randf_range(spec["min_h"], spec["max_h"])
		var ang := b * TAU / outer + rng2.randf_range(-0.35, 0.35)
		var bx := cos(ang) * rng2.randf_range(0.05, 0.1)
		var bz := sin(ang) * rng2.randf_range(0.05, 0.1)
		var w := rng2.randf_range(0.006, 0.01)
		_add_blade(st, origin + Vector3(bx, 0.0, bz), w, len, rng2.randf_range(0.6, 0.95), ang, base, tip, base_idx)
		base_idx += 8
	var inner: int = spec["inner"]
	for b in range(inner):
		var len := rng2.randf_range(spec["min_h"] * 0.6, spec["max_h"] * 0.85)
		var ang := rng2.randf_range(0.0, TAU)
		var bx := cos(ang) * rng2.randf_range(0.0, 0.02)
		var bz := sin(ang) * rng2.randf_range(0.0, 0.02)
		_add_blade(st, origin + Vector3(bx, 0.0, bz), rng2.randf_range(0.004, 0.007), len, rng2.randf_range(-0.25, 0.25), ang, base, tip, base_idx)
		base_idx += 8
	return base_idx


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
