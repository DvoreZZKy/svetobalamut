extends Node

const FacetButton = preload("res://scripts/facet_button.gd")
## Обучение с живой симуляцией: сначала интерфейс, затем практические действия.

const NORMAL_SPEED := 1.0
const SLOW_SPEED := 0.22
const TRANSITION_MS := 500
const UI_STEPS := [
	{"title":"АКТИВНЫЙ ХАОС","body":"В правом верхнем углу отображаются хаосы, которые действуют прямо сейчас. Если список пуст — арена временно спокойна.","target":"timer"},
	{"title":"ТАБЛИЦА МАТЧА","body":"Слева показаны все участники. Свет — сколько энергии осталось. Урон — сколько здоровья ты снял соперникам. Хил — сколько света восстановил. K — число выбывших игроков. Хаос — очки за устранения и события. Стрелка отмечает тебя.","target":"score"},
	{"title":"ПОДБОР УЛУЧШЕНИЙ","body":"На арене появляются светящиеся кристаллы. Подбери их, чтобы временно получить ускорение, усиленный урон, защиту или восстановление света.","target":"arena"},
	{"title":"ЗАПАС СВЕТА","body":"Полоса внизу — запас света и одновременно здоровье. Попадания, движение и выстрелы расходуют его. Восстанавливай свет в тёмных зонах и подбирай батареи.","target":"light"},
	{"title":"ПЕРЕЗАРЯДКА РЫВКА","body":"Голубая полоса показывает восстановление рывка. Рывок расходует свет и помогает быстро сменить позицию.","target":"dash"},
	{"title":"ПЕРЕЗАРЯДКА СПОСОБНОСТИ","body":"Фиолетовая полоса показывает перезарядку способности твоего класса. Когда она заполнится, Q снова можно использовать.","target":"ability"},
	{"title":"ТЁМНЫЕ ЗОНЫ И ПОБЕДА","body":"Круглые зоны на арене помогают восстанавливать свет. Матч заканчивается, когда остаётся один светящийся игрок. После победы появятся четыре рейтинга: урон, хил, киллы и хаос.","target":"zones"}
]
const CONTROL_STEPS := [
	{"title":"ПЕРЕДВИЖЕНИЕ","body":"Используй WASD, чтобы двигаться по арене. Персонаж реагирует сразу, без задержки.","kind":"move"},
	{"title":"РЫВОК","body":"Рывок резко ускоряет персонажа и на короткое время помогает избежать попаданий. Нажми ПРОБЕЛ.","kind":"dash"},
	{"title":"ОСОБАЯ СПОСОБНОСТЬ","body":"У каждого класса своя способность. Нажми Q, чтобы применить способность своего персонажа.","kind":"ability"},
	{"title":"АТАКА","body":"Наведи указатель на соперника и нажми левую кнопку мыши. Попробуй выстрелить.","kind":"fire"},
	{"title":"ВСЕЛЕНИЕ","body":"Подойди к подсвеченному игроку и нажми ЛКМ или E, чтобы вселиться в него.","kind":"possess"}
]

var arena: Node2D
var layer: CanvasLayer
var shade_parts: Array[ColorRect] = []
var panel: PanelContainer
var title_label: Label
var body_label: Label
var next_button: Button
var skip_button: Button
var key_row: HBoxContainer
var pointer: Line2D
var pointer_head: Polygon2D
var stage := "ui"
var ui_index := 0
var control_index := 0
var transition_target := ""
var transition_deadline := 0
var fade_started := 0
var pointer_target := ""
var focus_rect := Rect2()
var pulse := 0.0
var finished := false
var completion_return_to_lobby := false
var shadow_explanation := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	arena = get_parent()
	_build_overlay()
	_show_ui_step(0)


func _process(_dt: float) -> void:
	if finished:
		return
	pulse = float(Time.get_ticks_msec()) / 1000.0
	if stage == "transition":
		if Time.get_ticks_msec() >= transition_deadline:
			if transition_target == "ui":
				_show_ui_step(ui_index)
			elif transition_target == "control":
				_show_control_step(control_index)
			elif transition_target == "shadow":
				_show_shadow_explanation()
		return
	if stage == "ui_fade" or stage == "control_fade":
		var fade_duration := 650.0 if stage == "ui_fade" else 420.0
		var alpha := clampf(float(Time.get_ticks_msec() - fade_started) / fade_duration, 0.0, 1.0)
		panel.modulate.a = alpha
		for part in shade_parts:
			part.modulate.a = alpha
		if stage == "ui_fade":
			_update_pointer()
		if alpha >= 1.0:
			if stage == "ui_fade":
				stage = "ui"
				Engine.time_scale = 0.0
			else:
				stage = "control"
		return
	if stage == "ui":
		_update_focus()
	elif stage == "control":
		_update_pointer()
		if _current_control_done():
			if str(CONTROL_STEPS[control_index].kind) == "move":
				_begin_transition("control", control_index + 1, 0)
			elif str(CONTROL_STEPS[control_index].kind) == "fire":
				_begin_transition("shadow", 0)
			else:
				_begin_transition("control", control_index + 1)
	elif stage == "completion":
		_update_completion_pulse()


