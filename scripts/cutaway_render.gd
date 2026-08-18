extends SceneTree

func _init() -> void:
	var root := Node3D.new()
	root.name = "CutawayRoot"
	get_root().add_child(root)

	# Build padlock (copied from door.gd)
	var padlock := _build_padlock()
	root.add_child(padlock)
	padlock.position = Vector3.ZERO

	# Load and place paw
	var glb: PackedScene = load("res://assets/paw.glb")
	var model: Node3D = glb.instantiate()
	model.scale = Vector3.ONE * 0.55
	model.rotation.x = deg_to_rad(90.0)  # back of hand faces UP (+Y)
	model.rotation.y = deg_to_rad(0.0)
	model.rotation.z = deg_to_rad(0.0)
	root.add_child(model)
	await process_frame

	# Orange color override
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m != null:
			for s in m.get_surface_count():
				var mat: Material = m.surface_get_material(s)
				if mat is StandardMaterial3D:
					(mat as StandardMaterial3D).albedo_color = Color(0.9777, 0.68, 0.3492)
					(mat as StandardMaterial3D).roughness = 0.9

	# Place paw: anchor the palm (model local y ~0.35, z ~0.12) on the dial center
	# At rot_x=+90: local (0, 0.35, 0.12) -> world (0, -0.12, 0.35)
	# Dial at padlock-local (0, -0.005, 0.172)
	var anchor_local := Vector3(0.0, 0.35, 0.12)
	var anchor_world := model.global_transform * anchor_local
	var dial_world := padlock.to_global(Vector3(0.0, -0.005, 0.172))
	model.global_position += dial_world - anchor_world
	await process_frame

	# Camera: cutaway position - looking at the padlock dials from the front
	var cam := Camera3D.new()
	cam.current = true
	cam.fov = 42.0
	cam.global_position = padlock.global_position + Vector3(0.0, 0.02, 0.45)
	cam.look_at(padlock.global_position, Vector3.UP)
	root.add_child(cam)

	# Lights
	var key := DirectionalLight3D.new()
	key.light_energy = 0.7
	key.shadow_enabled = false
	key.rotation_degrees = Vector3(-30.0, 0.0, 0.0)
	root.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.3
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	root.add_child(fill)

	# Environment: dark bg
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.6, 0.55)
	env.ambient_light_energy = 0.18
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	# Render
	await process_frame
	await process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://screenshots/paw_cutaway_back_up.png")
	print("CUTAWAY saved res://screenshots/paw_cutaway_back_up.png")
	quit()

func _build_padlock() -> Node3D:
	var p := Node3D.new()
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.95, 0.75, 0.15)
	brass.metallic = 0.7
	brass.roughness = 0.28
	var brass_dark := StandardMaterial3D.new()
	brass_dark.albedo_color = Color(0.85, 0.65, 0.1)
	brass_dark.metallic = 0.7
	brass_dark.roughness = 0.32
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.55, 0.58, 0.62)
	steel.metallic = 0.8
	steel.roughness = 0.35
	var blk := StandardMaterial3D.new()
	blk.albedo_color = Color(0.12, 0.12, 0.14)
	blk.metallic = 0.4
	blk.roughness = 0.5

	# mounting plate
	var plate := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.13, 0.46, 0.025)
	pm.material = steel
	plate.mesh = pm
	plate.position = Vector3(0, 0, 0.02)
	p.add_child(plate)

	# door staple
	var staple := MeshInstance3D.new()
	var sm := TorusMesh.new()
	sm.inner_radius = 0.035
	sm.outer_radius = 0.055
	sm.rings = 12
	sm.ring_segments = 8
	sm.material = steel
	staple.mesh = sm
	staple.position = Vector3(0, 0.185, 0.055)
	staple.rotation = Vector3(PI / 2.0, 0, 0)
	p.add_child(staple)

	# shackle
	var shackle := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.045
	torus.outer_radius = 0.07
	torus.rings = 20
	torus.ring_segments = 10
	torus.material = brass_dark
	shackle.mesh = torus
	shackle.position = Vector3(0, 0.215, 0.10)
	shackle.rotation = Vector3(PI / 2.0, 0, 0)
	p.add_child(shackle)

	# lock body
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.24, 0.34, 0.12)
	bm.material = brass
	body.mesh = bm
	body.position = Vector3(0, -0.03, 0.10)
	p.add_child(body)

	# three dials
	for i in range(3):
		var dial := MeshInstance3D.new()
		var dm := CylinderMesh.new()
		dm.top_radius = 0.05
		dm.bottom_radius = 0.05
		dm.height = 0.035
		dm.radial_segments = 18
		dm.material = brass_dark
		dial.mesh = dm
		dial.position = Vector3(-0.06 + i * 0.06, -0.005, 0.172)
		dial.rotation = Vector3(PI / 2.0, 0, 0)
		p.add_child(dial)
		var groove := MeshInstance3D.new()
		var gm := CylinderMesh.new()
		gm.top_radius = 0.047
		gm.bottom_radius = 0.047
		gm.height = 0.012
		gm.radial_segments = 12
		gm.material = blk
		groove.mesh = gm
		groove.position = Vector3(-0.06 + i * 0.06, -0.005, 0.19)
		groove.rotation = Vector3(PI / 2.0, 0, 0)
		p.add_child(groove)

	# keyhole
	var kp := MeshInstance3D.new()
	var kpm := CylinderMesh.new()
	kpm.top_radius = 0.04
	kpm.bottom_radius = 0.04
	kpm.height = 0.01
	kpm.radial_segments = 16
	kp.mesh = kpm
	kp.position = Vector3(0, -0.14, 0.172)
	kp.rotation = Vector3(PI / 2.0, 0, 0)
	p.add_child(kp)
	var hole := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.014
	hm.bottom_radius = 0.014
	hm.height = 0.02
	hm.radial_segments = 10
	hole.mesh = hm
	hole.position = Vector3(0, -0.14, 0.21)
	hole.rotation = Vector3(PI / 2.0, 0, 0)
	p.add_child(hole)

	# jamb staple
	var jamb := MeshInstance3D.new()
	var jm := TorusMesh.new()
	jm.inner_radius = 0.035
	jm.outer_radius = 0.055
	jm.rings = 12
	jm.ring_segments = 8
	jm.material = steel
	jamb.mesh = jm
	jamb.position = Vector3(0.15, 0.0, 0.06)
	jamb.rotation = Vector3(PI / 2.0, 0, 0)
	p.add_child(jamb)

	return p
