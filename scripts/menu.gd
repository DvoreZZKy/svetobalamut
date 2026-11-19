extends Control
## Главное меню и подэкраны профиля, подключения, настроек и лобби.

var t := 0.0
var title: Label
var boxes := {}
var status: Label
var ip_edit: LineEdit
var lobby_list: Label
var lobby_info: Label
var start_btn: Button
var profile_preview: TextureRect
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
	title.add_theme_font_size_override("font_size", 112)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 40)
	title.size = Vector2(1280, 140)
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
	_title(profile, "ТВОЙ ПЕРСОНАЖ")
	profile_preview = TextureRect.new()
	profile_preview.custom_minimum_size = Vector2(140, 92)
	profile_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	profile_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	profile_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	profile.add_child(profile_preview)
	profile_info = Label.new()
	profile_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile_info.add_theme_font_size_override("font_size", 18)
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
	sh.text = "Тряска экрана"
	sh.button_pressed = G.shake_on
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
	_title(lobby, "Комната")
	lobby_info = Label.new()
	lobby_info.add_theme_font_size_override("font_size", 20)
	lobby.add_child(lobby_info)
	lobby_list = Label.new()
	lobby_list.add_theme_font_size_override("font_size", 24)
	lobby.add_child(lobby_list)
	start_btn = _btn("СТАРТ", lobby, func(): Net.start_match())
	_btn("Выйти из комнаты", lobby, func(): Net.leave(); _show("main"))

	Net.lobby_changed.connect(_on_lobby_changed)
	Net.join_failed.connect(func(): status.text = "Не удалось подключиться"; _show("join"))
	Net.disconnected.connect(func(): _show("main"))
	Net.match_started.connect(func(): get_tree().change_scene_to_file("res://scenes/arena.tscn"))
	_show("main")
	Sfx.play_music()


func _process(dt: float) -> void:
	t += dt
	title.modulate = G.hdr(Color.from_hsv(fmod(t * 0.08 + 0.5, 1.0), 0.6, 1.0), 1.45 + 0.22 * sin(t * 2.2))


func _build_particles() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var p := CPUParticles2D.new()
	p.position = Vector2(640, 760)
	p.texture = tex
	p.amount = 48
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(660, 10)
	p.direction = Vector2.UP
	p.spread = 12.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 220.0
	p.scale_amount_min = 0.1
	p.scale_amount_max = 0.45
	p.color = Color(0.35, 0.85, 1.15, 0.62)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1.0, 0.3, 1.0, 0))
	p.color_ramp = ramp
	add_child(p)


func _box(key: String) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.position = Vector2(440, 145)
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
	profile_preview.texture = load("res://assets/sprites/player_%d.png" % G.profile_kind)
	profile_preview.modulate = G.col(G.profile_color)
	profile_color_btn.text = "Цвет: " + colors[G.profile_color]
	profile_kind_btn.text = "Персонаж: " + kinds[G.profile_kind]
	profile_outfit_btn.text = "Костюм: " + outfits[G.profile_outfit]
	profile_hat_btn.text = "Шапка: " + hats[G.profile_hat]
	profile_info.text = "%s • %s • %s" % [kinds[G.profile_kind], outfits[G.profile_outfit], hats[G.profile_hat]]


func _show(key: String) -> void:
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
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(380, 58)
	b.add_theme_font_size_override("font_size", 26)
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.05, 0.12) if st == "normal" else Color(0.14, 0.06, 0.26)
		sb.set_border_width_all(2)
		sb.border_color = Color(0.3, 1.4, 2.0) if st == "normal" else Color(2.0, 0.5, 2.4)
		sb.set_corner_radius_all(8)
		b.add_theme_stylebox_override(st, sb)
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
	var s := ""
	for id in Net.names:
		s += "%s%s\n" % [Net.names[id], "  (хост)" if id == 1 else ""]
	lobby_list.text = s
	if Net.is_host:
		var ips := G.local_ips()
		lobby_info.text = "Адрес для друзей: %s : %d\nИгроков: %d / %d (до 6 добьём ботами)" % [
			", ".join(ips) if not ips.is_empty() else "твой IP", Net.PORT, Net.names.size(), Net.MAX_PLAYERS]
		start_btn.visible = true
	else:
		lobby_info.text = "Ждём, пока хост нажмёт СТАРТ…"
		start_btn.visible = false
