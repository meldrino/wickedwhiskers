extends CharacterBody3D

@export var move_speed := 3.0
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.0035
@export var max_pitch := 1.5

const INTERACT_RANGE := 1.8

var gravity: float
var yaw := 0.0
var pitch := 0.2
var cat_facing := 0.0
var current_interactable: Interactable = null
var destination := Vector3.ZERO
var has_destination := false
var walking := false
var _left_held := false
var _right_held := false
var pending_interact: Interactable = null
var _press_pos := Vector2.ZERO
var _press_moved := false
var _last_look_time := -100000
var _waiting_cam := false
var _wait_target := Vector3.ZERO
var camera_distance := 1.8
var camera_frozen := false
var skeleton: Skeleton3D
var cat_model: Node3D
var bone_idx := {}
var walk_time := 0.0
var idle_time := 0.0
var hop_t := 0.0
var _pending_fish := false
var _fish_cd := 0
var _pounce_t := -1.0
var _pounce_phase := 0
var _pounce_origin := Vector3.ZERO
var _pounce_target := Vector3.ZERO
var _clicked_fish: Node3D = null
var _shake_t := 0.0
var wet_time := 0.0
var _wet_meshes: Array = []
var _drip: CPUParticles3D = null

const POUNCE_IN_DUR := 0.55
const POUNCE_OUT_DUR := 0.7
const POUNCE_WET_DUR := 0.9
const POUNCE_HEIGHT := 0.5
const POUNCE_DIST := 2.2
const WET_TIME := 5.0

const ANIM_BONES := [
	"Thigh.L", "Thigh.R", "Shin.L", "Shin.R", "Foot.L", "Foot.R",
	"Toe.L", "Toe.R", "UpperArm.L", "UpperArm.R", "Forearm.L", "Forearm.R",
	"Hand.L", "Hand.R", "Spine", "Chest", "Head", "Ear.L", "Ear.R",
	"Tail01", "Tail02", "Tail03",
]

@onready var camera: Camera3D = $CameraHolder/Camera
@onready var camera_holder: Node3D = $CameraHolder
@onready var mesh_root: Node3D = $MeshRoot


func _ready() -> void:
	add_to_group("player")
	gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
	cat_facing = rotation.y
	yaw = rotation.y + PI
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_cat()


