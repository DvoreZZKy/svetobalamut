extends Node
## Интерактивный обучающий сценарий, работающий поверх настоящей симуляции арены.

const NORMAL_SPEED := 1.0
const SLOW_SPEED := 0.10
const STEPS := [
	{"title":"ЗДОРОВЬЕ И СВЕТ","body":"Полоса внизу показывает запас света. Получая попадания, ты теряешь свет. Движение и выстрелы тоже расходуют его, поэтому следи за запасом."},
	{"title":"ТВОЯ АТАКА","body":"Наведи мышь на противника и зажми левую кнопку мыши (ЛКМ), чтобы стрелять. Попадания отнимают свет у соперника."},
	{"title":"ТАЙМЕР","body":"В верхней части экрана находится таймер раунда. Если время закончится, победитель определяется по очкам хаоса."},
	{"title":"ТАБЛИЦА ИГРОКОВ","body":"Слева показаны участники, их текущий свет или состояние Тени, а также очки хаоса. Строка с отметкой > — это ты."},
	{"title":"ПОДСКАЗКИ И СПОСОБНОСТЬ","body":"Справа отображаются твой класс, способность и её перезарядка. Нажми Q, чтобы применить особую способность своего персонажа."},
	{"title":"РЫВОК","body":"Под полосой света находится перезарядка рывка. Пробел даёт короткое ускорение и неуязвимость на мгновение. Рывок расходует свет."},
	{"title":"ТЁМНЫЕ ЗОНЫ","body":"Фиолетовые круги на арене восстанавливают свет. Если стоять неподвижно, свет тоже понемногу возвращается. Используй это, чтобы продержаться дольше."}
]

var arena: Node2D
var layer: CanvasLayer
var shade: ColorRect
var panel: PanelContainer
var title_label: Label
var body_label: Label
var next_button: Button
var key_row: HBoxContainer
var pointer: Line2D
var pointer_dot: Polygon2D
var stage := "move_intro"
var step_index := 0
var bot_shot_seen := false
var pointer_target := ""
var pulse := 0.0
var finished := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	arena = get_parent()
	_build_overlay()
	_show_movement_intro()


func _process(dt: float) -> void:
	if finished:
		return
	pulse += dt
	if pointer_target != "":
		_update_pointer()
	if stage == "wait_move":
		var inp: Dictionary = arena._read_input()
		if (inp.get("mv", Vector2.ZERO) as Vector2).length() > 0.15:
			_show_dash_intro()
	elif stage == "wait_dash" and Input.is_action_just_pressed("dash"):
		_show_ability_intro()
	elif stage == "wait_ability" and Input.is_action_just_pressed("ability"):
		_wait_for_bot_shot()
	elif stage == "wait_bot_shot":
		for bullet in arena.view.get("bl", []):
			if int(bullet[3]) != arena.local_id:
				bot_shot_seen = true
				break
		if bot_shot_seen:
			_show_step("ПОПАДАНИЕ И СВЕТ", "Бот уже открыл огонь. Попадание уменьшает твой запас света — полоса также является твоим здоровьем. Когда свет закончится, ты превратишься в Тень.", "light")
	elif stage == "wait_shadow":
		var me := _local_player()
		if not me.is_empty() and bool(me.get("s", false)):
			_show_shadow_intro()
	elif stage == "wait_possess" and Input.is_action_pressed("possess"):
		_finish_tutorial()


func _build_overlay() -> void:
	layer = CanvasLayer.new()
	layer.layer = 30
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	arena.add_child(layer)
	shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.005, 0.008, 0.025, 0.28)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(shade)
	pointer = Line2D.new()
	pointer.width = 3.0
	pointer.default_color = Color("#68efff")
	pointer.z_index = 20
	layer.add_child(pointer)
	pointer_dot = Polygon2D.new()
	pointer_dot.polygon = PackedVector2Array([Vector2(0,-7), Vector2(13,0), Vector2(0,7)])
	pointer_dot.color = Color("#b8fbff")
	pointer_dot.z_index = 21
	layer.add_child(pointer_dot)
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position = Vector2(-390, -190)
	panel.size = Vector2(780, 160)
	panel.add_theme_stylebox_override("panel", _panel_style())
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 25)
	title_label.add_theme_color_override("font_color", Color("#7feaff"))
	column.add_child(title_label)
	body_label = Label.new()
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", 17)
	body_label.add_theme_color_override("font_color", Color("#e0edff"))
	body_label.custom_minimum_size.y = 58
	column.add_child(body_label)
	key_row = HBoxContainer.new()
	key_row.alignment = BoxContainer.ALIGNMENT_CENTER
	key_row.add_theme_constant_override("separation", 8)
	column.add_child(key_row)
	next_button = Button.new()
	next_button.text = "ДАЛЕЕ"
	next_button.custom_minimum_size = Vector2(190, 42)
	next_button.add_theme_font_size_override("font_size", 18)
	next_button.pressed.connect(_on_next)
	column.add_child(next_button)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0b1428", 0.97)
	style.border_color = Color("#36cce8")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _keycap(letter: String) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(48, 48)
	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color("#75eaff")
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	frame.add_theme_stylebox_override("panel", style)
	box.add_child(frame)
	var label := Label.new()
	label.text = letter
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 23)
	label.add_theme_color_override("font_color", Color("#e8fbff"))
	box.add_child(label)
	return box


func _set_keys(keys: Array[String]) -> void:
	for child in key_row.get_children():
		child.queue_free()
	for key in keys:
		key_row.add_child(_keycap(key))
	key_row.visible = not keys.is_empty()


