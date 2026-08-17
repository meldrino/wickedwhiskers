extends Node3D

# Cinematic cutaway: plays the pre-rendered frame sequence from
# screenshots/cutaway_anim/ as a fullscreen overlay.
# Correct combo: after playback, shackle pops (via game logic).
# Wrong combo: toast message.

const FRAME_DIR := "res://screenshots/cutaway_anim"
const TOTAL_FRAMES := 120
const FPS := 30.0

var _door: Node3D
var _padlock: Node3D
var _on_done: Callable = Callable()
var _player: Node3D = null
var _player_cam: Camera3D = null
var _saved_pos := Vector3.ZERO
var _saved_yaw := 0.0
var _entered_digits: Array[int] = [0, 0, 0]
var _combo_correct := true
var _tex_rect: TextureRect
var _layer: CanvasLayer
var _frame := 0
var _timer := 0.0
var _frames: Array[ImageTexture] = []
var _playing := false


func play_padlock_unlock(door: Node3D, entered_digits: Array[int], correct: bool, on_done: Callable) -> void:
	_on_done = on_done
	_door = door
	_entered_digits = entered_digits
	_combo_correct = correct
	_padlock = door.get("_padlock") as Node3D
	_snatch_player()
	_load_frames()
	_build_overlay()
	GameState.cinematic_active = true
	_playing = true
	set_process(true)


func _load_frames() -> void:
	for i in TOTAL_FRAMES:
		var path := FRAME_DIR + "/frame_%04d.png" % i
		var tex: Texture2D = load(path)
		if tex != null:
			_frames.append(tex as ImageTexture)
		else:
			push_error("CUTAWAY missing frame: " + path)


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


func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)
	_tex_rect = TextureRect.new()
	_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tex_rect.anchor_right = 1.0
	_tex_rect.anchor_bottom = 1.0
	_tex_rect.offset_right = 0.0
	_tex_rect.offset_bottom = 0.0
	_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_tex_rect)
	if _frames.size() > 0:
		_tex_rect.texture = _frames[0]


func _process(delta: float) -> void:
	if not _playing:
		return
	_timer += delta
	var target_frame := int(_timer * FPS)
	if target_frame >= _frames.size():
		target_frame = _frames.size() - 1
	if target_frame != _frame:
		_frame = target_frame
		if _frame < _frames.size():
			_tex_rect.texture = _frames[_frame]
	if _timer * FPS >= float(TOTAL_FRAMES):
		_playing = false
		set_process(false)
		_finish_cutaway()


func _finish_cutaway() -> void:
	if _layer != null:
		_layer.queue_free()
	_layer = null
	_tex_rect = null
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
