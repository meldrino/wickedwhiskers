extends Node3D

const CHUNK_SIZE := 5.0
const JITTER := 0.02
const EMBED := -0.002
const BUILD_PER_FRAME := 6000
const PROBE_STEP := 0.07
const COVER_RADIUS := 0.02

# Full-geometry tuft: short blades on top of the terrain, no sward base.
# Blade world height is hard-capped at 2 cm: local blade
# tip = base_off + max_h = 0.016 m, times the shader's size_large 1.15 -> 0.018 m.
const VEG := {
	"outer": 16,
	"inner": 8,
	"min_h": 0.006,
	"max_h": 0.008,
	"base": Color(0.24, 0.42, 0.16),
	"tip": Color(0.55, 0.78, 0.34),
	"disc_radius": 0.125,
	"disc_off": 0.006,
	"base_off": 0.008,
	"seed": 4242,
}

var _mm: MultiMeshInstance3D
var _cell := Vector2i.ZERO
var _size := 1.0
var size_m := 1.0
var _full_mesh: Mesh
var _disc_mesh: Mesh
var _rng := RandomNumberGenerator.new()
var _pending := 0
var _placed := 0
var _probes_x := 0
var _probe_total := 0
var _probe_cursor := 0
var _probe_covered := PackedByteArray()
var _new_mm: MultiMesh


static func build_full_mesh(hscale: float = 1.0) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = VEG["seed"] + 7
	var v: Dictionary = VEG
	if hscale != 1.0:
		v = VEG.duplicate()
		v["min_h"] = VEG["min_h"] * hscale
		v["max_h"] = VEG["max_h"] * hscale
		v["disc_radius"] = VEG["disc_radius"] * sqrt(hscale)
		v["spread"] = sqrt(hscale)
	_add_tuft(st, v, rng2, Vector3.ZERO, 0)
	st.generate_normals()
	return st.commit()


static func build_disc_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_sward_disc(st, Vector3.ZERO, VEG["disc_radius"], VEG["base"], 0, VEG["disc_off"])
	st.generate_normals()
	return st.commit()


func setup(cell: Vector2i, size: float, material: ShaderMaterial, full_mesh: Mesh, disc_mesh: Mesh) -> void:
	_cell = cell
	_size = size
	size_m = size
	_full_mesh = full_mesh
	_disc_mesh = disc_mesh
	position = Vector3(cell.x * CHUNK_SIZE, 0.0, cell.y * CHUNK_SIZE)
	_mm = MultiMeshInstance3D.new()
	_mm.material_override = material
	_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mm.custom_aabb = AABB(Vector3(0, -0.5, 0), Vector3(_size, 1.5, _size))
	add_child(_mm)
	_rebuild()


func _process(_delta: float) -> void:
	if _pending <= 0:
		return
	var budget := BUILD_PER_FRAME
	while _pending > 0 and budget > 0:
		_place_one()
		_pending -= 1
		budget -= 1
	if _pending > 0:
		return
	_new_mm.visible_instance_count = _placed
	_mm.multimesh = _new_mm
	_new_mm = null
	_mm.visible = true


func _rebuild() -> void:
	if _mm == null:
		return
	_rng.seed = hash(_cell) ^ 0x5DEECE66D
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _full_mesh
	_probes_x = int(ceil(CHUNK_SIZE / PROBE_STEP))
	_probe_total = _probes_x * _probes_x
	_probe_covered = PackedByteArray()
	_probe_covered.resize(_probe_total)
	_probe_cursor = 0
	mm.instance_count = _probe_total
	_new_mm = mm
	_pending = _probe_total
	_placed = 0
	if _mm.multimesh == null:
		_mm.visible = false


func _place_one() -> void:
	_place_adaptive()


func _place_adaptive() -> void:
	while _probe_cursor < _probe_total:
		var i := _probe_cursor
		_probe_cursor += 1
		if _probe_covered[i]:
			continue
		var px := i % _probes_x
		var pz := i / _probes_x
		var lx := (px + 0.5) * PROBE_STEP
		var lz := (pz + 0.5) * PROBE_STEP
		var wx := _cell.x * CHUNK_SIZE + lx
		var wz := _cell.y * CHUNK_SIZE + lz
		var h := Terrain.height_at(wx, wz)
		if h > Terrain.config.rock_start + 0.3:
			_probe_covered[i] = 1
			continue
		if GrassExclusion.is_excluded(wx, wz, h):
			_probe_covered[i] = 1
			continue
		var t := Transform3D(Basis(Vector3.UP, _rng.randf_range(0.0, TAU)), Vector3(lx, h + EMBED + _rng.randf_range(-0.002, 0.002), lz))
		_new_mm.set_instance_transform(_placed, t)
		_placed += 1
		_mark_covered(px, pz)
		return


