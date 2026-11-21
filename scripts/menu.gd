extends Control

const VectorActor = preload("res://scripts/vector_actor.gd")
const FacetButton = preload("res://scripts/facet_button.gd")
const VectorLogo = preload("res://scripts/vector_logo.gd")
## Главное меню и подэкраны профиля, подключения, настроек и лобби.

var t := 0.0
var bg_shards: Array[Polygon2D] = []
var bg_orbs: Array[Node2D] = []
var bg_dots: Array[Polygon2D] = []
var bg_dot_velocities: Array[Vector2] = []
var title: Control
var boxes := {}
var status: Label
var ip_edit: LineEdit
var lobby_list: VBoxContainer
var lobby_info: Label
var start_btn: Button
var profile_preview
var lobby_preview
var lobby_color_btn: Button
var lobby_kind_btn: Button
var lobby_outfit_btn: Button
var lobby_hat_btn: Button
var profile_info: Label
var profile_color_btn: Button
var profile_kind_btn: Button
var profile_outfit_btn: Button
var profile_hat_btn: Button
var lobby_frame_data: Array[Dictionary] = []
var lobby_root: VBoxContainer
var waiting_control := ""
var control_buttons := {}


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(G.make_env())
	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.012, 0.035)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_build_particles()
	_apply_menu_quality()
	title = VectorLogo.new()
	title.position = Vector2(0, 14)
	title.size = Vector2(1280, 112)
	add_child(title)

	var main := _box("main")
	_btn("Играть одному (с ботами)", main, func(): Sfx.play("click"); G.start_single())
	_btn("Обучение", main, _start_tutorial_from_menu)
	_btn("Создать комнату", main, _on_host)
	_btn("Подключиться", main, func(): Sfx.play("click"); _show("join"))
	_btn("Персонаж", main, func(): Sfx.play("click"); _refresh_profile(); _show("profile"))
	_btn("Настройки", main, func(): Sfx.play("click"); _show("settings"))
	_btn("Выход", main, func(): G.save_settings(); get_tree().quit())

	var join := _box("join")
	_title(join, "АДРЕС КОМНАТЫ (IP:ПОРТ)")
	ip_edit = LineEdit.new()
	ip_edit.text = "127.0.0.1"
	ip_edit.custom_minimum_size = Vector2(380, 50)
	ip_edit.add_theme_font_size_override("font_size", 26)
	join.add_child(ip_edit)
	_btn("Подключиться", join, _on_join)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 20)
	join.add_child(status)
	_btn("Назад", join, func(): _show("main"))

	var profile := _box("profile")
	profile.position = Vector2(390, 72)
	profile.size = Vector2(500, 560)
	profile.add_theme_constant_override("separation", 5)
	_title(profile, "ТВОЙ ПЕРСОНАЖ")
	profile_preview = _make_vector_preview(profile)
	profile_info = Label.new()
	profile_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile_info.add_theme_font_size_override("font_size", 15)
	profile.add_child(profile_info)
	profile_color_btn = _btn("Цвет", profile, func():
		G.profile_color = (G.profile_color + 1) % G.PROFILE_COLORS.size()
		_refresh_profile())
	profile_kind_btn = _btn("Персонаж", profile, func():
		G.profile_kind = (G.profile_kind + 1) % 4
		_refresh_profile())
	profile_outfit_btn = _btn("Костюм", profile, func():
		G.profile_outfit = (G.profile_outfit + 1) % 5
		_refresh_profile())
	profile_hat_btn = _btn("Шапка", profile, func():
		G.profile_hat = (G.profile_hat + 1) % 5
		_refresh_profile())
	_btn("Сохранить и назад", profile, func(): G.save_settings(); _show("main"))
	for profile_btn in [profile_color_btn, profile_kind_btn, profile_outfit_btn, profile_hat_btn]:
		profile_btn.custom_minimum_size = Vector2(450, 38)
		profile_btn.add_theme_font_size_override("font_size", 18)
	var save_profile_btn := profile.get_child(profile.get_child_count() - 1) as Button
	save_profile_btn.custom_minimum_size = Vector2(450, 38)
	save_profile_btn.add_theme_font_size_override("font_size", 18)
	_refresh_profile()

	var st := _box("settings")
	_title(st, "Настройки")
	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	st.add_child(tabs)
	var player_scroll := ScrollContainer.new()
	player_scroll.name = "ИГРОК И ЗВУК"
	player_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(player_scroll)
	var player_tab := VBoxContainer.new()
	player_tab.add_theme_constant_override("separation", 12)
	player_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_scroll.add_child(player_tab)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Имя игрока"
	name_edit.text = G.player_name
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(380, 46)
	name_edit.add_theme_font_size_override("font_size", 22)
	name_edit.text_changed.connect(func(s: String): G.player_name = s if s != "" else "Светляк")
	player_tab.add_child(name_edit)
	_slider(player_tab, "Музыка", G.vol_music, func(v: float): G.vol_music = v; Sfx.refresh_volume())
	_slider(player_tab, "Звуки", G.vol_sfx, func(v: float): G.vol_sfx = v; Sfx.play("shot"))

	var mouse_scroll := ScrollContainer.new()
	mouse_scroll.name = "МЫШЬ И УПРАВЛЕНИЕ"
	mouse_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(mouse_scroll)
	var mouse_tab := VBoxContainer.new()
	mouse_tab.add_theme_constant_override("separation", 12)
	mouse_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_scroll.add_child(mouse_tab)
	_slider(mouse_tab, "Чувствительность мыши", (G.mouse_sensitivity - 0.5) / 2.5, func(v: float): G.mouse_sensitivity = 0.5 + v * 2.5; G.save_settings())
	var match_sens := CheckBox.new()
	match_sens.text = "Изменять чувствительность в матче"
	match_sens.button_pressed = G.match_mouse_sensitivity
	match_sens.toggled.connect(func(b: bool): G.match_mouse_sensitivity = b; G.save_settings())
	mouse_tab.add_child(match_sens)
	_btn("УПРАВЛЕНИЕ КЛАВИШАМИ", mouse_tab, func(): _show("controls"))

	var graphics_scroll := ScrollContainer.new()
	graphics_scroll.name = "ГРАФИКА И ЭКРАН"
	graphics_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(graphics_scroll)
	var graphics_tab := VBoxContainer.new()
	graphics_tab.add_theme_constant_override("separation", 12)
	graphics_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graphics_scroll.add_child(graphics_tab)
	var quality_panel := VBoxContainer.new()
	quality_panel.add_theme_constant_override("separation", 8)
	var quality_heading := HBoxContainer.new()
	quality_heading.add_theme_constant_override("separation", 8)
	var quality_label := Label.new()
	quality_label.text = "КАЧЕСТВО ГРАФИКИ"
	quality_label.add_theme_font_size_override("font_size", 17)
	quality_label.add_theme_color_override("font_color", Color("#b9eefa"))
	quality_heading.add_child(quality_label)
	var quality_value := Label.new()
	quality_value.text = G.GRAPHICS_PRESETS[G.graphics_quality].to_upper()
	quality_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quality_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quality_value.add_theme_font_size_override("font_size", 14)
	quality_value.add_theme_color_override("font_color", Color("#69eaff"))
	quality_heading.add_child(quality_value)
	quality_panel.add_child(quality_heading)
	var quality_buttons := HBoxContainer.new()
	quality_buttons.add_theme_constant_override("separation", 6)
	var quality_group := ButtonGroup.new()
	var quality_names := ["ВЫСОКАЯ", "СРЕДНЯЯ", "НИЗКАЯ", "КАРТОШКА"]
	var quality_texts: Array[Label] = []
	for i in G.GRAPHICS_PRESETS.size():
		var preset_index := i
		var quality_btn := FacetButton.new()
		quality_btn.toggle_mode = true
		quality_btn.button_group = quality_group
		quality_btn.button_pressed = i == G.graphics_quality
		quality_btn.custom_minimum_size = Vector2(0, 46)
		quality_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		quality_btn.text = ""
		var quality_text := Label.new()
		quality_text.text = quality_names[i]
		quality_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		quality_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		quality_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		quality_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		quality_text.z_index = 3
		quality_text.add_theme_font_size_override("font_size", 12)
		quality_text.add_theme_font_override("font", ThemeDB.fallback_font)
		quality_text.add_theme_color_override("font_color", Color("#ffffff") if i == G.graphics_quality else Color("#b9eefa"))
		quality_text.add_theme_color_override("font_outline_color", Color("#07111f"))
		quality_text.add_theme_constant_override("outline_size", 2)
		quality_btn.add_child(quality_text)
		quality_texts.append(quality_text)
		quality_btn.pressed.connect(func():
			G.graphics_quality = preset_index
			quality_value.text = G.GRAPHICS_PRESETS[preset_index].to_upper()
			for j in quality_texts.size():
				quality_texts[j].add_theme_color_override("font_color", Color("#ffffff") if j == preset_index else Color("#b9eefa"))
			G.apply_graphics()
			_apply_menu_quality()
			G.save_settings())
		quality_buttons.add_child(quality_btn)
	quality_panel.add_child(quality_buttons)
	var quality_hint := Label.new()
	quality_hint.text = "Меньше эффектов — выше производительность"
	quality_hint.add_theme_font_size_override("font_size", 12)
	quality_hint.add_theme_color_override("font_color", Color("#829bb5"))
	quality_panel.add_child(quality_hint)
	graphics_tab.add_child(quality_panel)
	var sh := CheckBox.new()
	sh.text = "Эффекты камеры"
	sh.button_pressed = G.shake_on
	sh.tooltip_text = "Лёгкая тряска при ударах, столкновениях и взрывах."
	sh.add_theme_font_size_override("font_size", 20)
	sh.toggled.connect(func(b: bool): G.shake_on = b; G.save_settings())
	graphics_tab.add_child(sh)
	var fs := CheckBox.new()
	fs.text = "Полный экран"
	fs.button_pressed = G.fullscreen
	fs.add_theme_font_size_override("font_size", 20)
	fs.toggled.connect(func(b: bool): G.fullscreen = b; G.apply_display(); G.save_settings())
	graphics_tab.add_child(fs)
	_btn("НАЗАД", st, func(): G.save_settings(); _show("main"))


	var controls := _box("controls")
	controls.position = Vector2(390, 95)
	controls.size = Vector2(500, 610)
	_title(controls, "НАСТРОЙКА УПРАВЛЕНИЯ")
	for action in ["up", "down", "left", "right", "dash", "ability", "possess"]:
		var bind_btn := _btn("", controls, func(): _begin_rebind(action))
		bind_btn.custom_minimum_size = Vector2(450, 48)
		bind_btn.add_theme_font_size_override("font_size", 17)
		control_buttons[action] = bind_btn
		_update_bind_button(action)
	_btn("НАЗАД К НАСТРОЙКАМ", controls, func(): waiting_control = ""; _show("settings"))

	var lobby := _box("lobby")
	lobby_root = lobby
	_title(lobby, "КОМНАТА")
	lobby_info = Label.new()
	lobby_info.custom_minimum_size = Vector2(0, 58)
	lobby_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lobby_info.add_theme_font_size_override("font_size", 17)
	lobby_info.add_theme_color_override("font_color", Color("#a9efff"))
	lobby_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby.add_child(lobby_info)
	var lobby_columns := HBoxContainer.new()
	lobby_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lobby_columns.add_theme_constant_override("separation", 22)
	lobby.add_child(lobby_columns)
	var players_panel := VBoxContainer.new()
	players_panel.custom_minimum_size = Vector2(500, 390)
	players_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	players_panel.size_flags_stretch_ratio = 0.48
	lobby_columns.add_child(players_panel)
	_add_facet_panel(lobby, players_panel, Color("#10283a"), Color("#287e91"))
	var players_heading := _title(players_panel, "УЧАСТНИКИ")
	players_heading.custom_minimum_size.y = 42
	players_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var roster_scroll := ScrollContainer.new()
	roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_scroll.clip_contents = true
	players_panel.add_child(roster_scroll)
	lobby_list = VBoxContainer.new()
	lobby_list.add_theme_constant_override("separation", 8)
	lobby_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_scroll.add_child(lobby_list)
	var editor_panel := VBoxContainer.new()
	editor_panel.custom_minimum_size = Vector2(560, 390)
	editor_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_panel.size_flags_stretch_ratio = 0.52
	editor_panel.add_theme_constant_override("separation", 4)
	lobby_columns.add_child(editor_panel)
	_add_facet_panel(lobby, editor_panel, Color("#1b1b3b"), Color("#51458c"))
	var editor_heading := _title(editor_panel, "ВАШ ПЕРСОНАЖ")
	editor_heading.custom_minimum_size.y = 42
	editor_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_preview = _make_vector_preview(editor_panel)
	var lobby_editor_info := Label.new()
	lobby_editor_info.text = "Изменения сразу видны остальным игрокам"
	lobby_editor_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_editor_info.add_theme_font_size_override("font_size", 14)
	editor_panel.add_child(lobby_editor_info)
	lobby_color_btn = _btn("Цвет", editor_panel, func(): G.profile_color = (G.profile_color + 1) % G.PROFILE_COLORS.size(); _refresh_profile(); _sync_lobby_profile())
	lobby_kind_btn = _btn("Персонаж", editor_panel, func(): G.profile_kind = (G.profile_kind + 1) % 4; _refresh_profile(); _sync_lobby_profile())
	lobby_outfit_btn = _btn("Костюм", editor_panel, func(): G.profile_outfit = (G.profile_outfit + 1) % 5; _refresh_profile(); _sync_lobby_profile())
	lobby_hat_btn = _btn("Шапка", editor_panel, func(): G.profile_hat = (G.profile_hat + 1) % 5; _refresh_profile(); _sync_lobby_profile())
	for child in editor_panel.get_children():
		if child is Button:
			child.custom_minimum_size = Vector2(470, 38)
			child.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			child.add_theme_font_size_override("font_size", 17)
	_refresh_profile()
	var lobby_actions := HBoxContainer.new()
	lobby_actions.add_theme_constant_override("separation", 12)
	lobby.add_child(lobby_actions)
	_btn("ПРОЙТИ ТУТОРИАЛ", lobby_actions, _open_lobby_tutorial)
	start_btn = _btn("СТАРТ", lobby_actions, func(): Net.start_match())
	_btn("ВЫЙТИ", lobby_actions, func(): G.save_settings(); Net.leave(); _show("main"))

	Net.lobby_changed.connect(_on_lobby_changed)
	Net.join_failed.connect(_on_join_failed)
	Net.disconnected.connect(_on_net_disconnected)
	Net.match_started.connect(_on_match_started)
	_show("lobby" if Net.online else "main")
	Sfx.play_music()



