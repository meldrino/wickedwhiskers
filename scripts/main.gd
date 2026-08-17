extends Node3D

const WORLD_SIZE := 60.0
const HALF := WORLD_SIZE / 2.0
const FENCE_HALF := 25.0

const TREE_SCENES := [
	preload("res://assets/tree_ww_round.glb"),
	preload("res://assets/tree_ww_cone.glb"),
	preload("res://assets/tree_ww_fat.glb"),
]
const FENCE_PANEL := preload("res://assets/fence2.glb")
const FENCE_PANEL_WIDTH := 5.89
const FENCE_PANEL_HEIGHT := 1.1
const TRUNK_COLLIDER_SIZE := Vector3(0.5, 1.8, 0.5)
const ROCK_SCENES := [
	preload("res://assets/rock_ww_a.glb"),
	preload("res://assets/rock_ww_b.glb"),
	preload("res://assets/rock_ww_c.glb"),
]
const CROP_SCENES := [
	preload("res://assets/crop_carrot.glb"),
	preload("res://assets/crop_pumpkin.glb"),
	preload("res://assets/crop_turnip.glb"),
]
const LOG_SCENES := [
	preload("res://assets/log.glb"),
	preload("res://assets/log_large.glb"),
	preload("res://assets/log_stack.glb"),
]

const FARMHOUSE_POS := Vector3(0, 0, -38)
const SHED_POS := Vector3(16, 0, -10)
const TRACTOR_POS := Vector3(10, 0, -20)
const BIRD_TREE_POS := Vector3(20, 0, -4)
const DUMBLECLAW_POS := Vector3(4, 0, -14)
const MOUSE_POS := Vector3(2, 0, 6.5)

var rng := RandomNumberGenerator.new()
var trees: Array[Node3D] = []
var _shed_portal: Area3D
var _enter_shed_delay := -1.0


func _ready() -> void:
	rng.randomize()
	var bare := "--bare" in OS.get_cmdline_user_args()
	if not bare:
		_build_farmhouse(FARMHOUSE_POS)
		_build_shed(SHED_POS)
		_build_tractor()
		_build_lake()
		_build_bird_tree()
		_build_fence_perimeter()
		_build_path()
		_build_trees()
		_build_rocks()
		_build_crops()
		_build_logs()
		_build_distant_scenery()
		_spawn_pickups()
		_spawn_dumbleclaw()
		_spawn_mouse()
		_spawn_bird()
	_spawn_player()
	_build_grass()
	_maybe_screenshot()

func _build_grass() -> void:
	if "--nograss" in OS.get_cmdline_user_args():
		return
	var grass: Node3D = preload("res://scripts/grass_system.gd").new()
	grass.name = "GrassSystem"
	add_child(grass)


func _spawn_player() -> void:
	var pl := get_tree().get_first_node_in_group("player")
	if pl == null:
		return
	if GameState.spawn_near_shed:
		pl.global_position = Vector3(16, Terrain.height_at(16, -7.8), -7.8)
		GameState.spawn_near_shed = false
	pl.global_position.y = Terrain.height_at(pl.global_position.x, pl.global_position.z)


func _maybe_screenshot() -> void:
	print("MAYBESCREEN START")
	var args := OS.get_cmdline_user_args()
	_log_debug("maybe_screenshot args=" + str(args))
	if "--bare" in args and "--screenshot" in args:
		var p0 = get_tree().get_first_node_in_group("player")
		if p0 != null:
			var mr := p0.get_node_or_null("MeshRoot")
			if mr != null:
				mr.visible = false
		Hud.visible = false
	if "--smoketest" in args:
		_run_smoke()
		return
	if "--cutawaytest" in args:
		_run_cutawaytest()
		return
	if "--pawtest" in args:
		var vi := args.find("--pawtest")
		var variant := "v1"
		if vi >= 0 and vi + 1 < args.size():
			variant = args[vi + 1]
		_run_pawtest(variant)
		return
	if "--fpsbench" in args:
		_run_fpsbench()
		return
	if not "--screenshot" in args:
		return
	if "--noon" in args:
		GameState.day_time = GameState.DAY_SECONDS * 0.75
		await get_tree().process_frame
		await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_log_debug("after awaits, ticking=" + str(Engine.get_frames_drawn()) + " fps=" + str(Engine.get_frames_per_second()))
	print("MAYBESCREEN got player")
	var player = get_tree().get_first_node_in_group("player")
	if "--catclose" in args and player != null:
		player.camera_frozen = true
		var head: Vector3 = player.global_position + Vector3(0, 0.42, 0)
		player.camera.look_at_from_position(head + Vector3(0.9, 0.3, 1.1), head, Vector3.UP)
		for i in range(5):
			await get_tree().process_frame
	elif "--flyover" in args and player != null:
		player.camera_frozen = true
		player.camera_holder.position = Vector3(0, 16, 0)
		player.camera.position = Vector3(0, 0, 0)
		player.camera.look_at(Vector3(4, 0, -10), Vector3.UP)
	elif "--pond" in args and player != null:
		player.camera_frozen = true
		var pond_from := Vector3(Terrain.lake.center.x, 9, Terrain.lake.center.y)
		var pond_to := Vector3(Terrain.lake.center.x + 3.5, 0, Terrain.lake.center.y + 3.5)
		player.camera.look_at_from_position(pond_from, pond_to, Vector3.UP)
	elif "--ground" in args and player != null:
		player.camera_frozen = true
		player.camera_holder.position = player.global_position + Vector3(0, 0.4, 0)
		player.camera.position = Vector3(0, 0, 0)
		player.camera.look_at(player.global_position + Vector3(5, 0.1, -2), Vector3.UP)
	elif "--grass" in args and player != null:
		player.camera_frozen = true
		var gh := 0.4
		var gp := 0.0
		var gy := 0.0
		for a in args:
			if a.begins_with("--grassheight="):
				gh = float(a.get_slice("=", 1))
			if a.begins_with("--grasspitch="):
				gp = float(a.get_slice("=", 1))
			if a.begins_with("--grassyaw="):
				gy = float(a.get_slice("=", 1))
		player.camera_holder.position = Vector3(0, gh, 0)
		player.camera.position = Vector3(0, 0, 0)
		var look_off := Vector3(0, gh + sin(deg_to_rad(gp)) * 22.0, cos(deg_to_rad(gp)) * 22.0).rotated(Vector3.UP, deg_to_rad(gy))
		player.camera.look_at(player.global_position + look_off, Vector3.UP)
		if "--grassprobe" in args:
			for i in range(90):
				await get_tree().process_frame
			print("CALLING PROBE")
			_probe_grass(player, args)
		else:
			for i in range(5):
				await get_tree().process_frame
	elif "--dumbleclaw" in args and player != null:
		player.camera_frozen = true
		player.camera_holder.position = Vector3(4.2, 1.1, -12.4)
		player.camera.position = Vector3(0, 0, 0)
		player.camera.look_at(Vector3(4, 0.45, -14), Vector3.UP)
	elif "--gate" in args and player != null:
		player.camera_frozen = true
		player.global_position = Vector3(0, 0.5, -19)
		player.camera_holder.position = Vector3(0, 0.5, 0)
		player.camera.position = Vector3(0, 0, 0)
		player.camera.look_at(Vector3(0, 0.8, -25), Vector3.UP)
	else:
		for i in range(30):
			await get_tree().process_frame
	var mode := "base"
	for flag in ["catclose", "flyover", "pond", "ground", "grass", "dumbleclaw", "gate"]:
		if "--%s" % flag in args:
			mode = flag
			break
	if mode == "grass":
		for a in args:
			if a.begins_with("--grassyaw="):
				mode += "_" + a.get_slice("=", 1)
				break
	if "--grassprobe" in args and not mode.begins_with("grass"):
		_probe_grass(player, args)
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://screenshots/screenshot_%s.png" % mode)
	print("SCREENSHOT SAVED: res://screenshots/screenshot_%s.png" % mode)
	get_tree().quit()


