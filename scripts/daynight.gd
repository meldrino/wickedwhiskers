extends Node3D

var sun: DirectionalLight3D
var moon: DirectionalLight3D
var moon_mesh: MeshInstance3D
var stars: MeshInstance3D
var sky_mat: ProceduralSkyMaterial

const DAY_SECONDS := 7200.0
const SUN_AMPLITUDE := deg_to_rad(55.0)
const SUN_BASE := deg_to_rad(10.0)

const NIGHT_TOP := Color(0.08, 0.1, 0.24)
const NIGHT_HORIZON := Color(0.16, 0.18, 0.34)
const DUSK_TOP := Color(0.22, 0.26, 0.5)
const DUSK_HORIZON := Color(0.85, 0.45, 0.32)
const DAY_TOP := Color(0.35, 0.6, 0.95)
const DAY_HORIZON := Color(0.82, 0.86, 0.9)

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	var we := get_parent().get_node("WorldEnvironment")
	if we != null and we.environment != null:
		sky_mat = we.environment.sky.sky_material as ProceduralSkyMaterial
	_build_lights()
	_build_moon_mesh()
	_build_stars()
	_update_sky(0.0)


func _process(delta: float) -> void:
	GameState.day_time += delta
	if GameState.day_time >= DAY_SECONDS:
		GameState.day_time -= DAY_SECONDS
		GameState.day_index += 1
	_update_sky(GameState.day_time)
	_process_hunger(delta)
	_process_tiredness(delta)


func _update_sky(time_s: float) -> void:
	var t := fmod(time_s / DAY_SECONDS, 1.0)
	var elev := SUN_AMPLITUDE * cos((t - 0.75) * TAU) - SUN_BASE
	var e_deg := rad_to_deg(elev)

	var day := clampf(e_deg / 25.0, 0.0, 1.0)
	var night := clampf(-e_deg / 25.0, 0.0, 1.0)
	var dusk := clampf(1.0 - absf(e_deg) / 18.0, 0.0, 1.0)

	var top: Color = DAY_TOP.lerp(DUSK_TOP, dusk).lerp(NIGHT_TOP, night)
	var horizon: Color = DAY_HORIZON.lerp(DUSK_HORIZON, dusk).lerp(NIGHT_HORIZON, night)

	if sky_mat != null:
		sky_mat.sky_top_color = top
		sky_mat.sky_horizon_color = horizon
		sky_mat.ground_bottom_color = NIGHT_TOP.lerp(DAY_TOP, day)
		sky_mat.ground_horizon_color = horizon

	GameState.is_day = e_deg > 4.0
	if GameState.is_day and not GameState.first_dawn:
		GameState.first_dawn = true
		Hud.toast("Dawn breaks over the farm. The farmhouse door should be open now.")

	var azim := t * TAU
	_place(sun, azim, elev, 1.15 * day)
	var moon_dir := Vector3(cos(azim + PI) * cos(-elev + deg_to_rad(6.0)), sin(-elev + deg_to_rad(6.0)), sin(azim + PI) * cos(-elev + deg_to_rad(6.0)))
	_place(moon, azim + PI, -elev + deg_to_rad(6.0), 0.22 * night)
	moon_mesh.position = moon_dir.normalized() * 150.0

	var we := get_parent().get_node("WorldEnvironment")
	if we != null and we.environment != null:
		we.environment.ambient_light_energy = 0.32 + 0.5 * day
		we.environment.ambient_light_color = Color(0.9, 0.92, 1.0).lerp(Color(1.0, 1.0, 1.0), day)

	moon_mesh.visible = night > 0.2
	stars.visible = night > 0.15


func _process_hunger(delta: float) -> void:
	GameState.hunger -= delta / DAY_SECONDS
	if GameState.hunger > 0.0:
		return
	if GameState.food_count > 0:
		GameState.eat_food()
		Hud.toast("You wolf down some food. Hunger back to full. (+1 food eaten)")
	elif not GameState.first_dawn:
		GameState.hunger = 0.05
		GameState.toast_cooldown("hunger_mercy", "You're hungry, WW — but tonight you won't starve. Dumbleclaw says the farmhouse opens at dawn.")
	else:
		GameState.hunger = 1.0
		if GameState.lose_life("Starvation caught up with you — no food to eat!"):
			_restart()


func _process_tiredness(delta: float) -> void:
	GameState.tiredness += delta / (DAY_SECONDS * 0.8)
	if GameState.tiredness >= 1.0:
		GameState.tiredness = 0.0
		var player := get_tree().get_first_node_in_group("player")
		if player != null:
			var scene := get_tree().current_scene
			var pos := Vector3(0, 0.0, 12.0)
			if scene != null and scene.name == "Shed":
				pos = Vector3(0, 0.0, 0.0)
			player.global_position = pos
			if player.has_method("stop_walk"):
				player.stop_walk()
		if GameState.lose_life("Exhaustion caught up with you. You should have napped!"):
			_restart()


func _restart() -> void:
	Hud.toast("Game over — Wicked Whiskers loses all nine lives. Restarting the farm...")
	await get_tree().create_timer(1.2).timeout
	GameState.new_game()
	get_tree().reload_current_scene()


func _place(light: DirectionalLight3D, azim: float, elev: float, energy: float) -> void:
	var dir := Vector3(cos(azim) * cos(elev), sin(elev), sin(azim) * cos(elev))
	if dir.length() < 0.001:
		dir = Vector3.UP
	light.look_at_from_position(dir * 100.0, Vector3.ZERO, Vector3.UP)
	light.light_energy = energy


func _build_lights() -> void:
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.shadow_bias = 0.02
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.7, 0.78, 1.0)
	moon.light_energy = 0.0
	add_child(moon)


func _build_moon_mesh() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.94, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 2.0
	sm.height = 4.0
	sm.material = mat
	moon_mesh.mesh = sm
	add_child(moon_mesh)
	moon_mesh.visible = false


func _build_stars() -> void:
	var pts := PackedVector3Array()
	for i in range(220):
		var a := rng.randf_range(0.0, TAU)
		var e := rng.randf_range(0.05, 1.35)
		pts.append(Vector3(cos(a) * cos(e), sin(e), sin(a) * cos(e)) * 280.0)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arr)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 1.0, 1.0)
	mat.point_size = 2.5
	mesh.surface_set_material(0, mat)
	stars = MeshInstance3D.new()
	stars.mesh = mesh
	stars.visible = false
	add_child(stars)