func _build_overlay() -> void:
	layer = CanvasLayer.new()
	layer.layer = 30
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	arena.add_child(layer)
	for i in 4:
		var part := ColorRect.new()
		part.color = Color(0.004, 0.006, 0.018, 0.82)
		part.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(part)
		shade_parts.append(part)
	panel = PanelContainer.new()
	panel.size = Vector2(650, 190)
	panel.modulate.a = 0.0
	panel.add_theme_stylebox_override("panel", _panel_style())
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	panel.add_child(column)
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color("#7feaff"))
	column.add_child(title_label)
	body_label = Label.new()
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", 17)
	body_label.add_theme_color_override("font_color", Color("#e0edff"))
	body_label.custom_minimum_size = Vector2(0, 62)
	column.add_child(body_label)
	key_row = HBoxContainer.new()
	key_row.alignment = BoxContainer.ALIGNMENT_CENTER
	key_row.add_theme_constant_override("separation", 7)
	column.add_child(key_row)
	next_button = FacetButton.new()
	next_button.text = "ДАЛЕЕ"
	next_button.custom_minimum_size = Vector2(170, 38)
	next_button.pressed.connect(_on_next)
	column.add_child(next_button)
	pointer = Line2D.new()
	pointer.width = 2.6
	pointer.default_color = Color("#68efff")
	pointer.z_index = 15
	layer.add_child(pointer)
	pointer_head = Polygon2D.new()
	pointer_head.color = Color("#b8fbff")
	pointer_head.z_index = 16
	layer.add_child(pointer_head)
	skip_button = FacetButton.new()
	skip_button.text = "ПРОПУСТИТЬ ОБУЧЕНИЕ"
	skip_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_button.offset_left = -385
	skip_button.offset_top = -72
	skip_button.offset_right = -42
	skip_button.offset_bottom = -28
	skip_button.add_theme_font_size_override("font_size", 12)
	skip_button.pressed.connect(_show_completion)
	layer.add_child(skip_button)
	_hide_shade()


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0b1428", 0.96)
	style.border_color = Color("#36cce8")
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	style.shadow_color = Color("#36cce8", 0.22)
	style.shadow_size = 10
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _keycap(letter: String) -> Control:
	var box := Control.new()
	var font := ThemeDB.fallback_font
	var measured := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var cap_width := maxf(46.0, measured + 26.0)
	box.custom_minimum_size = Vector2(cap_width, 46)
	var frame := Panel.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#101d32")
	style.border_color = Color("#75eaff")
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	frame.add_theme_stylebox_override("panel", style)
	box.add_child(frame)
	var label := Label.new()
	label.text = letter
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color("#e8fbff"))
	box.add_child(label)
	return box


func _mouse_icon() -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(42, 56)
	var body := Panel.new()
	body.position = Vector2(5, 1)
	body.size = Vector2(32, 52)
	var body_style := StyleBoxFlat.new()
	body_style.bg_color = Color("#15243b")
	body_style.border_color = Color("#8ceeff")
	body_style.set_border_width_all(2)
	body_style.set_corner_radius_all(12)
	body.add_theme_stylebox_override("panel", body_style)
	root.add_child(body)
	var left := Panel.new()
	left.position = Vector2(7, 3)
	left.size = Vector2(13, 18)
	var left_style := StyleBoxFlat.new()
	left_style.bg_color = Color("#6beaff")
	left_style.set_corner_radius_all(5)
	left.add_theme_stylebox_override("panel", left_style)
	body.add_child(left)
	var split := ColorRect.new()
	split.position = Vector2(14, 3)
	split.size = Vector2(2, 18)
	split.color = Color("#8ceeff")
	body.add_child(split)
	return root


func _set_keys(keys: Array[String]) -> void:
	for child in key_row.get_children():
		child.queue_free()
	for key in keys:
		if key == "ЛКМ":
			key_row.add_child(_mouse_icon())
		else:
			key_row.add_child(_keycap(key))
	key_row.visible = not keys.is_empty()


