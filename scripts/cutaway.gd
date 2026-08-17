extends Node3D

# Cinematic cutaway v6: builds its own isolated scene (own padlock, environment,
# camera, paw.glb) exactly like cutaway_anim.gd, but plays live instead of
# rendering to files. Shows the player's entered digits on the dials.

const ANCHOR := Vector3(0.0, 0.3525, -0.03)
const PAW_ROT_X := 5.0
const PAW_ROT_Y := 180.0
const PAW_SCALE := 0.35
const HAND_BEND := -15.0
const FUR_COLOR := Color(0.9777, 0.68, 0.3492)
const FUR_ROUGH := 0.5
const DIAL_SPACING := 0.06
const DIAL_Y := -0.005
const DIAL_Z := 0.172
const DURATION := 4.0
const BG_COLOR := Color(0.05, 0.06, 0.09)

var _cam: Camera3D
var _paw: Node3D
var _dial_labels: Array[Label3D] = []
var _dial_positions: Array[Vector3] = []
var _paw_targets: Array[Vector3] = []
var _padlock: Node3D
var _shackle: MeshInstance3D = null
var _time := 0.0
var _playing := false
var _entered_digits: Array[int] = [0, 0, 0]
var _combo_correct := true
var _on_done: Callable = Callable()
var _player: Node3D = null
var _player_cam: Camera3D = null
var _saved_pos := Vector3.ZERO
var _saved_yaw := 0.0
var _click: AudioStreamPlayer
var _pop: AudioStreamPlayer


func play_padlock_unlock(door: Node3D, entered_digits: Array[int], correct: bool, on_done: Callable) -> void:
	_entered_digits = entered_digits
	_combo_correct = correct
	_on_done = on_done
	_snatch_player()
	# Calculate dial positions
	for i in range(3):
		_dial_positions.append(Vector3(-DIAL_SPACING + i * DIAL_SPACING, DIAL_Y, DIAL_Z))
	_build_padlock()
	_build_environment()
	_build_camera()
	_build_lights()
	_build_audio()
	add_child(_padlock)
	await _build_paw()
	_calculate_targets()
	_build_dial_labels()
	GameState.cinematic_active = true
	_time = 0.0
	_playing = true
	set_process(true)


func _snatch_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return
	_saved_pos = _player.global_position
	_saved_yaw = _player.get("yaw") as float
	_player.set("velocity", Vector3.ZERO)
	_player.global_position = Vector3(0.0, 0.6, 20.0)


func _restore_player() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_player.set("velocity", Vector3.ZERO)
	_player.global_position = _saved_pos
	_player.set("yaw", _saved_yaw)


func _find_player_cam() -> void:
	if _player != null:
		_player_cam = _player.find_child("Camera", true, false) as Camera3D


func _build_padlock() -> void:
	_padlock = Node3D.new()
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
	_padlock.add_child(plate)

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
	_padlock.add_child(staple)

	var shackle := MeshInstance3D.new()
	shackle.name = "Shackle"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.045
	torus.outer_radius = 0.07
	torus.rings = 20
	torus.ring_segments = 10
	torus.material = brass_dark
	shackle.mesh = torus
	shackle.position = Vector3(0, 0.215, 0.10)
	shackle.rotation = Vector3(PI / 2.0, 0, 0)
	_padlock.add_child(shackle)
	_shackle = shackle

	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.24, 0.34, 0.12)
	bm.material = brass
	body.mesh = bm
	body.position = Vector3(0, -0.03, 0.10)
	_padlock.add_child(body)

	for i in range(3):
		var dial := MeshInstance3D.new()
		dial.name = "Dial%d" % i
		var dm := CylinderMesh.new()
		dm.top_radius = 0.05
		dm.bottom_radius = 0.05
		dm.height = 0.035
		dm.radial_segments = 18
		dm.material = brass_dark
		dial.mesh = dm
		dial.position = _dial_positions[i]
		dial.rotation = Vector3(PI / 2.0, 0, 0)
		_padlock.add_child(dial)
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
		_padlock.add_child(groove)

	var kp := MeshInstance3D.new()
	var kpm := CylinderMesh.new()
	kpm.top_radius = 0.04
	kpm.bottom_radius = 0.04
	kpm.height = 0.01
	kpm.radial_segments = 16
	kp.mesh = kpm
	kp.position = Vector3(0, -0.14, 0.172)
	kp.rotation = Vector3(PI / 2.0, 0, 0)
	_padlock.add_child(kp)
	var hole := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.014
	hm.bottom_radius = 0.014
	hm.height = 0.02
	hm.radial_segments = 10
	hole.mesh = hm
	hole.position = Vector3(0, -0.14, 0.21)
	hole.rotation = Vector3(PI / 2.0, 0, 0)
	_padlock.add_child(hole)

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
	_padlock.add_child(jamb)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.6, 0.55)
	env.ambient_light_energy = 0.18
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _build_camera() -> void:
	_cam = Camera3D.new()
	_cam.current = true
	_cam.fov = 38.0
	add_child(_cam)
	_cam.global_position = _padlock.global_position + Vector3(0.05, 0.0, 0.55)
	_cam.look_at(_padlock.global_position + Vector3(0.0, 0.02, 0.08), Vector3.UP)


func _build_lights() -> void:
	var key := DirectionalLight3D.new()
	key.light_energy = 0.5
	key.shadow_enabled = false
	key.rotation_degrees = Vector3(-40.0, 0.0, 0.0)
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.4
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	add_child(fill)


