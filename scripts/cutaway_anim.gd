extends Node3D

const FPS := 30
const DURATION := 4.0
const TOTAL_FRAMES := int(FPS * DURATION)

var _padlock: Node3D
var _cam: Camera3D
var _dial_labels: Array[Label3D] = []
var _dial_positions: Array[Vector3] = []
var _paw: Node3D
var _frame := 0
var _save_dir := "res://screenshots/cutaway_anim"

# Paw anchor in local space (same as pawtest_params)
const ANCHOR := Vector3(0.0, 0.3525, -0.03)

# Paw config
const PawRotX := 5.0
const PawRotY := 180.0
const PawScale := 0.35

# Dial world positions (matching _build_padlock)
const DIAL_SPACING := 0.06
const DIAL_Y := -0.005
const DIAL_Z := 0.172
const HAND_BEND := -15.0

# Animation keyframes (time in seconds)
# Paw target positions (world coords where paw anchor sits on dial center)
var _paw_target: Array[Vector3] = []
var _setup_done := false

func _ready() -> void:
	print("CUTAWAY ANIM start")
	set_process(false)
	global_position = Vector3(0.0, 300.0, 0.0)
	for n in get_tree().root.get_children():
		if n == self:
			continue
		if n is Node3D:
			(n as Node3D).visible = false
		elif n is CanvasLayer:
			(n as CanvasLayer).visible = false

	var pf := FileAccess.open("res://screenshots/pawtest_params.json", FileAccess.READ)
	if pf == null:
		push_error("CUTAWAY ANIM no pawtest_params.json")
		get_tree().quit()
		return
	var params: Dictionary = JSON.parse_string(pf.get_as_text())
	pf.close()

	# Calculate dial positions (must be before _build_padlock which uses them)
	for i in range(3):
		var dial_center := Vector3(-DIAL_SPACING + i * DIAL_SPACING, DIAL_Y, DIAL_Z)
		_dial_positions.append(dial_center)

	# Make save dir
	DirAccess.make_dir_recursive_absolute(_save_dir)

	_padlock = _build_padlock()
	_padlock.position = Vector3.ZERO
	add_child(_padlock)

	# Environment
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	var bg: Array = params.get("bg", [0.05, 0.06, 0.09])
	env.background_color = Color(bg[0], bg[1], bg[2])
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.6, 0.55)
	env.ambient_light_energy = 0.18
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Camera (same as static cutaway)
	var co: Array = params.get("cam_offset", [0.0, 0.0, 0.55])
	var lo: Array = params.get("look_at_offset", [0.0, 0.02, 0.08])
	_cam = Camera3D.new()
	_cam.current = true
	_cam.fov = float(params.get("cam_fov", 38.0))
	add_child(_cam)
	_cam.global_position = _padlock.global_position + Vector3(co[0], co[1], co[2])
	_cam.look_at(_padlock.global_position + Vector3(lo[0], lo[1], lo[2]), Vector3.UP)

	# Lights
	var key := DirectionalLight3D.new()
	key.light_energy = float(params.get("key_energy", 0.5))
	key.shadow_enabled = false
	key.rotation_degrees = Vector3(float(params.get("key_pitch_deg", -40.0)), 0.0, 0.0)
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_energy = float(params.get("fill_energy", 0.4))
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	add_child(fill)

	# Load paw model
	var glb: PackedScene = load("res://assets/paw.glb")
	if glb == null:
		push_error("CUTAWAY ANIM failed to load paw.glb")
		get_tree().quit()
		return
	_paw = glb.instantiate()
	_paw.scale = Vector3.ONE * PawScale
	_paw.rotation.x = deg_to_rad(PawRotX)
	_paw.rotation.y = deg_to_rad(PawRotY)
	add_child(_paw)
	await get_tree().process_frame

	# Apply hand bend
	for sk in _paw.find_children("*", "Skeleton3D", true, false):
		var hand_i: int = (sk as Skeleton3D).find_bone("Hand.L")
		if hand_i >= 0:
			var rest_q: Quaternion = (sk as Skeleton3D).get_bone_rest(hand_i).basis.get_rotation_quaternion()
			(sk as Skeleton3D).set_bone_pose_rotation(hand_i, rest_q * Quaternion(Vector3.RIGHT, deg_to_rad(HAND_BEND)))
			await get_tree().process_frame
			break

	# Paint paw orange
	for mi in _paw.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var mat: Material = mi.mesh.surface_get_material(s)
			if mat is StandardMaterial3D:
				var fd: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
				fd.albedo_color = Color(0.9777, 0.68, 0.3492)
				fd.roughness = 0.5
				fd.metallic = 0.0
				mi.set_surface_override_material(s, fd)

	# Calculate the world-space offset from paw origin to anchor
	# This offset depends only on rotation + scale, not position
	_paw.global_position = Vector3.ZERO
	await get_tree().process_frame
	var anchor_offset := _paw.to_global(ANCHOR) - _paw.global_position

	# Paw target positions (where paw origin goes so anchor sits on dial center)
	for i in range(3):
		var dial_world := _padlock.to_global(_dial_positions[i])
		_paw_target.append(dial_world - anchor_offset)

	# Off-screen position (below visible area)
	var off_screen := _paw_target[0] + Vector3(0.0, -0.5, 0.0)

	# Start off-screen
	_paw.global_position = off_screen

	# Animation loop
	_frame = 0
	_setup_done = true
	set_process(true)

