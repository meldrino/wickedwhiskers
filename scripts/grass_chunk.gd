extends Node3D

const CHUNK_SIZE := 5.0
const NEAR_COUNT := 1000000
const MID_COUNT := 250000
const NEAR_RADIUS := 6.0
const BUILD_PER_FRAME := 250000

const DETAILED_MESH := preload("res://assets/grass-stalk.obj")
const SIMPLE_MESH := preload("res://assets/grass-stalk-simple.obj")

var _mm: MultiMeshInstance3D
var _cell := Vector2i.ZERO
var _tier := -1
var _rng := RandomNumberGenerator.new()
var _pending := 0
var _placed := 0
var _new_mm: MultiMesh


func setup(cell: Vector2i, material: ShaderMaterial) -> void:
	_cell = cell
	position = Vector3(cell.x * CHUNK_SIZE, 0.0, cell.y * CHUNK_SIZE)
	_mm = MultiMeshInstance3D.new()
	_mm.material_override = material
	_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mm.custom_aabb = AABB(Vector3(0, -3.0, 0), Vector3(CHUNK_SIZE, 9.0, CHUNK_SIZE))
	add_child(_mm)


func set_tier(tier: int) -> void:
	if tier == _tier:
		return
	_tier = tier
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
	_new_mm.instance_count = _placed
	_mm.multimesh = _new_mm
	_new_mm = null
	_mm.visible = true


func _data_mesh() -> Mesh:
	if _tier == 1:
		return SIMPLE_MESH
	return DETAILED_MESH


func _place_one() -> void:
	var lx := _rng.randf_range(0.0, CHUNK_SIZE)
	var lz := _rng.randf_range(0.0, CHUNK_SIZE)
	var a := _rng.randf_range(0.0, TAU)
	var wx := _cell.x * CHUNK_SIZE + lx
	var wz := _cell.y * CHUNK_SIZE + lz
	var h := Terrain.height_at(wx, wz)
	if GrassExclusion.is_excluded(wx, wz, h):
		return
	var t := Transform3D(Basis(Vector3.UP, a).scaled(Vector3.ONE * 1.001), Vector3(lx, h, lz))
	_new_mm.set_instance_transform(_placed, t)
	_placed += 1


func _rebuild() -> void:
	if _mm == null:
		return
	var count := NEAR_COUNT
	if _tier == 1:
		count = MID_COUNT
	_rng.seed = hash(_cell) ^ 0x5DEECE66D
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _data_mesh()
	mm.instance_count = count
	_new_mm = mm
	_pending = count
	_placed = 0
	if _mm.multimesh == null:
		_mm.visible = false
