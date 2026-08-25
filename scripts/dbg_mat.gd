extends SceneTree

func _init() -> void:
	var glb: PackedScene = load("res://assets/paw.glb")
	var m: Node3D = glb.instantiate()
	root.add_child(m)
	await process_frame
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var mins := {}
			var maxs := {}
			for v in verts:
				var slab := int(round(v.y * 20)) / 20.0
				var key: String = str(slab)
				if not mins.has(key):
					mins[key] = v
					maxs[key] = v
				else:
					var mn: Vector3 = mins[key]
					var mx: Vector3 = maxs[key]
					mn.x = minf(mn.x, v.x); mn.y = minf(mn.y, v.y); mn.z = minf(mn.z, v.z)
					mx.x = maxf(mx.x, v.x); mx.y = maxf(mx.y, v.y); mx.z = maxf(mx.z, v.z)
					mins[key] = mn
					maxs[key] = mx
			print("DBG slab model local (y) -- total verts=", verts.size())
			for key in mins.keys():
				var mn: Vector3 = mins[key]
				var mx: Vector3 = maxs[key]
				print("DBG y~", key, " x:[", roundf(mn.x * 1000.0) / 1000.0, ",", roundf(mx.x * 1000.0) / 1000.0, "] z:[", roundf(mn.z * 1000.0) / 1000.0, ",", roundf(mx.z * 1000.0) / 1000.0, "]")
	quit()