func _mark_covered(px: int, pz: int) -> void:
	var r := int(ceil(COVER_RADIUS / PROBE_STEP))
	var x0 := maxi(0, px - r)
	var x1 := mini(_probes_x - 1, px + r)
	var z0 := maxi(0, pz - r)
	var z1 := mini(_probes_x - 1, pz + r)
	var cr := COVER_RADIUS * COVER_RADIUS
	for z in range(z0, z1 + 1):
		var dz := float(z - pz) * PROBE_STEP
		var dz2 := dz * dz
		var row := z * _probes_x
		for x in range(x0, x1 + 1):
			var dx := float(x - px) * PROBE_STEP
			if dx * dx + dz2 <= cr:
				_probe_covered[row + x] = 1


static func _add_tuft(st: SurfaceTool, v: Dictionary, rng2: RandomNumberGenerator, origin: Vector3, base_idx: int) -> int:
	var base: Color = v["base"]
	var tip: Color = v["tip"]
	var base_off: float = v["base_off"]
	var s: float = v.get("spread", 1.0)
	var outer: int = v["outer"]
	for b in range(outer):
		var len := rng2.randf_range(v["min_h"], v["max_h"])
		var ang := b * TAU / outer + rng2.randf_range(-0.35, 0.35)
		var bx := cos(ang) * rng2.randf_range(0.03, 0.06) * s
		var bz := sin(ang) * rng2.randf_range(0.03, 0.06) * s
		var w := rng2.randf_range(0.007, 0.011) * sqrt(s)
		base_idx = _add_blade(st, origin + Vector3(bx, 0.0, bz), w, len, rng2.randf_range(0.6, 0.95), ang, base, tip, base_idx, base_off)
	var inner: int = v["inner"]
	for b in range(inner):
		var len := rng2.randf_range(v["min_h"] * 0.6, v["max_h"] * 0.85)
		var ang := rng2.randf_range(0.0, TAU)
		var bx := cos(ang) * rng2.randf_range(0.0, 0.02) * s
		var bz := sin(ang) * rng2.randf_range(0.0, 0.02) * s
		base_idx = _add_blade(st, origin + Vector3(bx, 0.0, bz), rng2.randf_range(0.005, 0.007) * sqrt(s), len, rng2.randf_range(-0.25, 0.25), ang, base, tip, base_idx, base_off)
	return base_idx


# A flat fan of triangles under the tuft. 24 segments (smooth circles - the old
# 10 made octagon edges visible up close). Radial vertex shading (darker core,
# brighter rim) plus per-instance Y jitter keeps the lawn from reading as a
# uniform tone; UV.x = 2 tells the shader to keep it flat, fully lit and
# wind-still.
static func _add_sward_disc(st: SurfaceTool, o: Vector3, radius: float, color: Color, base_idx: int, disc_off: float) -> int:
	var segs := 24
	var rim := Color(color.r * 0.78, color.g * 0.78, color.b * 0.78)
	var center_c := Color(color.r * 0.6, color.g * 0.6, color.b * 0.6)
	var center := o + Vector3(0.0, disc_off, 0.0)
	st.set_uv(Vector2(2.0, 1.0))
	st.set_color(center_c)
	st.add_vertex(center)
	for i in range(segs + 1):
		var a := float(i) / float(segs) * TAU
		st.set_uv(Vector2(2.0, 1.0))
		st.set_color(rim)
		st.add_vertex(center + Vector3(cos(a) * radius, 0.0, sin(a) * radius))
	for i in range(segs):
		st.add_index(base_idx)
		st.add_index(base_idx + i + 1)
		st.add_index(base_idx + i + 2)
	return base_idx + segs + 2


# A thin ribbon blade (4 vertex rings = 6 triangles, half the old box) so the
# vertex shader can bend it smoothly. UV.y = 1 at the base, 0 at the tip - the
# shader derives its bottom_to_top factor and blade gradient from that.
static func _add_blade(st: SurfaceTool, o: Vector3, w: float, h: float, lean: float, yaw: float, base: Color, tip: Color, base_idx: int, base_off: float) -> int:
	var segs := 3
	var half := w * 0.5
	var rot := Basis(Vector3.UP, yaw)
	var count := (segs + 1) * 2
	var verts: Array[Vector3] = []
	verts.resize(count)
	for ring in range(segs + 1):
		var t := float(ring) / float(segs)
		var hw := half * (1.0 - 0.6 * t)
		verts[ring * 2] = rot * (o + Vector3(lean * h * t - hw, base_off + h * t, 0.0))
		verts[ring * 2 + 1] = rot * (o + Vector3(lean * h * t + hw, base_off + h * t, 0.0))
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