func _unhandled_input(event: InputEvent) -> void:
	if _pouncing():
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_left_held = true
				_press_pos = event.position
				_press_moved = false
				_try_start_walk()
			else:
				_left_held = false
				if not _press_moved:
					_handle_click_at(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				if not Hud.any_panel_open():
					_right_held = true
					_waiting_cam = false
					_wait_target = Vector3.ZERO
					Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				_right_held = false
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				camera_distance -= 0.25 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.25
				camera_distance = clampf(camera_distance, 0.9, 12.0)
				camera.position.z = camera_distance
	elif event is InputEventMouseMotion:
		_last_look_time = Time.get_ticks_msec()
		if _left_held and not _press_moved and event.position.distance_to(_press_pos) > 8.0:
			_press_moved = true
		if _right_held and not _look_suspended():
			yaw -= event.relative.x * mouse_sensitivity
			pitch -= event.relative.y * mouse_sensitivity
			_clamp_pitch()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E:
				_do_interact()
			KEY_1:
				_try_craft_trap()
			KEY_2:
				_try_craft_ladder()
			KEY_F:
				_try_eat()


func _look_suspended() -> bool:
	if _waiting_cam:
		return true
	if Hud.any_panel_open():
		return true
	return false


func _mouse_recent(ms: int) -> bool:
	return Time.get_ticks_msec() - _last_look_time < ms


func set_interactable(item) -> void:
	current_interactable = item


func _pick_interactable(screen_pos: Vector2) -> Interactable:
	var from := camera.project_ray_origin(screen_pos)
	var best: Interactable = null
	var best_d := INF
	var vp_size := get_viewport().get_visible_rect().size
	for item in get_tree().get_nodes_in_group("interactable"):
		var it := item as Interactable
		if it == null:
			continue
		var wp := it.get_interaction_point()
		var to_item: Vector3 = wp - from
		if to_item.length() > 50.0:
			continue
		if to_item.normalized().dot(camera.global_transform.basis.z) >= -0.05:
			continue
		var sp := camera.unproject_position(wp)
		if sp.x < 0.0 or sp.y < 0.0 or sp.x > vp_size.x or sp.y > vp_size.y:
			continue
		var d := sp.distance_to(screen_pos)
		if d < best_d:
			best_d = d
			best = it
	if best == null or best_d > 40.0:
		return null
	# Occlusion: a solid wall/fence between the camera and the object blocks the
	# click — but never the object's own colliders (e.g. the gate panel).
	var wp2 := best.get_interaction_point()
	var dir := (wp2 - from).normalized()
	var qa := PhysicsRayQueryParameters3D.create(from, wp2 + dir * 0.3)
	qa.collide_with_areas = false
	qa.collide_with_bodies = true
	var rids: Array[RID] = [get_rid()]
	_collect_rids(best, rids)
	qa.exclude = rids
	var hb := get_world_3d().direct_space_state.intersect_ray(qa)
	if not hb.is_empty():
		var body_dist := from.distance_to(hb.get("position"))
		if body_dist < from.distance_to(wp2) - 0.2:
			return null
	return best


func _collect_rids(node: Node, rids: Array[RID]) -> void:
	for child in node.get_children():
		if child is CollisionObject3D:
			rids.append(child.get_rid())
		_collect_rids(child, rids)


func _pick_fish(screen_pos: Vector2) -> Node3D:
	var from := camera.project_ray_origin(screen_pos)
	var best: Node3D = null
	var best_d := INF
	var vp_size := get_viewport().get_visible_rect().size
	for f in get_tree().get_nodes_in_group("fish"):
		var node := f as Node3D
		if node == null:
			continue
		var wp := node.global_position
		var to_item: Vector3 = wp - from
		if to_item.length() > 50.0:
			continue
		if to_item.normalized().dot(camera.global_transform.basis.z) >= -0.05:
			continue
		var sp := camera.unproject_position(wp)
		if sp.x < 0.0 or sp.y < 0.0 or sp.x > vp_size.x or sp.y > vp_size.y:
			continue
		var d := sp.distance_to(screen_pos)
		if d < best_d:
			best_d = d
			best = node
	if best == null or best_d > 40.0:
		return null
	return best


func _pitch_min() -> float:
	var d := camera_distance
	var h := camera_holder.position.y
	var cam_pos := camera_holder.to_global(camera.position)
	var t := Terrain.height_at(cam_pos.x, cam_pos.z) + 0.15
	return asin(clampf((t - global_position.y - h) / d, -1.0, 1.0))


func _clamp_pitch() -> void:
	pitch = clampf(pitch, _pitch_min(), max_pitch)


func _clamp_camera_in_room() -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.name != "Shed":
		return
	var cam := camera_holder.to_global(camera.position)
	var half := Vector3(2.25, 1.35, 1.65)
	var clamped := Vector3(
		clampf(cam.x, -half.x, half.x),
		clampf(cam.y, 0.25, half.y),
		clampf(cam.z, -half.z, half.z))
	if clamped != cam:
		camera.position = camera_holder.to_local(clamped)


func walk_to(pos: Vector3) -> void:
	destination = pos
	has_destination = true
	walking = true


func stop_walk() -> void:
	has_destination = false
	walking = false


func _handle_click_at(screen_pos: Vector2) -> void:
	if GameState.chase_active or Hud.any_panel_open():
		return
	if _pouncing():
		return
	var fish := _pick_fish(screen_pos)
	if fish != null:
		_try_fish(fish)
		return
	if has_destination:
		return
	_waiting_cam = false
	_wait_target = Vector3.ZERO
	var item := _pick_interactable(screen_pos)
	if item != null:
		if _within_interact_range(item):
			item.interact()
		else:
			_go_interact(item)
		return
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var qa := PhysicsRayQueryParameters3D.create(from, from + dir * 80.0)
	qa.collide_with_bodies = true
	qa.collide_with_areas = false
	qa.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(qa)
	if hit.is_empty():
		return
	var gp: Vector3 = hit.get("position")
	if Terrain.in_water(gp.x, gp.z):
		_try_fish(null)
		return
	_request_walk(Vector3(gp.x, 0, gp.z))


func _try_start_walk() -> void:
	if GameState.chase_active or Hud.any_panel_open():
		return
	_waiting_cam = false
	_wait_target = Vector3.ZERO
	var item := _pick_interactable(get_viewport().get_mouse_position())
	if item != null:
		if not _within_interact_range(item):
			_go_interact(item)
		return
	_walk_to_screen_point(get_viewport().get_mouse_position())


func _request_walk(point: Vector3, keep_pending := false) -> bool:
	if not keep_pending:
		pending_interact = null
	var to: Vector3 = point - global_position
	to.y = 0.0
	if to.length() < 0.35:
		return false
	var behind := atan2(to.x, to.z) + PI
	if absf(angle_difference(yaw, behind)) > 0.6:
		_waiting_cam = true
		_wait_target = point
	else:
		walk_to(point)
	return true


func _go_interact(item: Interactable) -> void:
	pending_interact = item
	var p := item.get_interaction_point()
	_request_walk(Vector3(p.x, 0, p.z), true)


func _try_fish(fish: Node3D) -> void:
	if GameState.chase_active or Hud.any_panel_open():
		return
	if _pouncing():
		return
	if Time.get_ticks_msec() < _fish_cd:
		return
	stop_walk()
	_clicked_fish = fish
	_waiting_cam = false
	_wait_target = Vector3.ZERO
	var to_lake: Vector2 = Vector2(
		Terrain.lake.center.x - global_position.x,
		Terrain.lake.center.y - global_position.z)
	if to_lake.length() < 0.01:
		return
	var dir := to_lake.normalized()
	var r := Terrain.shore_distance(dir)
	var shore := Vector3(
		Terrain.lake.center.x + dir.x * (r - 0.4),
		0,
		Terrain.lake.center.y + dir.y * (r - 0.4))
	_pending_fish = true
	if not _request_walk(shore, true):
		_pending_fish = false
		_start_pounce()


func _pouncing() -> bool:
	return _pounce_t >= 0.0


func _start_pounce() -> void:
	_fish_cd = Time.get_ticks_msec() + 8000
	_pounce_phase = 0
	_pounce_t = 0.0
	_pounce_origin = global_position
	var to_lake: Vector2 = Vector2(
		Terrain.lake.center.x - global_position.x,
		Terrain.lake.center.y - global_position.z)
	var dir := to_lake.normalized()
	cat_facing = atan2(dir.x, dir.y)
	_pounce_target = _pounce_origin + Vector3(dir.x, 0.0, dir.y) * POUNCE_DIST
	_pounce_target.y = Terrain.water_level
	velocity = Vector3.ZERO
	camera_frozen = true


func _update_pounce(delta: float) -> void:
	_pounce_t += delta
	var pitch_dive := 0.0
	if _pounce_phase == 0:
		var k := clampf(_pounce_t / POUNCE_IN_DUR, 0.0, 1.0)
		var pos := _pounce_origin.lerp(_pounce_target, k)
		pos.y = lerpf(_pounce_origin.y, _pounce_target.y, k) + sin(k * PI) * POUNCE_HEIGHT
		global_position = pos
		pitch_dive = lerpf(0.0, -1.25, k)
		if _pounce_t >= POUNCE_IN_DUR:
			_pounce_t = 0.0
			_pounce_phase = 1
			_do_splash()
	elif _pounce_phase == 1:
		var k := clampf(_pounce_t / POUNCE_WET_DUR, 0.0, 1.0)
		global_position = _pounce_target + Vector3(0.0, -sin(k * PI) * 0.32, 0.0)
		pitch_dive = -0.3
		if _pounce_t >= POUNCE_WET_DUR:
			_pounce_t = 0.0
			_pounce_phase = 2
	else:
		var k := clampf(_pounce_t / POUNCE_OUT_DUR, 0.0, 1.0)
		var pos := _pounce_target.lerp(_pounce_origin, k)
		pos.y = lerpf(_pounce_target.y, _pounce_origin.y, k) + sin(k * PI) * 0.9
		global_position = pos
		pitch_dive = lerpf(-0.3, 0.0, k)
		if _pounce_t >= POUNCE_OUT_DUR:
			_finish_pounce()
	mesh_root.rotation = Vector3(pitch_dive, cat_facing, 0.0)


func _do_splash() -> void:
	var lake_node := get_tree().current_scene.get_node_or_null("Lake")
	if lake_node != null and lake_node.has_method("splash"):
		lake_node.splash(global_position)
	if _clicked_fish != null and is_instance_valid(_clicked_fish):
		var school: Node = _clicked_fish.get_meta("school", null)
		if school != null:
			school.call("taunt", _clicked_fish)


func _finish_pounce() -> void:
	_pounce_t = -1.0
	camera_frozen = false
	wet_time = WET_TIME
	_shake_t = 0.0
	velocity = Vector3.ZERO
	_wet_cat(true)
	if _drip != null:
		_drip.emitting = true
	_clicked_fish = null
	Hud.show_dialogue([
		"Fish: Ha Ha Whiskers — you can't reach me and there is no-fin you can do about it!",
		"Whiskers: (climbs back onto the bank, soaked and dripping, and glares at the smug goldfish.)",
	])


func _wet_cat(wet: bool) -> void:
	for entry in _wet_meshes:
		var mi: MeshInstance3D = entry["mesh"]
		var orig: Dictionary = entry["orig"]
		if wet:
			for i in range(mi.mesh.get_surface_count()):
				if i in orig:
					continue
				var src: Material = mi.surface_get_material(i)
				orig[i] = src
				if src is StandardMaterial3D:
					var m: StandardMaterial3D = src.duplicate()
					m.albedo_color = Color(
						m.albedo_color.r * 0.55,
						m.albedo_color.g * 0.6,
						m.albedo_color.b * 0.75,
						m.albedo_color.a)
					m.metallic = maxf(m.metallic, 0.3)
					m.roughness = 0.12
					mi.set_surface_override_material(i, m)
		else:
			for i in orig.keys():
				mi.set_surface_override_material(i, null)
			orig.clear()


func _within_interact_range(item: Interactable) -> bool:
	var p := item.get_interaction_point()
	p.y = global_position.y
	return global_position.distance_to(p) <= INTERACT_RANGE


func _walk_to_screen_point(screen_pos: Vector2) -> bool:
	pending_interact = null
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var qa := PhysicsRayQueryParameters3D.create(from, from + dir * 80.0)
	qa.collide_with_bodies = true
	qa.collide_with_areas = false
	qa.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(qa)
	if hit.is_empty():
		return false
	var gp: Vector3 = hit.get("position")
	if gp.distance_to(global_position) < 0.35:
		return false
	walk_to(Vector3(gp.x, 0, gp.z))
	return true


func _do_interact() -> void:
	if Hud.is_dialogue_open():
		Hud.advance_dialogue()
		return
	if current_interactable != null:
		current_interactable.interact()


func _try_craft_trap() -> void:
	if Hud.is_dialogue_open():
		return
	if GameState.trap_placed:
		Hud.toast("You already have a convoluted mouse trap placed.")
		return
	if not GameState.can_afford_trap():
		Hud.toast("Need 1 string + 2 sticks for a convoluted mouse trap.")
		return
	GameState.spend_trap()
	GameState.trap_placed = true
	var trap := preload("res://scripts/trap.gd").new()
	var place := global_position + (-camera_holder.global_basis.z) * 2.2
	place.y = Terrain.height_at(place.x, place.z)
	trap.position = place
	get_tree().current_scene.add_child(trap)
	Hud.toast("You build a convoluted mouse trap! Now lure a mouse...")


func _try_craft_ladder() -> void:
	if Hud.is_dialogue_open():
		return
	if GameState.ladder_placed:
		Hud.toast("You already have a ladder placed.")
		return
	if not GameState.can_afford_ladder():
		Hud.toast("Need 1 string + 2 sticks for a ladder.")
		return
	GameState.spend_ladder()
	GameState.ladder_placed = true
	var ladder := preload("res://scripts/ladder.gd").new()
	var place := global_position + (-camera_holder.global_basis.z) * 2.2
	place.y = Terrain.height_at(place.x, place.z)
	ladder.position = place
	get_tree().current_scene.add_child(ladder)
	Hud.toast("You prop up a ladder. It leans toward the sky — and the birds.")


func _try_eat() -> void:
	if Hud.any_panel_open():
		return
	if GameState.eat_food():
		Hud.toast("You tuck into your food. Hunger back to full. (Munch, munch.)")
	else:
		Hud.toast("Nothing to eat! Catch a mouse or bird — or check the farmhouse at dawn.")


func _physics_process(delta: float) -> void:
	if _pounce_t >= 0.0:
		_update_pounce(delta)
		_animate_cat(delta)
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = jump_velocity
	if GameState.chase_active and is_on_floor():
		hop_t -= delta
		if hop_t <= 0.0:
			hop_t = 0.45
			velocity.y = jump_velocity * 0.7

	var move_dir := Vector3.ZERO
	var wasd := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		wasd.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		wasd.y -= 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		wasd.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		wasd.x += 1.0
	var moving_keys := wasd != Vector2.ZERO

	if moving_keys and not GameState.chase_active and not Hud.any_panel_open():
		pending_interact = null
		_waiting_cam = false
		_wait_target = Vector3.ZERO
		has_destination = false
		walking = true
		var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		move_dir = (fwd * wasd.y + right * wasd.x).normalized()
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed
	elif _waiting_cam:
		var to: Vector3 = _wait_target - global_position
		to.y = 0.0
		if to.length() < 0.35 or GameState.chase_active or Hud.any_panel_open():
			_waiting_cam = false
			_wait_target = Vector3.ZERO
		else:
			walking = false
			velocity.x = move_toward(velocity.x, 0.0, move_speed)
			velocity.z = move_toward(velocity.z, 0.0, move_speed)
			var behind := atan2(to.x, to.z) + PI
			yaw = lerp_angle(yaw, behind, 6.0 * delta)
			if absf(angle_difference(yaw, behind)) < 0.15:
				_waiting_cam = false
				walk_to(_wait_target)
				_wait_target = Vector3.ZERO
	elif has_destination:
		var to: Vector3 = destination - global_position
		to.y = 0.0
		if to.length() < 0.35:
			has_destination = false
			walking = false
			velocity.x = move_toward(velocity.x, 0.0, move_speed)
			velocity.z = move_toward(velocity.z, 0.0, move_speed)
			if _pending_fish:
				_pending_fish = false
				_start_pounce()
			if pending_interact != null:
				var it := pending_interact
				pending_interact = null
				if is_instance_valid(it) and _within_interact_range(it):
					it.interact()
		else:
			var dir := to.normalized()
			move_dir = dir
			velocity.x = dir.x * move_speed
			velocity.z = dir.z * move_speed
	elif _left_held and not GameState.chase_active and not Hud.any_panel_open():
		if _press_moved:
			if not _walk_to_screen_point(get_viewport().get_mouse_position()):
				velocity.x = move_toward(velocity.x, 0.0, move_speed)
				velocity.z = move_toward(velocity.z, 0.0, move_speed)
			else:
				move_dir = (destination - global_position)
				move_dir.y = 0.0
				move_dir = move_dir.normalized()
		else:
			velocity.x = move_toward(velocity.x, 0.0, move_speed)
			velocity.z = move_toward(velocity.z, 0.0, move_speed)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)

	move_and_slide()

	if walking and move_dir != Vector3.ZERO:
		cat_facing = atan2(move_dir.x, move_dir.z)
	mesh_root.rotation.y = lerp_angle(mesh_root.rotation.y, cat_facing, 14.0 * delta)
	if not camera_frozen:
		if walking and not _waiting_cam and not moving_keys and not _mouse_recent(350):
			yaw = lerp_angle(yaw, cat_facing + PI, 2.5 * delta)
		_clamp_pitch()
		camera_holder.rotation = Vector3(-pitch, yaw, 0.0)
		_clamp_camera_in_room()

	if Hud.is_dialogue_open():
		Hud.set_prompt("")
	else:
		var hover := _pick_interactable(get_viewport().get_mouse_position())
		if hover != null and not _within_interact_range(hover):
			hover = null
		Hud.set_prompt(hover.prompt if hover != null else "")

	_animate_cat(delta)


