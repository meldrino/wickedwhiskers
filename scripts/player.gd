extends CharacterBody3D

@export var move_speed := 4.5
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.0035
@export var max_pitch := 1.0

var gravity: float
var yaw := 0.0
var pitch := 0.2
var current_interactable: Interactable = null
var destination := Vector3.ZERO
var has_destination := false
var walking := false
var drag_active := false
var drag_start := Vector2.ZERO
var drag_moved := false
var camera_distance := 1.8
var camera_frozen := false
var skeleton: Skeleton3D
var cat_model: Node3D
var bone_idx := {}
var walk_time := 0.0
var idle_time := 0.0
var hop_t := 0.0

const ANIM_BONES := [
	"Thigh.L", "Thigh.R", "Shin.L", "Shin.R", "Foot.L", "Foot.R",
	"Toe.L", "Toe.R", "UpperArm.L", "UpperArm.R", "Forearm.L", "Forearm.R",
	"Hand.L", "Hand.R", "Spine", "Chest", "Head", "Ear.L", "Ear.R",
	"Tail01", "Tail02", "Tail03",
]

# Shed interior volume (world-aligned) used to keep the camera inside the walls.
const SHED_CENTER := Vector3(16, 0, -10)
const SHED_HALF := Vector3(2.1, 0, 1.5)
const SHED_WALL_CLEAR := 0.15

@onready var camera: Camera3D = $CameraHolder/Camera
@onready var camera_holder: Node3D = $CameraHolder
@onready var mesh_root: Node3D = $MeshRoot


func _ready() -> void:
	add_to_group("player")
	gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
	yaw = rotation.y
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_cat()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			drag_active = true
			drag_start = event.position
			drag_moved = false
		else:
			drag_active = false
			if not drag_moved:
				_handle_click_at(event.position)
	elif event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		if event.pressed:
			camera_distance -= 0.25 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.25
			camera_distance = clampf(camera_distance, 0.9, 4.5)
			camera.position.z = camera_distance
	elif event is InputEventMouseMotion and drag_active:
		if not drag_moved and event.position.distance_to(drag_start) > 8.0:
			drag_moved = true
		if drag_moved:
			yaw -= event.relative.x * mouse_sensitivity
			pitch -= event.relative.y * mouse_sensitivity
			pitch = clampf(pitch, -max_pitch, _pitch_max())
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E:
				_do_interact()
			KEY_1:
				_try_craft_trap()
			KEY_2:
				_try_craft_ladder()
			KEY_3:
				_try_craft_rod()
			KEY_F:
				_try_eat()


func set_interactable(item) -> void:
	current_interactable = item


func _pitch_max() -> float:
	var height := camera_holder.position.y
	return asin(clampf((height - 0.1) / camera_distance, -1.0, 1.0))


func _clamp_camera_in_shed() -> void:
	var p := global_position - SHED_CENTER
	if absf(p.x) > SHED_HALF.x or absf(p.z) > SHED_HALF.z:
		return
	var cam_world := camera_holder.to_global(camera.position)
	var c := cam_world - SHED_CENTER
	var clamped := Vector3(
		clampf(c.x, -SHED_HALF.x + SHED_WALL_CLEAR, SHED_HALF.x - SHED_WALL_CLEAR),
		clampf(c.y, 0.15, 3.0 - SHED_WALL_CLEAR),
		clampf(c.z, -SHED_HALF.z + SHED_WALL_CLEAR, SHED_HALF.z - SHED_WALL_CLEAR))
	if clamped != c:
		camera.position = camera_holder.to_local(SHED_CENTER + clamped)


func walk_to(pos: Vector3) -> void:
	destination = pos
	has_destination = true
	walking = true


func stop_walk() -> void:
	has_destination = false
	walking = false


func _handle_click_at(screen_pos: Vector2) -> void:
	if GameState.chase_active:
		return
	if Hud.any_panel_open():
		return
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var to := from + dir * 100.0
	# Ground point under the cursor (used for click-to-move).
	var has_ground := false
	var ground_dist := INF
	if dir.y < -0.0001:
		var t := -from.y / dir.y
		if t > 0.0:
			has_ground = true
			ground_dist = t
	# Interactables (areas) — a click only counts as an interaction when the
	# object is closer to the camera than the ground under the cursor, i.e. the
	# cursor is actually on the object rather than on the dirt in front of it.
	var qa := PhysicsRayQueryParameters3D.create(from, to)
	qa.collide_with_areas = true
	qa.collide_with_bodies = false
	qa.exclude = [get_rid()]
	var ha := get_world_3d().direct_space_state.intersect_ray(qa)
	if not ha.is_empty():
		var c: Object = ha.get("collider")
		if c is Interactable:
			var hit_dist := from.distance_to(ha.get("position"))
			if not has_ground or hit_dist < ground_dist - 0.05:
				c.interact()
				return
	if has_ground:
		var gp := from + dir * ground_dist
		walk_to(Vector3(gp.x, 0, gp.z))


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
	place.y = 0.0
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
	place.y = 0.0
	ladder.position = place
	get_tree().current_scene.add_child(ladder)
	Hud.toast("You prop up a ladder. It leans toward the sky — and the birds.")


func _try_craft_rod() -> void:
	if Hud.is_dialogue_open():
		return
	if GameState.rod_placed:
		Hud.toast("You already have a fishing rod.")
		return
	if not GameState.can_afford_rod():
		Hud.toast("Need 1 string + 2 sticks for a fishing rod.")
		return
	GameState.spend_rod()
	GameState.rod_placed = true
	Hud.toast("You craft a fishing rod. Now try the pond — that's oFISHial!")


func _try_eat() -> void:
	if Hud.any_panel_open():
		return
	if GameState.eat_food():
		Hud.toast("You tuck into your food. Hunger back to full. (Munch, munch.)")
	else:
		Hud.toast("Nothing to eat! Catch a mouse, fish or bird — or check the farmhouse at dawn.")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = jump_velocity
	if GameState.chase_active and is_on_floor():
		hop_t -= delta
		if hop_t <= 0.0:
			hop_t = 0.45
			velocity.y = jump_velocity * 0.7

	if has_destination:
		var to: Vector3 = destination - global_position
		to.y = 0.0
		if to.length() < 0.35:
			has_destination = false
			walking = false
			velocity.x = move_toward(velocity.x, 0.0, move_speed)
			velocity.z = move_toward(velocity.z, 0.0, move_speed)
		else:
			var dir := to.normalized()
			velocity.x = dir.x * move_speed
			velocity.z = dir.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)

	move_and_slide()

	var mesh_target := yaw
	if walking:
		var to: Vector3 = destination - global_position
		if to.length() > 0.001:
			mesh_target = atan2(to.x, to.z)
	mesh_root.rotation.y = lerp_angle(mesh_root.rotation.y, mesh_target, 14.0 * delta)
	if not camera_frozen:
		pitch = clampf(pitch, -max_pitch, _pitch_max())
		camera_holder.rotation = Vector3(pitch, yaw, 0.0)
		_clamp_camera_in_shed()

	if Hud.is_dialogue_open():
		Hud.set_prompt("")
	elif current_interactable != null:
		Hud.set_prompt(current_interactable.prompt)
	else:
		Hud.set_prompt("")

	_animate_cat(delta)


func _animate_cat(delta: float) -> void:
	if skeleton == null or bone_idx.is_empty():
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
		return
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