func _probe_grass(player: Node3D, args: Array) -> void:
	# Samples actual rendered pixel colors at fixed world points, so we can
	# measure (not guess) the near-vs-far and camera-angle brightness deltas.
	var cam: Camera3D = player.camera
	var px_origin: Vector3 = player.global_position
	var heights := [
		Vector3(0.0, 0.0, 3.0),
		Vector3(0.0, 0.0, 10.0),
		Vector3(0.0, 0.0, 14.5),
		Vector3(0.0, 0.0, 26.0),
	]
	for a in args:
		if a.begins_with("--probez="):
			heights = [Vector3(0.0, 0.0, float(a.get_slice("=", 1)))]
	if "--probescan" in args:
		heights = []
		for d in range(2, 41, 1):
			heights.append(Vector3(0.0, 0.0, float(d)))
	if "--probeforward" in args:
		var fwd: Vector3 = -cam.global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		heights = []
		for d in range(1, 26, 1):
			heights.append(fwd * float(d))
	print("PROBE camera_height=%.2f pitch=%.1f" % [player.camera_holder.position.y, rad_to_deg(cam.global_rotation.x)])
	print("PROBE cam_world=%s cur_cam=%s same=%s day=%.1f is_day=%s" % [cam.global_position, get_viewport().get_camera_3d().global_position, get_viewport().get_camera_3d() == cam, GameState.day_time, GameState.is_day])
	var img := get_viewport().get_texture().get_image()
	var vw := img.get_width()
	var vh := img.get_height()
	var pc := func(x: int, y: int) -> String:
		var c := img.get_pixel(x, y)
		return "(%.3f, %.3f, %.3f)" % [c.r, c.g, c.b]
	print("PROBE refpix top=%s center=%s bottom=%s" % [pc.call(vw / 2, 10), pc.call(vw / 2, vh / 2), pc.call(vw / 2, vh - 10)])
	for y in range(0, vh, 40):
		print("STRIP y=%d %s" % [y, pc.call(vw / 2, y)])
	if "--probefine" in args:
		for y in range(230, 350, 10):
			var frow := ""
			for x in range(vw / 2 - 200, vw / 2 + 201, 50):
				frow += "%d:%s " % [x, pc.call(x, y)]
			print("FINE y=%d %s" % [y, frow])
	for y in [240, 300, 360, 500, 640]:
		var row := ""
		for x in range(0, vw, 160):
			row += "%d:%s " % [x, pc.call(x, y)]
		print("ROW y=%d %s" % [y, row])
	print("PROBE terrain water_level=%.3f water_radius=%.1f lake=%.1f,%.1f r%.1f" % [Terrain.water_level, Terrain.water_radius, Terrain.lake.center.x, Terrain.lake.center.y, Terrain.lake.radius])
	for wp in heights:
		var wpos: Vector3 = px_origin + wp
		var ground := Terrain.height_at(wpos.x, wpos.z)
		wpos.y = ground + 0.15
		var slope := TerrainGenerator.slope_at(Terrain.heights, Terrain.config, wpos.x, wpos.z)
		var excl := GrassExclusion.is_excluded(wpos.x, wpos.z, ground)
		print("PROBE geom dist=%.1fm world=(%.1f,%.3f,%.1f) h=%.3f slope=%.3f excluded=%s" % [wp.z, wpos.x, wpos.y, wpos.z, ground, slope, excl])
		var sp: Vector2 = cam.unproject_position(wpos)
		var sx := int(sp.x)
		var sy := int(sp.y)
		if sx < 2 or sy < 2 or sx >= vw - 2 or sy >= vh - 2:
			print("PROBE dist=%.1fm OFF-SCREEN (screen %d,%d of %dx%d)" % [wp.z, sx, sy, vw, vh])
			continue
		if sy > vh - 90:
			print("PROBE dist=%.1fm SKIPPED (near bottom edge, screen %d,%d)" % [wp.z, sx, sy])
			continue
		var r_sum := 0.0
		var g_sum := 0.0
		var b_sum := 0.0
		var dark := 0
		var n := 0
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var c := img.get_pixel(sx + dx, sy + dy)
				r_sum += c.r
				g_sum += c.g
				b_sum += c.b
				if (c.r + c.g + c.b) / 3.0 < 0.35:
					dark += 1
				n += 1
		var r := r_sum / n
		var g := g_sum / n
		var b := b_sum / n
		var lum := (r + g + b) / 3.0
		print("PROBE dist=%.1fm rgb=(%.3f, %.3f, %.3f) lum=%.3f dark_flecks=%d/9 screen=%d,%d" % [wp.z, r, g, b, lum, dark, sx, sy])
	print("PROBE DONE")