func _animate_cat(delta: float) -> void:
	if skeleton == null or bone_idx.is_empty():
		return
	if _pounce_t >= 0.0:
		_animate_pounce()
		return
	if wet_time > 0.0:
		wet_time -= delta
		if _drip != null:
			_drip.emitting = wet_time > 0.0
		if wet_time <= 0.0:
			_wet_cat(false)
		else:
			_animate_wet(delta)
		return
	var poses := {}
	if walking:
		walk_time += delta * velocity.length() * 5.2
		var s := sin(walk_time)
		# swing phases: LH/LF forward when s<0, RH/RF forward when s>0 (diagonal trot)
		var sw_l := maxf(0.0, -s)
		var sw_r := maxf(0.0, s)
		poses["Thigh.L"] = Vector3(0.45 * s, 0.0, 0.03 * s)
		poses["Thigh.R"] = Vector3(-0.45 * s, 0.0, -0.03 * s)
		poses["Shin.L"] = Vector3(0.20 * sw_l, 0.0, 0.0)
		poses["Shin.R"] = Vector3(0.20 * sw_r, 0.0, 0.0)
		poses["Foot.L"] = Vector3(0.05 * sw_l, 0.0, 0.0)
		poses["Foot.R"] = Vector3(0.05 * sw_r, 0.0, 0.0)
		poses["Toe.L"] = Vector3(0.03 * sw_l, 0.0, 0.0)
		poses["Toe.R"] = Vector3(0.03 * sw_r, 0.0, 0.0)
		# front legs diagonal to the hind legs
		poses["UpperArm.L"] = Vector3(-0.35 * s, 0.0, -0.03 * s)
		poses["UpperArm.R"] = Vector3(0.35 * s, 0.0, 0.03 * s)
		poses["Forearm.L"] = Vector3(0.12 * sw_l, 0.0, 0.0)
		poses["Forearm.R"] = Vector3(0.12 * sw_r, 0.0, 0.0)
		poses["Hand.L"] = Vector3(0.04 * sw_l, 0.0, 0.0)
		poses["Hand.R"] = Vector3(0.04 * sw_r, 0.0, 0.0)
		# body rock + tail swish; body sinks so the stance paws stay planted
		poses["Spine"] = Vector3(0.06 * s, 0.0, 0.0)
		poses["Tail01"] = Vector3(0.0, 0.0, 0.14 * s)
		poses["Tail02"] = Vector3(0.0, 0.0, 0.18 * s)
		poses["Tail03"] = Vector3(0.0, 0.0, 0.12 * s)
		cat_model.position.y = -0.0021 - (1.0 - cos(0.45 * absf(s))) * 0.12
	else:
		idle_time += delta
		var ph := idle_time
		var breath := sin(ph * 2.0) * 0.04
		poses["Chest"] = Vector3(breath, 0.0, 0.0)
		poses["Spine"] = Vector3(-breath * 0.6, 0.0, 0.0)
		poses["Head"] = Vector3(sin(ph * 0.8) * 0.05, sin(ph * 0.5) * 0.04, 0.0)
		var sway := sin(ph * 1.3)
		poses["Tail01"] = Vector3(0.0, 0.0, 0.16 * sway)
		poses["Tail02"] = Vector3(0.0, 0.0, 0.22 * sway)
		poses["Tail03"] = Vector3(0.0, 0.0, 0.14 * sway)
		var ear_ph := fmod(ph, 4.5)
		if ear_ph < 0.35:
			var k := sin(ear_ph / 0.35 * PI)
			poses["Ear.L"] = Vector3(0.14 * k, 0.0, 0.0)
			poses["Ear.R"] = Vector3(-0.14 * k, 0.0, 0.0)
	_apply_poses(poses)


