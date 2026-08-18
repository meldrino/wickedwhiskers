extends SceneTree
func _initialize() -> void:
	print("MESHDUMP start")
	var glb := load("res://assets/paw_ai_v4.glb") as PackedScene
	var model := glb.instantiate()
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		print("MESHDUMP name=", m.name, " pos=", m.position, " scale=", m.scale)
		if m.mesh != null:
			var a := m.mesh.get_aabb()
			print("MESHDUMP   aabb_center=", a.get_center(), " size=", a.size)
	var nodes := []
	model.find_nodes_by_filter(func(n): nodes.append(n), true)
	print("MESHDUMP done")
	quit(0)