func _show_movement_intro() -> void:
	stage = "move_intro"
	Engine.time_scale = 0.0
	_set_keys(["W"])
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 0)
	_set_keys(["W"])
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_keycap("A"))
	row.add_child(_keycap("S"))
	row.add_child(_keycap("D"))
	key_row.add_child(row)
	title_label.text = "ПЕРЕДВИЖЕНИЕ"
	body_label.text = "Для перемещения используй клавиши WASD. Нажми «Далее», затем попробуй пройтись по арене."
	next_button.visible = true
	pointer_target = "player"


func _show_dash_intro() -> void:
	stage = "dash_intro"
	Engine.time_scale = 0.0
	_set_keys(["ПРОБЕЛ"])
	title_label.text = "РЫВОК"
	body_label.text = "Пробел позволяет резко ускориться. Нажми «Далее», а затем используй рывок."
	next_button.visible = true
	pointer_target = "player"


func _show_ability_intro() -> void:
	stage = "ability_intro"
	Engine.time_scale = 0.0
	_set_keys(["Q"])
	title_label.text = "ОСОБАЯ СПОСОБНОСТЬ"
	body_label.text = "У каждого класса есть собственная способность. Нажми «Далее» и попробуй применить её клавишей Q."
	next_button.visible = true
	pointer_target = "help"


func _wait_for_bot_shot() -> void:
	stage = "wait_bot_shot"
	Engine.time_scale = SLOW_SPEED
	title_label.text = "СМОТРИ НА СОПЕРНИКОВ"
	body_label.text = "Боты сражаются самостоятельно. Подожди, пока один из них выстрелит — мы остановим бой и разберём интерфейс."
	_set_keys([])
	next_button.visible = false
	pointer_target = "player"


func _show_step(step_title: String, description: String, target: String) -> void:
	stage = "step"
	Engine.time_scale = 0.0
	title_label.text = step_title
	body_label.text = description
	_set_keys([])
	next_button.visible = true
	pointer_target = target


func _on_next() -> void:
	match stage:
		"move_intro":
			stage = "wait_move"
			Engine.time_scale = SLOW_SPEED
			next_button.visible = false
			body_label.text = "Теперь подвигайся с помощью WASD."
		"dash_intro":
			stage = "wait_dash"
			Engine.time_scale = SLOW_SPEED
			next_button.visible = false
			body_label.text = "Попробуй сделать рывок клавишей ПРОБЕЛ."
		"ability_intro":
			stage = "wait_ability"
			Engine.time_scale = SLOW_SPEED
			next_button.visible = false
			body_label.text = "Нажми Q, чтобы применить способность."
		"step":
			if step_index < STEPS.size():
				var item: Dictionary = STEPS[step_index]
				step_index += 1
				_show_step(str(item.title), str(item.body), _step_target(step_index))
			else:
				_force_shadow()


func _step_target(index: int) -> String:
	return ["timer", "score", "help", "dash", "arena"][mini(index - 1, 4)]


func _force_shadow() -> void:
	stage = "force_shadow"
	Engine.time_scale = 0.0
	title_label.text = "ТЕПЕРЬ ТЫ — ТЕНЬ"
	body_label.text = "Чтобы показать механику Тени, мы завершим твою световую форму в рамках обучения. Нажми «Далее»."
	_set_keys([])
	next_button.visible = true
	pointer_target = "player"
	step_index = STEPS.size() + 1


func _show_shadow_intro() -> void:
	stage = "shadow_intro"
	Engine.time_scale = 0.0
	title_label.text = "СПОСОБНОСТИ ТЕНИ"
	body_label.text = "Тень быстрее обычного игрока и может скрытно приблизиться к живому сопернику. Для вселения подойди к нему и нажми ПКМ или E."
	_set_keys(["ПКМ", "E"])
	next_button.visible = true
	pointer_target = "player"


func _local_player() -> Dictionary:
	for pd in arena.view.get("pl", []):
		if int(pd.i) == arena.local_id:
			return pd
	return {}


func _update_pointer() -> void:
	var vp := get_viewport().get_visible_rect().size
	var target := vp * 0.5
	match pointer_target:
		"player":
			var me := _local_player()
			if not me.is_empty():
				target = vp * 0.5 + (me.p - Vector2(800, 450)) * 0.78
		"timer": target = Vector2(vp.x * 0.5, 55)
		"score": target = Vector2(175, 150)
		"help": target = Vector2(vp.x - 240, 105)
		"light": target = Vector2(vp.x * 0.5, vp.y - 42)
		"dash": target = Vector2(vp.x * 0.5, vp.y - 18)
		"arena": target = vp * 0.5
	var origin := Vector2(vp.x * 0.5, vp.y - 190)
	pointer.points = PackedVector2Array([origin, origin + Vector2(0, -35), target])
	pointer_dot.position = target
	pointer_dot.rotation = (origin - target).angle()
	pointer.default_color = Color("#68efff", 0.75 + 0.25 * sin(pulse * 4.0))


func _on_shadow_next() -> void:
	pass


func _finish_tutorial() -> void:
	finished = true
	Engine.time_scale = NORMAL_SPEED
	G.tutorial_active = false
	G.tutorial_done = true
	G.save_settings()
	if is_instance_valid(layer):
		layer.queue_free()
	if G.tutorial_return_to_lobby:
		G.tutorial_return_to_lobby = false
		get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _input(event: InputEvent) -> void:
	if finished:
		return
	if stage == "shadow_intro" and event is InputEventKey and event.pressed and (event.keycode == KEY_E):
		stage = "wait_possess"
	elif stage == "shadow_intro" and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		stage = "wait_possess"
	if stage == "force_shadow" and event is InputEventMouseButton and event.pressed:
		return
