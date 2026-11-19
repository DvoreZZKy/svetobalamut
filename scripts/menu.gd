extends Control

const VectorActor = preload("res://scripts/vector_actor.gd")
const FacetButton = preload("res://scripts/facet_button.gd")
## Главное меню и подэкраны профиля, подключения, настроек и лобби.

var t := 0.0
var bg_shards: Array[Polygon2D] = []
var bg_orbs: Array[Node2D] = []
var title: Label
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


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(G.make_env())
	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.012, 0.035)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_build_particles()
	title = Label.new()
	title.text = "СВЕТОБАЛАМУТ"
	title.add_theme_font_size_override("font_size", 96)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 20)
	title.size = Vector2(1280, 120)
	add_child(title)

	var main := _box("main")
	_btn("Играть одному (с ботами)", main, func(): Sfx.play("click"); G.start_single())
	_btn("Создать комнату", main, _on_host)
	_btn("Подключиться", main, func(): Sfx.play("click"); _show("join"))
	_btn("Персонаж", main, func(): Sfx.play("click"); _refresh_profile(); _show("profile"))
	_btn("Настройки", main, func(): Sfx.play("click"); _show("settings"))
	_btn("Выход", main, func(): get_tree().quit())

	var join := _box("join")
	_title(join, "IP хоста")
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
	var name_edit := LineEdit.new()
	name_edit.text = G.player_name
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(380, 46)
	name_edit.add_theme_font_size_override("font_size", 24)
	name_edit.text_changed.connect(func(s: String): G.player_name = s if s != "" else "Светляк")
	st.add_child(name_edit)
	_slider(st, "Музыка", G.vol_music, func(v: float): G.vol_music = v; Sfx.refresh_volume())
	_slider(st, "Звуки", G.vol_sfx, func(v: float): G.vol_sfx = v; Sfx.play("shot"))
	var sh := CheckBox.new()
	sh.text = "Эффекты камеры"
	sh.button_pressed = G.shake_on
	sh.tooltip_text = "Лёгкая тряска при ударах, столкновениях и взрывах."
	sh.add_theme_font_size_override("font_size", 22)
	sh.toggled.connect(func(b: bool): G.shake_on = b)
	st.add_child(sh)
	var fs := CheckBox.new()
	fs.text = "Полный экран"
	fs.button_pressed = G.fullscreen
	fs.add_theme_font_size_override("font_size", 22)
	fs.toggled.connect(func(b: bool): G.fullscreen = b; G.apply_display())
	st.add_child(fs)
	_btn("Назад", st, func(): G.save_settings(); _show("main"))

	var lobby := _box("lobby")
	_title(lobby, "КОМНАТА")
	_add_facet_panel(lobby, Vector2(0, 82), Vector2(520, 475), Color("#10283a"), Color("#287e91"))
	_add_facet_panel(lobby, Vector2(545, 82), Vector2(635, 475), Color("#1b1b3b"), Color("#51458c"))
	lobby_info = Label.new()
	lobby_info.add_theme_font_size_override("font_size", 17)
	lobby_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var lobby_columns := HBoxContainer.new()
	lobby_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lobby_columns.add_theme_constant_override("separation", 22)
	lobby.add_child(lobby_columns)
	var players_panel := VBoxContainer.new()
	players_panel.custom_minimum_size = Vector2(500, 390)
	players_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lobby_columns.add_child(players_panel)
	_title(players_panel, "УЧАСТНИКИ")
	var roster_scroll := ScrollContainer.new()
	roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	players_panel.add_child(roster_scroll)
	lobby_list = VBoxContainer.new()
	lobby_list.add_theme_constant_override("separation", 8)
	lobby_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_scroll.add_child(lobby_list)
	var editor_panel := VBoxContainer.new()
	editor_panel.custom_minimum_size = Vector2(560, 390)
	editor_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_panel.add_theme_constant_override("separation", 4)
	lobby_columns.add_child(editor_panel)
	_title(editor_panel, "ВАШ ПЕРСОНАЖ")
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
			child.custom_minimum_size = Vector2(570, 38)
			child.add_theme_font_size_override("font_size", 17)
	_refresh_profile()
	var lobby_actions := HBoxContainer.new()
	lobby_actions.add_theme_constant_override("separation", 12)
	lobby.add_child(lobby_actions)
	_btn("ПРОЙТИ ТУТОРИАЛ", lobby_actions, _open_lobby_tutorial)
	start_btn = _btn("СТАРТ", lobby_actions, func(): Net.start_match())
	_btn("ВЫЙТИ", lobby_actions, func(): G.save_settings(); Net.leave(); _show("main"))

	Net.lobby_changed.connect(_on_lobby_changed)
	Net.join_failed.connect(func(): status.text = "Не удалось подключиться"; _show("join"))
	Net.disconnected.connect(func(): _show("main"))
	Net.match_started.connect(func(): get_tree().change_scene_to_file("res://scenes/arena.tscn"))
	_show("lobby" if Net.online else "main")
	Sfx.play_music()


