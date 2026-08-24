extends Node3D

# Fishing-rod cutaway: same SubViewport architecture as cutaway.gd (lock).
# Beat 1 (first craft only): paw lashes string around a stick -> pops into rod_v3.
# Beat 2: cast swing, line arcs to pond, bobber, ripples, bite, fish lands in paw.
# on_done fires after restore; game effects stay in player.gd.

const DURATION := 6.2
const PAW_SCALE := 0.35
const HAND_BEND := -25.0
const ARM_POS := Vector3(0.26, -0.34, 0.30)
const ROD_SCALE := 0.55
const WATER_Y := -0.55
const BOBBER := Vector3(-0.28, WATER_Y + 0.02, 0.12)
const FISH_HOLD := Vector3(0.22, -0.24, 0.24)

var _viewport: SubViewport
var _canvas: CanvasLayer
var _cam: Camera3D
var _arm: Node3D
var _paw: Node3D
var _stick: Node3D
var _wraps: Array[MeshInstance3D] = []
var _rod: Node3D = null
var _rod_tip: Marker3D = null
var _line_pivot: Node3D
var _line_mesh: MeshInstance3D
var _bobber: MeshInstance3D
var _ripples: Array[MeshInstance3D] = []
var _water: MeshInstance3D
var _fish: Node3D = null
var _time := 0.0
var _playing := false
var _first_craft := true
var _on_done: Callable = Callable()
var _click: AudioStreamPlayer
var _pop: AudioStreamPlayer
var _speed := 1.0


func play_rod_catch(first_craft: bool, on_done: Callable) -> void:
	_first_craft = first_craft
	_on_done = on_done
	if DisplayServer.get_name() == "headless":
		_speed = 10.0
	_snatch_player()
	_setup_viewport()
	_build_environment()
	_build_props()
	_build_camera()
	_build_lights()
	_build_audio()
	await _build_paw()
	if not _first_craft:
		_skip_craft()
	GameState.cinematic_active = true
	_time = 0.0
	_playing = true
	set_process(true)


func _snatch_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	player.set("velocity", Vector3.ZERO)
	player.global_position = Vector3(0.0, 0.6, 20.0)


func _restore_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		return
	player.set("velocity", Vector3.ZERO)


func _setup_viewport() -> void:
	var screen_size := get_viewport().get_visible_rect().size
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.size = screen_size
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_canvas = CanvasLayer.new()
	_canvas.layer = 100
	add_child(_canvas)
	var tex_rect := TextureRect.new()
	tex_rect.texture = _viewport.get_texture()
	tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.add_child(tex_rect)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.23, 0.27)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.68, 0.62)
	env.ambient_light_energy = 0.22
	var we := WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)


func _build_camera() -> void:
	_cam = Camera3D.new()
	_cam.current = true
	_cam.fov = 40.0
	_viewport.add_child(_cam)
	_cam.global_position = Vector3(0.06, -0.12, 0.88)
	_cam.look_at(Vector3(0.0, -0.26, 0.05), Vector3.UP)


func _build_lights() -> void:
	var key := DirectionalLight3D.new()
	key.light_energy = 0.55
	key.shadow_enabled = false
	key.rotation_degrees = Vector3(-42.0, -18.0, 0.0)
	_viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.35
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(6.0, 155.0, 0.0)
	_viewport.add_child(fill)


func _build_audio() -> void:
	_click = AudioStreamPlayer.new()
	_click.stream = load("res://assets/sounds/click1.wav")
	add_child(_click)
	_pop = AudioStreamPlayer.new()
	_pop.stream = load("res://assets/sounds/click2.wav")
	add_child(_pop)