func _process(_delta: float) -> void:
	if not _setup_done:
		return
	if _frame >= TOTAL_FRAMES:
		set_process(false)
		print("CUTAWAY ANIM done - " + str(TOTAL_FRAMES) + " frames in " + _save_dir)
		get_tree().quit()
		return

	var t := float(_frame) / float(FPS)  # time in seconds

	# Determine paw position
	var off_screen: Vector3 = _paw_target[0] + Vector3(0.0, -0.5, 0.0)
	var paw_pos: Vector3

	if t < 0.5:
		# Hold: paw off-screen
		paw_pos = off_screen
	elif t < 1.5:
		# Paw enters from bottom to dial 1
		var enter_t := (t - 0.5) / 1.0  # 0..1 over 1 second
		enter_t = _ease_in_out(enter_t)
		paw_pos = off_screen.lerp(_paw_target[0], enter_t)
	elif t < 1.7:
		# Hold on dial 1
		paw_pos = _paw_target[0]
	elif t < 2.3:
		# Slide to dial 2
		var slide_t := (t - 1.7) / 0.6
		slide_t = _ease_in_out(slide_t)
		paw_pos = _paw_target[0].lerp(_paw_target[1], slide_t)
	elif t < 2.5:
		# Hold on dial 2
		paw_pos = _paw_target[1]
	elif t < 3.1:
		# Slide to dial 3
		var slide_t := (t - 2.5) / 0.6
		slide_t = _ease_in_out(slide_t)
		paw_pos = _paw_target[1].lerp(_paw_target[2], slide_t)
	elif t < 3.3:
		# Hold on dial 3
		paw_pos = _paw_target[2]
	else:
		# Final hold
		paw_pos = _paw_target[2]

	_paw.global_position = paw_pos

	# Determine which dials have been switched to "2"
	var digits := ["0", "0", "0"]
	if t >= 1.5:
		digits[0] = "2"
	if t >= 2.3:
		digits[1] = "2"
	if t >= 3.1:
		digits[2] = "2"

	for i in range(3):
		_dial_labels[i].text = digits[i]

	# Render frame
	await get_tree().process_frame

	var img := get_viewport().get_texture().get_image()
	var fname := _save_dir + "/frame_%04d.png" % _frame
	img.save_png(fname)

	_frame += 1

func _ease_in_out(t: float) -> float:
	# Smooth step
	return t * t * (3.0 - 2.0 * t)

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

	var plate := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.13, 0.46, 0.025)
	pm.material = steel
	plate.mesh = pm
	plate.position = Vector3(0, 0, 0.02)
	p.add_child(plate)

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

	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.24, 0.34, 0.12)
	bm.material = brass
	body.mesh = bm
	body.position = Vector3(0, -0.03, 0.10)
	p.add_child(body)

	for i in range(3):
		var dial := MeshInstance3D.new()
		var dm := CylinderMesh.new()
		dm.top_radius = 0.05
		dm.bottom_radius = 0.05
		dm.height = 0.035
		dm.radial_segments = 18
		dm.material = brass_dark
		dial.mesh = dm
		dial.position = _dial_positions[i]
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
		groove.position = Vector3(_dial_positions[i].x, _dial_positions[i].y, _dial_positions[i].z + 0.018)
		groove.rotation = Vector3(PI / 2.0, 0, 0)
		p.add_child(groove)

		var num_label := Label3D.new()
		num_label.text = "0"
		num_label.pixel_size = 0.001
		num_label.font_size = 40
		num_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		num_label.modulate = Color(0.97, 0.96, 0.9)
		num_label.position = Vector3(_dial_positions[i].x, _dial_positions[i].y, _dial_positions[i].z + 0.026)
		p.add_child(num_label)
		_dial_labels.append(num_label)

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
