extends Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#080d19")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title := Label.new()
	title.text = "ПЕРЕД ПЕРВЫМ МАТЧЕМ"
	title.position = Vector2(0, 55)
	title.size = Vector2(1280, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color("#7feaff"))
	add_child(title)
	var panel := VBoxContainer.new()
	panel.position = Vector2(190, 155)
	panel.size = Vector2(900, 390)
	panel.add_theme_constant_override("separation", 18)
	add_child(panel)
	var lines := [
		"ЦЕЛЬ — остаться последним игроком, у которого есть свет.",
		"WASD — перемещение. Мышь — направление атаки, ЛКМ — выстрел.",
		"ПРОБЕЛ — рывок. Q — уникальная способность выбранного персонажа.",
		"Тёмные зоны на арене восстанавливают свет. Движение и атаки его расходуют.",
		"Если свет закончился, ты становишься Тенью. Найди живого игрока и нажми ПКМ или E, чтобы вселиться.",
		"У каждого класса свои характеристики, атака и способность. Меняй класс и экипировку в профиле."
	]
	for text_line in lines:
		var line := Label.new()
		line.text = "◆  " + text_line
		line.custom_minimum_size = Vector2(880, 48)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_font_size_override("font_size", 21)
		line.add_theme_color_override("font_color", Color("#d5e3f5"))
		panel.add_child(line)
	var actions := HBoxContainer.new()
	actions.position = Vector2(190, 590)
	actions.size = Vector2(900, 72)
	actions.add_theme_constant_override("separation", 18)
	add_child(actions)
	_make_button("ПРОПУСТИТЬ ТУТОРИАЛ", actions, _finish)
	_make_button("ПОНЯТНО, НАЧАТЬ", actions, _finish)


func _make_button(text: String, parent: Node, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(440, 62)
	button.add_theme_font_size_override("font_size", 20)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#101d30")
	normal.border_color = Color("#39d8ee")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(0)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color("#1b3048")
	button.add_theme_stylebox_override("hover", hover)
	button.pressed.connect(callback)
	parent.add_child(button)


func _finish() -> void:
	G.tutorial_done = true
	G.save_settings()
	if G.tutorial_return_to_lobby:
		G.tutorial_return_to_lobby = false
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
	else:
		G.start_single_game()
