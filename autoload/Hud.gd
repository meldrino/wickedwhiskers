extends CanvasLayer

var inventory_label: Label
var prompt_label: Label
var controls_label: Label
var toast_label: Label
var dialogue_panel: PanelContainer
var dialogue_label: RichTextLabel
var dialogue_hint: Label
var dialogue_button: Button
var choice_panel: PanelContainer
var choice_title: Label
var choice_box: VBoxContainer
var combo_panel: PanelContainer
var combo_display: Label

var toast_text := ""
var toast_time := 0.0
var dialogue_lines: Array = []
var dialogue_idx := 0
var dialogue_open := false
var choice_open := false
var combo_open := false

var _choice_cb: Callable = Callable()
var _combo_cb: Callable = Callable()
var _combo_digits: Array[int] = [0, 0, 0]
var _combo_idx := 0

const TOAST_DURATION := 2.5

const BAR_FULL := "▓▓▓▓▓▓▓▓▓▓"
const BAR_EMPTY := "░░░░░░░░░░"


func _ready() -> void:
	layer = 10

	inventory_label = Label.new()
	inventory_label.position = Vector2(12, 10)
	inventory_label.add_theme_font_size_override("font_size", 18)
	add_child(inventory_label)

	controls_label = Label.new()
	controls_label.position = Vector2(12, 692)
	controls_label.text = "Right-drag = look around  |  Click ground = walk  |  Click object = interact  |  Hold+drag = keep walking  |  WASD/arrows = walk  |  Wheel zoom  |  Space jump  |  F eat  |  1 trap  |  2 ladder"
	controls_label.add_theme_font_size_override("font_size", 13)
	add_child(controls_label)

	prompt_label = Label.new()
	prompt_label.custom_minimum_size = Vector2(1280, 26)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.position = Vector2(0, 606)
	prompt_label.add_theme_font_size_override("font_size", 17)
	add_child(prompt_label)

	toast_label = Label.new()
	toast_label.custom_minimum_size = Vector2(1280, 26)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.position = Vector2(0, 574)
	toast_label.add_theme_font_size_override("font_size", 19)
	add_child(toast_label)

	_build_dialogue()
	_build_choices()
	_build_combo()


func _build_dialogue() -> void:
	dialogue_panel = PanelContainer.new()
	dialogue_panel.size = Vector2(1000, 250)
	dialogue_panel.position = Vector2(140, 440)
	dialogue_panel.visible = false
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	var vbox := VBoxContainer.new()
	dialogue_label = RichTextLabel.new()
	dialogue_label.fit_content = true
	dialogue_label.text = ""
	dialogue_label.add_theme_font_size_override("normal_font_size", 18)
	vbox.add_child(dialogue_label)
	dialogue_hint = Label.new()
	dialogue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_hint.text = ""
	dialogue_hint.add_theme_font_size_override("font_size", 13)
	vbox.add_child(dialogue_hint)
	dialogue_button = Button.new()
	dialogue_button.text = "Continue"
	dialogue_button.custom_minimum_size = Vector2(180, 34)
	dialogue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dialogue_button.add_theme_font_size_override("font_size", 15)
	dialogue_button.pressed.connect(advance_dialogue)
	vbox.add_child(dialogue_button)
	margin.add_child(vbox)
	dialogue_panel.add_child(margin)
	add_child(dialogue_panel)


func _build_choices() -> void:
	choice_panel = PanelContainer.new()
	choice_panel.size = Vector2(560, 0)
	choice_panel.position = Vector2(360, 300)
	choice_panel.visible = false
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	choice_title = Label.new()
	choice_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice_title.add_theme_font_size_override("font_size", 17)
	choice_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(choice_title)
	choice_box = VBoxContainer.new()
	choice_box.add_theme_constant_override("separation", 6)
	vbox.add_child(choice_box)
	margin.add_child(vbox)
	choice_panel.add_child(margin)
	add_child(choice_panel)


func _build_combo() -> void:
	combo_panel = PanelContainer.new()
	combo_panel.size = Vector2(460, 0)
	combo_panel.position = Vector2(410, 240)
	combo_panel.visible = false
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = "Combination padlock — enter 3 digits"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 17)
	vbox.add_child(title)
	combo_display = Label.new()
	combo_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_display.add_theme_font_size_override("font_size", 44)
	combo_display.text = "0 0 0"
	vbox.add_child(combo_display)

	var left := HBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 12)
	var b_dec := Button.new()
	b_dec.text = "▼"
	b_dec.custom_minimum_size = Vector2(110, 34)
	b_dec.pressed.connect(_combo_dec)
	left.add_child(b_dec)
	var b_inc := Button.new()
	b_inc.text = "▲"
	b_inc.custom_minimum_size = Vector2(110, 34)
	b_inc.pressed.connect(_combo_inc)
	left.add_child(b_inc)
	vbox.add_child(left)

	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 12)
	var b_prev := Button.new()
	b_prev.text = "◀ digit"
	b_prev.custom_minimum_size = Vector2(110, 34)
	b_prev.pressed.connect(_combo_prev)
	nav.add_child(b_prev)
	var b_next := Button.new()
	b_next.text = "digit ▶"
	b_next.custom_minimum_size = Vector2(110, 34)
	b_next.pressed.connect(_combo_next)
	nav.add_child(b_next)
	vbox.add_child(nav)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 12)
	var b_ok := Button.new()
	b_ok.text = "TRY LOCK"
	b_ok.custom_minimum_size = Vector2(150, 36)
	b_ok.pressed.connect(_combo_try)
	btns.add_child(b_ok)
	var b_cancel := Button.new()
	b_cancel.text = "CANCEL"
	b_cancel.custom_minimum_size = Vector2(110, 36)
	b_cancel.pressed.connect(_combo_cancel)
	btns.add_child(b_cancel)
	vbox.add_child(btns)

	margin.add_child(vbox)
	combo_panel.add_child(margin)
	add_child(combo_panel)


