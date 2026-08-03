extends Interactable


func _ready() -> void:
	super()
	prompt = "E — Talk to Dumbleclaw"
	interaction_box = Vector3(0.8, 1.5, 0.8)
	interaction_center = Vector3(0, 0.75, 0)
	_build_dumbleclaw()


func interact() -> void:
	if Hud.any_panel_open():
		return
	if GameState.quest == "meet":
		Hud.show_dialogue([
			"Dumbleclaw: Ah, young whiskers. I am Dumbleclaw — nine lifetimes of wisdom, most of it spent napping.",
			"Dumbleclaw: The night is your hunting hour. Mice, fish and birds are the farm's bounty.",
			"Dumbleclaw: But no claw will catch them alone. String waits in the shed; sticks litter the yard.",
			"Dumbleclaw: Each catch fills your belly for a full day. Catch what you need — and bring me your surplus. Gold is worth having where we're headed.",
		])
		GameState.quest = "advice"
		return
	Hud.show_choices("Dumbleclaw, the wise old cat, blinks slowly at you:", [
		"Ask for advice",
		"Trade surplus food",
		"Just passing",
	], _on_choice)


func _on_choice(i: int) -> void:
	match i:
		0:
			_advice()
		1:
			_trade()
		2:
			pass


func _advice() -> void:
	if GameState.total_catches() == 0:
		if GameState.is_day:
			Hud.show_dialogue([
				"Dumbleclaw: Nothing caught yet, whiskers? The farmhouse door is open now — the farmer's wife sometimes leaves catfood for strays.",
				"Dumbleclaw: But real cats hunt. The bird needs a ladder or the tractor. The fish needs a rod. The mouse needs a TRAP.",
			])
		else:
			Hud.show_dialogue([
				"Dumbleclaw: Nothing caught yet, whiskers? The shed holds string — but it wears a padlock. Read the tractor's number plate, and the lock will make sense.",
				"Dumbleclaw: Gather string and sticks, then craft. The night is long; the farm is yours.",
			])
	else:
		var missing := []
		if not GameState.mouse_caught:
			missing.append("a mouse (it needs a convoluted trap)")
		if not GameState.bird_caught:
			missing.append("the bird (ladder or tractor)")
		if not GameState.fish_caught:
			missing.append("the fish (you'll need a rod)")
		if missing.is_empty():
			Hud.show_dialogue([
				"Dumbleclaw: You've caught them all, whiskers! Mouse, bird AND fish. I always said you had the makings of a legend.",
				"Dumbleclaw: Save what you can, trade the surplus, and save gold. Thirty gold opens the gates to the town... and talk of a golden fish.",
			])
		else:
			Hud.show_dialogue([
				"Dumbleclaw: Well done so far! You still have %s to catch." % (" and ".join(missing)),
				"Dumbleclaw: Each catch is a day's food. Eat one, keep two, and sell the rest to me.",
			])


func _trade() -> void:
	if GameState.food_count > 2:
		GameState.food_count -= 1
		GameState.gold += GameState.TRADE_GOLD
		Hud.show_dialogue([
			"Dumbleclaw: Splendid, whisker-youngster! I'm far too old to hunt these days.",
			"Dumbleclaw: Here are %d gold coins for that food. Spend wisely. (%d gold total.)" % [GameState.TRADE_GOLD, GameState.gold],
		])
	elif GameState.food_count > 0:
		Hud.show_dialogue([
			"Dumbleclaw: That's all you've got, young one. Keep it — a hungry cat is a poor cat.",
			"Dumbleclaw: Catch more, and bring me the surplus. One for your belly, the rest for gold.",
		])
	else:
		Hud.show_dialogue([
			"Dumbleclaw: You've nothing to trade yet, whiskers. Catch a mouse, a fish or a bird first.",
		])


func _build_dumbleclaw() -> void:
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.62, 0.6, 0.58)
	var robe := StandardMaterial3D.new()
	robe.albedo_color = Color(0.45, 0.4, 0.6)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.95, 0.95, 0.92)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.2, 0.16, 0.12)

	var barrel := _mesh("cylinder", Vector3(0.38, 0.5, 0.38), dark)
	barrel.position = Vector3(0, 0.25, 0)
	add_child(barrel)

	var robe_mesh := _mesh("box", Vector3(0.6, 0.45, 0.42), robe)
	robe_mesh.position = Vector3(0, 0.55, 0)
	add_child(robe_mesh)

	var head := _mesh("sphere", Vector3(0.4, 0.36, 0.38), grey)
	head.position = Vector3(0, 0.88, 0.02)
	add_child(head)

	for x in [-0.14, 0.14]:
		var ear := _mesh("box", Vector3(0.09, 0.12, 0.07), grey)
		ear.position = Vector3(x, 1.05, 0.04)
		ear.rotation = Vector3(-0.2, 0, x * -0.4)
		add_child(ear)

	var beard := _mesh("box", Vector3(0.24, 0.34, 0.06), white)
	beard.position = Vector3(0, 0.66, 0.22)
	add_child(beard)

	for x in [-0.07, 0.07]:
		var lens := _mesh("box", Vector3(0.07, 0.07, 0.02), white)
		lens.position = Vector3(x, 0.92, 0.21)
		add_child(lens)
	var bridge := _mesh("box", Vector3(0.1, 0.025, 0.02), white)
	bridge.position = Vector3(0, 0.92, 0.21)
	add_child(bridge)

	var nose := _mesh("sphere", Vector3(0.09, 0.08, 0.06), dark)
	nose.position = Vector3(0, 0.82, 0.24)
	add_child(nose)


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
		"cylinder":
			var cm := CylinderMesh.new()
			cm.top_radius = size.x
			cm.bottom_radius = size.x
			cm.height = size.y
			mesh = cm
	mesh.material = mat
	mi.mesh = mesh
	return mi
