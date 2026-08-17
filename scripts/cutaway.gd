extends Node3D

# Cinematic cutaway v5: paw.glb enters from bottom, slides across the three
# dials (left to right), pauses on each. Label3D shows the entered digits.
# Correct combo: shackle pops, padlock drops, door opens.
# Wrong combo: toast message, padlock stays.
# Letterboxed, CC0 click sound.

const ANCHOR := Vector3(0.0, 0.3525, -0.03)
const PAW_ROT_X := 5.0
const PAW_ROT_Y := 180.0
const PAW_SCALE := 0.35
const HAND_BEND := -15.0
const FUR_COLOR := Color(0.9777, 0.68, 0.3492)
const FUR_ROUGH := 0.5

var _door: Node3D
var _padlock: Node3D
var _dials: Array[MeshInstance3D] = []
var _shackle: MeshInstance3D = null
var _body: MeshInstance3D = null
var _player: Node3D = null
var _player_cam: Camera3D = null
var _cam: Camera3D = null
var _paw: Node3D = null
var _click: AudioStreamPlayer = null
var _pop: AudioStreamPlayer = null
var _bars: Array[ColorRect] = []
var _bar_h := 0.0
var _on_done: Callable = Callable()
var _saved_pos := Vector3.ZERO
var _saved_yaw := 0.0
var _entered_digits: Array[int] = [0, 0, 0]
var _combo_correct := true
var _dial_world_positions: Array[Vector3] = []
var _anchor_offset := Vector3.ZERO


func play_padlock_unlock(door: Node3D, entered_digits: Array[int], correct: bool, on_done: Callable) -> void:
	_on_done = on_done
	_door = door
	_entered_digits = entered_digits
	_combo_correct = correct
	_padlock = door.get("_padlock") as Node3D
	if _padlock == null:
		_finish()
		return
	for c in _padlock.get_children():
		if c.name.begins_with("Dial") and c is MeshInstance3D:
			_dials.append(c as MeshInstance3D)
		elif c.name == "Shackle" and c is MeshInstance3D:
			_shackle = c as MeshInstance3D
		elif c.name == "LockBody" and c is MeshInstance3D:
			_body = c as MeshInstance3D
	_snatch_player()
	_build_camera()
	_build_letterbox()
	_build_audio()
	_build_paw()
	_add_dial_labels()
	_cache_dial_positions()
	GameState.cinematic_active = true
	_sequence()


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


func _build_camera() -> void:
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true
	_cam.fov = 38.0
	var target := _padlock.global_position + Vector3(0.0, 0.02, 0.08)
	_cam.global_position = _padlock.global_position + Vector3(0.05, 0.0, 0.55)
	_cam.look_at(target, Vector3.UP)


func _build_letterbox() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_bar_h = get_viewport().get_visible_rect().size.y * 0.16
	var vp_h := get_viewport().get_visible_rect().size.y
	for i in 2:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0)
		bar.anchor_left = 0.0
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0
		bar.anchor_bottom = 0.0
		if i == 0:
			bar.offset_top = -_bar_h
			bar.offset_bottom = 0.0
		else:
			bar.offset_top = vp_h
			bar.offset_bottom = vp_h + _bar_h
		layer.add_child(bar)
		_bars.append(bar)


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
	_anchor_offset = _paw.to_global(ANCHOR) - _paw.global_position
	_paw.visible = false


func _cache_dial_positions() -> void:
	for dial in _dials:
		_dial_world_positions.append(_padlock.to_global(dial.position))


func _dial_world(dial: Node3D) -> Vector3:
	return _padlock.to_global(dial.position)


func _add_dial_labels() -> void:
	for i in range(_dials.size()):
		var dial := _dials[i]
		var lbl := Label3D.new()
		lbl.text = str(_entered_digits[i])
		lbl.font_size = 28
		lbl.modulate = Color(0.12, 0.12, 0.14)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		var lp := dial.position + Vector3(0.0, 0.0, 0.03)
		lbl.position = lp
		lbl.rotation = dial.rotation
		_padlock.add_child(lbl)