func _begin_rebind(action: String) -> void:
	waiting_control = action
	if control_buttons.has(action):
		control_buttons[action].text = "НАЖМИ НОВУЮ КЛАВИШУ…"


func _update_bind_button(action: String) -> void:
	if not control_buttons.has(action):
		return
	var names := {"up": "ВВЕРХ", "down": "ВНИЗ", "left": "ВЛЕВО", "right": "ВПРАВО", "dash": "РЫВОК", "ability": "СПОСОБНОСТЬ", "possess": "ВСЕЛЕНИЕ"}
	var key_name := OS.get_keycode_string(int(G.control_keys[action]))
	control_buttons[action].text = "%s  —  %s" % [names[action], key_name.to_upper()]


func _input(event: InputEvent) -> void:
	if waiting_control == "" or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	var keycode := int(key_event.physical_keycode) if key_event.physical_keycode != 0 else int(key_event.keycode)
	if keycode <= 0:
		return
	G.set_control_key(waiting_control, keycode)
	var changed := waiting_control
	waiting_control = ""
	_update_bind_button(changed)
	get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	# Net is an autoload that outlives this scene: never leave stale connections behind.
	for pair in [[Net.lobby_changed, _on_lobby_changed], [Net.join_failed, _on_join_failed],
			[Net.disconnected, _on_net_disconnected], [Net.match_started, _on_match_started]]:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])