func _run_fpsbench() -> void:
	GameState.day_time = GameState.DAY_SECONDS * 0.75
	await get_tree().process_frame
	await get_tree().process_frame
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	player.camera_frozen = true
	var samples: Array[float] = []
	print("FPSBENCH START")
	var frames := 0
	var deadline := Time.get_ticks_msec() + 15000
	var cam_pos: Vector3 = player.global_position + Vector3(0, 0.4, 0)
	while Time.get_ticks_msec() < deadline:
		player.camera_holder.position = cam_pos
		player.camera.position = Vector3(0, 0, 0)
		player.camera.look_at(player.global_position + Vector3(5, 0.1, -2), Vector3.UP)
		var fps := Engine.get_frames_per_second()
		samples.append(fps)
		frames += 1
		await get_tree().process_frame
	samples.sort()
	var avg := 0.0
	for s in samples:
		avg += s
	avg /= float(samples.size())
	var p95 := samples[int(samples.size() * 0.95)]
	var min_f := samples[0]
	print("FPSBENCH frames=%d avg=%.1f p95=%.1f min=%.1f" % [samples.size(), avg, p95, min_f])
	get_tree().quit()



func _build_farmhouse(home: Vector3) -> void:
	var house := Node3D.new()
	house.position = Vector3(home.x, Terrain.height_at(home.x, home.z), home.z)
	house.name = "Farmhouse"
	add_child(house)

	# walls
	_add_mesh(house, "box", Vector3(9.0, 4.5, 6.5), Vector3(0, 2.25, 0), Color(0.93, 0.88, 0.74))
	# gable roof
	_add_mesh(house, "box", Vector3(10.4, 0.3, 3.9), Vector3(0, 5.125, 1.85), Color(0.62, 0.28, 0.2), Vector3(-0.326, 0, 0))
	_add_mesh(house, "box", Vector3(10.4, 0.3, 3.9), Vector3(0, 5.125, -1.85), Color(0.62, 0.28, 0.2), Vector3(0.326, 0, 0))
	_add_mesh(house, "box", Vector3(10.4, 0.4, 0.9), Vector3(0, 5.9, 0), Color(0.55, 0.24, 0.16))
	# gable ends
	_add_mesh(house, "box", Vector3(0.25, 1.25, 6.5), Vector3(-4.55, 5.125, 0), Color(0.85, 0.78, 0.6))
	_add_mesh(house, "box", Vector3(0.25, 1.25, 6.5), Vector3(4.55, 5.125, 0), Color(0.85, 0.78, 0.6))
	# porch slab + posts (front, +Z)
	_add_mesh(house, "box", Vector3(4.2, 0.2, 1.6), Vector3(0, 1.15, 3.45), Color(0.55, 0.4, 0.28))
	_add_mesh(house, "box", Vector3(0.22, 2.1, 0.22), Vector3(-1.6, 2.25, 3.6), Color(0.75, 0.68, 0.55))
	_add_mesh(house, "box", Vector3(0.22, 2.1, 0.22), Vector3(1.6, 2.25, 3.6), Color(0.75, 0.68, 0.55))
	# door + frame (named so door.gd can find it)
	var door_mesh := _mesh("box", Vector3(1.5, 2.3, 0.15), Color(0.5, 0.33, 0.2))
	door_mesh.name = "Door"
	door_mesh.position = Vector3(0, 1.15, 3.28)
	house.add_child(door_mesh)
	_add_mesh(house, "box", Vector3(1.15, 2.0, 0.2), Vector3(0, 1.1, 3.2), Color(0.32, 0.2, 0.12))
	# windows (front + both sides)
	_add_mesh(house, "box", Vector3(0.95, 0.95, 0.2), Vector3(-2.3, 2.5, 3.28), Color(0.78, 0.85, 0.92))
	_add_mesh(house, "box", Vector3(0.95, 0.95, 0.2), Vector3(2.3, 2.5, 3.28), Color(0.78, 0.85, 0.92))
	_add_mesh(house, "box", Vector3(0.2, 0.95, 0.95), Vector3(-4.5, 2.5, -1.2), Color(0.78, 0.85, 0.92))
	_add_mesh(house, "box", Vector3(0.2, 0.95, 0.95), Vector3(-4.5, 2.5, 1.2), Color(0.78, 0.85, 0.92))
	_add_mesh(house, "box", Vector3(0.2, 0.95, 0.95), Vector3(4.5, 2.5, -1.2), Color(0.78, 0.85, 0.92))
	_add_mesh(house, "box", Vector3(0.2, 0.95, 0.95), Vector3(4.5, 2.5, 1.2), Color(0.78, 0.85, 0.92))
	# chimney
	_add_mesh(house, "box", Vector3(0.7, 1.6, 0.7), Vector3(2.8, 5.5, -1.0), Color(0.5, 0.44, 0.38))
	_add_mesh(house, "box", Vector3(0.85, 0.3, 0.85), Vector3(2.8, 6.3, -1.0), Color(0.4, 0.35, 0.3))
	# step
	_add_mesh(house, "box", Vector3(1.8, 0.25, 0.6), Vector3(0, 0.12, 3.7), Color(0.6, 0.5, 0.38))

	_add_collider(house, Vector3(9.0, 4.5, 6.5), Vector3(0, 2.25, 0))
	_add_collider(house, Vector3(1.3, 2.1, 0.2), Vector3(0, 1.05, 3.28))

	var door := _make_door("farmhouse")
	door.position = Vector3(0, 1.0, 3.28)
	house.add_child(door)


