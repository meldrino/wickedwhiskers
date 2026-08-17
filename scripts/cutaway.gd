extends Node3D

# Cinematic cutaway v4: correct combo -> camera pushes in on the shed padlock.
# ONE right paw with REAL finger anatomy (3 fingers + 1 thumb) wraps the dial's
# top edge and TURNS it: the dial and the paw rotate rigidly together around the
# dial axis, so the paw visibly drives the rotation (grip-turn, not hover/wave).
# Left paw steadies the lock body (mirrored, planted, no motion).
# Fur color is sampled from the live WW.glb Paw_L material so a recolor of the
# cat updates the cutaway automatically. Letterboxed, CC0 click sound.

const FALLBACK_FUR := Color(0.976, 0.678, 0.349)  # WW.glb #f9ad59
const FALLBACK_PAD := Color(0.506, 0.435, 0.365)  # WW.glb #816f5d
const FALLBACK_ROUGH := 0.5

const RISE := 0.05      # wrist sits this far above the dial centre
const FRONT := 0.035    # and this far in front of the dial face
const BASE_TILT := 0.28 # rig tilt so digits press the dial face while turning

var _door: Node3D
var _padlock: Node3D
var _dials: Array[MeshInstance3D] = []
var _shackle: MeshInstance3D = null
var _body: MeshInstance3D = null
var _player: Node3D = null
var _player_cam: Camera3D = null
var _cam: Camera3D = null
var _fur_color := FALLBACK_FUR
var _pad_color := FALLBACK_PAD
var _fur_rough := FALLBACK_ROUGH
var _paw_l: Node3D = null
var _paw_r: Node3D = null
var _click: AudioStreamPlayer = null
var _pop: AudioStreamPlayer = null
var _bars: Array[ColorRect] = []
var _bar_h := 0.0
var _on_done: Callable = Callable()
var _saved_pos := Vector3.ZERO
var _saved_yaw := 0.0
var _entered_digits: Array[int] = [0, 0, 0]
var _combo_correct := true


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
	_sample_fur()
	_snatch_player()
	_build_camera()
	_build_letterbox()
	_build_audio()
	_build_paws()
	_add_dial_labels()
	GameState.cinematic_active = true
	_sequence()


