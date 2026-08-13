extends Node3D

func _ready() -> void:
	var scene := load("res://scenes/main.tscn")
	add_child(scene.instantiate())
	await get_tree().process_frame
	await get_tree().process_frame

	var gate: Node3D = null
	var gates := get_tree().get_nodes_in_group("interactable")
	print("TEST interactable_count=", gates.size())
	for g in gates:
		print("TEST interactable: ", g.name, " class=", g.get_class())
		if "ate" in g.name:
			gate = g

	if gate == null:
		print("TEST RESULT: GATE NOT FOUND")
		get_tree().quit(1)
		return

	print("TEST gate=", gate.name, " interaction_point=", gate.get_interaction_point())
	print("TEST gate.in_group=", gate.is_in_group("interactable"))
	var pivot: Node3D = gate.get("_pivot") as Node3D
	print("TEST pivot_exists=", pivot != null, " pivot_name=", pivot.name if pivot != null else "n/a")

	var player := get_tree().get_first_node_in_group("player") as Node3D
	var cam: Camera3D = null
	if player != null:
		for c in player.find_children("*", "Camera3D", true, false):
			cam = c as Camera3D
			break
	print("TEST player=", player != null, " cam=", cam != null)
	if player != null and cam != null:
		player.global_position = Vector3(0, 0.5, -20)
		await get_tree().process_frame
		await get_tree().process_frame
		var to_gate: Vector3 = gate.get_interaction_point() - player.global_position
		to_gate.y = 0.0
		var yaw_to: float = atan2(-to_gate.x, -to_gate.z)
		player.set("yaw", yaw_to)
		player.set("pitch", -0.2)
		await get_tree().process_frame
		await get_tree().process_frame
		var sp: Vector2 = cam.unproject_position(gate.get_interaction_point())
		print("TEST far_click: within_range=", player.call("_within_interact_range", gate))
		player.call("_handle_click_at", sp)
		await get_tree().create_timer(3.0).timeout
		print("TEST after_far_click: gate_open=", gate.get("_open"), " player_pos=", player.global_position)
		player.global_position = Vector3(-1.7, 0.5, -24.2)
		var to_c: Vector3 = gate.get_interaction_point() - player.global_position
		to_c.y = 0.0
		player.set("yaw", atan2(-to_c.x, -to_c.z))
		player.set("pitch", -0.2)
		await get_tree().process_frame
		await get_tree().process_frame
		print("TEST close: within_range=", player.call("_within_interact_range", gate))
		var sp3: Vector2 = cam.unproject_position(gate.get_interaction_point())
		player.call("_handle_click_at", sp3)
		await get_tree().create_timer(3.0).timeout
		print("TEST after_open_click: gate_open=", gate.get("_open"), " pivot_rot_y=%.3f" % (pivot.rotation.y if pivot != null else 0.0), " busy=", gate.get("_busy"))
		print("TEST player_pos=", player.global_position)
		var sp2: Vector2 = cam.unproject_position(gate.get_interaction_point())
		print("TEST screen_pos2=", sp2, " within_range=", player.call("_within_interact_range", gate))
		player.call("_handle_click_at", sp2)
		await get_tree().create_timer(3.0).timeout
		print("TEST after_close_click: gate_open=", gate.get("_open"), " pivot_rot_y=%.3f" % (pivot.rotation.y if pivot != null else 0.0), " busy=", gate.get("_busy"))
		print("TEST player_pos2=", player.global_position)
		player.global_position = Vector3(1.45, 0.5, -24.3)
		var to_g2: Vector3 = gate.get_interaction_point() - player.global_position
		to_g2.y = 0.0
		player.set("yaw", atan2(-to_g2.x, -to_g2.z))
		player.set("pitch", -0.2)
		await get_tree().process_frame
		await get_tree().process_frame
		print("TEST far_end: within_range=", player.call("_within_interact_range", gate))
		var sp4: Vector2 = cam.unproject_position(gate.get_interaction_point())
		var picked = player.call("_pick_interactable", sp4)
		var fish_pick = player.call("_pick_fish", sp4)
		print("TEST far_end_pick=", picked.name if picked != null else "null", " fish=", fish_pick.name if fish_pick != null else "null")
		player.call("_handle_click_at", sp4)
		await get_tree().create_timer(3.0).timeout
		print("TEST after_far_end_click: gate_open=", gate.get("_open"), " player_pos=", player.global_position)
	else:
		gate.interact()
		await get_tree().create_timer(1.3).timeout
		print("TEST direct_interact: gate_open=", gate.get("_open"), " pivot_rot_y=%.3f" % (pivot.rotation.y if pivot != null else 0.0))
	print("TEST RESULT: DONE")
	get_tree().quit(0)