func _on_join_failed() -> void:
	status.text = "Не удалось подключиться"
	_show("join")


func _on_net_disconnected() -> void:
	status.text = "Соединение потеряно"
	_show("main")


func _on_match_started() -> void:
	get_tree().change_scene_to_file("res://scenes/arena.tscn")


func _process(dt: float) -> void:
	t += dt
	_update_lobby_frames()
	var shard_count: int = [bg_shards.size(), 18, 8, 0][G.graphics_quality]
	for i in shard_count:
		var shard := bg_shards[i]
		shard.rotation += dt * (0.16 if i % 2 == 0 else -0.12)
		shard.position.y += sin(t * 0.75 + float(i)) * dt * 5.0
		if shard.position.y > 740.0:
			shard.position.y = -30.0
		shard.position.x += sin(t * 0.42 + float(i) * 0.7) * dt * 7.0
	var orb_count: int = [bg_orbs.size(), 5, 2, 0][G.graphics_quality]
	for i in orb_count:
		var orb := bg_orbs[i]
		orb.rotation += dt * (0.035 if i % 2 == 0 else -0.028)
		var wave := 1.0 + 0.10 * sin(t * 0.8 + float(i) * 1.7)
		orb.scale = Vector2.ONE * wave
		orb.position.y += sin(t * 0.25 + float(i)) * dt * 3.0
	var dot_count: int = [bg_dots.size(), 24, 8, 0][G.graphics_quality]
	for i in dot_count:
		var dot := bg_dots[i]
		dot.position += bg_dot_velocities[i] * dt
		dot.rotation += dt * (0.8 if i % 2 == 0 else -0.65)
		if dot.position.x < -30.0 or dot.position.x > 1310.0:
			bg_dot_velocities[i].x *= -1.0
		if dot.position.y < -30.0 or dot.position.y > 750.0:
			bg_dot_velocities[i].y *= -1.0
		dot.modulate.a = 0.35 + 0.3 * (0.5 + 0.5 * sin(t * 2.0 + float(i)))
	title.modulate = G.hdr(Color.from_hsv(fmod(t * 0.08 + 0.5, 1.0), 0.6, 1.0), 1.45 + 0.22 * sin(t * 2.2))