func _build_shed(shed_pos: Vector3) -> void:
	var shed := Node3D.new()
	shed.position = Vector3(shed_pos.x, Terrain.height_at(shed_pos.x, shed_pos.z), shed_pos.z)
	shed.name = "Shed"
	add_child(shed)

	var wood := Color(0.47, 0.31, 0.18)
	var wood_dark := Color(0.36, 0.24, 0.14)
	var roof_col := Color(0.32, 0.22, 0.13)
	var frame_col := Color(0.25, 0.17, 0.11)
	var half_w := 1.5
	var half_d := 1.2
	var wall_h := 2.5

	# Solid exterior box (the interior now lives in its own scene: scenes/shed.tscn)
	_add_mesh(shed, "box", Vector3(half_w * 2.0, wall_h, half_d * 2.0), Vector3(0, wall_h / 2.0, 0), wood)
	_add_collider(shed, Vector3(half_w * 2.0, wall_h, half_d * 2.0), Vector3(0, wall_h / 2.0, 0))
	# Vertical plank seams (proud of the walls, front + back)
	for x in range(-1, 2):
		if x == 0:
			continue
		_add_mesh(shed, "box", Vector3(0.03, wall_h, 0.02), Vector3(x * 0.9, wall_h / 2.0, half_d + 0.01), wood_dark)
		_add_mesh(shed, "box", Vector3(0.03, wall_h, 0.02), Vector3(x * 0.9, wall_h / 2.0, -half_d - 0.01), wood_dark)
	# Horizontal plank seams on the side walls
	for y in range(3):
		_add_mesh(shed, "box", Vector3(0.02, 0.03, half_d * 2.0), Vector3(half_w + 0.01, 0.5 + y * 1.0, 0), wood_dark)
		_add_mesh(shed, "box", Vector3(0.02, 0.03, half_d * 2.0), Vector3(-half_w - 0.01, 0.5 + y * 1.0, 0), wood_dark)
	# Corner posts
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_add_mesh(shed, "box", Vector3(0.22, wall_h + 0.1, 0.22),
				Vector3(sx * (half_w - 0.1), (wall_h + 0.1) / 2.0, sz * (half_d - 0.1)), frame_col)
	# Gabled roof (two sloped slabs) + ridge cap — derived from the box size
	var roof_over := 0.35
	var rise := 0.5
	var roof_d := half_d * 2.0 + 0.8
	var slab_len := sqrt((half_w + roof_over) * (half_w + roof_over) + rise * rise)
	var slope_ang := atan(rise / (half_w + roof_over))
	var slab_cx := (half_w + roof_over) / 2.0
	_add_mesh(shed, "box", Vector3(slab_len, 0.22, roof_d), Vector3(slab_cx, wall_h + rise / 2.0, 0), roof_col)
	shed.get_child(-1).rotation.z = -slope_ang
	_add_mesh(shed, "box", Vector3(slab_len, 0.22, roof_d), Vector3(-slab_cx, wall_h + rise / 2.0, 0), roof_col)
	shed.get_child(-1).rotation.z = slope_ang
	_add_mesh(shed, "box", Vector3(0.45, 0.45, roof_d), Vector3(0, wall_h + rise - 0.02, 0), roof_col)
	# Gable triangles filling the roof ends (triangular prisms, flat side down)
	var gable_h := rise + 0.15
	var gable := PrismMesh.new()
	gable.size = Vector3(half_w * 2.0, gable_h, 0.35)
	var gmi := MeshInstance3D.new()
	gmi.mesh = gable
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = wood_dark
	gmi.material_override = gmat
	gmi.position = Vector3(0, wall_h + gable_h / 2.0 - 0.1, half_d + 0.05)
	shed.add_child(gmi)
	var gmi2 := gmi.duplicate()
	gmi2.position.z = -half_d - 0.05
	shed.add_child(gmi2)
	# Small window on each side wall with a wooden frame + alpha-blended glass pane
	for sx in [-1, 1]:
		var wx: float = sx * (half_w - 0.04)
		var glass := StandardMaterial3D.new()
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.albedo_color = Color(0.72, 0.83, 0.9, 0.4)
		glass.metallic = 0.2
		glass.roughness = 0.1
		var pane := _mesh("box", Vector3(0.04, 0.56, 0.56), Color(1, 1, 1))
		pane.material_override = glass
		pane.position = Vector3(wx - sx * 0.06, 1.6, 0)
		shed.add_child(pane)
		_add_mesh(shed, "box", Vector3(0.1, 0.7, 0.7), Vector3(wx, 1.6, 0), frame_col)
		_add_mesh(shed, "box", Vector3(0.14, 0.08, 0.76), Vector3(wx, 1.2, 0), frame_col)
		_add_mesh(shed, "box", Vector3(0.14, 0.72, 0.08), Vector3(wx, 1.6, -0.3), frame_col)
		_add_mesh(shed, "box", Vector3(0.14, 0.72, 0.08), Vector3(wx, 1.6, 0.3), frame_col)
	# Door frame + dark door (door mesh swings open on unlock)
	_add_mesh(shed, "box", Vector3(0.9, 2.0, 0.12), Vector3(0, 1.0, half_d - 0.05), wood_dark)
	_add_mesh(shed, "box", Vector3(0.08, 2.0, 0.05), Vector3(-0.55, 1.0, half_d - 0.02), frame_col)
	_add_mesh(shed, "box", Vector3(0.08, 2.0, 0.05), Vector3(0.55, 1.0, half_d - 0.02), frame_col)
	# Planks on the door itself
	_add_mesh(shed, "box", Vector3(0.8, 0.06, 0.05), Vector3(0, 0.6, half_d + 0.01), frame_col)
	_add_mesh(shed, "box", Vector3(0.8, 0.06, 0.05), Vector3(0, 1.5, half_d + 0.01), frame_col)
	var door_mesh := _mesh("box", Vector3(0.9, 2.0, 0.1), Color(0.1, 0.08, 0.06))
	door_mesh.name = "Door"
	door_mesh.position = Vector3(0, 1.0, half_d - 0.02)
	shed.add_child(door_mesh)

	var door := _make_door("shed")
	door.position = Vector3(0, 1.0, half_d - 0.02)
	shed.add_child(door)

	_build_shed_portal(shed)


func _build_shed_portal(shed: Node3D) -> void:
	var portal := Area3D.new()
	portal.name = "ShedPortal"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.1, 2.1, 0.7)
	col.shape = box
	portal.add_child(col)
	portal.position = Vector3(0, 1.0, 1.5)
	_shed_portal = portal
	shed.add_child(portal)