func _process(delta: float) -> void:
	var bar := GameState.hunger
	var hbar := BAR_FULL if bar >= 1.0 else BAR_EMPTY
	var ts := clampf(GameState.tiredness, 0.0, 1.0)
	var tbar := ""
	for i in range(10):
		tbar += "▓" if float(i) / 10.0 < ts else "░"
	inventory_label.text = "Day %d   Lives: %d/%d   Food: %d   Gold: %d\nHunger %s   Energy %s   String: %d   Sticks: %d%s" % [
		GameState.day_index, GameState.lives, GameState.MAX_LIVES,
		GameState.food_count, GameState.gold,
		hbar, tbar, GameState.string_count, GameState.stick_count,
		"   (keys!)" if GameState.has_keys else "",
	]
	if toast_time > 0.0:
		toast_time -= delta
		toast_label.text = toast_text
		toast_label.modulate.a = clampf(toast_time / 0.5, 0.0, 1.0)
	else:
		toast_label.text = ""


func toast(text: String) -> void:
	toast_text = text
	toast_time = TOAST_DURATION


func set_prompt(text: String) -> void:
	prompt_label.text = text


func show_dialogue(lines: Array) -> void:
	dialogue_lines = lines
	dialogue_idx = 0
	dialogue_open = true
	dialogue_panel.visible = true
	_render_dialogue()


func advance_dialogue() -> void:
	dialogue_idx += 1
	if dialogue_idx >= dialogue_lines.size():
		close_dialogue()
	else:
		_render_dialogue()


func close_dialogue() -> void:
	dialogue_open = false
	dialogue_panel.visible = false


func is_dialogue_open() -> bool:
	return dialogue_open


func _render_dialogue() -> void:
	dialogue_label.text = str(dialogue_lines[dialogue_idx])
	if dialogue_idx < dialogue_lines.size() - 1:
		dialogue_hint.text = "Click — continue"
		dialogue_button.text = "Continue ▶"
	else:
		dialogue_hint.text = "Click — close"
		dialogue_button.text = "Close"


func show_choices(title: String, labels: Array, cb: Callable) -> void:
	_choice_cb = cb
	choice_title.text = title
	for child in choice_box.get_children():
		child.queue_free()
	for i in labels.size():
		var b := Button.new()
		b.text = str(labels[i])
		b.custom_minimum_size = Vector2(500, 40)
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(_on_choice.bind(i))
		choice_box.add_child(b)
	choice_open = true
	choice_panel.visible = true


func _on_choice(i: int) -> void:
	choice_open = false
	choice_panel.visible = false
	var cb := _choice_cb
	_choice_cb = Callable()
	cb.call(i)


func is_choice_open() -> bool:
	return choice_open


func show_combo(cb: Callable) -> void:
	_combo_cb = cb
	_combo_digits = [0, 0, 0]
	_combo_idx = 0
	combo_open = true
	combo_panel.visible = true
	_render_combo()


func is_combo_open() -> bool:
	return combo_open


func _render_combo() -> void:
	var parts: Array[String] = []
	for i in 3:
		var d := str(_combo_digits[i])
		if i == _combo_idx:
			d = "[" + d + "]"
		parts.append(d)
	combo_display.text = "  ".join(parts)


func _combo_inc() -> void:
	_combo_digits[_combo_idx] = (_combo_digits[_combo_idx] + 1) % 10
	_render_combo()


func _combo_dec() -> void:
	_combo_digits[_combo_idx] = (_combo_digits[_combo_idx] + 9) % 10
	_render_combo()


func _combo_prev() -> void:
	_combo_idx = (_combo_idx + 2) % 3
	_render_combo()


func _combo_next() -> void:
	_combo_idx = (_combo_idx + 1) % 3
	_render_combo()


func _combo_try() -> void:
	combo_open = false
	combo_panel.visible = false
	var cb := _combo_cb
	_combo_cb = Callable()
	cb.call(_combo_digits[0] * 100 + _combo_digits[1] * 10 + _combo_digits[2])


func _combo_cancel() -> void:
	combo_open = false
	combo_panel.visible = false
	_combo_cb = Callable()


func any_panel_open() -> bool:
	return dialogue_open or choice_open or combo_open