func _build_particles() -> void:
	var shard_colors := [Color("#164c62"), Color("#24446b"), Color("#3b2d68"), Color("#1b6870")]
	for i in 26:
		var shard := Polygon2D.new()
		var w := randf_range(5.0, 13.0)
		var h := randf_range(8.0, 24.0)
		shard.polygon = PackedVector2Array([
			Vector2(0, -h), Vector2(w * 0.7, -h * 0.25),
			Vector2(w, h * 0.45), Vector2(0, h), Vector2(-w, h * 0.35),
			Vector2(-w * 0.55, -h * 0.35)
		])
		shard.position = Vector2(randf_range(20.0, 1260.0), randf_range(20.0, 700.0))
		shard.rotation = randf_range(0.0, TAU)
		shard.color = shard_colors[i % shard_colors.size()]
		shard.color.a = randf_range(0.12, 0.28)
		add_child(shard)
		bg_shards.append(shard)
	for i in 7:
		var orb := Node2D.new()
		orb.position = Vector2(100.0 + float(i) * 178.0, 120.0 + float(i % 3) * 205.0)
		var disc := Polygon2D.new()
		var points := PackedVector2Array()
		var outline_points := PackedVector2Array()
		for j in 48:
			var point := Vector2.from_angle(TAU * float(j) / 48.0) * (34.0 + float(i % 3) * 12.0)
			points.append(point)
			outline_points.append(point)
		disc.polygon = points
		disc.color = [Color("#174b70", 0.055), Color("#4a347a", 0.06), Color("#176c72", 0.05)][i % 3]
		orb.add_child(disc)
		var ring := Line2D.new()
		ring.points = outline_points
		ring.closed = true
		ring.width = 1.4
		ring.default_color = [Color("#277a9a", 0.22), Color("#7254a8", 0.20), Color("#25858a", 0.18)][i % 3]
		orb.add_child(ring)
		add_child(orb)
		bg_orbs.append(orb)
	for i in 34:
		var dot := Polygon2D.new()
		var r := randf_range(2.0, 5.0)
		dot.polygon = PackedVector2Array([
			Vector2(0, -r * 1.8), Vector2(r, -r * 0.35),
			Vector2(r * 0.65, r), Vector2(-r * 0.65, r),
			Vector2(-r, -r * 0.35)
		])
		dot.position = Vector2(randf_range(0.0, 1280.0), randf_range(0.0, 720.0))
		dot.color = [Color("#43dff4"), Color("#a78bfa"), Color("#7cf7d4")][i % 3]
		dot.modulate.a = randf_range(0.25, 0.7)
		add_child(dot)
		bg_dots.append(dot)
		bg_dot_velocities.append(Vector2.from_angle(randf_range(0.0, TAU)) * randf_range(18.0, 68.0))