func _physics_process(delta: float) -> void:
	if _enter_shed_delay > 0.0:
		_enter_shed_delay -= delta
		if _enter_shed_delay <= 0.0:
			get_tree().change_scene_to_file("res://scenes/shed.tscn")
		return
	if not GameState.shed_unlocked or _shed_portal == null:
		return
	# Poll overlaps every frame (self-healing - no body_entered can be missed).
	for body in _shed_portal.get_overlapping_bodies():
		if body.is_in_group("player"):
			# Small beat so the padlock CLICK + door swing register before the cut.
			_enter_shed_delay = 0.7
			return


func _make_door(kind: String) -> Node3D:
	var door: Node3D = preload("res://scripts/door.gd").new()
	door.door_kind = kind
	door.name = "Door_%s" % kind
	return door


func _run_smoke() -> void:
	for i in range(30):
		await get_tree().process_frame
	print("SMOKE start: is_day=%s combo=%03d hunger=%.2f energy=%.2f" % [GameState.is_day, GameState.combo, GameState.hunger, GameState.tiredness])

	var dc := get_node("Dumbleclaw")
	dc.interact()
	Hud.close_dialogue()
	print("SMOKE quest_after_meet=%s" % GameState.quest)

	GameState.add_string(1)
	GameState.add_sticks(2)
	var shed_door := get_node("Shed/Door_shed")
	shed_door._on_combo(GameState.combo)
	print("SMOKE shed_unlocked=%s has_keys=%s string=%d" % [GameState.shed_unlocked, GameState.has_keys, GameState.string_count])

	var mouse := get_node("Mouse")
	mouse._on_choice(1)
	var caught := false
	for i in range(300):
		await get_tree().process_frame
		if GameState.mouse_caught:
			caught = true
			break
	print("SMOKE mouse_caught=%s (caught=%s) food=%d trap_placed=%s" % [GameState.mouse_caught, caught, GameState.food_count, GameState.trap_placed])

	GameState.add_string(1)
	GameState.add_sticks(2)
	var bird := get_node("Bird")
	bird._on_choice(1)
	print("SMOKE bird_caught=%s food=%d ladder_placed=%s" % [GameState.bird_caught, GameState.food_count, GameState.ladder_placed])

	var tractor := get_node("Tractor")
	tractor._on_choice(0)
	Hud.close_dialogue()
	tractor._on_choice(1)

	var dc2 := get_node("Dumbleclaw")
	dc2._on_choice(1)
	print("SMOKE after_trade food=%d gold=%d" % [GameState.food_count, GameState.gold])

	var farmhouse_door := get_node("Farmhouse/Door_farmhouse")
	farmhouse_door.interact()
	Hud.close_dialogue()
	GameState.day_time = 0.75 * GameState.DAY_SECONDS
	for i in range(3):
		await get_tree().process_frame
	farmhouse_door.interact()
	Hud.close_dialogue()
	print("SMOKE is_day=%s catfood_used=%s food=%d" % [GameState.is_day, GameState.catfood_used, GameState.food_count])
	print("SMOKE DONE")
	get_tree().quit()


func _run_cutawaytest() -> void:
	print("CUTAWAY start")
	await get_tree().process_frame
	await get_tree().process_frame
	var shed_door := get_node("Shed/Door_shed")
	shed_door._on_combo(GameState.combo)
	var shots := [1.5, 2.3, 3.1, 3.9, 4.4, 5.2]
	for i in range(shots.size()):
		await get_tree().create_timer(shots[i]).timeout
		var img := get_viewport().get_texture().get_image()
		var p := "res://screenshots/cw_%d.png" % (i + 1)
		img.save_png(p)
		print("CUTAWAY shot " + p)
	print("CUTAWAY DONE")
	get_tree().quit()


