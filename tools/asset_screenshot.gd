extends Node3D

func _ready() -> void:
	var scene: PackedScene = preload("res://assets/misc/string.glb")
	var inst: Node3D = scene.instantiate()
	inst.position = Vector3(0, 0.15, 0)
	inst.scale = Vector3.ONE * 2.5
	add_child(inst)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.25, 0.4)
	cam.rotation = Vector3(-0.35, 0, 0)
	cam.fov = 30
	add_child(cam)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.3, 0)
	sun.light_energy = 1.5
	sun.light_color = Color(1.0, 0.95, 0.9)
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.3, -2.5, 0)
	fill.light_energy = 0.5
	add_child(fill)

	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 0.3
	floor_mesh.bottom_radius = 0.3
	floor_mesh.height = 0.01
	var floor_mi := MeshInstance3D.new()
	floor_mi.mesh = floor_mesh
	floor_mi.position = Vector3(0, -0.005, 0)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.3, 0.3, 0.32)
	floor_mi.material_override = floor_mat
	add_child(floor_mi)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.18, 0.20)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.4, 0.42)
	env.ambient_light_energy = 0.5
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://screenshots/string_preview.png")
	get_tree().quit()
