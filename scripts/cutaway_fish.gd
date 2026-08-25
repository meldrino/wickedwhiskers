extends Node3D

# Fishing cutaway v3 - REAL WORLD, minimal (Andy spec):
# pick camera angle + WW facing, put rod in his hand, animate the fish landing.
# No viewport, no props scenery: the actual pond/terrain/cat are the scene.

const DURATION := 3.6
const ROD_SCALE := 0.62
const LEAP_T0 := 2.0
const LEAP_DUR := 0.8

var _player: Node3D
var _mesh_root: Node3D
var _cam_holder: Node3D
var _camera: Camera3D
var _fish: Node3D
var _rod_pivot: Node3D
var _rod: Node3D
var _rod_tip: Marker3D
var _line_pivot: Node3D
var _line_mesh: MeshInstance3D
var _bobber_pos := Vector3.ZERO
var _catch_pos := Vector3.ZERO
var _ripples: Array[MeshInstance3D] = []
var _click: AudioStreamPlayer
var _pop: AudioStreamPlayer
var _time := 0.0
var _playing := false
var _first_craft := true
var _on_done: Callable = Callable()
var _speed := 1.0
var _saved_cam_xf: Transform3D = Transform3D()
var _saved_cam_local := Vector3.ZERO
var _saved_mesh_y := 0.0


func play_rod_catch(first_craft: bool, fish: Node3D, on_done: Callable) -> void:
	_first_craft = first_craft
	_on_done = on_done
	_fish = fish
	if DisplayServer.get_name() == "headless":
		_speed = 10.0
	_player = get_tree().get_first_node_in_group("player")
	if _player == null or not is_instance_valid(_player):
		_finish()
		return
	_mesh_root = _player.get_node_or_null("MeshRoot")
	_cam_holder = _player.get_node_or_null("CameraHolder")
	_camera = _player.get_node_or_null("CameraHolder/Camera")
	var lake_c: Vector3 = Vector3(Terrain.lake.center.x, 0.0, Terrain.lake.center.y)
	var dir := Vector2(lake_c.x - _player.global_position.x, lake_c.z - _player.global_position.z)
	if dir.length() < 0.01:
		dir = Vector2(1, 0)
	dir = dir.normalized()
	var dir3 := Vector3(dir.x, 0.0, dir.y)

	_saved_cam_xf = _cam_holder.global_transform if _cam_holder else Transform3D()
	_saved_cam_local = _camera.position if _camera else Vector3.ZERO
	_saved_mesh_y = _mesh_root.rotation.y if _mesh_root else 0.0

	# WW faces the pond (profile to the side-on camera).
	if _mesh_root:
		_mesh_root.rotation.y = atan2(dir.x, dir.y)

	# Side-on profile camera centred on the whole fishing segment.
	var perp := Vector3(-dir.y, 0.0, dir.x)
	var eye := _player.global_position + dir3 * 1.1 + perp * 2.4 + Vector3(0, 1.05, 0)
	var focus := _player.global_position + dir3 * 0.9 + Vector3(0, 0.35, 0)

	# Bobber floats on the real water along the cast bearing.
	var r_shore := Terrain.shore_distance(dir)
	_bobber_pos = lake_c + Vector3(dir.x, 0.0, dir.y) * (r_shore * 0.5)
	_bobber_pos.y = Terrain.water_level + 0.02
	_catch_pos = _player.global_position + dir3 * 0.42 + Vector3(0, 0.52, 0)

	# Cat-centric side-on profile: close and low on WW, rod/line
	# sweeping toward the pond behind him.
	var sperp := Vector3(-dir.y, 0.0, dir.x)
	eye = _player.global_position + sperp * 3.2 + dir3 * 0.6 + Vector3(0, 1.35, 0)
	focus = _player.global_position + dir3 * 0.85 + Vector3(0, 0.45, 0)

	GameState.cinematic_active = true
	if _cam_holder:
		_cam_holder.global_transform = Transform3D(Basis(), eye)
		_cam_holder.look_at(focus, Vector3.UP)
	if _camera:
		_camera.position = Vector3.ZERO

	_build_rod_and_fx()

	if _fish != null and is_instance_valid(_fish):
		_fish.set_process(false)
		_fish.set_physics_process(false)

	_pop.play()
	_time = 0.0
	_playing = true
	set_process(true)