func _run_pawtest(_variant: String = "v1") -> void:
	print("PAWTEST start")
	GameState.day_time = 0.0
	Hud.visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	var shed_door := get_node("Shed/Door_shed")
	var padlock: Node3D = shed_door.get("_padlock")
	if padlock == null:
		push_error("PAWTEST no padlock")
		get_tree().quit()
		return
	var dials: Array[MeshInstance3D] = []
	for c in padlock.get_children():
		if c.name.begins_with("Dial") and c is MeshInstance3D:
			dials.append(c)
	if dials.is_empty():
		push_error("PAWTEST no dials")
		get_tree().quit()
		return
	var dial: Node3D = dials[0]
	var params := {
		"show_paw": true,
		"path_mode": false,
		"advance": 0.0,
		"path_start": [0.20, -0.10, 0.02],
		"path_end": [0.0, 0.0, 0.02],
		"fingers": false,
		"target_offset": [0.0, -0.02, 0.018],
		"model_rot_x_deg": 0.0,
		"model_rot_y_deg": 0.0,
		"model_rot_z_deg": 0.0,
		"hand_bend_deg": 0.0,
		"model_scale": 0.35,
		"model_glb": "res://assets/WW.glb",
		"cam_offset": [0.0, 0.02, 0.42],
		"cam_fov": 42.0,
		"out": "pawtest_iter.png",
	}
	var pf := FileAccess.open("res://screenshots/pawtest_params.json", FileAccess.READ)
	if pf != null:
		var j: Variant = JSON.parse_string(pf.get_as_text())
		if j is Dictionary:
			for k in j:
				params[k] = j[k]
		pf.close()
	if bool(params["show_paw"]):
		var toff: Array = params["target_offset"]
		var target: Vector3 = dial.global_position + Vector3(toff[0], toff[1], toff[2])
		var glb: PackedScene = load(str(params["model_glb"]))
		if glb == null:
			push_error("PAWTEST failed to load model_glb=" + str(params["model_glb"]))
			get_tree().quit()
			return
		var model := glb.instantiate()
		model.scale = Vector3.ONE * float(params["model_scale"])
		model.rotation.x = deg_to_rad(float(params["model_rot_x_deg"]))
		model.rotation.y = deg_to_rad(float(params["model_rot_y_deg"]))
		model.rotation.z = deg_to_rad(float(params["model_rot_z_deg"]))
		add_child(model)
		await get_tree().process_frame
		var skel: Skeleton3D = null
		for sk in model.find_children("*", "Skeleton3D", true, false):
			skel = sk as Skeleton3D
			break
		var standalone: bool = skel == null
		if standalone:
			print("PAWTEST standalone model (no skeleton)")
		var show_fingers: bool = bool(params["fingers"])
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if standalone:
				m.visible = true
			elif show_fingers:
				m.visible = (m.name == "Arm_L")
			else:
				m.visible = (m.name == "Paw_L" or m.name == "Arm_L")
		if params.has("paw_debug_color"):
			var dc: Array = params["paw_debug_color"]
			for mi in model.find_children("*", "MeshInstance3D", true, false):
				var mm := (mi as MeshInstance3D).mesh
				if mm != null:
					for s in mm.get_surface_count():
						var smat: Material = mm.surface_get_material(s)
						if smat is StandardMaterial3D:
							(smat as StandardMaterial3D).albedo_color = Color(dc[0], dc[1], dc[2])
		var hand_w: Vector3 = Vector3.ZERO
		if skel != null:
			var hand_i := skel.find_bone("Hand.L")
			var bend := float(params["hand_bend_deg"])
			if absf(bend) > 0.01:
				var rest_q: Quaternion = skel.get_bone_rest(hand_i).basis.get_rotation_quaternion()
				skel.set_bone_pose_rotation(hand_i, rest_q * Quaternion(Vector3.RIGHT, deg_to_rad(bend)))
				await get_tree().process_frame
			hand_w = skel.to_global(skel.get_bone_global_pose(hand_i).origin)
		if bool(params["path_mode"]):
			var paw_mi: MeshInstance3D = null
			var paw_name := "Paw_L" if not standalone else "*"
			for mi in model.find_children(paw_name, "MeshInstance3D", true, false):
				paw_mi = mi as MeshInstance3D
				break
			var paw_center: Vector3 = Vector3.ZERO
			if paw_mi != null and paw_mi.mesh != null:
				paw_center = paw_mi.global_transform * paw_mi.mesh.get_aabb().get_center()
			var ps: Array = params["path_start"]
			var pe: Array = params["path_end"]
			var start: Vector3 = dial.global_position + Vector3(ps[0], ps[1], ps[2])
			var end: Vector3 = dial.global_position + Vector3(pe[0], pe[1], pe[2])
			var desired: Vector3 = start.lerp(end, clampf(float(params["advance"]), 0.0, 1.0))
			model.global_position += desired - paw_center
			print("PAWTEST paw_center=" + str(paw_center) + " desired=" + str(desired) + " dial=" + str(dial.global_position))
		else:
			if standalone:
				var anchor_w: Vector3 = Vector3.ZERO
				if params.has("model_anchor"):
					var ma: Array = params["model_anchor"]
					anchor_w = model.global_transform * Vector3(ma[0], ma[1], ma[2])
				else:
					var paw_mi: MeshInstance3D = null
					for mi in model.find_children("*", "MeshInstance3D", true, false):
						paw_mi = mi as MeshInstance3D
						break
					if paw_mi != null and paw_mi.mesh != null:
						anchor_w = paw_mi.global_transform * paw_mi.mesh.get_aabb().get_center()
				model.global_position += target - anchor_w
				print("PAWTEST anchor_w=" + str(anchor_w) + " target=" + str(target) + " model_pos=" + str(model.global_position))
			else:
				model.global_position += target - hand_w
		if bool(params["fingers"]):
			_pawtest_fingers(model, dial)
		await get_tree().process_frame
	var cam := Camera3D.new()
	cam.current = true
	cam.fov = float(params["cam_fov"])
	add_child(cam)
	if float(params.get("light_energy", 0.0)) > 0.0:
		var key := DirectionalLight3D.new()
		key.light_energy = float(params["light_energy"])
		key.shadow_enabled = false
		key.rotation_degrees = Vector3(float(params.get("light_pitch_deg", -30.0)), float(params.get("light_yaw_deg", 0.0)), 0.0)
		add_child(key)
		var fill := DirectionalLight3D.new()
		fill.light_energy = float(params.get("light_fill_energy", 0.35))
		fill.shadow_enabled = false
		fill.rotation_degrees = Vector3(float(params.get("fill_pitch_deg", 0.0)), float(params.get("fill_yaw_deg", 180.0)), 0.0)
		add_child(fill)
	var co: Array = params["cam_offset"] as Array
	cam.global_position = padlock.global_position + Vector3(co[0], co[1], co[2])
	cam.look_at(padlock.global_position, Vector3.UP)
	await get_tree().process_frame
	var dn := get_node_or_null("DayNight")
	if dn != null:
		for c in dn.get_children():
			if c is DirectionalLight3D:
				c.light_energy = 0.0
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.6, 0.55)
	env.ambient_light_energy = 0.18
	var we := get_node_or_null("WorldEnvironment")
	if we != null:
		we.environment = env
	else:
		var we2 := WorldEnvironment.new()
		we2.environment = env
		add_child(we2)
	var img := get_viewport().get_texture().get_image()
	var p := "res://screenshots/" + str(params["out"])
	img.save_png(p)
	print("PAWTEST saved=" + p)
	get_tree().quit()


func _pawtest_segment(a: Vector3, b: Vector3, r: float, mat: Material) -> void:
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = maxf(a.distance_to(b) + r * 2.0, 0.002)
	cm.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	add_child(mi)
	mi.look_at_from_position((a + b) * 0.5, b, Vector3.UP)
	mi.rotate_object_local(Vector3.RIGHT, PI / 2.0)