func _box(key: String) -> VBoxContainer:
	var b := VBoxContainer.new()
	if key == "lobby":
		b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.offset_left = 36
		b.offset_top = 40
		b.offset_right = -36
		b.offset_bottom = -24
	else:
		b.position = Vector2(440, 180 if key == "main" else 145)
		b.size = Vector2(400, 560)
	b.add_theme_constant_override("separation", 14)
	add_child(b)
	boxes[key] = b
	return b


func _refresh_profile() -> void:
	var colors := ["Неоновый голубой", "Розовый", "Золотой", "Фиолетовый", "Мятный", "Оранжевый", "Белый", "Маджента"]
	var kinds := ["Светляк", "Капсула", "Призрак", "Кристалл"]
	var outfits := ["Без костюма", "Броня", "Полосатый", "Неоновый", "Плащ"]
	var hats := ["Без шапки", "Корона", "Кепка", "Рожки", "Ауреол"]
	profile_preview.setup(G.profile_kind, G.col(G.profile_color), G.profile_outfit, G.profile_hat)
	if is_instance_valid(lobby_preview):
		lobby_preview.setup(G.profile_kind, G.col(G.profile_color), G.profile_outfit, G.profile_hat)
	profile_color_btn.text = "Цвет: " + colors[G.profile_color]
	profile_kind_btn.text = "Персонаж: " + kinds[G.profile_kind]
	profile_outfit_btn.text = "Костюм: " + outfits[G.profile_outfit]
	profile_hat_btn.text = "Шапка: " + hats[G.profile_hat]
	if is_instance_valid(lobby_color_btn): lobby_color_btn.text = "Цвет: " + colors[G.profile_color]
	if is_instance_valid(lobby_kind_btn): lobby_kind_btn.text = "Персонаж: " + kinds[G.profile_kind]
	if is_instance_valid(lobby_outfit_btn): lobby_outfit_btn.text = "Костюм: " + outfits[G.profile_outfit]
	if is_instance_valid(lobby_hat_btn): lobby_hat_btn.text = "Шапка: " + hats[G.profile_hat]
	var class_notes := [
		"Быстрый • очередь из 3 зарядов • Q: ускорение и скорострельность",
		"Танк • много здоровья • Q: щит, снижающий урон",
		"Ловкий • быстрые лёгкие выстрелы • Q: рывок сквозь пространство",
		"Тяжёлый • медленные мощные снаряды • Q: круговой залп"
	]
	profile_info.text = "%s\n%s\n%s • %s" % [kinds[G.profile_kind], class_notes[G.profile_kind], outfits[G.profile_outfit], hats[G.profile_hat]]