func _sample_fur() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var paw := player.find_child("Paw_L", true, false) as MeshInstance3D
	if paw != null and paw.mesh != null and paw.mesh.surface_get_material(0) is StandardMaterial3D:
		var sm := paw.mesh.surface_get_material(0) as StandardMaterial3D
		_fur_color = sm.albedo_color
		_fur_rough = sm.roughness
	var inner := player.find_child("InnerEar_L", true, false) as MeshInstance3D
	if inner != null and inner.mesh != null and inner.mesh.surface_get_material(0) is StandardMaterial3D:
		_pad_color = (inner.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color


# Park the real cat far away so it can never be in the cutaway frame.
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
	_cam.fov = 70.0
	var target := _padlock.global_position + Vector3(0.0, 0.01, 0.0)
	_cam.global_position = _padlock.global_position + Vector3(0.05, 0.07, 0.68)
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


# Align a capsule mesh (axis +Y) along the segment a->b. Works while the parent
# is still outside the tree (look_at_from_position takes absolute/local points).
func _add_segment(parent: Node3D, mat: StandardMaterial3D, a: Vector3, b: Vector3, r: float) -> void:
	var mid := (a + b) * 0.5
	var len := a.distance_to(b)
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = len
	cm.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	parent.add_child(mi)
	mi.look_at_from_position(mid, b, Vector3.UP)
	mi.rotate_object_local(Vector3.RIGHT, PI / 2.0)


# A paw rig: origin at the wrist, arm hanging down-right off-frame, 3 fingers +
# 1 thumb curling DOWN over the dial's front face. Mirror with scale.x = -1.
func _make_paw() -> Node3D:
	var paw := Node3D.new()
	var fur := StandardMaterial3D.new()
	fur.albedo_color = _fur_color
	fur.roughness = _fur_rough
	var pad := StandardMaterial3D.new()
	pad.albedo_color = _pad_color
	pad.roughness = _fur_rough
	# two-segment arm with an elbow, tapering, going down-right off-frame
	_add_segment(paw, fur, Vector3(0.02, -0.01, 0.02), Vector3(0.07, -0.14, 0.05), 0.024)
	_add_segment(paw, fur, Vector3(0.07, -0.14, 0.05), Vector3(0.13, -0.34, 0.08), 0.032)
	# paw body (dorsum)
	var ps := MeshInstance3D.new()
	var pm := SphereMesh.new()
	pm.radius = 0.031
	pm.height = 0.062
	pm.material = fur
	ps.mesh = pm
	ps.scale = Vector3(1.1, 0.85, 1.15)
	ps.position = Vector3(0.005, -0.014, 0.01)
	paw.add_child(ps)
	# 3 fingers curling down over the dial face
	for i in 3:
		var x := -0.02 + i * 0.015
		var base := Vector3(x, -0.004, 0.008)
		var knuckle := base + Vector3(0.0, -0.042, 0.0)
		var tip := knuckle + Vector3(0.0, -0.048, 0.012)
		_add_segment(paw, fur, base, knuckle, 0.0095)
		_add_segment(paw, fur, knuckle, tip, 0.0075)
		var tp := MeshInstance3D.new()
		var tm := SphereMesh.new()
		tm.radius = 0.0075
		tm.height = 0.015
		tm.material = pad
		tp.mesh = tm
		tp.position = tip
		paw.add_child(tp)
	# 1 thumb, offset and slightly shorter, tucked toward the dial centre
	var tb := Vector3(0.022, -0.028, 0.006)
	var tk := tb + Vector3(-0.008, -0.034, 0.004)
	var tt := tk + Vector3(-0.004, -0.03, 0.012)
	_add_segment(paw, fur, tb, tk, 0.0095)
	_add_segment(paw, fur, tk, tt, 0.0075)
	var tp2 := MeshInstance3D.new()
	var tm2 := SphereMesh.new()
	tm2.radius = 0.0075
	tm2.height = 0.015
	tm2.material = pad
	tp2.mesh = tm2
	tp2.position = tt
	paw.add_child(tp2)
	# remember the 4 digit tips for the overlap debug
	var tips := PackedVector3Array()
	for i in 3:
		var x := -0.02 + i * 0.015
		tips.append(Vector3(x, -0.094, 0.020))
	tips.append(Vector3(-0.01, -0.092, 0.022))
	paw.set_meta("tips", tips)
	return paw


func _build_paws() -> void:
	_paw_r = _make_paw()
	_paw_r.name = "PawR"
	add_child(_paw_r)
	_paw_l = _make_paw()
	_paw_l.name = "PawL"
	_paw_l.scale = Vector3(-1.0, 1.0, 1.0)
	add_child(_paw_l)


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


# Grip position of the wrist relative to the dial centre, rotated by theta.
func _grip_offset(theta: float) -> Vector3:
	return Vector3(-RISE * sin(theta), RISE * cos(theta), FRONT)


func _place_paw(paw: Node3D, dial: Node3D, theta: float) -> void:
	var c := _dial_world(dial)
	paw.global_position = c + _grip_offset(theta)
	paw.rotation.z = BASE_TILT + theta


# One held twist: dial and paw orbit together (rigid grip), driving the dial.
func _turn_dial(dial: Node3D, steps: int) -> void:
	var c := _dial_world(dial)
	for s in range(steps):
		var a0 := dial.rotation.z
		var a1 := a0 + 0.38
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(dial, "rotation:z", a1, 0.09)
		tw.tween_method(_grip_at.bind(c), a0, a1, 0.09)
		await tw.finished
		_click.play()
	_debug_fingers(dial)


func _grip_at(theta: float, c: Vector3) -> void:
	_paw_r.global_position = c + _grip_offset(theta)
	_paw_r.rotation.z = BASE_TILT + theta


func _sequence() -> void:
	await _animate_bars(true, 0.3)
	if not _ok():
		return
	var cam_to := _padlock.global_position + Vector3(0.05, 0.08, 0.60)
	var ct := create_tween()
	ct.tween_property(_cam, "global_position", cam_to, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# left paw plants on the lock body and stays absolutely still
	var left_hold := _padlock.to_global(Vector3(-0.10, -0.03, 0.125))
	_paw_l.global_position = left_hold + Vector3(0.0, -0.5, 0.0)
	var pl := create_tween()
	pl.tween_property(_paw_l, "global_position", left_hold, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _wait(0.55)
	if not _ok():
		return
	# right paw enters from below-right, grips the rightmost dial
	_paw_r.global_position = _padlock.to_global(Vector3(0.4, -0.35, 0.05))
	_paw_r.rotation.z = BASE_TILT
	var pr := create_tween()
	pr.tween_property(_paw_r, "global_position", _grip_world(_dials[2], 0.0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await pr.finished
	if not _ok():
		return
	# turn each dial rightmost -> leftmost with a rigid grip-turn
	for i in range(2, -1, -1):
		var dial: Node3D = _dials[i]
		if i < 2:
			# release, lift, slide to the next dial, re-grip
			var lift := _dial_world(dial) + Vector3(0.0, RISE + 0.10, FRONT + 0.05)
			var l1 := create_tween()
			l1.tween_property(_paw_r, "global_position", lift, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			l1.parallel().tween_property(_paw_r, "rotation:z", 0.0, 0.18)
			await l1.finished
			if not _ok():
				return
			await _wait(0.08)
			if not _ok():
				return
			var lower := create_tween()
			lower.tween_property(_paw_r, "global_position", _grip_world(dial, 0.0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			lower.parallel().tween_property(_paw_r, "rotation:z", BASE_TILT, 0.18)
			await lower.finished
			if not _ok():
				return
		await _turn_dial(dial, 3)
		if not _ok():
			return
	# right paw releases and exits below-right
	var out := _padlock.to_global(Vector3(0.42, -0.42, 0.02))
	var po := create_tween()
	po.tween_property(_paw_r, "global_position", out, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await po.finished
	if not _ok():
		return
	# beat of tension, then branch on correct/wrong
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
		# padlock tilts, drops, and is freed
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
		# wrong combo — padlock stays shut
		Hud.toast("The padlock stays shut. That wasn't the right combination.")
		await _wait(1.2)
		if not _ok():
			return
	await _animate_bars(false, 0.3)
	_finish()


func _grip_world(dial: Node3D, theta: float) -> Vector3:
	return _dial_world(dial) + _grip_offset(theta)


# Blind-man's eyes: prove the 4 digit tips are ON the dial in screen space.
func _debug_fingers(dial: Node3D) -> void:
	if _cam == null or not is_instance_valid(_cam) or not is_instance_valid(_paw_r):
		return
	var dial_center: Vector2 = _cam.unproject_position(_dial_world(dial))
	var radius_px: float = _cam.unproject_position(_dial_world(dial) + Vector3(0.05, 0.0, 0.0)).distance_to(dial_center)
	var inside := 0
	var closest := INF
	var tips: PackedVector3Array = _paw_r.get_meta("tips", PackedVector3Array())
	for t in tips:
		var w: Vector3 = _paw_r.to_global(t)
		var d: float = _cam.unproject_position(w).distance_to(dial_center)
		closest = minf(closest, d)
		if d <= radius_px * 1.15:
			inside += 1
	var vp := get_viewport().get_visible_rect().size
	print("CUTAWAY fingers %s: dial_px=%s radius_px=%d tips_within=%d/4 closest_px=%d dial_in_frame=%s" % [
		dial.name, dial_center.round(), int(radius_px), inside, int(closest),
		dial_center.x > 0 and dial_center.x < vp.x and dial_center.y > 0 and dial_center.y < vp.y,
	])


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