func _pawtest_fingers(model: Node3D, dial: Node3D) -> void:
	var fur := StandardMaterial3D.new()
	fur.albedo_color = Color("#f9ad59")
	fur.roughness = 0.9
	for mi in model.find_children("Paw_L", "MeshInstance3D", true, false):
		var sm := (mi as MeshInstance3D).mesh
		if sm != null and sm.get_surface_count() > 0:
			var src := sm.surface_get_material(0)
			if src is StandardMaterial3D:
				fur.albedo_color = (src as StandardMaterial3D).albedo_color
				fur.roughness = (src as StandardMaterial3D).roughness
				break
	var claw := StandardMaterial3D.new()
	claw.albedo_color = Color("#f5e6d0")
	claw.roughness = 0.5
	var d: Vector3 = dial.global_position
	var palm := MeshInstance3D.new()
	var pm := SphereMesh.new()
	pm.radius = 0.026
	pm.height = 0.052
	pm.material = fur
	palm.mesh = pm
	palm.scale = Vector3(1.25, 0.75, 0.85)
	palm.position = d + Vector3(0.0, -0.006, 0.006)
	add_child(palm)
	var spread := [-0.017, -0.006, 0.006, 0.017]
	for i in 4:
		var base := d + Vector3(spread[i], 0.010, 0.014)
		var knuckle := d + Vector3(spread[i] * 0.8, 0.030, 0.008)
		var tip := d + Vector3(spread[i] * 0.55, 0.044, -0.004)
		_pawtest_segment(base, knuckle, 0.0058, fur)
		_pawtest_segment(knuckle, tip, 0.0045, fur)
		var dir: Vector3 = (tip - knuckle).normalized()
		var claw_tip: Vector3 = tip + dir * 0.012 + Vector3(0.0, -0.006, -0.004)
		_pawtest_segment(tip, claw_tip, 0.0022, claw)


func _build_tractor() -> void:
	var tractor: Node3D = preload("res://scripts/tractor.gd").new()
	tractor.name = "Tractor"
	tractor.position = Vector3(TRACTOR_POS.x, Terrain.height_at(TRACTOR_POS.x, TRACTOR_POS.z), TRACTOR_POS.z)
	tractor.rotation = Vector3(0, 0.7, 0)
	add_child(tractor)


func _build_lake() -> void:
	var lake: Node3D = preload("res://scripts/lake.gd").new()
	lake.name = "Lake"
	lake.position = Vector3(Terrain.lake.center.x, 0, Terrain.lake.center.y)
	add_child(lake)


func _build_bird_tree() -> void:
	var scene: PackedScene = preload("res://assets/tree_ww_round.glb")
	var tree: Node3D = scene.instantiate()
	tree.position = Vector3(BIRD_TREE_POS.x, Terrain.height_at(BIRD_TREE_POS.x, BIRD_TREE_POS.z), BIRD_TREE_POS.z)
	tree.scale = Vector3.ONE * 4.0
	add_child(tree)
	tree.add_to_group("trees")
	trees.append(tree)
	_add_collider(tree, TRUNK_COLLIDER_SIZE / 4.0, Vector3(0, 1.2, 0))


func _log_debug(msg: String) -> void:
	var f := FileAccess.open("res://screenshots/debug.log", FileAccess.WRITE)
	if f:
		f.store_line(msg)
		f.close()


func _build_fence_perimeter() -> void:
	var dist := FENCE_HALF
	var span := dist * 2.0
	var per_edge := maxi(2, int(round(span / FENCE_PANEL_WIDTH)))
	var spacing := span / per_edge
	var start := -dist + spacing / 2.0

	for edge in range(4):
		if edge == 0:
			_build_gate_edge(dist, spacing)
			continue
		for i in range(per_edge):
			var fence: Node3D = FENCE_PANEL.instantiate()
			var off := start + i * spacing
			var pos := Vector3.ZERO
			var rot := 0.0
			match edge:
				1:
					pos = Vector3(dist, 0, off)
					rot = PI / 2.0
				2:
					pos = Vector3(-off, 0, dist)
					rot = PI
				3:
					pos = Vector3(-dist, 0, -off)
					rot = -PI / 2.0
			fence.position = pos
			fence.rotation = Vector3(0, rot, 0)
			add_child(fence)
			_add_fence_collider(fence)


func _build_gate_edge(dist: float, spacing: float) -> void:
	# North edge (faces the farmhouse): gate centred at x=0, panels symmetric on
	# either side at the same spacing as the other edges.
	var items := int(round(dist * 2.0 / spacing)) + 1
	for i in range(items):
		var off := -dist + i * spacing
		if is_equal_approx(off, 0.0):
			var gate: Node3D = preload("res://scripts/gate.gd").new()
			gate.name = "Gate"
			gate.position = Vector3(0, 0, -dist)
			add_child(gate)
			continue
		var fence: Node3D = FENCE_PANEL.instantiate()
		fence.position = Vector3(off, 0, -dist)
		add_child(fence)
		_add_fence_collider(fence)


func _add_fence_collider(parent: Node3D) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(FENCE_PANEL_WIDTH, FENCE_PANEL_HEIGHT, 0.17)
	col.shape = box
	col.position = Vector3(0, FENCE_PANEL_HEIGHT / 2.0, 0)
	body.add_child(col)
	parent.add_child(body)


func _build_trees() -> void:
	for i in range(20):
		var scene: PackedScene = TREE_SCENES[rng.randi_range(0, TREE_SCENES.size() - 1)]
		var tree: Node3D = scene.instantiate()
		var pos := _random_pos(3.0)
		if _too_close_to_landmarks(pos):
			continue
		tree.position = Vector3(pos.x, Terrain.height_at(pos.x, pos.z), pos.z)
		tree.rotation = Vector3(0, rng.randf_range(0, TAU), 0)
		var scale := rng.randf_range(2.6, 4.4)
		tree.scale = Vector3(scale, scale, scale)
		add_child(tree)
		tree.add_to_group("trees")
		trees.append(tree)
		_add_collider(tree, TRUNK_COLLIDER_SIZE / scale, Vector3(0, 1.0, 0))


func _build_rocks() -> void:
	for i in range(12):
		var scene: PackedScene = ROCK_SCENES[rng.randi_range(0, ROCK_SCENES.size() - 1)]
		var rock: Node3D = scene.instantiate()
		var pos := _random_pos(2.0)
		if _too_close_to_landmarks(pos):
			continue
		rock.position = Vector3(pos.x, Terrain.height_at(pos.x, pos.z), pos.z)
		var scale := rng.randf_range(0.7, 1.8)
		rock.scale = Vector3(scale, scale, scale)
		add_child(rock)


