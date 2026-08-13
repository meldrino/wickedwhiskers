extends Node3D

# Cinematic cutaway: correct combo entered -> camera pushes in on the shed
# padlock, procedural cat paws (sampled from the live WW.glb fur material, so a
# recolor of the cat updates this automatically) turn the three dials, the
# shackle springs open and the padlock drops. Letterboxed, with a CC0 click
# sound. Player input is locked while this plays.

const FALLBACK_FUR := Color(0.976, 0.678, 0.349)  # WW.glb #f9ad59
const FALLBACK_PAD := Color(0.506, 0.435, 0.365)  # WW.glb #816f5d
const FALLBACK_ROUGH := 0.5

var _door: Node3D
var _padlock: Node3D
var _dials: Array[MeshInstance3D] = []
var _shackle: MeshInstance3D = null
var _body: MeshInstance3D = null
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


func play_padlock_unlock(door: Node3D, on_done: Callable) -> void:
	_on_done = on_done
	_door = door
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
	_find_player_cam()
	_build_camera()
	_build_letterbox()
	_build_audio()
	_build_paws()
	GameState.cinematic_active = true
	_sequence()


func _sample_fur() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var paw := player.find_child("Paw_L", true, false) as MeshInstance3D
	if paw == null or paw.mesh == null:
		return
	var mat := paw.mesh.surface_get_material(0)
	if mat is StandardMaterial3D:
		var sm := mat as StandardMaterial3D
		_fur_color = sm.albedo_color
		_fur_rough = sm.roughness
	var inner := player.find_child("InnerEar_L", true, false) as MeshInstance3D
	if inner != null and inner.mesh != null and inner.mesh.surface_get_material(0) is StandardMaterial3D:
		_pad_color = (inner.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color


func _find_player_cam() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		_player_cam = player.find_child("Camera", true, false) as Camera3D


func _build_camera() -> void:
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true
	var target := _padlock.global_position + Vector3(0.0, 0.02, 0.0)
	_cam.global_position = _padlock.global_position + Vector3(0.16, 0.17, 0.92)
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
		# start off-screen so bars slide in
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


func _make_paw() -> Node3D:
	var paw := Node3D.new()
	var fur := StandardMaterial3D.new()
	fur.albedo_color = _fur_color
	fur.roughness = _fur_rough
	var pad := StandardMaterial3D.new()
	pad.albedo_color = _pad_color
	pad.roughness = _fur_rough
	# forearm
	var arm := MeshInstance3D.new()
	var am := CapsuleMesh.new()
	am.radius = 0.035
	am.height = 0.20
	am.material = fur
	arm.mesh = am
	arm.position = Vector3(0, -0.07, 0.02)
	paw.add_child(arm)
	# paw sphere
	var ps := MeshInstance3D.new()
	var pm := SphereMesh.new()
	pm.radius = 0.05
	pm.height = 0.1
	pm.material = fur
	ps.mesh = pm
	ps.scale = Vector3(1.0, 0.72, 1.3)
	ps.position = Vector3(0, 0.04, 0.05)
	paw.add_child(ps)
	# big pad (palm) + 3 toe beans
	var big := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.02
	bm.height = 0.04
	bm.material = pad
	big.mesh = bm
	big.scale = Vector3(1.1, 0.8, 1.0)
	big.position = Vector3(0, 0.03, 0.075)
	paw.add_child(big)
	for i in 3:
		var bean := MeshInstance3D.new()
		var bbm := SphereMesh.new()
		bbm.radius = 0.013
		bbm.height = 0.026
		bbm.material = pad
		bean.mesh = bbm
		bean.scale = Vector3(0.9, 0.7, 0.9)
		bean.position = Vector3(-0.02 + i * 0.02, 0.055, 0.1)
		paw.add_child(bean)
	return paw


func _build_paws() -> void:
	_paw_l = _make_paw()
	_paw_l.name = "PawL"
	add_child(_paw_l)
	_paw_r = _make_paw()
	_paw_r.name = "PawR"
	add_child(_paw_r)


func _ok() -> bool:
	if not is_instance_valid(self):
		return false
	return is_instance_valid(_padlock)


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _sequence() -> void:
	await _animate_bars(true, 0.3)
	if not _ok():
		return
	# push-in on the padlock + left paw steadies the body
	var cam_to := _padlock.global_position + Vector3(0.14, 0.14, 0.74)
	var ct := create_tween()
	ct.tween_property(_cam, "global_position", cam_to, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_paw_l.global_position = _padlock.to_global(Vector3(-0.28, 0.06, 0.24))
	_paw_l.rotation_degrees = Vector3(0, -20, -18)
	var pl := create_tween()
	pl.tween_property(_paw_l, "global_position", _padlock.to_global(Vector3(-0.19, 0.02, 0.15)), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _wait(0.5)
	if not _ok():
		return
	await pl.finished
	if not _ok():
		return
	# right paw spins the dials, rightmost first (sweeps left across the frame)
	for i in range(_dials.size() - 1, -1, -1):
		var dial: Node3D = _dials[i]
		var dpos: Vector3 = _padlock.to_global(dial.position)
		_paw_r.global_position = dpos + Vector3(0.17, 0.07, 0.2)
		var pr := create_tween()
		pr.tween_property(_paw_r, "global_position", dpos + Vector3(0.0, 0.01, 0.095), 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await pr.finished
		if not _ok():
			return
		await _wait(0.12)
		if not _ok():
			return
		await _spin_dial(dial, 3)
		if not _ok():
			return
		var po := create_tween()
		po.tween_property(_paw_r, "global_position", dpos + Vector3(-0.16, 0.13, 0.24), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		await po.finished
		if not _ok():
			return
	# beat of tension, then it pops
	await _wait(0.55)
	if not _ok():
		return
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
	await _animate_bars(false, 0.3)
	_finish()


func _spin_dial(dial: Node3D, steps: int) -> void:
	for s in range(steps):
		var tw := create_tween()
		tw.tween_property(dial, "rotation:z", dial.rotation.z + 0.38, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tw.finished
		_click.play()


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
	if _player_cam != null and is_instance_valid(_player_cam):
		_player_cam.current = true
	GameState.cinematic_active = false
	var cb := _on_done
	_on_done = Callable()
	if cb.is_valid():
		cb.call()
	queue_free()