func _ok() -> bool:
	if not is_instance_valid(self):
		return false
	return is_instance_valid(_padlock)


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _paw_target_for_dial(dial_world: Vector3) -> Vector3:
	return dial_world - _anchor_offset


func _sequence() -> void:
	await _animate_bars(true, 0.3)
	if not _ok():
		return
	# camera push-in
	var cam_to := _padlock.global_position + Vector3(0.05, 0.01, 0.45)
	var ct := create_tween()
	ct.tween_property(_cam, "global_position", cam_to, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _wait(0.55)
	if not _ok():
		return
	# paw enters from below dial 0
	_paw.visible = true
	var dial0_target := _paw_target_for_dial(_dial_world_positions[0])
	var off_screen := dial0_target + Vector3(0.0, -0.5, 0.0)
	_paw.global_position = off_screen
	var enter := create_tween()
	enter.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	enter.tween_property(_paw, "global_position", dial0_target, 0.5)
	await enter.finished
	if not _ok():
		return
	_click.play()
	await _wait(0.3)
	if not _ok():
		return
	# slide to dial 1
	var dial1_target := _paw_target_for_dial(_dial_world_positions[1])
	var s1 := create_tween()
	s1.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	s1.tween_property(_paw, "global_position", dial1_target, 0.4)
	await s1.finished
	if not _ok():
		return
	_click.play()
	await _wait(0.3)
	if not _ok():
		return
	# slide to dial 2
	var dial2_target := _paw_target_for_dial(_dial_world_positions[2])
	var s2 := create_tween()
	s2.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	s2.tween_property(_paw, "global_position", dial2_target, 0.4)
	await s2.finished
	if not _ok():
		return
	_click.play()
	await _wait(0.3)
	if not _ok():
		return
	# paw exits below
	var out := _paw.global_position + Vector3(0.0, -0.5, 0.0)
	var po := create_tween()
	po.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	po.tween_property(_paw, "global_position", out, 0.3)
	await po.finished
	if not _ok():
		return
	_paw.visible = false
	# beat of tension, then branch
	await _wait(0.5)
	if not _ok():
		return
	if _combo_correct:
		_pop.play()
		if _shackle != null:
			var sw := create_tween()
			sw.tween_property(_shackle, "rotation:x", PI / 2.0 + 1.8, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			await sw.finished
			if not _ok():
				return
		# padlock tilts, drops, freed
		var dw := create_tween()
		dw.set_parallel(true)
		dw.tween_property(_padlock, "position", _padlock.position + Vector3(0.0, -0.1, 0.05), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		dw.tween_property(_padlock, "rotation:x", _padlock.rotation.x + 0.55, 0.35)
		await dw.finished
		if _ok():
			_click.pitch_scale = 0.45
			_click.play()
			_padlock.queue_free()
			await _wait(0.4)
	else:
		Hud.toast("The padlock stays shut. That wasn't the right combination.")
		await _wait(1.2)
		if not _ok():
			return
	await _animate_bars(false, 0.3)
	_finish()


func _animate_bars(in_out: bool, dur: float) -> void:
	var vp_h := get_viewport().get_visible_rect().size.y
	var targets := [0.0, 0.0, 0.0, 0.0]
	if in_out:
		targets = [0.0, _bar_h, vp_h - _bar_h, vp_h]
	else:
		targets = [-_bar_h, 0.0, vp_h, vp_h + _bar_h]
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_bars[0], "offset_top", targets[0], dur)
	tw.tween_property(_bars[0], "offset_bottom", targets[1], dur)
	tw.tween_property(_bars[1], "offset_top", targets[2], dur)
	tw.tween_property(_bars[1], "offset_bottom", targets[3], dur)
	await tw.finished


func _finish() -> void:
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