func _build_crops() -> void:
	var row := Node3D.new()
	row.position = Vector3(14.5, Terrain.height_at(14.5, -6), -6)
	add_child(row)
	for i in range(6):
		var scene: PackedScene = CROP_SCENES[rng.randi_range(0, CROP_SCENES.size() - 1)]
		var crop: Node3D = scene.instantiate()
		crop.position = Vector3(i * 1.6 - 4.0, 0, 0)
		var scale := rng.randf_range(0.8, 1.3)
		crop.scale = Vector3(scale, scale, scale)
		row.add_child(crop)


func _build_logs() -> void:
	for i in range(5):
		var scene: PackedScene = LOG_SCENES[rng.randi_range(0, LOG_SCENES.size() - 1)]
		var log: Node3D = scene.instantiate()
		var pos := _random_pos(2.0)
		if _too_close_to_landmarks(pos):
			continue
		log.position = Vector3(pos.x, Terrain.height_at(pos.x, pos.z), pos.z)
		log.rotation = Vector3(0, rng.randf_range(0, TAU), 0)
		add_child(log)


func _spawn_pickups() -> void:
	var stick_positions := [
		Vector3(1.5, 0.25, 8.0),
		Vector3(2.6, 0.25, 5.2),
		Vector3(-2.2, 0.25, 9.6),
		Vector3(4.2, 0.25, 10.8),
		Vector3(-3.4, 0.25, 6.0),
		Vector3(6.0, 0.25, -3.0),
		Vector3(0.5, 0.25, -1.0),
	]
	for p in stick_positions:
		var st := preload("res://scripts/pickup.gd").new()
		st.kind = "stick"
		st.position = Vector3(p.x, Terrain.height_at(p.x, p.z) + 0.25, p.z)
		add_child(st)


func _spawn_dumbleclaw() -> void:
	var dc := preload("res://scripts/dumbleclaw.gd").new()
	dc.name = "Dumbleclaw"
	dc.position = Vector3(DUMBLECLAW_POS.x, Terrain.height_at(DUMBLECLAW_POS.x, DUMBLECLAW_POS.z), DUMBLECLAW_POS.z)
	add_child(dc)


func _spawn_mouse() -> void:
	var m := preload("res://scripts/mouse.gd").new()
	m.name = "Mouse"
	m.position = Vector3(MOUSE_POS.x, Terrain.height_at(MOUSE_POS.x, MOUSE_POS.z), MOUSE_POS.z)
	add_child(m)


func _spawn_bird() -> void:
	var b := preload("res://scripts/bird.gd").new()
	b.name = "Bird"
	var anchor := Vector3(BIRD_TREE_POS.x, Terrain.height_at(BIRD_TREE_POS.x, BIRD_TREE_POS.z) + 4.0 * 1.4 + 0.4, BIRD_TREE_POS.z)
	b.anchor = anchor
	b.position = anchor
	add_child(b)


func _add_mesh(parent: Node3D, kind: String, size: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := _mesh(kind, size, color)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _mesh(kind: String, size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh: Mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	match kind:
		"box":
			var bm := BoxMesh.new()
			bm.size = size
			mesh = bm
		"cylinder":
			var cm := CylinderMesh.new()
			cm.top_radius = size.x
			cm.bottom_radius = size.x
			cm.height = size.y
			mesh = cm
		"sphere":
			var sm := SphereMesh.new()
			sm.radius = size.x * 0.5
			sm.height = size.y
			mesh = sm
	mesh.material = mat
	mi.mesh = mesh
	return mi


func _add_collider(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	body.add_child(col)
	parent.add_child(body)


func _random_pos(margin: float) -> Vector3:
	var x := rng.randf_range(-FENCE_HALF + margin, FENCE_HALF - margin)
	var z := rng.randf_range(-FENCE_HALF + margin, FENCE_HALF - margin)
	return Vector3(x, 0, z)


func _too_close_to_landmarks(pos: Vector3) -> bool:
	var lake_center := Vector3(Terrain.lake.center.x, 0, Terrain.lake.center.y)
	for lm in [FARMHOUSE_POS, SHED_POS, TRACTOR_POS, lake_center, BIRD_TREE_POS]:
		if pos.distance_to(lm) < 6.0:
			return true
	return pos.distance_to(Vector3(0, 0, 12)) < 3.0


func _build_path() -> void:
	var dirt := Color(0.6, 0.48, 0.32)
	var dust := Color(0.55, 0.44, 0.3)
	var fence_z := FENCE_HALF
	var path: Node3D = Node3D.new()
	path.name = "Path"
	add_child(path)
	# Main run: gate -> farmhouse door
	var run_len := -FARMHOUSE_POS.z - fence_z - 2.6
	var run_mid := (fence_z + (-FARMHOUSE_POS.z - 2.6)) / 2.0
	_add_mesh(path, "box", Vector3(2.6, 0.06, run_len), Vector3(0, 0.02, -run_mid), dirt)
	# Farmhouse dooryard pad
	_add_mesh(path, "box", Vector3(4.0, 0.06, 3.0), Vector3(0, 0.02, -FARMHOUSE_POS.z + 1.3), dust)
	# Gate pad (just outside the fence)
	_add_mesh(path, "box", Vector3(4.0, 0.06, 2.0), Vector3(0, 0.02, -(fence_z + 1.4)), dust)


func _build_distant_scenery() -> void:
	var spots := [
		Vector3(-44, 0, 40), Vector3(-38, 0, 44), Vector3(46, 0, 42),
		Vector3(40, 0, -44), Vector3(-42, 0, -40), Vector3(44, 0, -30),
		Vector3(30, 0, 46), Vector3(-30, 0, 46), Vector3(46, 0, 20),
		Vector3(-46, 0, 24), Vector3(18, 0, -45), Vector3(-20, 0, -44),
	]
	for s in spots:
		var scene: PackedScene = TREE_SCENES[rng.randi_range(0, TREE_SCENES.size() - 1)]
		var tree: Node3D = scene.instantiate()
		tree.position = Vector3(s.x, Terrain.height_at(s.x, s.z), s.z)
		tree.rotation = Vector3(0, rng.randf_range(0, TAU), 0)
		var scale := rng.randf_range(2.2, 3.6)
		tree.scale = Vector3(scale, scale, scale)
		add_child(tree)
		tree.add_to_group("trees")
