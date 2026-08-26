@tool
extends Node3D

func _ready() -> void:
	GameState.shed_unlocked = true
	var shed := preload("res://scripts/shed.gd").new()
	shed.name = "ShedView"
	add_child(shed)
	# Warm light
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.55)
	light.light_energy = 3.0
	light.omni_range = 6.0
	light.position = Vector3(0, 2.0, 0)
	add_child(light)
	# Camera inside shed, looking down at floor + back wall
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 1.2, 0.5)
	cam.rotation_degrees = Vector3(-25, 0, 0)
	cam.fov = 65
	add_child(cam)
	Hud.visible = false
	await get_tree().create_timer(0.5).timeout
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	img.save_png("res://screenshots/shed_interior.png")
	print("SCREENSHOT SAVED: screenshots/shed_interior.png")
	get_tree().quit()