func _build_audio() -> void:
	_click = AudioStreamPlayer.new()
	_click.stream = load("res://assets/sounds/click1.wav")
	add_child(_click)
	_pop = AudioStreamPlayer.new()
	_pop.stream = load("res://assets/sounds/click2.wav")
	_pop.pitch_scale = 0.65
	add_child(_pop)


func _build_paw() -> void:
	var glb: PackedScene = load("res://assets/paw.glb")
	if glb == null:
		push_error("CUTAWAY failed to load paw.glb")
		return
	_paw = glb.instantiate()
	_paw.scale = Vector3.ONE * PAW_SCALE
	_paw.rotation.x = deg_to_rad(PAW_ROT_X)
	_paw.rotation.y = deg_to_rad(PAW_ROT_Y)
	add_child(_paw)
	await get_tree().process_frame
	for sk in _paw.find_children("*", "Skeleton3D", true, false):
		var hand_i: int = (sk as Skeleton3D).find_bone("Hand.L")
		if hand_i >= 0:
			var rest_q: Quaternion = (sk as Skeleton3D).get_bone_rest(hand_i).basis.get_rotation_quaternion()
			(sk as Skeleton3D).set_bone_pose_rotation(hand_i, rest_q * Quaternion(Vector3.RIGHT, deg_to_rad(HAND_BEND)))
			await get_tree().process_frame
			break
	for mi in _paw.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var mat: Material = mi.mesh.surface_get_material(s)
			if mat is StandardMaterial3D:
				var fd: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
				fd.albedo_color = FUR_COLOR
				fd.roughness = FUR_ROUGH
				fd.metallic = 0.0
				mi.set_surface_override_material(s, fd)
	_paw.global_position = Vector3.ZERO
	await get_tree().process_frame
	var anchor_offset := _paw.to_global(ANCHOR) - _paw.global_position
	_paw.visible = false


func _calculate_targets() -> void:
	_paw.global_position = Vector3.ZERO
	await get_tree().process_frame
	var anchor_offset := _paw.to_global(ANCHOR) - _paw.global_position
	for i in range(3):
		var dial_world := _padlock.to_global(_dial_positions[i])
		_paw_targets.append(dial_world - anchor_offset)


func _build_dial_labels() -> void:
	for i in range(3):
		var lbl := Label3D.new()
		lbl.text = str(_entered_digits[i])
		lbl.pixel_size = 0.001
		lbl.font_size = 40
		lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		lbl.modulate = Color(0.12, 0.12, 0.14)
		lbl.position = Vector3(_dial_positions[i].x, _dial_positions[i].y, _dial_positions[i].z + 0.026)
		_padlock.add_child(lbl)
		_dial_labels.append(lbl)


func _process(delta: float) -> void:
	if not _playing:
		return
	_time += delta
	var t := _time
	# Animate labels: digits appear as paw passes each dial
	for i in range(3):
		var appear_time := 1.5 + i * 0.8
		if t >= appear_time:
			_dial_labels[i].modulate = Color(0.97, 0.96, 0.9)
		else:
			_dial_labels[i].modulate = Color(0.12, 0.12, 0.14)
	# Animate paw position
	var off_screen := _paw_targets[0] + Vector3(0.0, -0.5, 0.0)
	var paw_pos: Vector3
	if t < 0.5:
		paw_pos = off_screen
	elif t < 1.5:
		var enter_t := _ease_in_out((t - 0.5) / 1.0)
		paw_pos = off_screen.lerp(_paw_targets[0], enter_t)
	elif t < 1.7:
		paw_pos = _paw_targets[0]
	elif t < 2.3:
		var slide_t := _ease_in_out((t - 1.7) / 0.6)
		paw_pos = _paw_targets[0].lerp(_paw_targets[1], slide_t)
	elif t < 2.5:
		paw_pos = _paw_targets[1]
	elif t < 3.1:
		var slide_t := _ease_in_out((t - 2.5) / 0.6)
		paw_pos = _paw_targets[1].lerp(_paw_targets[2], slide_t)
	else:
		paw_pos = _paw_targets[2]
	if t >= 1.5:
		_paw.visible = true
		_paw.global_position = paw_pos
	# Click on each dial arrival
	if t >= 1.5 and t < 1.52:
		_click.play()
	if t >= 2.3 and t < 2.32:
		_click.play()
	if t >= 3.1 and t < 3.12:
		_click.play()
	# End of animation
	if t >= DURATION:
		_playing = false
		set_process(false)
		_finish_animation()


func _ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


func _finish_animation() -> void:
	_paw.visible = false
	if _combo_correct:
		_pop.play()
		if _shackle != null:
			var sw := create_tween()
			sw.tween_property(_shackle, "rotation:x", PI / 2.0 + 1.8, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			await sw.finished
		var dw := create_tween()
		dw.set_parallel(true)
		dw.tween_property(_padlock, "position", _padlock.position + Vector3(0.0, -0.1, 0.05), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		dw.tween_property(_padlock, "rotation:x", _padlock.rotation.x + 0.55, 0.35)
		await dw.finished
		_click.pitch_scale = 0.45
		_click.play()
		await get_tree().create_timer(0.4).timeout
	else:
		Hud.toast("The padlock stays shut. That wasn't the right combination.")
		await get_tree().create_timer(1.2).timeout
	_cleanup()


func _cleanup() -> void:
	_restore_player()
	_find_player_cam()
	if _player_cam != null and is_instance_valid(_player_cam):
		_player_cam.current = true
	GameState.cinematic_active = false
	var cb := _on_done
	_on_done = Callable()
	if cb.is_valid():
		cb.call()
	queue_free()