func _animate_pounce() -> void:
	var poses := {}
	match _pounce_phase:
		0:
			var k := clampf(_pounce_t / POUNCE_IN_DUR, 0.0, 1.0)
			var s := sin(k * PI)
			poses["Spine"] = Vector3(0.3 * s, 0.0, 0.0)
			poses["Chest"] = Vector3(0.12 * s, 0.0, 0.0)
			poses["Head"] = Vector3(0.35 * s, -0.1 * s, -0.35 * s)
			poses["UpperArm.L"] = Vector3(-1.5, 0.0, 1.0)
			poses["UpperArm.R"] = Vector3(-1.5, 0.0, 1.0)
			poses["Forearm.L"] = Vector3(0.9, 0.0, 0.3)
			poses["Forearm.R"] = Vector3(0.9, 0.0, 0.3)
			poses["Thigh.L"] = Vector3(0.85, 0.0, 0.5)
			poses["Thigh.R"] = Vector3(0.85, 0.0, 0.5)
			poses["Shin.L"] = Vector3(-0.5, 0.0, 0.0)
			poses["Shin.R"] = Vector3(-0.5, 0.0, 0.0)
			poses["Tail01"] = Vector3(0.0, 0.0, 0.5)
			poses["Tail02"] = Vector3(0.0, 0.0, 0.6)
			poses["Tail03"] = Vector3(0.0, 0.0, 0.4)
		1:
			var s2 := sin(_pounce_t * 22.0)
			poses["UpperArm.L"] = Vector3(0.9 * s2, 0.0, -0.4)
			poses["UpperArm.R"] = Vector3(0.9 * -s2, 0.0, -0.4)
			poses["Forearm.L"] = Vector3(-0.4, 0.0, 0.0)
			poses["Forearm.R"] = Vector3(-0.4, 0.0, 0.0)
			poses["Thigh.L"] = Vector3(0.9 * -s2, 0.0, 0.3)
			poses["Thigh.R"] = Vector3(0.9 * s2, 0.0, 0.3)
			poses["Shin.L"] = Vector3(0.3, 0.0, 0.0)
			poses["Shin.R"] = Vector3(0.3, 0.0, 0.0)
			poses["Head"] = Vector3(0.0, 0.1, -0.2)
			poses["Spine"] = Vector3(0.0, 0.0, 0.0)
			poses["Tail01"] = Vector3(0.0, 0.0, 0.5)
		2:
			var k2 := clampf(_pounce_t / POUNCE_OUT_DUR, 0.0, 1.0)
			var s3 := sin(k2 * PI)
			poses["Chest"] = Vector3(-0.15 * s3, 0.0, 0.0)
			poses["Spine"] = Vector3(0.3 * s3, 0.0, 0.0)
			poses["Head"] = Vector3(0.0, 0.2 * s3, -0.15 * s3)
			poses["UpperArm.L"] = Vector3(-0.9, 0.0, 0.3)
			poses["UpperArm.R"] = Vector3(-0.9, 0.0, 0.3)
			poses["Forearm.L"] = Vector3(0.6, 0.0, 0.0)
			poses["Forearm.R"] = Vector3(0.6, 0.0, 0.0)
			poses["Thigh.L"] = Vector3(0.6, 0.0, -0.4)
			poses["Thigh.R"] = Vector3(0.6, 0.0, -0.4)
			poses["Shin.L"] = Vector3(-0.3, 0.0, 0.0)
			poses["Shin.R"] = Vector3(-0.3, 0.0, 0.0)
			poses["Tail01"] = Vector3(0.0, 0.0, -0.4)
	_apply_poses(poses)