func _add_facet_panel(parent: Control, target: Control, fill: Color, edge: Color) -> void:
	var shape := Polygon2D.new()
	shape.z_index = 0
	shape.color = fill
	parent.add_child(shape)
	parent.move_child(shape, 2 + lobby_frame_data.size() * 2)
	var outline := Line2D.new()
	outline.z_index = 0
	outline.width = 2.0
	outline.default_color = edge
	outline.closed = true
	parent.add_child(outline)
	parent.move_child(outline, 3 + lobby_frame_data.size() * 2)
	lobby_frame_data.append({"target": target, "shape": shape, "outline": outline})


func _update_lobby_frames() -> void:
	if not is_instance_valid(lobby_root) or not boxes.has("lobby"):
		return
	var lobby_box: Control = boxes["lobby"]
	if not is_instance_valid(lobby_box) or not lobby_box.visible:
		return
	for frame in lobby_frame_data:
		var target: Control = frame.target
		if not is_instance_valid(target):
			continue
		var rect := target.get_global_rect().grow(7.0)
		var pos := rect.position - lobby_root.global_position
		var size := rect.size
		var cut := minf(22.0, minf(size.x, size.y) * 0.12)
		var points := PackedVector2Array([
			Vector2(cut, 0), Vector2(size.x - cut, 0), Vector2(size.x, cut),
			Vector2(size.x, size.y - cut), Vector2(size.x - cut, size.y),
			Vector2(cut, size.y), Vector2(0, size.y - cut), Vector2(0, cut)
		])
		var shape: Polygon2D = frame.shape
		shape.position = pos
		shape.polygon = points
		var outline: Line2D = frame.outline
		outline.position = pos
		outline.points = points