func _mat(c: Color, rough := 0.7, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _build_props() -> void:
	_water = MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = 1.1
	wm.bottom_radius = 1.1
	wm.height = 0.02
	wm.radial_segments = 64
	wm.material = _mat(Color(0.16, 0.36, 0.44), 0.15, 0.2)
	_water.mesh = wm
	_water.position = Vector3(0, WATER_Y, -0.15)
	_viewport.add_child(_water)

	_arm = Node3D.new()
	_arm.position = ARM_POS
	_arm.rotation_degrees = Vector3(0, 0, 18)
	_viewport.add_child(_arm)

	_stick = Node3D.new()
	var shaft := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.008
	sm.bottom_radius = 0.014
	sm.height = 0.30
	sm.radial_segments = 10
	sm.material = _mat(Color(0.42, 0.29, 0.16))
	shaft.mesh = sm
	shaft.position = Vector3(0, 0.15, 0)
	_stick.add_child(shaft)
	for i in range(3):
		var wrap := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.010
		tm.outer_radius = 0.017
		tm.rings = 12
		tm.ring_segments = 6
		tm.material = _mat(Color(0.93, 0.90, 0.78), 0.9)
		wrap.mesh = tm
		wrap.position = Vector3(0, 0.255 + i * 0.018, 0)
		wrap.visible = false
		_stick.add_child(wrap)
		_wraps.append(wrap)
	_arm.add_child(_stick)

	_line_pivot = Node3D.new()
	_line_pivot.visible = false
	_viewport.add_child(_line_pivot)
	_line_mesh = MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 0.0025
	lm.bottom_radius = 0.0025
	lm.height = 1.0
	lm.radial_segments = 6
	lm.material = _mat(Color(0.95, 0.97, 0.95), 0.6)
	_line_mesh.mesh = lm
	_line_mesh.rotation.x = PI / 2.0
	_line_pivot.add_child(_line_mesh)

	_bobber = MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.02
	bm.height = 0.04
	bm.radial_segments = 12
	bm.rings = 8
	bm.material = _mat(Color(0.85, 0.2, 0.16), 0.4)
	_bobber.mesh = bm
	_bobber.visible = false
	_viewport.add_child(_bobber)

	for i in range(2):
		var rp := MeshInstance3D.new()
		var rm := TorusMesh.new()
		rm.inner_radius = 0.075
		rm.outer_radius = 0.085
		rm.rings = 32
		rm.ring_segments = 6
		rm.material = _mat(Color(0.75, 0.92, 0.95, 0.0), 0.4)
		rm.material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rp.mesh = rm
		rp.position = BOBBER + Vector3(0, 0.01, 0)
		rp.visible = false
		_viewport.add_child(rp)
		_ripples.append(rp)


func _tip_world() -> Vector3:
	if _rod_tip != null and _rod.is_inside_tree():
		return _rod_tip.global_position
	return _arm.to_global(Vector3(0, 0.30, 0))


func _stretch_line(a: Vector3, b: Vector3) -> void:
	_line_pivot.global_position = a
	var d := a.distance_to(b)
	if d > 0.001:
		_line_pivot.look_at(b, Vector3.UP)
	_line_mesh.scale = Vector3(1, d, 1)


func _build_paw() -> void:
	var glb: PackedScene = load("res://assets/paw.glb")
	_paw = glb.instantiate()
	_paw.scale = Vector3.ONE * PAW_SCALE
	_paw.rotation_degrees = Vector3(-70.0, 180.0, 10.0)
	_paw.position = Vector3(0.015, -0.03, 0)
	_arm.add_child(_paw)
	await get_tree().process_frame
	for sk in _paw.find_children("*", "Skeleton3D", true, false):
		var hand_i: int = (sk as Skeleton3D).find_bone("Hand.L")
		if hand_i >= 0:
			var rest_q: Quaternion = (sk as Skeleton3D).get_bone_rest(hand_i).basis.get_rotation_quaternion()
			(sk as Skeleton3D).set_bone_pose_rotation(hand_i, rest_q * Quaternion(Vector3.RIGHT, deg_to_rad(HAND_BEND)))
			break
	for mi in _paw.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var mat: Material = mi.mesh.surface_get_material(s)
			if mat is StandardMaterial3D:
				var fd: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
				fd.albedo_color = Color(0.9777, 0.68, 0.3492)
				fd.roughness = 0.5
				fd.metallic = 0.0
				mi.set_surface_override_material(s, fd)
	await get_tree().process_frame


func _swap_to_rod() -> void:
	if _rod != null:
		return
	var glb: PackedScene = load("res://assets/rods/rod_v3.glb")
	_rod = glb.instantiate()
	_rod.scale = Vector3.ONE * ROD_SCALE
	_arm.add_child(_rod)
	_rod_tip = Marker3D.new()
	_rod_tip.position = Vector3(0, 0.57 * ROD_SCALE, 0)
	_rod.add_child(_rod_tip)
	_stick.visible = false


func _skip_craft() -> void:
	_swap_to_rod()
	_time = 2.45


func _process(delta: float) -> void:
	if not _playing:
		return
	_time += delta * _speed
	var t := _time
	var arm_base := ARM_POS

	if t < 0.7:
		var k: float = t / 0.7
		k = k * k * (3.0 - 2.0 * k)
		_arm.global_position = arm_base + Vector3(0.3 * (1.0 - k) + 0.15, -0.45 * (1.0 - k), 0)
	elif t < 2.2 and _first_craft:
		_arm.global_position = arm_base + Vector3(sin(t * 21.0) * 0.006, 0, 0)
		var wraps_shown := 0
		if t >= 1.0:
			wraps_shown = 1
		if t >= 1.4:
			wraps_shown = 2
		if t >= 1.8:
			wraps_shown = 3
		for i in range(3):
			_wraps[i].visible = i < wraps_shown
	elif t < 2.5:
		_arm.global_position = arm_base
	elif t < 3.2:
		var k: float = clampf((t - 2.5) / 0.35, 0.0, 1.0)
		var back := lerpf(0.0, -50.0, k)
		var k2: float = clampf((t - 2.85) / 0.35, 0.0, 1.0)
		k2 = k2 * k2 * (3.0 - 2.0 * k2)
		_arm.rotation_degrees.x = back + lerpf(0.0, 95.0, k2)
		if t >= 2.95 and not _line_pivot.visible:
			_line_pivot.visible = true
			_bobber.visible = true
	else:
		_arm.rotation_degrees.x = lerp_angle(_arm.rotation_degrees.x, 0.0, minf(1.0, delta * 6.0))

	if t >= 2.2 and t < 2.25 and _first_craft:
		_swap_to_rod()
		_pop.play()

	if _line_pivot.visible and t < 4.5:
		var tip := _tip_world()
		var droop: float = clampf((t - 2.95) / 0.35, 0.0, 1.0)
		var end := tip.lerp(BOBBER, droop)
		_stretch_line(tip, end)
		_bobber.global_position = Vector3(BOBBER.x, BOBBER.y + sin(t * 3.0) * 0.008 if t > 3.3 else BOBBER.y, BOBBER.z)

	if t >= 3.5 and t < 3.55:
		_ripples[0].visible = true
		_click.play()
	if t >= 4.3 and t < 4.35:
		_ripples[1].visible = true
		_pop.play()
		_arm.rotation_degrees.x = 14.0
	for i in range(2):
		if _ripples[i].visible:
			var rk: float = clampf((t - (3.5 if i == 0 else 4.3)) / 0.9, 0.0, 1.0)
			_ripples[i].scale = Vector3.ONE * lerpf(0.4, 3.2, rk)
			var rmat: StandardMaterial3D = (_ripples[i].mesh as TorusMesh).material
			rmat.albedo_color.a = 0.65 * (1.0 - rk)

	if t >= 4.55 and _fish == null and is_instance_valid(_rod):
		var fglb: PackedScene = load("res://assets/fish/goldfish_v3.glb")
		_fish = fglb.instantiate()
		_fish.scale = Vector3.ONE * 0.22
		_viewport.add_child(_fish)
	if _fish != null:
		var fk: float = clampf((t - 4.55) / 0.85, 0.0, 1.0)
		fk = fk * fk * (3.0 - 2.0 * fk)
		var p0 := BOBBER + Vector3(0, 0.02, 0)
		var p1 := Vector3(-0.04, 0.10, 0.20)
		var p2 := FISH_HOLD
		var q0 := p0.lerp(p1, fk)
		var q1 := p1.lerp(p2, fk)
		var fp := q0.lerp(q1, fk)
		_fish.global_position = fp
		var ahead := q0.lerp(q1, minf(fk + 0.03, 1.0)).lerp(p2, minf(fk + 0.03, 1.0))
		if fp.distance_to(ahead) > 0.001:
			_fish.look_at(ahead, Vector3.UP)
		if _line_pivot.visible and t < 5.6:
			_stretch_line(_tip_world(), fp)
		if t >= 5.4:
			_fish.visible = true
		if t < 5.35 and int(t * 60.0) % 3 == 0:
			_fish.visible = not _fish.visible

	if t >= DURATION + 0.4:
		_finish()


func _finish() -> void:
	_playing = false
	set_process(false)
	GameState.cinematic_active = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_canvas.free()
	_viewport.free()
	_restore_player()
	if _on_done.is_valid():
		_on_done.call()
	free()
