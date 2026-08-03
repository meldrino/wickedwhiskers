extends Node3D


func _ready() -> void:
	add_to_group("traps")
	_build_trap()


func _build_trap() -> void:
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.75, 0.18, 0.15)
	var tan := StandardMaterial3D.new()
	tan.albedo_color = Color(0.72, 0.55, 0.35)
	var brown := StandardMaterial3D.new()
	brown.albedo_color = Color(0.4, 0.28, 0.16)
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.55, 0.55, 0.58)

	var bucket := _mesh("cylinder", Vector3(0.3, 0.38, 0.3), red)
	bucket.position = Vector3(0.3, 0.28, 0)
	bucket.rotation = Vector3(0.15, 0.2, 0.5)
	add_child(bucket)

	var plank := _mesh("box", Vector3(0.1, 0.05, 1.3), tan)
	plank.position = Vector3(-0.15, 0.35, 0.15)
	plank.rotation = Vector3(-0.4, 0, 0.25)
	add_child(plank)

	var crate := _mesh("box", Vector3(0.34, 0.34, 0.34), brown)
	crate.position = Vector3(-0.5, 0.17, -0.15)
	add_child(crate)

	var ball := _mesh("sphere", Vector3(0.14, 0.14, 0.14), grey)
	ball.position = Vector3(-0.2, 0.85, 0.28)
	add_child(ball)

	var trigger := _mesh("box", Vector3(0.08, 0.08, 0.5), tan)
	trigger.position = Vector3(0.0, 0.04, 0.5)
	trigger.rotation = Vector3(0, 0.3, 0)
	add_child(trigger)


func _mesh(kind: String, size: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh: Mesh
	match kind:
		"box":
			var bm := BoxMesh.new()
			bm.size = size
			mesh = bm
		"sphere":
			var sm := SphereMesh.new()
			sm.radius = size.x * 0.5
			sm.height = size.y
			mesh = sm
		"cylinder":
			var cm := CylinderMesh.new()
			cm.top_radius = size.x
			cm.bottom_radius = size.x
			cm.height = size.y
			mesh = cm
	mesh.material = mat
	mi.mesh = mesh
	return mi