func _animate_wet(delta: float) -> void:
	_shake_t += delta
	var poses := {}
	poses["Spine"] = Vector3(0.35, 0.0, 0.0)
	poses["Chest"] = Vector3(0.22, 0.0, 0.0)
	poses["Head"] = Vector3(0.0, 0.35, 0.0)
	poses["Ear.L"] = Vector3(-0.3, 0.0, 0.0)
	poses["Ear.R"] = Vector3(0.3, 0.0, 0.0)
	poses["Tail01"] = Vector3(0.0, 0.0, 0.3)
	poses["Tail02"] = Vector3(0.0, 0.0, 0.35)
	poses["Tail03"] = Vector3(0.0, 0.0, 0.2)
	var shake := sin(_shake_t * 9.0)
	if fmod(_shake_t, 1.4) < 0.25:
		poses["Chest"] = Vector3(0.22 + 0.15 * shake, 0.0, 0.0)
		poses["Spine"] = Vector3(0.35 - 0.2 * shake, 0.0, 0.0)
		poses["Head"] = Vector3(0.25 * shake, 0.35, 0.0)
	_apply_poses(poses)


func _apply_poses(poses: Dictionary) -> void:
	var axis_z := Vector3(0.0, 0.0, 1.0)
	for bone_name in bone_idx:
		var idx: int = bone_idx[bone_name]
		var rest_q: Quaternion = skeleton.get_bone_rest(idx).basis.get_rotation_quaternion()
		var delta := Quaternion.IDENTITY
		if bone_name in poses:
			var v: Vector3 = poses[bone_name]
			delta = Quaternion(Vector3.RIGHT, v.x) * Quaternion(Vector3.UP, v.y) * Quaternion(axis_z, v.z)
		skeleton.set_bone_pose_rotation(idx, rest_q * delta)