func _make_player_portrait(parent: Node, kind: int, color: int, outfit: int, hat: int) -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var vp := SubViewport.new()
	vp.size = Vector2i(140, 140)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	container.add_child(vp)
	parent.add_child(container)
	var actor := VectorActor.new()
	actor.position = Vector2(70, 73)
	actor.scale = Vector2.ONE * 1.22
	vp.add_child(actor)
	actor.setup(kind, G.col(color), outfit, hat)
	return container


func _make_vector_preview(parent: Node) -> Node2D:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(260, 190)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.stretch = true
	var vp := SubViewport.new()
	vp.size = Vector2i(320, 230)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(vp)
	parent.add_child(container)
	var actor := VectorActor.new()
	actor.position = Vector2(160, 120)
	actor.scale = Vector2.ONE * 1.8
	vp.add_child(actor)
	actor.setup(G.profile_kind, G.col(G.profile_color), G.profile_outfit, G.profile_hat)
	return actor


func _sync_lobby_profile() -> void:
	if Net.online:
		Net.set_local_profile()


func _start_tutorial_from_menu() -> void:
	Sfx.play("click")
	G.tutorial_done = false
	G.save_settings()
	G.start_tutorial_game(false)


func _open_lobby_tutorial() -> void:
	Sfx.play("click")
	G.start_tutorial_game(true)

func _show(key: String) -> void:
	title.visible = (key == "main")
	for k in boxes:
		boxes[k].visible = (k == key)
	if key == "lobby":
		_on_lobby_changed()


func _title(parent: Node, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 30)
	l.modulate = Color(1.2, 1.6, 2.2)
	parent.add_child(l)
	return l


func _btn(text: String, parent: Node, cb: Callable) -> Button:
	var b: Button = FacetButton.new()
	b.text = text
	b.custom_minimum_size = Vector2(380, 58)
	b.add_theme_font_size_override("font_size", 21)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _slider(parent: Node, text: String, val: float, cb: Callable) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(110, 0)
	l.add_theme_font_size_override("font_size", 22)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = val
	s.custom_minimum_size = Vector2(260, 30)
	s.value_changed.connect(cb)
	h.add_child(s)
	parent.add_child(h)


