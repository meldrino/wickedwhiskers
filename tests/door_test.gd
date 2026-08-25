extends Node3D

func _ready() -> void:
	var scene := load("res://scenes/main.tscn")
	add_child(scene.instantiate())
	await get_tree().process_frame
	await get_tree().process_frame

	var door: Node3D = null
	for g in get_tree().get_nodes_in_group("interactable"):
		if g.name == "Door_shed":
			door = g
			break
	if door == null:
		print("TEST RESULT: DOOR NOT FOUND")
		get_tree().quit(1)
		return

	var padlock: Node3D = door.get("_padlock") as Node3D
	print("TEST door=", door.name, " interaction_point=", door.get_interaction_point())
	if padlock == null:
		print("TEST RESULT: PADLOCK NOT FOUND")
		get_tree().quit(1)
		return
	var hit := padlock.get_node_or_null("PadlockHit") as StaticBody3D
	print("TEST padlock_local=", padlock.position, " global=", padlock.global_position)
	print("TEST padlock_hit=", hit != null, " layer=", (hit.collision_layer if hit != null else -1))

	var player := get_tree().get_first_node_in_group("player") as Node3D
	var cam: Camera3D = null
	if player != null:
		for c in player.find_children("*", "Camera3D", true, false):
			cam = c as Camera3D
			break
	print("TEST player=", player != null, " cam=", cam != null)
	if player == null or cam == null:
		get_tree().quit(1)
		return

	player.global_position = Vector3(15.4, 0.5, -7.4)
	await get_tree().process_frame
	await get_tree().process_frame
	var to_p: Vector3 = padlock.global_position - player.global_position
	to_p.y = 0.0
	player.set("yaw", atan2(-to_p.x, -to_p.z))
	player.set("pitch", -0.1)
	await get_tree().process_frame
	await get_tree().process_frame

	var sp: Vector2 = cam.unproject_position(padlock.global_position)
	print("TEST padlock_screen=", sp, " within_range=", player.call("_within_interact_range", door))
	var picked = player.call("_pick_interactable", sp)
	print("TEST click_padlock_pick=", (picked.name if picked != null else "null"))
	player.call("_handle_click_at", sp)
	await get_tree().create_timer(2.0).timeout
	print("TEST after_padlock_click combo_open=", Hud.combo_open, " walking=", player.get("walking"))
	if Hud.combo_open:
		Hud._combo_cancel()

	var door_ip: Vector3 = door.get_interaction_point()
	var sp2: Vector2 = cam.unproject_position(door_ip)
	var picked2 = player.call("_pick_interactable", sp2)
	print("TEST click_door_face_pick=", (picked2.name if picked2 != null else "null"))
	print("TEST RESULT: DONE")
	get_tree().quit(0)