func _build_cat() -> void:
	var glb: PackedScene = load("res://assets/WW.glb")
	if glb == null:
		push_error("WW.glb failed to import — falling back to primitives")
		_build_cat_primitive()
	else:
		var model := glb.instantiate()
		model.scale = Vector3.ONE * 0.19
		model.position = Vector3(0, -0.0021, 0)
		mesh_root.add_child(model)
		mesh_root.scale = Vector3.ONE
		cat_model = model
		for child in model.find_children("*", "Skeleton3D", true, false):
			skeleton = child
			break
		if skeleton != null:
			for bone_name in ANIM_BONES:
				var bi := skeleton.find_bone(bone_name)
				if bi >= 0:
					bone_idx[bone_name] = bi
	_collect_wet_meshes()
	_setup_drip()


func _collect_wet_meshes() -> void:
	_wet_meshes.clear()
	for child in mesh_root.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi != null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
			_wet_meshes.append({"mesh": mi, "orig": {}})


func _setup_drip() -> void:
	_drip = CPUParticles3D.new()
	_drip.name = "Drip"
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.8, 0.92, 1.0, 0.85)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var bm := BoxMesh.new()
	bm.size = Vector3(0.03, 0.03, 0.03)
	bm.material = dm
	_drip.mesh = bm
	_drip.amount = 20
	_drip.lifetime = 0.7
	_drip.one_shot = false
	_drip.emitting = false
	_drip.direction = Vector3(0, -1, 0)
	_drip.spread = 30.0
	_drip.gravity = Vector3(0, -4.0, 0)
	_drip.initial_velocity_min = 0.3
	_drip.initial_velocity_max = 0.8
	_drip.scale_amount_min = 0.7
	_drip.scale_amount_max = 1.3
	_drip.position = Vector3(0, 0.42, 0)
	if cat_model != null:
		cat_model.add_child(_drip)
	else:
		mesh_root.add_child(_drip)