func _on_host() -> void:
	Sfx.play("click")
	var err := Net.host()
	if err != OK:
		status.text = "Не удалось создать комнату (порт %d занят?)" % Net.PORT
		_show("join")
		return
	_show("lobby")


func _on_join() -> void:
	Sfx.play("click")
	status.text = "Подключаюсь…"
	if Net.join(ip_edit.text) != OK:
		status.text = "Неверный адрес"


func _on_lobby_changed() -> void:
	if not Net.online:
		return
	if not boxes["lobby"].visible:
		_show("lobby")
		return
	for child in lobby_list.get_children():
		child.queue_free()
	for id in Net.names:
		var p: Dictionary = Net.profiles.get(id, {})
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 108)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color("#0b1b2d", 0.72)
		card_style.border_color = Color("#287e91", 0.85)
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(0)
		card_style.content_margin_left = 8
		card_style.content_margin_right = 8
		card_style.content_margin_top = 4
		card_style.content_margin_bottom = 4
		card.add_theme_stylebox_override("panel", card_style)
		lobby_list.add_child(card)
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 96)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 12)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(row)
		var portrait := _make_player_portrait(row,
			int(p.get("kind", 0)), int(p.get("color", 0)),
			int(p.get("outfit", 0)), int(p.get("hat", 0)))
		portrait.custom_minimum_size = Vector2(112, 96)
		portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(details)
		var name_label := Label.new()
		name_label.text = str(Net.names[id]) + ("  •  ХОСТ" if int(id) == 1 else "")
		name_label.add_theme_font_size_override("font_size", 20)
		details.add_child(name_label)
		var role_label := Label.new()
		role_label.text = "Участник комнаты"
		role_label.add_theme_font_size_override("font_size", 13)
		role_label.modulate = Color("#9bb4ce")
		details.add_child(role_label)
		if Net.is_host and int(id) != 1:
			var kick_btn := FacetButton.new()
			kick_btn.text = "КИК"
			kick_btn.custom_minimum_size = Vector2(76, 38)
			kick_btn.add_theme_font_size_override("font_size", 14)
			var kicked_id := int(id)
			kick_btn.pressed.connect(func(): Net.kick_peer(kicked_id))
			row.add_child(kick_btn)
	if Net.is_host:
		var ips := G.local_ips()
		var room_addresses: Array[String] = []
		for ip in ips:
			var code := Net.room_code_for_ip(ip)
			if code != "":
				room_addresses.append(code + "   •   " + ip + ":" + str(Net.PORT))
		lobby_info.text = "ЦИФРОВОЙ КОД КОМНАТЫ • ВВЕДИ ЕГО В ПОДКЛЮЧЕНИИ\n%s\nИГРОКИ  %d / %d" % [
			"\n".join(room_addresses) if not room_addresses.is_empty() else "Локальный IP недоступен • порт " + str(Net.PORT),
			Net.names.size(), Net.MAX_PLAYERS]
		start_btn.visible = true
	else:
		lobby_info.text = "ОЖИДАНИЕ ХОСТА • ПОДКЛЮЧЕНИЕ ПО IP:ПОРТ"
		start_btn.visible = false


func _apply_menu_quality() -> void:
	var shard_count: int = [bg_shards.size(), 18, 8, 0][G.graphics_quality]
	var orb_count: int = [bg_orbs.size(), 5, 2, 0][G.graphics_quality]
	var dot_count: int = [bg_dots.size(), 24, 8, 0][G.graphics_quality]
	for i in bg_shards.size():
		bg_shards[i].visible = i < shard_count
	for i in bg_orbs.size():
		bg_orbs[i].visible = i < orb_count
	for i in bg_dots.size():
		bg_dots[i].visible = i < dot_count