func _hide_shade() -> void:
	for part in shade_parts:
		part.visible = false
	pointer.clear_points()
	pointer_head.visible = false


func _show_ui_step(index: int) -> void:
	if index >= UI_STEPS.size():
		_begin_transition("control", 0)
		return
	stage = "ui_fade"
	Engine.time_scale = SLOW_SPEED
	var item: Dictionary = UI_STEPS[index]
	if index == 2:
		_spawn_tutorial_pickup()
	title_label.text = str(item.title)
	body_label.text = str(item.body)
	_set_keys([])
	next_button.visible = true
	next_button.text = "ДАЛЕЕ"
	panel.visible = true
	panel.modulate.a = 0.0
	fade_started = Time.get_ticks_msec()
	for part in shade_parts:
		part.modulate.a = 0.0
	pointer_target = str(item.target)
	_update_focus()


func _spawn_tutorial_pickup() -> void:
	if arena.sim == null:
		return
	# The pointer highlights the arena center; put a guaranteed, long-lived upgrade there.
	arena.sim.pickups.append({"pos": Vector2(800.0, 450.0), "kind": "swift", "t": 60.0})
	arena.view = arena.sim.snapshot()


func _show_control_step(index: int) -> void:
	if index >= CONTROL_STEPS.size():
		_show_completion()
		return
	stage = "control_fade"
	Engine.time_scale = SLOW_SPEED
	_hide_shade()
	var item: Dictionary = CONTROL_STEPS[index]
	title_label.text = str(item.title)
	body_label.text = str(item.body)
	match str(item.kind):
		"move": _set_wasd_keys()
		"dash": _set_keys([_key_name("dash")])
		"ability": _set_keys([_key_name("ability")])
		"fire": _set_keys(["ЛКМ"])
		"possess": _set_keys(["ЛКМ", _key_name("possess")])
	next_button.visible = false
	panel.visible = true
	panel.modulate.a = 0.0
	fade_started = Time.get_ticks_msec()
	pointer_target = "player"
	_position_control_panel()
	_update_pointer()


func _set_wasd_keys() -> void:
	for child in key_row.get_children():
		child.queue_free()
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 3)
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(_keycap(_key_name("up")))
	layout.add_child(top)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 5)
	for action in ["left", "down", "right"]:
		bottom.add_child(_keycap(_key_name(action)))
	layout.add_child(bottom)
	key_row.add_child(layout)
	key_row.visible = true


func _key_name(action: String) -> String:
	var state := _global_state()
	var controls: Dictionary = state.get("control_keys")
	return OS.get_keycode_string(int(controls.get(action, KEY_W))).to_upper()


func _current_control_done() -> bool:
	match str(CONTROL_STEPS[control_index].kind):
		"move":
			var input_state: Dictionary = arena._read_input()
			return (input_state.get("mv", Vector2.ZERO) as Vector2).length() > 0.15
		"dash": return Input.is_action_just_pressed("dash")
		"ability": return Input.is_action_just_pressed("ability")
		"fire": return Input.is_action_just_pressed("fire")
		"possess":
			var me: Dictionary = arena.sim.players.get(arena.local_id, {})
			return not me.is_empty() and int(me.get("poss_target", 0)) != 0
	return false



func _show_shadow_explanation() -> void:
	var me: Dictionary = arena.sim.players.get(arena.local_id, {})
	if me.is_empty():
		_show_completion()
		return
	arena.sim._make_shadow(me, 0, true)
	# Prepare one stationary, living training target so the possession lesson is always completable.
	me.pos = Vector2(800, 450)
	me.vel = Vector2.ZERO
	for candidate in arena.sim.players.values():
		if candidate.id == arena.local_id:
			continue
		candidate.shadow = false
		candidate.decoy = false
		candidate.light = candidate.max_light
		candidate.derp_t = 0.0
		candidate.derp_by = 0
		candidate.poss_target = 0
		candidate.pos = Vector2(900, 450)
		candidate.vel = Vector2.ZERO
		candidate.human = true
		# It is no longer driven by bot AI; drop its last bot input so it truly stands still.
		arena.sim.inputs.erase(candidate.id)
		break
	arena.view = arena.sim.snapshot()
	stage = "ui"
	shadow_explanation = true
	Engine.time_scale = 0.0
	pointer_target = "player"
	title_label.text = "ЦЕЛЬ ДЛЯ ВСЕЛЕНИЯ"
	body_label.text = "Подсвеченный игрок — доступная цель. Подойди к нему и нажми ЛКМ или E, чтобы вселиться и управлять им."
	_set_keys([])
	next_button.visible = true
	next_button.text = "ПОПРОБОВАТЬ ВСЕЛЕНИЕ"
	panel.visible = true
	panel.modulate.a = 1.0
	_update_focus()


