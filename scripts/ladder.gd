extends Node3D


func _ready() -> void:
	add_to_group("ladders")
	_build_ladder()


func _build_ladder() -> void:
	var brown := StandardMaterial3D.new()
	brown.albedo_color = Color(0.62, 0.44, 0.24)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.45, 0.32, 0.18)

	for x in [-0.28, 0.28]:
		var rail := _mesh("box", Vector3(0.06, 2.2, 0.06), brown)
		rail.position = Vector3(x, 1.1, 0)
		add_child(rail)

	for i in range(6):
		var y := 0.18 + i * 0.4
		var rung := _mesh("box", Vector3(0.62, 0.04, 0.05), dark)
		rung.position = Vector3(0, y, 0)
		add_child(rung)

	rotation = Vector3(0, 0, 0.06)


func _mesh(kind: String, size: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	return mi
