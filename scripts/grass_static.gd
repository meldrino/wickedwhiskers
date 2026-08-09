extends MultiMeshInstance3D

const MESH := preload("res://assets/grass-stalk-simple.obj")

@export var center := Vector2(0.0, -6.0)
@export var half_x := 32.0
@export var half_z := 40.0
@export var density := 36.0

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_build()


func _build() -> void:
	rng.seed = 20260809
	var total := int(half_x * 2.0 * half_z * 2.0 * density)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = MESH
	mm.instance_count = total
	var placed := 0
	for i in total:
		var wx := center.x + rng.randf_range(-half_x, half_x)
		var wz := center.y + rng.randf_range(-half_z, half_z)
		var h := Terrain.height_at(wx, wz)
		if GrassExclusion.is_excluded(wx, wz, h):
			continue
		var a := rng.randf_range(0.0, TAU)
		var t := Transform3D(Basis(Vector3.UP, a).scaled(Vector3.ONE * 1.001), Vector3(wx, h, wz))
		mm.set_instance_transform(placed, t)
		placed += 1
	mm.instance_count = placed
	multimesh = mm
	custom_aabb = AABB(Vector3(center.x - half_x, -3.0, center.y - half_z), Vector3(half_x * 2.0, 9.0, half_z * 2.0))