func _begin_transition(next_stage: String, next_index: int, delay_ms: int = TRANSITION_MS) -> void:
	stage = "transition"
	transition_target = next_stage
	if next_stage == "control":
		control_index = next_index
	else:
		ui_index = next_index
	Engine.time_scale = NORMAL_SPEED
	_hide_shade()
	panel.modulate.a = 0.0
	transition_deadline = Time.get_ticks_msec() + delay_ms


func _on_next() -> void:
	if stage != "ui":
		return
	if shadow_explanation:
		shadow_explanation = false
		_begin_transition("control", control_index + 1)
		return
	ui_index += 1
	# UI explanations are a continuous sequence: no gameplay-speed gap between them.
	_show_ui_step(ui_index)


func _target_rect() -> Rect2:
	var vp := get_viewport().get_visible_rect().size
	match pointer_target:
		"timer": return Rect2(Vector2(vp.x - 450, 0), Vector2(450, 115))
		"score": return Rect2(Vector2(40, 24), Vector2(320, 205))
		"help": return Rect2(Vector2(vp.x - 525, 0), Vector2(525, 145))
		"zones": return Rect2(vp * 0.5 + (Vector2(400, 225) - Vector2(800, 450)) * 0.78 - Vector2(88, 88), Vector2(176, 176))
		"light": return Rect2(Vector2(vp.x * 0.5 - 190, vp.y - 74), Vector2(360, 30))
		"dash": return Rect2(Vector2(vp.x * 0.5 - 220, vp.y - 43), Vector2(440, 15))
		"ability": return Rect2(Vector2(vp.x * 0.5 - 220, vp.y - 29), Vector2(440, 15))
		"arena": return Rect2(vp * 0.5 - Vector2(240, 180), Vector2(480, 360))
	return Rect2(vp * 0.5 - Vector2(80, 50), Vector2(160, 100))


func _update_focus() -> void:
	var vp := get_viewport().get_visible_rect().size
	focus_rect = _target_rect()
	var left := focus_rect.position.x
	var top := focus_rect.position.y
	var right := left + focus_rect.size.x
	var bottom := top + focus_rect.size.y
	var rects := [
		Rect2(Vector2.ZERO, Vector2(vp.x, maxf(0.0, top))),
		Rect2(Vector2(0, bottom), Vector2(vp.x, maxf(0.0, vp.y - bottom))),
		Rect2(Vector2(0, top), Vector2(maxf(0.0, left), focus_rect.size.y)),
		Rect2(Vector2(right, top), Vector2(maxf(0.0, vp.x - right), focus_rect.size.y))
	]
	for i in 4:
		var part := shade_parts[i]
		part.visible = true
		part.position = rects[i].position
		part.size = rects[i].size
	_update_panel_near_focus()
	_update_pointer()


func _update_panel_near_focus() -> void:
	var vp := get_viewport().get_visible_rect().size
	var size := Vector2(650, 190)
	var pos := Vector2((vp.x - size.x) * 0.5, (vp.y - size.y) * 0.5)
	if focus_rect.position.y < vp.y * 0.32:
		pos.y = minf(vp.y - size.y - 18, focus_rect.end.y + 16)
	elif focus_rect.end.y > vp.y * 0.68:
		pos.y = maxf(58.0, focus_rect.position.y - size.y - 16)
	elif pointer_target == "arena":
		pos = Vector2((vp.x - size.x) * 0.5, 58.0)
	elif focus_rect.position.x < vp.x * 0.35:
		pos = Vector2(minf(vp.x - size.x - 14, focus_rect.end.x + 14), (vp.y - size.y) * 0.5)
	else:
		pos = Vector2(maxf(12.0, focus_rect.position.x - size.x - 14), (vp.y - size.y) * 0.5)
	pos.x = clampf(pos.x, 12.0, vp.x - size.x - 12.0)
	pos.y = clampf(pos.y, 54.0, vp.y - size.y - 12.0)
	panel.position = pos
	panel.size = size


func _position_control_panel() -> void:
	var vp := get_viewport().get_visible_rect().size
	panel.position = Vector2((vp.x - 650) * 0.5, vp.y - 225)
	panel.size = Vector2(650, 190)