func _build_rod_and_fx() -> void:
	_rod_pivot = Node3D.new()
	_rod_pivot.rotation_degrees = Vector3(0, 0, -32)
	var skel: Skeleton3D = null
	for sk in _player.find_children("*", "Skeleton3D", true, false):
		skel = sk
		break
	if skel != null and skel.find_bone("Hand.R") >= 0:
		var att := BoneAttachment3D.new()
		att.bone_name = "Hand.R"
		skel.add_child(att)
		att.add_child(_rod_pivot)
	else:
		_player.add_child(_rod_pivot)
		_rod_pivot.position = Vector3(0, 0.55, 0.28)
	var glb: PackedScene = load("res://assets/rods/rod_v3.glb")
	if glb != null:
		_rod = glb.instantiate()
		_rod.scale = Vector3.ONE * ROD_SCALE
		_rod_pivot.add_child(_rod)
		_rod_tip = Marker3D.new()
		_rod_tip.position = Vector3(0, 0.57 * ROD_SCALE, 0)
		_rod.add_child(_rod_tip)

	_line_pivot = Node3D.new()
	_line_pivot.visible = false
	add_child(_line_pivot)
	_line_mesh = MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 0.0022
	lm.bottom_radius = 0.0022
	lm.height = 1.0
	lm.radial_segments = 6
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color(0.96, 0.98, 0.96)
	lmat.roughness = 0.55
	lmat.shaded = false
	_line_mesh.mesh = lm
	_line_mesh.material_override = lmat
	_line_mesh.rotation.x = PI / 2.0
	_line_pivot.add_child(_line_mesh)

	var bob := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.03
	bm.height = 0.06
	var bomat := StandardMaterial3D.new()
	bomat.albedo_color = Color(0.85, 0.2, 0.16)
	bob.mesh = bm
	bob.material_override = bomat
	bob.position = _bobber_pos
	add_child(bob)

	for i in range(2):
		var rp := MeshInstance3D.new()
		var rm := TorusMesh.new()
		rm.inner_radius = 0.075
		rm.outer_radius = 0.085
		rm.rings = 32
		rm.ring_segments = 6
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color(0.85, 0.95, 0.97, 0.65)
		rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rmat.shaded = false
		rm.material = rmat
		rp.mesh = rm
		rp.position = _bobber_pos + Vector3(0, 0.012, 0)
		rp.visible = false
		add_child(rp)
		_ripples.append(rp)

	_click = AudioStreamPlayer.new()
	_click.stream = load("res://assets/sounds/click1.wav")
	add_child(_click)
	_pop = AudioStreamPlayer.new()
	_pop.stream = load("res://assets/sounds/click2.wav")
	add_child(_pop)


func _tip_world() -> Vector3:
	if _rod_tip != null:
		return _rod_tip.global_position
	return _player.global_position + Vector3(0, 0.8, 0)


func _stretch_line(a: Vector3, b: Vector3) -> void:
	_line_pivot.global_position = a
	var d := a.distance_to(b)
	if d > 0.001:
		_line_pivot.look_at(b, Vector3.UP)
	_line_mesh.scale = Vector3(1, d, 1)


func _process(delta: float) -> void:
	if not _playing:
		return
	_time += delta * _speed
	var t := _time

	# Cast swing.
	if t < 0.45:
		var k: float = clampf(t / 0.25, 0.0, 1.0)
		_rod_pivot.rotation_degrees.z = lerpf(-32.0, 55.0, k * k * (3.0 - 2.0 * k))
	elif t < 0.95:
		var k2: float = clampf((t - 0.45) / 0.3, 0.0, 1.0)
		k2 = k2 * k2 * (3.0 - 2.0 * k2)
		_rod_pivot.rotation_degrees.z = lerpf(55.0, -75.0, k2)
		if t >= 0.62 and not _line_pivot.visible:
			_line_pivot.visible = true
			_click.play()
	else:
		_rod_pivot.rotation_degrees.z = lerp_angle(_rod_pivot.rotation_degrees.z, -18.0, minf(1.0, delta * 6.0))

	# Line out to bobber.
	if _line_pivot.visible and t < LEAP_T0 + LEAP_DUR:
		var droop: float = clampf((t - 0.62) / 0.3, 0.0, 1.0)
		var end := _tip_world().lerp(_bobber_pos, droop)
		if t >= LEAP_T0:
			end = _fish_target()
		_stretch_line(_tip_world(), end)

	if t >= 1.15 and t < 1.2:
		_ripples[0].visible = true
		_pop.play()
	if t >= 1.75 and t < 1.8:
		_ripples[1].visible = true
		_click.play()
		_rod_pivot.rotation_degrees.z = -4.0
	for i in range(2):
		if _ripples[i].visible:
			var rk: float = clampf((t - (1.15 if i == 0 else 1.75)) / 0.9, 0.0, 1.0)
			_ripples[i].scale = Vector3.ONE * lerpf(0.4, 3.0, rk)
			var rmat: StandardMaterial3D = (_ripples[i].mesh as TorusMesh).material
			rmat.albedo_color.a = 0.65 * (1.0 - rk)

	# The real fish leaps into WW's arms.
	if _fish != null and is_instance_valid(_fish) and t >= LEAP_T0:
		var fk: float = clampf((t - LEAP_T0) / LEAP_DUR, 0.0, 1.0)
		fk = fk * fk * (3.0 - 2.0 * fk)
		var p0 := _bobber_pos
		var p1 := (_bobber_pos + _catch_pos) * 0.5 + Vector3(0, 0.75, 0)
		var p2 := _catch_pos
		var q0 := p0.lerp(p1, fk)
		var q1 := p1.lerp(p2, fk)
		var fp := q0.lerp(q1, fk)
		_fish.global_position = fp
		if t < LEAP_T0 + LEAP_DUR:
			var fa: float = minf(fk + 0.04, 1.0)
			var ahead := p0.lerp(p1, fa).lerp(p1.lerp(p2, fa), fa)
			if fp.distance_to(ahead) > 0.001:
				var cur := _fish.global_rotation
				_fish.look_at(ahead, Vector3.UP)
				_fish.global_rotation.y = cur.y

	if t >= DURATION:
		_finish()


func _fish_target() -> Vector3:
	return _catch_pos


func _finish() -> void:
	_playing = false
	set_process(false)
	GameState.cinematic_active = false
	if _cam_holder:
		_cam_holder.global_transform = _saved_cam_xf
	if _camera:
		_camera.position = _saved_cam_local
	if _mesh_root:
		_mesh_root.rotation.y = _saved_mesh_y
	if _on_done.is_valid():
		_on_done.call()
	free()