func _build_cat_primitive() -> void:
	var orange := StandardMaterial3D.new()
	orange.albedo_color = Color(0.92, 0.55, 0.2)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.96, 0.96, 0.92)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.15, 0.12, 0.1)

	# body
	var body := _mesh("box", Vector3(0.75, 0.55, 1.1), orange)
	body.position = Vector3(0, 0.55, 0.0)
	mesh_root.add_child(body)

	# legs / paws
	for x in [-0.24, 0.24]:
		for z in [-0.35, 0.35]:
			var leg := _mesh("box", Vector3(0.16, 0.22, 0.16), dark)
			leg.position = Vector3(x, 0.11, z)
			mesh_root.add_child(leg)

	# head
	var head := _mesh("sphere", Vector3(0.6, 0.6, 0.6), orange)
	head.position = Vector3(0, 0.85, 0.62)
	mesh_root.add_child(head)

	# muzzle
	var muzzle := _mesh("sphere", Vector3(0.36, 0.26, 0.28), white)
	muzzle.position = Vector3(0, 0.78, 0.92)
	mesh_root.add_child(muzzle)

	# eyes
	for x in [-0.13, 0.13]:
		var eye := _mesh("sphere", Vector3(0.12, 0.12, 0.06), dark)
		eye.position = Vector3(x, 0.9, 0.88)
		mesh_root.add_child(eye)

	# ears
	for x in [-0.2, 0.2]:
		var ear := _mesh("box", Vector3(0.18, 0.26, 0.14), orange)
		ear.position = Vector3(x, 1.12, 0.66)
		ear.rotation = Vector3(-0.35, 0.0, x * -0.35)
		mesh_root.add_child(ear)

	# tail
	var tail := _mesh("box", Vector3(0.1, 0.1, 0.85), orange)
	tail.position = Vector3(0, 0.72, -0.6)
	tail.rotation = Vector3(0.6, 0.0, 0.0)
	mesh_root.add_child(tail)

	mesh_root.scale = Vector3(0.33, 0.33, 0.33)


func _mesh(kind: String, size: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh: Mesh
	match kind:
		"box":
			var bm := BoxMesh.new()
			bm.size = size
			mesh = bm
		"sphere":
			var sm := SphereMesh.new()
			sm.radius = size.x * 0.5
			sm.height = size.y
			mesh = sm
	mi.mesh = mesh
	mesh.material = mat
	return mi