func _process(dt: float) -> void:
	t += dt
	for i in bg_shards.size():
		var shard := bg_shards[i]
		shard.rotation += dt * (0.16 if i % 2 == 0 else -0.12)
		shard.position.y += sin(t * 0.75 + float(i)) * dt * 5.0
		if shard.position.y > 740.0:
			shard.position.y = -30.0
		shard.position.x += sin(t * 0.42 + float(i) * 0.7) * dt * 7.0
	for i in bg_orbs.size():
		var orb := bg_orbs[i]
		orb.rotation += dt * (0.035 if i % 2 == 0 else -0.028)
		var wave := 1.0 + 0.10 * sin(t * 0.8 + float(i) * 1.7)
		orb.scale = Vector2.ONE * wave
		orb.position.y += sin(t * 0.25 + float(i)) * dt * 3.0
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

func _box(key: String) -> VBoxContainer:
	var b := VBoxContainer.new()
	if key == "lobby":
		b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.offset_left = 36
		b.offset_top = 24
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


func _add_facet_panel(parent: Node, pos: Vector2, panel_size: Vector2, fill: Color, edge: Color) -> void:
	var shape := Polygon2D.new()
	shape.position = pos
	shape.z_index = 0
	shape.polygon = PackedVector2Array([
		Vector2(18, 0), Vector2(panel_size.x - 18, 0), Vector2(panel_size.x, 18),
		Vector2(panel_size.x, panel_size.y - 18), Vector2(panel_size.x - 18, panel_size.y),
		Vector2(18, panel_size.y), Vector2(0, panel_size.y - 18), Vector2(0, 18)
	])
	shape.color = fill
	parent.add_child(shape)
	var outline := Line2D.new()
	outline.position = pos
	outline.z_index = 0
	outline.width = 2.0
	outline.default_color = edge
	outline.closed = true
	outline.points = shape.polygon
	parent.add_child(outline)


func _make_player_portrait(parent: Node, kind: int, color: int, outfit: int, hat: int) -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var vp := SubViewport.new()
	vp.size = Vector2i(180, 150)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(vp)
	parent.add_child(container)
	var actor := VectorActor.new()
	actor.position = Vector2(90, 76)
	actor.scale = Vector2.ONE * 1.45
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


func _open_lobby_tutorial() -> void:
	Sfx.play("click")
	G.start_tutorial_game(true)

func _show(key: String) -> void:
	title.visible = (key == "main")
	for k in boxes:
		boxes[k].visible = (k == key)
	if key == "lobby":
		_on_lobby_changed()


func _title(parent: Node, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 30)
	l.modulate = Color(1.2, 1.6, 2.2)
	parent.add_child(l)


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
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 82)
		row.add_theme_constant_override("separation", 12)
		var portrait := _make_player_portrait(row,
			int(p.get("kind", 0)), int(p.get("color", 0)),
			int(p.get("outfit", 0)), int(p.get("hat", 0)))
		portrait.custom_minimum_size = Vector2(86, 76)
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
		lobby_list.add_child(row)
	if Net.is_host:
		var ips := G.local_ips()
		lobby_info.text = "Адрес для друзей: %s : %d\nИгроков: %d / %d (до 6 добьём ботами)" % [
			", ".join(ips) if not ips.is_empty() else "твой IP", Net.PORT, Net.names.size(), Net.MAX_PLAYERS]
		start_btn.visible = true
	else:
		lobby_info.text = "Ждём, пока хост нажмёт СТАРТ…"
		start_btn.visible = false