func _update_pointer() -> void:
	var vp := get_viewport().get_visible_rect().size
	var target := focus_rect.get_center() if stage == "ui" else Vector2(vp.x * 0.5, vp.y * 0.5)
	if (stage == "control" or stage == "ui") and pointer_target == "player":
		var me := _local_player()
		if not me.is_empty():
			var target_pos: Vector2 = me.p
			if shadow_explanation:
				for candidate in arena.view.get("pl", []):
					if int(candidate.i) != arena.local_id and not bool(candidate.s):
						target_pos = candidate.p
						break
			target = vp * 0.5 + (target_pos - Vector2(800, 450)) * 0.78
	if stage == "ui" or stage == "ui_fade":
		var start := panel.position + Vector2(panel.size.x * 0.5, panel.size.y * 0.5)
		var direction := (target - start).normalized()
		var half_size := panel.size * 0.5
		var edge_distance := minf(half_size.x / maxf(absf(direction.x), 0.001), half_size.y / maxf(absf(direction.y), 0.001))
		var edge_start := start + direction * (edge_distance + 7.0)
		var tip := target - direction * 13.0
		pointer.points = PackedVector2Array([edge_start, tip])
		var side := Vector2(-direction.y, direction.x)
		pointer_head.polygon = PackedVector2Array([target, target - direction * 15.0 + side * 7.0, target - direction * 15.0 - side * 7.0])
		pointer_head.position = Vector2.ZERO
		pointer_head.visible = true
		pointer.default_color = Color("#68efff", 0.72 + 0.25 * sin(pulse * 3.2))
		pointer.width = 2.4 + 0.5 * (0.5 + 0.5 * sin(pulse * 3.2))
	else:
		pointer.clear_points()
		pointer_head.visible = false


func _local_player() -> Dictionary:
	for pd in arena.view.get("pl", []):
		if int(pd.i) == arena.local_id:
			return pd
	return {}


func _global_state() -> Node:
	return get_node("/root/G")


func _update_completion_pulse() -> void:
	panel.modulate.a = 0.96 + 0.04 * sin(pulse * 2.0)


func _show_completion() -> void:
	if finished:
		return
	stage = "completion"
	Engine.time_scale = NORMAL_SPEED
	_hide_shade()
	pointer_target = ""
	title_label.text = "ОБУЧЕНИЕ ПРОЙДЕНО!"
	body_label.text = "Отличная работа! Теперь ты знаешь основы Светобаламута. Можешь сразу начать матч или пройти обучение ещё раз."
	_set_keys([])
	next_button.visible = false
	panel.visible = true
	var viewport_size := get_viewport().get_visible_rect().size
	panel.position = Vector2((viewport_size.x - 650) * 0.5, (viewport_size.y - 190) * 0.5)
	panel.size = Vector2(650, 190)
	var column := panel.get_child(0) as VBoxContainer
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	var finish_btn := FacetButton.new()
	finish_btn.text = "ЗАВЕРШИТЬ ОБУЧЕНИЕ"
	finish_btn.custom_minimum_size = Vector2(235, 42)
	finish_btn.pressed.connect(_complete_and_exit)
	actions.add_child(finish_btn)
	var replay_btn := FacetButton.new()
	replay_btn.text = "ПРОЙТИ ЕЩЁ РАЗ"
	replay_btn.custom_minimum_size = Vector2(200, 42)
	replay_btn.pressed.connect(_restart_tutorial)
	actions.add_child(replay_btn)
	column.add_child(actions)
	skip_button.visible = false
	var state := _global_state()
	state.set("tutorial_done", true)
	state.call("save_settings")


func _complete_and_exit() -> void:
	if finished:
		return
	finished = true
	var state := _global_state()
	var back_to_lobby := bool(state.get("tutorial_return_to_lobby"))
	Engine.time_scale = NORMAL_SPEED
	state.set("tutorial_active", false)
	state.set("tutorial_return_to_lobby", false)
	if back_to_lobby:
		state.set("mode", state.get("tutorial_previous_mode"))
	else:
		state.set("mode", "single")
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _restart_tutorial() -> void:
	if finished:
		return
	finished = true
	var state := _global_state()
	var back_to_lobby := bool(state.get("tutorial_return_to_lobby"))
	var previous_mode = state.get("tutorial_previous_mode")
	Engine.time_scale = NORMAL_SPEED
	state.set("tutorial_active", false)
	if back_to_lobby:
		state.set("mode", previous_mode)
	state.call("start_tutorial_game", back_to_lobby)


func _exit_tree() -> void:
	Engine.time_scale = NORMAL_SPEED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not finished:
		var state := _global_state()
		state.set("tutorial_active", false)
		if bool(state.get("tutorial_return_to_lobby")):
			state.set("mode", state.get("tutorial_previous_mode"))
		state.set("tutorial_return_to_lobby", false)
