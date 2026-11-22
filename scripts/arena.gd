extends Node2D
## Арена: ввод, цикл симуляции (хост/соло) или приём снапшотов (клиент), рендер, эффекты, HUD.
## Рисуем всегда из словаря `view` (snapshot) — одна и та же картинка на хосте и у клиентов.

const ARENA := Vector2(1600, 900)
const CHAOS_RU := {
	"invert": "ИНВЕРСИЯ СВЕТА И ТЬМЫ", "reverse": "РЕВЕРС УПРАВЛЕНИЯ", "blind": "СЛЕПОТА",
	"bounce": "ОТСКОК ВЫСТРЕЛОВ", "zerog": "НУЛЕВАЯ ГРАВИТАЦИЯ", "rain": "ДОЖДЬ ПОЖИРАТЕЛЕЙ",
	"steal": "КРАЖА СВЕТА И ЦВЕТА", "doubles": "ДВОЙНИКИ!", "magnet": "МАГНИТ", "bomb": "НЕОНОВЫЙ ВЗРЫВ",
}

var sim: Sim = null
var is_client := false
var local_id := 1
var view: Dictionary = {}
var net_ev: Array = []
var snap_timer := 0.0
var snap_age := 0.0
var last_seq := 0
var shake := 0.0
var t := 0.0
var last_bullet_count := -1
var ability_latch := 0.0
var capsule_charge_ring: Line2D
var last_score_text := ""
var timer_glitch_until := 0
var glitch_step := -1
var glitch_text := "0:00"

var pviews := {}
var eviews := {}
var cis := {}

var cam: Camera2D
var ambient_layer: Node2D
var ambient_motes: Array[Dictionary] = []
var trail_layer: Node2D
var ent_layer: Node2D
var bullet_layer: Node2D
var fx_layer: Node2D
var halo_tex: GradientTexture2D
var add_mat: CanvasItemMaterial
var trail_curve: Curve
var trail_grad: Gradient
var fade_grad: Gradient
var trail_shader: Shader
var fx_mat: ShaderMaterial
const VectorActor = preload("res://scripts/vector_actor.gd")
const FacetButton = preload("res://scripts/facet_button.gd")
const ArenaTutorial = preload("res://scripts/arena_tutorial.gd")
var invert_cur := 0.0
var blind_cur := 0.0
var edge_feedback: EdgeFeedback


class NeonProgressBar extends Control:
	var tint := Color("#62eaff")
	var fill_ratio := 1.0

	func set_fill_ratio(ratio: float) -> void:
		fill_ratio = clampf(ratio, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var cut := minf(5.0, h * 0.42)
		var frame := PackedVector2Array([
			Vector2(cut, 0), Vector2(w - cut, 0), Vector2(w, cut),
			Vector2(w, h - cut), Vector2(w - cut, h), Vector2(cut, h),
			Vector2(0, h - cut), Vector2(0, cut)
		])
		draw_colored_polygon(frame, Color("#06101e", 0.96))
		var fill_w := clampf(w * fill_ratio - 2.0, 0.0, w - 2.0)
		var inner_top := 1.5
		var inner_bottom := maxf(inner_top + 1.0, h - 1.5)
		if fill_w > 1.0 and inner_bottom > inner_top:
			var fill_cut := minf(3.0, minf((inner_bottom - inner_top) * 0.45, fill_w * 0.3))
			var fill := PackedVector2Array([
				Vector2(1 + fill_cut, inner_top), Vector2(maxf(1 + fill_cut, fill_w - fill_cut), inner_top),
				Vector2(fill_w, inner_top + fill_cut), Vector2(fill_w, inner_bottom - fill_cut),
				Vector2(maxf(1 + fill_cut, fill_w - fill_cut), inner_bottom), Vector2(1 + fill_cut, inner_bottom),
				Vector2(1, inner_bottom - fill_cut), Vector2(1, inner_top + fill_cut)
			])
			draw_colored_polygon(fill, tint.lightened(0.12))
		draw_polyline(PackedVector2Array([frame[0], frame[1], frame[2], frame[3], frame[4], frame[5], frame[6], frame[7], frame[0]]), tint.darkened(0.22), 1.5, true)


class EdgeFeedback extends Control:
	var damage_strength := 0.0
	var heal_strength := 0.0

	func ping_damage(amount: float) -> void:
		damage_strength = maxf(damage_strength, clampf(amount / 24.0, 0.28, 1.0))
		queue_redraw()

	func ping_heal(amount: float) -> void:
		heal_strength = maxf(heal_strength, clampf(amount / 18.0, 0.25, 0.85))
		queue_redraw()

	func _process(dt: float) -> void:
		damage_strength = move_toward(damage_strength, 0.0, dt * 2.8)
		heal_strength = move_toward(heal_strength, 0.0, dt * 2.2)
		if damage_strength > 0.01 or heal_strength > 0.01:
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		for i in 8:
			var inset := float(i) * 13.0
			var alpha_fade := 1.0 - float(i) / 8.0
			if damage_strength > 0.01:
				var a := damage_strength * alpha_fade * 0.105
				var red := Color(1.0, 0.055, 0.12, a)
				draw_rect(Rect2(0.0, inset, w, 13.0), red)
				draw_rect(Rect2(0.0, h - inset - 13.0, w, 13.0), red)
				draw_rect(Rect2(inset, 0.0, 13.0, h), red)
				draw_rect(Rect2(w - inset - 13.0, 0.0, 13.0, h), red)
			if heal_strength > 0.01:
				var a := heal_strength * alpha_fade * 0.095
				var green := Color(0.08, 1.0, 0.48, a)
				draw_rect(Rect2(0.0, inset, w, 13.0), green)
				draw_rect(Rect2(0.0, h - inset - 13.0, w, 13.0), green)
				draw_rect(Rect2(inset, 0.0, 13.0, h), green)
				draw_rect(Rect2(w - inset - 13.0, 0.0, 13.0, h), green)

var timer_lbl: RichTextLabel
var timer_shape: Polygon2D
var timer_outline: Line2D
var ability_bar: NeonProgressBar
var capsule_ammo_lbl: Label
var capsule_reload_bar: NeonProgressBar
var cursor_layer: CanvasLayer
var cursor_canvas: Control
var aim_screen_pos := Vector2.ZERO
var stopwatch_lbl: Label
var result_cards: Array[Button] = []
var result_detail_open := false
var result_list_scroll: ScrollContainer
var result_list: VBoxContainer
var banner: Label
var score_lbl: RichTextLabel
var help_lbl: Label
var light_bar: NeonProgressBar
var dash_bar: NeonProgressBar
var over_rect: ColorRect
var over_shape: Polygon2D
var over_outline: Line2D
var over_lbl: RichTextLabel
var over_restart_btn: Button
var over_menu_btn: Button
var over_exit_btn: Button
var wait_lbl: Label
var objective_lbl: Label
var pause_layer: CanvasLayer
var pause_shade: ColorRect
var pause_shape: Polygon2D
var pause_outline: Line2D
var pause_title: Label
var pause_resume_btn: Button
var pause_menu_btn: Button
var pause_open := false

func _is_potato() -> bool:
	return G.graphics_quality >= 3


func _ready() -> void:
	is_client = G.mode == "client"
	local_id = multiplayer.get_unique_id() if G.mode != "single" else 1
	var arena_env := G.make_env()
	add_child(arena_env)
	cam = Camera2D.new()
	cam.position = ARENA / 2.0
	cam.zoom = Vector2(0.78, 0.78)
	add_child(cam)
	ambient_layer = Node2D.new()
	ambient_layer.z_index = 0
	ambient_layer.draw.connect(_draw_ambient)
	add_child(ambient_layer)
	_seed_ambient()
	trail_layer = Node2D.new()
	ent_layer = Node2D.new()
	bullet_layer = Node2D.new()
	fx_layer = Node2D.new()
	for n in [trail_layer, ent_layer, bullet_layer, fx_layer]:
		add_child(n)
	capsule_charge_ring = Line2D.new()
	capsule_charge_ring.width = 3.5
	capsule_charge_ring.default_color = Color(0.25, 0.95, 1.0, 0.95)
	capsule_charge_ring.closed = true
	capsule_charge_ring.z_index = 12
	for i in 64:
		capsule_charge_ring.add_point(Vector2.from_angle(TAU * float(i) / 64.0))
	capsule_charge_ring.visible = false
	ent_layer.add_child(capsule_charge_ring)
	bullet_layer.draw.connect(_draw_bullets)
	_build_resources()
	_build_fx_overlay()
	_build_hud()
	_build_pause_menu()
	_build_aim_cursor()
	if is_client:
		Net.disconnected.connect(_to_menu)
	else:
		sim = Sim.new()
		sim.endless = G.tutorial_active          # the lesson can't end by timeout or last-survivor
		sim.chaos_enabled = not G.tutorial_active  # and random chaos doesn't derail it
		sim.reset(G.cfg)
		Net.peer_left.connect(_on_peer_left)
		view = sim.snapshot()
	if G.tutorial_active:
		var tutorial_controller := ArenaTutorial.new()
		add_child(tutorial_controller)
		if Net.online:
			# A lobby member doing the tutorial must still be pulled into the match the host starts.
			Net.match_started.connect(_on_lobby_match_started)
	Sfx.play_music()


func _exit_tree() -> void:
	if Net.match_started.is_connected(_on_lobby_match_started):
		Net.match_started.disconnect(_on_lobby_match_started)
	if Net.peer_left.is_connected(_on_peer_left):
		Net.peer_left.disconnect(_on_peer_left)
	if Net.disconnected.is_connected(_to_menu):
		Net.disconnected.disconnect(_to_menu)


func _on_lobby_match_started() -> void:
	G.tutorial_active = false
	G.tutorial_return_to_lobby = false
	G.mode = "host" if Net.is_host else "client"
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/arena.tscn")


func _on_peer_left(id: int) -> void:
	if sim and sim.players.has(id):
		sim.players[id].human = false
	Net.inputs.erase(id)


func _to_menu() -> void:
	pause_open = false
	if is_instance_valid(pause_layer):
		pause_layer.visible = false
	if Net.online:
		Net.leave()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


# --------------------------------------------------------------- ресурсы --
func _build_resources() -> void:
	# Reuse autoload-owned resources across every arena instance and match restart.
	halo_tex = G.get_halo_texture()
	add_mat = G.get_additive_material()
	trail_curve = Curve.new()
	trail_curve.add_point(Vector2(0.0, 0.0))
	trail_curve.add_point(Vector2(1.0, 1.0))
	trail_grad = Gradient.new()
	trail_grad.set_color(0, Color(1, 1, 1, 0.0))
	trail_grad.set_color(1, Color(1, 1, 1, 0.95))
	fade_grad = Gradient.new()
	fade_grad.set_color(0, Color(1, 1, 1, 1))
	fade_grad.set_color(1, Color(1, 1, 1, 0))
	trail_shader = load("res://shaders/trail.gdshader")
	


func _build_fx_overlay() -> void:
	var edge_layer := CanvasLayer.new()
	edge_layer.layer = 8
	add_child(edge_layer)
	edge_feedback = EdgeFeedback.new()
	edge_feedback.set_anchors_preset(Control.PRESET_FULL_RECT)
	edge_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge_layer.add_child(edge_feedback)
	if _is_potato():
		return
	var cl := CanvasLayer.new()
	cl.layer = 5
	add_child(cl)
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_mat = ShaderMaterial.new()
	fx_mat.shader = load("res://shaders/screen_fx.gdshader")
	r.material = fx_mat
	cl.add_child(r)


func _bold_hud_font() -> Font:
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 0.72
	return font


func _label(text: String, size: int, pos: Vector2, sz: Vector2, parent: Node, center := false) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", _bold_hud_font())
	l.text = text
	l.position = pos
	l.size = sz
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _bar(pos: Vector2, sz: Vector2, col: Color, parent: Node) -> NeonProgressBar:
	var b := NeonProgressBar.new()
	b.tint = col
	b.position = pos
	b.size = sz
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#06101e", 0.96)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(3)
	bg.border_color = col.darkened(0.28)
	bg.shadow_color = Color(col.r, col.g, col.b, 0.22)
	bg.shadow_size = 2
	var fl := StyleBoxFlat.new()
	fl.bg_color = col.lightened(0.12)
	fl.shadow_color = Color(col.r, col.g, col.b, 0.45)
	fl.shadow_size = 3
	fl.set_corner_radius_all(3)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(b)
	return b


func _build_hud() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 10
	add_child(cl)
	timer_lbl = RichTextLabel.new()
	timer_lbl.bbcode_enabled = true
	timer_lbl.fit_content = false
	timer_lbl.scroll_active = false
	timer_lbl.clip_contents = true
	timer_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_lbl.anchor_left = 1.0
	timer_lbl.anchor_right = 1.0
	timer_lbl.offset_left = -370
	timer_lbl.offset_right = -24
	timer_lbl.offset_top = 18
	timer_lbl.offset_bottom = 116
	timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_lbl.add_theme_font_size_override("normal_font_size", 11)
	timer_lbl.add_theme_font_override("normal_font", _bold_hud_font())
	timer_lbl.add_theme_font_override("bold_font", _bold_hud_font())
	timer_lbl.add_theme_constant_override("table_h_separation", 0)
	timer_lbl.add_theme_constant_override("table_v_separation", 1)
	timer_lbl.modulate = Color("#a9efff")
	cl.add_child(timer_lbl)
	stopwatch_lbl = _label("00:00", 20, Vector2.ZERO, Vector2(160, 34), cl, true)
	stopwatch_lbl.anchor_left = 0.5
	stopwatch_lbl.anchor_right = 0.5
	stopwatch_lbl.offset_left = -80
	stopwatch_lbl.offset_right = 80
	stopwatch_lbl.offset_top = 14
	stopwatch_lbl.offset_bottom = 48
	stopwatch_lbl.add_theme_color_override("font_color", Color("#b7f7ff"))
	banner = _label("", 70, Vector2.ZERO, Vector2(1280, 100), cl, true)
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.offset_left = -640
	banner.offset_right = 640
	banner.anchor_top = 0.28
	banner.anchor_bottom = 0.28
	banner.pivot_offset = Vector2(640, 50)
	banner.modulate.a = 0.0
	score_lbl = RichTextLabel.new()
	score_lbl.bbcode_enabled = true
	score_lbl.fit_content = false
	score_lbl.scroll_active = false
	score_lbl.position = Vector2(52, 34)
	score_lbl.size = Vector2(280, 150)
	score_lbl.clip_contents = true
	score_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_lbl.add_theme_font_size_override("normal_font_size", 10)
	score_lbl.add_theme_font_override("normal_font", _bold_hud_font())
	score_lbl.add_theme_font_override("bold_font", _bold_hud_font())
	score_lbl.add_theme_constant_override("table_h_separation", 8)
	score_lbl.add_theme_constant_override("table_v_separation", 1)
	score_lbl.add_theme_color_override("default_color", Color("#eaf6ff"))
	var board_style := StyleBoxFlat.new()
	board_style.bg_color = Color("#071321", 0.88)
	board_style.border_color = Color("#42d9ed", 0.72)
	board_style.set_border_width_all(1)
	board_style.set_corner_radius_all(0)
	board_style.content_margin_left = 9
	board_style.content_margin_right = 9
	board_style.content_margin_top = 8
	board_style.content_margin_bottom = 8
	score_lbl.add_theme_stylebox_override("normal", board_style)
	cl.add_child(score_lbl)
	help_lbl = _label("", 11, Vector2.ZERO, Vector2(340, 76), cl)
	help_lbl.anchor_left = 1.0
	help_lbl.anchor_right = 1.0
	help_lbl.offset_left = -356
	help_lbl.offset_right = -16
	help_lbl.offset_top = 74
	help_lbl.offset_bottom = 150
	help_lbl.anchor_top = 0.0
	help_lbl.anchor_bottom = 0.0
	help_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_lbl.add_theme_font_size_override("font_size", 10)
	help_lbl.add_theme_font_override("font", _bold_hud_font())
	help_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_lbl.modulate = Color(0.7, 0.8, 1.0, 0.0)
	timer_shape = Polygon2D.new()
	timer_shape.position = Vector2(1070, 54)
	timer_shape.polygon = PackedVector2Array([
		Vector2(-190, -78), Vector2(190, -78), Vector2(202, -66),
		Vector2(202, 66), Vector2(190, 78), Vector2(-190, 78),
		Vector2(-202, 66), Vector2(-202, -66)
	])
	timer_shape.color = Color("#0c1d31", 0.0)
	timer_shape.z_index = -1
	cl.add_child(timer_shape)
	timer_outline = Line2D.new()
	timer_outline.position = timer_shape.position
	timer_outline.points = timer_shape.polygon
	timer_outline.closed = true
	timer_outline.width = 2.0
	timer_outline.z_index = -1
	timer_outline.default_color = Color("#39d9f0", 0.0)
	cl.add_child(timer_outline)
	timer_shape.position = Vector2(1100, 48)
	timer_outline.position = timer_shape.position
	timer_shape.visible = false
	timer_outline.visible = false
	light_bar = _bar(Vector2.ZERO, Vector2(292, 14), Color("#ffd76a"), cl)
	light_bar.anchor_left = 0.5
	light_bar.anchor_right = 0.5
	light_bar.anchor_top = 1.0
	light_bar.anchor_bottom = 1.0
	light_bar.offset_left = -132
	light_bar.offset_right = 160
	light_bar.offset_top = -65
	light_bar.offset_bottom = -51
	dash_bar = _bar(Vector2.ZERO, Vector2(292, 9), Color("#62eaff"), cl)
	dash_bar.anchor_left = 0.5
	dash_bar.anchor_right = 0.5
	dash_bar.anchor_top = 1.0
	dash_bar.anchor_bottom = 1.0
	dash_bar.offset_left = -132
	dash_bar.offset_right = 160
	dash_bar.offset_top = -46
	dash_bar.offset_bottom = -37
	ability_bar = _bar(Vector2.ZERO, Vector2(292, 9), Color("#b68aff"), cl)
	ability_bar.anchor_left = 0.5
	ability_bar.anchor_right = 0.5
	ability_bar.anchor_top = 1.0
	ability_bar.anchor_bottom = 1.0
	ability_bar.offset_left = -132
	ability_bar.offset_right = 160
	ability_bar.offset_top = -31
	ability_bar.offset_bottom = -22
	var light_caption := _label("СВЕТ", 9, Vector2.ZERO, Vector2(54, 14), cl)
	light_caption.anchor_left = 0.5
	light_caption.anchor_right = 0.5
	light_caption.anchor_top = 1.0
	light_caption.anchor_bottom = 1.0
	light_caption.offset_left = -190
	light_caption.offset_right = -138
	light_caption.offset_top = -65
	light_caption.offset_bottom = -51
	light_caption.add_theme_color_override("font_color", Color("#ffe28a"))
	var dash_caption := _label("РЫВОК", 9, Vector2.ZERO, Vector2(54, 14), cl)
	dash_caption.anchor_left = 0.5
	dash_caption.anchor_right = 0.5
	dash_caption.anchor_top = 1.0
	dash_caption.anchor_bottom = 1.0
	dash_caption.offset_left = -190
	dash_caption.offset_right = -138
	dash_caption.offset_top = -46
	dash_caption.offset_bottom = -32
	dash_caption.add_theme_color_override("font_color", Color("#76eaff"))
	var ability_caption := _label("Q", 9, Vector2.ZERO, Vector2(54, 14), cl)
	ability_caption.anchor_left = 0.5
	ability_caption.anchor_right = 0.5
	ability_caption.anchor_top = 1.0
	ability_caption.anchor_bottom = 1.0
	ability_caption.offset_left = -190
	ability_caption.offset_right = -138
	ability_caption.offset_top = -31
	ability_caption.offset_bottom = -17
	ability_caption.add_theme_color_override("font_color", Color("#c3a0ff"))
	capsule_ammo_lbl = _label("ВОЛНЫ  ◆ ◆ ◆ ◆", 12, Vector2(18, 0), Vector2(190, 20), cl)
	capsule_ammo_lbl.anchor_top = 1.0
	capsule_ammo_lbl.anchor_bottom = 1.0
	capsule_ammo_lbl.offset_top = -66
	capsule_ammo_lbl.offset_bottom = -42
	capsule_ammo_lbl.add_theme_color_override("font_color", Color("#75efff"))
	capsule_reload_bar = _bar(Vector2(18, 0), Vector2(150, 5), Color("#62eaff"), cl)
	capsule_reload_bar.anchor_top = 1.0
	capsule_reload_bar.anchor_bottom = 1.0
	capsule_reload_bar.offset_top = -37
	capsule_reload_bar.offset_bottom = -31
	capsule_ammo_lbl.visible = false
	capsule_reload_bar.visible = false
	light_bar.offset_top = -64
	light_bar.offset_bottom = -46
	wait_lbl = _label("Ждём хоста…", 30, Vector2.ZERO, Vector2(1280, 60), cl, true)
	wait_lbl.anchor_left = 0.5
	wait_lbl.anchor_right = 0.5
	wait_lbl.anchor_top = 0.5
	wait_lbl.anchor_bottom = 0.5
	wait_lbl.offset_left = -640
	wait_lbl.offset_right = 640
	wait_lbl.offset_top = -30
	wait_lbl.offset_bottom = 30
	wait_lbl.visible = is_client
	over_rect = ColorRect.new()
	over_rect.color = Color(0.003, 0.004, 0.018, 0.84)
	over_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over_rect.visible = false
	cl.add_child(over_rect)
	over_shape = Polygon2D.new()
	over_shape.color = Color("#101a32", 0.98)
	over_shape.visible = false
	cl.add_child(over_shape)
	over_outline = Line2D.new()
	over_outline.width = 3.0
	over_outline.default_color = Color("#43eaff")
	over_outline.closed = true
	over_outline.visible = false
	cl.add_child(over_outline)
	over_lbl = RichTextLabel.new()
	over_lbl.bbcode_enabled = true
	over_lbl.fit_content = false
	over_lbl.scroll_active = false
	over_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_lbl.add_theme_font_override("normal_font", _bold_hud_font())
	over_lbl.add_theme_font_override("bold_font", _bold_hud_font())
	over_lbl.add_theme_font_size_override("normal_font_size", 20)
	over_lbl.add_theme_color_override("default_color", Color("#f0fbff"))
	cl.add_child(over_lbl)
	over_lbl.visible = false
	result_list_scroll = ScrollContainer.new()
	result_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	result_list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	result_list_scroll.visible = false
	var result_list_panel := PanelContainer.new()
	var result_list_style := StyleBoxFlat.new()
	result_list_style.bg_color = Color("#071625", 0.96)
	result_list_style.border_color = Color("#287e91", 0.9)
	result_list_style.set_border_width_all(1)
	result_list_style.set_corner_radius_all(0)
	result_list_style.content_margin_left = 8
	result_list_style.content_margin_right = 8
	result_list_style.content_margin_top = 8
	result_list_style.content_margin_bottom = 8
	result_list_panel.add_theme_stylebox_override("panel", result_list_style)
	result_list_scroll.add_child(result_list_panel)
	result_list = VBoxContainer.new()
	result_list.add_theme_constant_override("separation", 7)
	result_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_list_panel.add_child(result_list)
	cl.add_child(result_list_scroll)
	over_restart_btn = FacetButton.new()
	over_restart_btn.text = "РЕВАНШ"
	over_restart_btn.custom_minimum_size = Vector2(210, 48)
	_style_result_button(over_restart_btn, Color("#42eaff"))
	over_restart_btn.pressed.connect(_restart_match)
	cl.add_child(over_restart_btn)
	over_menu_btn = FacetButton.new()
	over_menu_btn.text = "В МЕНЮ"
	over_menu_btn.custom_minimum_size = Vector2(210, 48)
	_style_result_button(over_menu_btn, Color("#b58aff"))
	over_menu_btn.pressed.connect(_to_menu)
	cl.add_child(over_menu_btn)
	over_exit_btn = FacetButton.new()
	over_exit_btn.text = "В МЕНЮ"
	over_exit_btn.custom_minimum_size = Vector2(180, 48)
	_style_result_button(over_exit_btn, Color("#b58aff"))
	over_exit_btn.pressed.connect(_to_menu)
	cl.add_child(over_exit_btn)
	over_exit_btn.visible = false
	over_restart_btn.visible = false
	over_menu_btn.visible = false
	for category in ["УРОН", "ХИЛ", "УБИЙСТВА", "ХАОС"]:
		var card := FacetButton.new()
		card.text = category
		card.custom_minimum_size = Vector2(190, 118)
		card.visible = false
		_style_result_button(card, Color("#64eaff"))
		card.pressed.connect(_open_result_category.bind(category))
		cl.add_child(card)
		result_cards.append(card)


# -------------------------------------------------------------- рисование --
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, ARENA), Color(0.012, 0.012, 0.035))
	if _is_potato():
		# Keep the arena's gameplay zones visible, but draw them as cheap outlines:
		# no filled polygons, inner decoration, ticks, or background grid.
		for z in Sim.ZONES:
			var center := Vector2(z.x, z.y)
			draw_arc(center, z.z, 0.0, TAU, 48, Color(0.30, 0.34, 0.46, 0.78), 2.0, true)
		var simple_border := PackedVector2Array([
			Vector2(24, 0), Vector2(ARENA.x - 24, 0), Vector2(ARENA.x, 24),
			Vector2(ARENA.x, ARENA.y - 24), Vector2(ARENA.x - 24, ARENA.y),
			Vector2(24, ARENA.y), Vector2(0, ARENA.y - 24), Vector2(0, 24), Vector2(24, 0)
		])
		draw_polyline(simple_border, Color(0.22, 0.25, 0.34, 0.8), 2.0, true)
		return
	var gc := Color(0.12, 0.28, 0.48, 0.14)
	for x in range(0, 1601, 100):
		draw_line(Vector2(x, 0), Vector2(x, ARENA.y), gc, 1.5)
	for y in range(0, 901, 100):
		draw_line(Vector2(0, y), Vector2(ARENA.x, y), gc, 1.5)
	for z in Sim.ZONES:
		var c := Vector2(z.x, z.y)
		var zone_poly := PackedVector2Array()
		var inner_ring := PackedVector2Array()
		for i in 24:
			var direction := Vector2.from_angle(TAU * float(i) / 24.0)
			zone_poly.append(c + direction * z.z)
			inner_ring.append(c + direction * z.z * 0.72)
		draw_colored_polygon(zone_poly, Color(0.015, 0.01, 0.035, 0.55))
		var zone_outline := zone_poly.duplicate()
		zone_outline.append(zone_poly[0])
		draw_polyline(zone_outline, Color(0.36, 0.22, 0.72, 0.55), 2.2, true)
		inner_ring.append(inner_ring[0])
		draw_polyline(inner_ring, Color(0.24, 0.62, 0.92, 0.16), 1.2, true)
		for tick in 4:
			var axis := Vector2.from_angle(TAU * float(tick) / 4.0)
			draw_line(c + axis * z.z * 0.82, c + axis * z.z * 0.94, Color(0.52, 0.34, 0.92, 0.38), 2.0, true)
	var border := PackedVector2Array([
		Vector2(24,0), Vector2(ARENA.x-24,0), Vector2(ARENA.x,24),
		Vector2(ARENA.x,ARENA.y-24), Vector2(ARENA.x-24,ARENA.y),
		Vector2(24,ARENA.y), Vector2(0,ARENA.y-24), Vector2(0,24)
	])
	border.append(border[0])
	draw_polyline(border, Color(0.48, 0.2, 0.72), 3.0, true)


func _seed_ambient() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var mote_count: int = [22, 12, 5, 0][G.graphics_quality]
	for i in mote_count:
		ambient_motes.append({
			"p": Vector2(rng.randf_range(35.0, ARENA.x - 35.0), rng.randf_range(35.0, ARENA.y - 35.0)),
			"v": Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(7.0, 20.0),
			"r": rng.randf_range(2.0, 4.5),
			"phase": rng.randf_range(0.0, TAU),
			"tone": i % 3
		})


func _update_ambient(dt: float) -> void:
	if _is_potato() or dt <= 0.0:
		return
	var mote_count: int = [ambient_motes.size(), 12, 5, 0][G.graphics_quality]
	for i in mote_count:
		var mote: Dictionary = ambient_motes[i]
		mote.p += mote.v * dt
		if mote.p.x < 20.0 or mote.p.x > ARENA.x - 20.0:
			mote.v.x *= -1.0
		if mote.p.y < 20.0 or mote.p.y > ARENA.y - 20.0:
			mote.v.y *= -1.0
	ambient_layer.queue_redraw()


# Unit geometry is allocated once; each mote only changes its draw transform.
var ambient_diamond := PackedVector2Array([
	Vector2(0, -2), Vector2(1, 0), Vector2(0, 2), Vector2(-1, 0)
])
var ambient_h_line := PackedVector2Array([Vector2(-3, 0), Vector2(3, 0)])
var ambient_v_line := PackedVector2Array([Vector2(0, -3), Vector2(0, 3)])
var ambient_palette := [Color("#39dff5"), Color("#a77bff"), Color("#62f5d0")]


func _draw_ambient() -> void:
	var mote_count: int = [ambient_motes.size(), 12, 5, 0][G.graphics_quality]
	for i in mote_count:
		var mote: Dictionary = ambient_motes[i]
		var r: float = mote.r
		var pulse := 0.45 + 0.35 * sin(t * 1.7 + float(mote.phase))
		var color: Color = ambient_palette[int(mote.tone)]
		ambient_layer.draw_set_transform(mote.p, 0.0, Vector2(r, r))
		ambient_layer.draw_colored_polygon(ambient_diamond, Color(color, pulse * 0.32))
		ambient_layer.draw_polyline(ambient_h_line, Color(color, pulse * 0.22), 1.0, true)
		ambient_layer.draw_polyline(ambient_v_line, Color(color, pulse * 0.22), 1.0, true)
	ambient_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_bullets() -> void:
	for pickup in view.get("pu", []):
		var pickup_pos: Vector2 = pickup[0]
		var pickup_kind: String = str(pickup[1])
		var pickup_color: Color = {"swift": Color("#64eaff"), "overdrive": Color("#ff8b67"), "shield": Color("#a78bfa"), "battery": Color("#7cf7b2")}.get(pickup_kind, Color.WHITE)
		var points := PackedVector2Array()
		for side in 6:
			points.append(pickup_pos + Vector2.from_angle(TAU * float(side) / 6.0) * 17.0)
		bullet_layer.draw_colored_polygon(points, pickup_color * Color(1, 1, 1, 0.85))
		bullet_layer.draw_polyline(points, Color.WHITE, 2.0, true)
		bullet_layer.draw_arc(pickup_pos, 25.0 + 2.0 * sin(t * 5.0), 0.0, TAU, 32, pickup_color, 2.0, true)
	for meteor in view.get("mt", []):
		var center: Vector2 = meteor[0]
		var remaining: float = float(meteor[1])
		var progress := clampf(1.0 - remaining / 1.15, 0.0, 1.0)
		var pulse := 0.72 + 0.28 * sin(t * 22.0)
		var warning_color := Color(1.0, 0.24, 0.12, 0.72 * pulse)
		bullet_layer.draw_arc(center, 138.0, 0.0, TAU, 64, warning_color, 4.0, true)
		bullet_layer.draw_arc(center, 126.0 + 7.0 * pulse, 0.0, TAU, 64, Color(1.0, 0.62, 0.18, 0.4), 2.0, true)
		var meteor_pos := center + Vector2(-150.0, -430.0).lerp(Vector2.ZERO, progress)
		if _is_potato():
			bullet_layer.draw_line(meteor_pos - Vector2(0, 90), meteor_pos, Color(1.0, 0.38, 0.12), 7.0, false)
			bullet_layer.draw_circle(meteor_pos, 15.0, Color(1.0, 0.72, 0.28))
		else:
			bullet_layer.draw_line(meteor_pos - Vector2(0, 105), meteor_pos, Color(1.0, 0.24, 0.08, 0.5), 30.0, true)
			bullet_layer.draw_circle(meteor_pos, 20.0, Color(3.2, 0.72, 0.18))
			bullet_layer.draw_circle(meteor_pos, 9.0, Color(4.0, 2.4, 0.8))
	for b in view.get("bl", []):
		var vel: Vector2 = b[2]
		var pos: Vector2 = b[1] + vel * snap_age
		var col: Color = G.col(cis.get(b[3], 0))
		if b[4] > 0:
			col = Color(1, 1, 1)
		if _is_potato():
			bullet_layer.draw_line(pos - vel * 0.035, pos, col, 3.0, false)
			bullet_layer.draw_circle(pos, 4.0, col)
			continue
		var tail := pos - vel * 0.075
		var glow := G.hdr(col, 1.6)
		glow.a = 0.35
		var radius: float = float(b[6]) if b.size() > 6 else 6.0
		var width := 8.0 + radius * 0.8
		bullet_layer.draw_line(tail, pos, glow, width * 2.0, true)
		bullet_layer.draw_line(tail, pos, G.hdr(col, 2.0), width * 0.4, true)
		bullet_layer.draw_circle(pos, 6.0, Color(4, 4, 4))


# ----------------------------------------------------------------- цикл ---

func _build_aim_cursor() -> void:
	cursor_layer = CanvasLayer.new()
	cursor_layer.layer = 100
	cursor_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(cursor_layer)
	cursor_canvas = Control.new()
	cursor_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor_canvas.size = Vector2(48, 48)
	cursor_canvas.z_index = 100
	cursor_canvas.draw.connect(_draw_aim_cursor)
	cursor_layer.add_child(cursor_canvas)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	aim_screen_pos = get_viewport().get_visible_rect().size * 0.5


func _draw_aim_cursor() -> void:
	if not is_instance_valid(cursor_canvas):
		return
	var center := Vector2(24, 24)
	var color := Color("#8df6ff")
	cursor_canvas.draw_arc(center, 13.0, 0.0, TAU, 32, Color.BLACK, 5.0, true)
	cursor_canvas.draw_arc(center, 13.0, 0.0, TAU, 32, Color(color, 1.0), 2.8, true)
	cursor_canvas.draw_line(Vector2(24, 0), Vector2(24, 9), Color.BLACK, 5.0, true)
	cursor_canvas.draw_line(Vector2(24, 39), Vector2(24, 48), Color.BLACK, 5.0, true)
	cursor_canvas.draw_line(Vector2(0, 24), Vector2(9, 24), Color.BLACK, 5.0, true)
	cursor_canvas.draw_line(Vector2(39, 24), Vector2(48, 24), Color.BLACK, 5.0, true)
	cursor_canvas.draw_line(Vector2(24, 0), Vector2(24, 9), color, 2.2, true)
	cursor_canvas.draw_line(Vector2(24, 39), Vector2(24, 48), color, 2.2, true)
	cursor_canvas.draw_line(Vector2(0, 24), Vector2(9, 24), color, 2.2, true)
	cursor_canvas.draw_line(Vector2(39, 24), Vector2(48, 24), color, 2.2, true)
	cursor_canvas.draw_circle(center, 3.0, Color.WHITE)


func _read_input() -> Dictionary:
	return {
		"mv": Input.get_vector("left", "right", "up", "down"),
		"aim": get_canvas_transform().affine_inverse() * aim_screen_pos,
		"fire": Input.is_action_pressed("fire"),
		"dash": Input.is_action_pressed("dash"),
		"poss": Input.is_action_pressed("possess") or (bool(view.get("pl", []).filter(func(p): return int(p.i) == local_id and p.s).size() > 0) and Input.is_action_pressed("fire")),
		"ability": Input.is_action_just_pressed("ability"),
	}


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not pause_open:
		if G.tutorial_active:
			aim_screen_pos = event.position.clamp(Vector2.ZERO, get_viewport().get_visible_rect().size)
		else:
			var sensitivity := G.mouse_sensitivity if G.match_mouse_sensitivity else 1.0
			aim_screen_pos += event.relative * sensitivity
			aim_screen_pos = aim_screen_pos.clamp(Vector2.ZERO, get_viewport().get_visible_rect().size)


func _process(dt: float) -> void:
	if not G.tutorial_active and Input.is_action_just_pressed("ui_cancel") and view.get("ph", "play") != "over":
		_toggle_pause()
	if pause_open and (not Net.online or G.tutorial_active):
		# The scene and UI keep processing, but the offline match does not advance.
		return
	t += dt
	_update_ambient(dt)
	var inp := _read_input()
	# Inputs travel over an unreliable channel: stretch the one-frame ability press over ~0.18 s
	# so a dropped or overwritten packet can't eat it. The ability cooldown makes repeats harmless.
	if Input.is_action_just_pressed("ability"):
		ability_latch = 0.18
	ability_latch = maxf(0.0, ability_latch - dt)
	inp["ability"] = ability_latch > 0.0
	if pause_open:
		inp = {"mv": Vector2.ZERO, "aim": get_canvas_transform().affine_inverse() * aim_screen_pos,
			"fire": false, "dash": false, "poss": false, "ability": false}
	if not is_client:
		sim.inputs[local_id] = inp
		if not G.tutorial_active:
			for pid in Net.inputs:
				sim.inputs[pid] = Net.inputs[pid]
		if not (G.tutorial_active and Engine.time_scale <= 0.001):
			sim.step(minf(dt, 0.05))
		sim.shake_req = 0.0
		view = sim.snapshot()
		var ev: Array = sim.events
		sim.events = []
		_handle_events(ev)
		net_ev.append_array(ev)
		snap_timer -= dt
		if Net.online and not G.tutorial_active:
			if snap_timer <= 0.0:
				snap_timer = 0.05
				Net.broadcast_snap(view)
				Net.broadcast_events(net_ev)  # reliable channel, batched at snapshot rate
				net_ev = []
		else:
			net_ev.clear()  # solo/tutorial: nobody consumes the batch, don't let it grow forever
		snap_age = 0.0
		if Input.is_action_just_pressed("restart") and view.ph == "over":
			sim.reset(G.cfg)
			_clear_views()
	else:
		Net.send_input(inp)
		if Net.snap_seq != last_seq:
			last_seq = Net.snap_seq
			view = Net.latest_snap
			snap_age = 0.0
		else:
			snap_age = minf(snap_age + dt, 0.12)
		_handle_events(Net.take_events())
		wait_lbl.visible = view.is_empty()
	if not view.is_empty():
		_update_views(dt)
		_update_fx(dt)
		_update_hud(dt)
	# Markers (meteors and upgrades) must redraw even when no bullets are flying.
	# Otherwise the last bullet disappearing can freeze the layer and hide later warnings.
	bullet_layer.queue_redraw()
	last_bullet_count = view.get("bl", []).size()
	if is_instance_valid(cursor_canvas):
		cursor_canvas.visible = not G.tutorial_active and not pause_open and view.get("ph", "play") != "over"
		if cursor_canvas.visible:
			cursor_canvas.position = aim_screen_pos - cursor_canvas.size * 0.5
			cursor_canvas.queue_redraw()
	shake = maxf(0.0, shake - (shake * 8.0 + 25.0) * dt)
	var s: float = shake if G.shake_on else 0.0
	if s > 0.05:
		cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * s
		cam.rotation = randf_range(-1, 1) * s * 0.0006
	else:
		cam.offset = Vector2.ZERO
		cam.rotation = 0.0




func _build_pause_menu() -> void:
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 40
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_layer)
	pause_shade = ColorRect.new()
	pause_shade.color = Color(0.002, 0.004, 0.018, 0.78)
	pause_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_layer.add_child(pause_shade)
	pause_shape = Polygon2D.new()
	pause_shape.color = Color("#101b32")
	pause_layer.add_child(pause_shape)
	pause_outline = Line2D.new()
	pause_outline.width = 3.0
	pause_outline.default_color = Color("#42eaff")
	pause_outline.closed = true
	pause_layer.add_child(pause_outline)
	pause_title = _label("ПАУЗА", 38, Vector2.ZERO, Vector2(620, 64), pause_layer, true)
	pause_title.add_theme_color_override("font_color", Color("#eafaff"))
	pause_resume_btn = FacetButton.new()
	pause_resume_btn.text = "ПРОДОЛЖИТЬ"
	pause_resume_btn.custom_minimum_size = Vector2(300, 54)
	pause_resume_btn.pressed.connect(_toggle_pause)
	pause_layer.add_child(pause_resume_btn)
	pause_menu_btn = FacetButton.new()
	pause_menu_btn.text = "ВЫЙТИ В МЕНЮ"
	pause_menu_btn.custom_minimum_size = Vector2(300, 54)
	pause_menu_btn.pressed.connect(_to_menu)
	pause_layer.add_child(pause_menu_btn)
	pause_layer.visible = false
	_layout_pause_menu()


func _layout_pause_menu() -> void:
	if not is_instance_valid(pause_layer):
		return
	var vp := get_viewport().get_visible_rect().size
	var w := minf(650.0, vp.x - 40.0)
	var h := 310.0
	var pos := (vp - Vector2(w, h)) * 0.5
	var cut := 22.0
	var pts := PackedVector2Array([
		pos + Vector2(cut, 0), pos + Vector2(w - cut, 0),
		pos + Vector2(w, cut), pos + Vector2(w, h - cut),
		pos + Vector2(w - cut, h), pos + Vector2(cut, h),
		pos + Vector2(0, h - cut), pos + Vector2(0, cut)
	])
	pause_shape.polygon = pts
	pause_outline.points = pts
	pause_title.position = Vector2(pos.x + 15, pos.y + 38)
	pause_resume_btn.position = Vector2((vp.x - 300.0) * 0.5, pos.y + 135)
	pause_menu_btn.position = Vector2((vp.x - 300.0) * 0.5, pos.y + 205)


func _toggle_pause() -> void:
	pause_open = not pause_open
	pause_layer.visible = pause_open
	if pause_open:
		shake = 0.0  # don't freeze the camera mid-shake behind the pause panel
		cam.offset = Vector2.ZERO
		cam.rotation = 0.0
	if is_instance_valid(cursor_canvas):
		cursor_canvas.visible = not pause_open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if pause_open else Input.MOUSE_MODE_CAPTURED
	if pause_open:
		pause_title.text = "ПАУЗА" if (not Net.online or G.tutorial_active) else "МЕНЮ МАТЧА"
		pause_menu_btn.text = "ВЫЙТИ ИЗ МАТЧА"
		_layout_pause_menu()


func _clear_views() -> void:
	for pv in pviews.values():
		pv.root.queue_free()
		pv.line.queue_free()
	for ev in eviews.values():
		ev.root.queue_free()
	pviews.clear()
	eviews.clear()


# ------------------------------------------------------------- рендер ----
func _make_pv(pd: Dictionary) -> Dictionary:
	var root := Node2D.new()
	ent_layer.add_child(root)
	var halo := Sprite2D.new()
	halo.visible = not _is_potato()
	halo.texture = halo_tex
	halo.material = add_mat
	root.add_child(halo)
	var actor := VectorActor.new()
	actor.setup(int(pd.k), G.col(int(pd.c)), int(pd.get("outfit", 0)), int(pd.get("hat", 0)))
	root.add_child(actor)
	var local_ring := Line2D.new()
	local_ring.width = 5.0
	local_ring.default_color = Color(0.25, 0.95, 1.0, 0.95)
	local_ring.closed = true
	for i in 12:
		local_ring.add_point(Vector2.from_angle(TAU * float(i) / 12.0) * 49.0)
	local_ring.visible = false
	local_ring.z_index = 5
	root.add_child(local_ring)
	# Ring that shows an active class ability (Светляк overdrive / Капсула shield).
	var ability_ring := Line2D.new()
	ability_ring.width = 3.0
	ability_ring.closed = true
	for i in 20:
		ability_ring.add_point(Vector2.from_angle(TAU * float(i) / 20.0) * 38.0)
	ability_ring.visible = false
	ability_ring.z_index = 4
	root.add_child(ability_ring)
	var lbl := Label.new()
	lbl.position = Vector2(-70, -66)
	lbl.size = Vector2(140, 22)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	root.add_child(lbl)
	var line := Line2D.new()
	line.width = 28.0
	line.width_curve = trail_curve
	line.gradient = trail_grad
	line.joint_mode = Line2D.LINE_JOINT_BEVEL
	line.begin_cap_mode = Line2D.LINE_CAP_NONE
	var sm: ShaderMaterial = null
	if not _is_potato():
		sm = ShaderMaterial.new()
		sm.shader = trail_shader
		line.material = sm
	else:
		line.visible = false
	trail_layer.add_child(line)
	return {"root": root, "halo": halo, "actor": actor, "lbl": lbl, "line": line, "mat": sm,
		"local_ring": local_ring, "ability_ring": ability_ring, "pos": pd.p, "rot": (pd.a as Vector2).angle() + PI * 0.5,
		"kick": 0.0, "kind": pd.k, "ci": pd.c}


func _update_views(dt: float) -> void:
	var pl: Array = view.get("pl", [])
	var local_shadow := false
	var ci_name := {}
	for pd in pl:
		if pd.i == local_id:
			local_shadow = pd.s
		if not pd.d:
			ci_name[pd.c] = pd.n
	var bomb_id: int = view.get("bomb", 0)
	var bomb_t: float = view.get("bt", 0.0)
	var seen := {}
	for pd in pl:
		var id: int = pd.i
		seen[id] = true
		cis[id] = pd.c
		var pv: Dictionary = pviews.get(id, {})
		if pv.is_empty():
			pv = _make_pv(pd)
			pviews[id] = pv
		var vel: Vector2 = pd.v
		var tpos: Vector2 = pd.p + vel * snap_age
		var line: Line2D = pv.line
		if is_client:
			pv.pos = pv.pos.lerp(tpos, minf(1.0, 24.0 * dt))
		else:
			pv.pos = tpos
		if line.get_point_count() > 0 and (line.get_point_position(line.get_point_count() - 1) - pv.pos).length() > 350.0:
			line.clear_points()
		var shadow: bool = pd.s
		var vis: bool = (not shadow) or local_shadow or id == local_id
		# Light fraction relative to THIS class's maximum (classes have 100..155 max light).
		var lf: float = clampf(float(pd.l) / maxf(float(pd.get("hpmax", 100.0)), 1.0), 0.0, 1.0) * 1.1
		var col: Color = G.col(pd.c)
		var root: Node2D = pv.root
		var actor = pv.actor
		var halo: Sprite2D = pv.halo
		var local_ring: Line2D = pv.local_ring
		var new_outfit := int(pd.get("outfit", 0))
		var new_hat := int(pd.get("hat", 0))
		if pv.kind != int(pd.k) or pv.ci != int(pd.c) or int(pv.get("outfit", -1)) != new_outfit or int(pv.get("hat", -1)) != new_hat:
			actor.setup(int(pd.k), G.col(int(pd.c)), new_outfit, new_hat)
			pv.kind = int(pd.k)
			pv.ci = int(pd.c)
			pv.outfit = new_outfit
			pv.hat = new_hat
		var lbl: Label = pv.lbl
		root.visible = vis
		local_ring.visible = (id == local_id and not shadow) or float(pd.get("dr", 0.0)) > 0.0
		local_ring.default_color = Color("#ffdc70") if float(pd.get("dr", 0.0)) > 0.0 else Color("#8df6ff")
		local_ring.width = 5.0 + 2.0 * (0.5 + 0.5 * sin(t * 7.0))
		capsule_charge_ring.visible = false
		var ability_ring: Line2D = pv.ability_ring
		var ability_on: bool = float(pd.get("ab", 0.0)) > 0.0 and not shadow and (int(pd.k) == 0 or int(pd.k) == 1)
		ability_ring.visible = ability_on and not _is_potato()
		if ability_on:
			var ring_color := Color(0.35, 1.7, 2.2) if int(pd.k) == 0 else Color(2.2, 1.6, 0.5)
			ring_color.a = 0.55 + 0.35 * sin(t * 16.0)
			ability_ring.default_color = ring_color
			ability_ring.scale = Vector2.ONE * (1.0 + 0.08 * sin(t * 12.0))
		line.visible = vis and not _is_potato()
		root.position = pv.pos
		# The character artwork's forward side (and hat) points upward in local space.
		# Rotate that top edge toward the aim vector instead of aligning its X axis.
		var aim_rotation := (pd.a as Vector2).angle() + PI * 0.5
		pv.rot = lerp_angle(pv.rot, aim_rotation, minf(1.0, 30.0 * dt))
		actor.rotation = pv.rot
		pv.kick = maxf(0.0, pv.kick - dt * 7.0)
		var pulse := 1.0 + 0.07 * sin(t * 11.0 + id)
		actor.scale = Vector2.ONE * (0.92 + 0.18 * lf) if _is_potato() else Vector2.ONE * (0.92 + 0.18 * lf) * pulse * (1.0 + pv.kick * 0.35)
		halo.visible = not _is_potato()
		if not _is_potato():
			halo.scale = Vector2.ONE * (0.55 + 0.75 * lf)
		if shadow:
			var ghost_alpha := 0.66 + 0.10 * sin(t * 3.6 + float(id))
			actor.modulate = Color(0.20, 0.11, 0.38, ghost_alpha) if not _is_potato() else Color(0.38, 0.32, 0.52, 0.9)
			halo.modulate = Color(0.48, 0.12, 1.35, 0.42 + 0.10 * sin(t * 2.8 + float(id)))
			if not _is_potato():
				actor.scale = Vector2.ONE * 0.62 * (1.0 + 0.025 * sin(t * 4.0 + float(id)))
		else:
			var c := col if _is_potato() else G.hdr(col, 1.0 + 0.55 * lf)
			if pd.h > 0.0:
				c = Color.WHITE if _is_potato() else Color(3.2, 3.2, 3.2)
			if pd.iv > 0.0 and not _is_potato():
				c.a = 0.45 + 0.4 * sin(t * 70.0)
			if bomb_id == id:
				c = (Color("#ff654d") if sin(t * (9.0 + (4.0 - bomb_t) * 7.0)) > 0.0 else Color.WHITE) if _is_potato() else (Color(3.4, 0.5, 0.3) if sin(t * (9.0 + (4.0 - bomb_t) * 7.0)) > 0.0 else Color(3.4, 3.4, 3.4))
			if pd.dr > 0.0 and not _is_potato():
				c = Color(2.4, 0.4, 2.8) if int(t * 14.0) % 2 == 0 else Color(0.6, 2.0, 2.4)
				root.position += Vector2(randf_range(-6, 6), randf_range(-6, 6))
			actor.modulate = c
			var hc := G.hdr(col, 0.12 + 0.28 * lf)
			hc.a = 0.20 + 0.32 * lf
			halo.modulate = hc
		lbl.visible = vis and not shadow
		var nm: String = pd.n
		if pd.d:
			nm = ci_name.get(pd.c, "?")
		if bool(pd.get("bot", false)):
			nm += " (бот)"
		lbl.text = ("> " + nm) if id == local_id else nm
		if bomb_id == id:
			lbl.text = "БОМБА %.1f" % maxf(bomb_t, 0.0)
		lbl.modulate = Color(1, 1, 1, 0.85)
		# Potato mode removes trails completely, including their point updates.
		if _is_potato():
			if line.get_point_count() > 0:
				line.clear_points()
			continue
		# трейл
		var moving: bool = vel.length() > 60.0 or pd.dt
		if moving:
			var point_count := line.get_point_count()
			if point_count == 0 or line.get_point_position(point_count - 1).distance_squared_to(pv.pos) >= 81.0 or pd.dt:
				line.add_point(pv.pos)
			var maxp := 30 if pd.dt else 20
			while line.get_point_count() > maxp:
				line.remove_point(0)
		elif line.get_point_count() > 0:
			line.remove_point(0)
		var sm: ShaderMaterial = pv.mat
		sm.set_shader_parameter("tint", Color(0.6, 0.2, 1.0) if shadow else col)
		sm.set_shader_parameter("hdr", 1.7 if shadow else (5.0 if pd.dt else 2.2 + 1.6 * lf))
	for id in pviews.keys():
		if not seen.has(id):
			pviews[id].root.queue_free()
			pviews[id].line.queue_free()
			pviews.erase(id)
	_update_eaters(dt)


func _update_eaters(dt: float) -> void:
	var seen := {}
	for ed in view.get("ea", []):
		var id: int = ed[0]
		seen[id] = true
		var ev: Dictionary = eviews.get(id, {})
		if ev.is_empty():
			var root := Node2D.new()
			var halo := Sprite2D.new()
			halo.texture = halo_tex
			halo.material = add_mat
			root.add_child(halo)
			var spr := Polygon2D.new()
			var detail := Node2D.new()
			if int(ed[3]) == 0:
				# Crawler: squat armored body, hooked legs and a jagged maw.
				spr.polygon = PackedVector2Array([Vector2(-29,-12),Vector2(-21,-25),Vector2(-5,-29),Vector2(12,-24),Vector2(29,-9),Vector2(25,12),Vector2(10,25),Vector2(-12,24),Vector2(-29,9)])
				spr.color = Color("#b84b72")
				_add_eater_line(detail, PackedVector2Array([Vector2(-13,-8),Vector2(-31,-23),Vector2(-39,-20)]), Color("#71334f"), 5.0)
				_add_eater_line(detail, PackedVector2Array([Vector2(12,-8),Vector2(30,-24),Vector2(39,-20)]), Color("#71334f"), 5.0)
				_add_eater_line(detail, PackedVector2Array([Vector2(-15,9),Vector2(-32,23),Vector2(-39,20)]), Color("#71334f"), 5.0)
				_add_eater_line(detail, PackedVector2Array([Vector2(14,9),Vector2(31,23),Vector2(39,20)]), Color("#71334f"), 5.0)
				_add_eater_poly(detail, PackedVector2Array([Vector2(-19,-16),Vector2(-12,-31),Vector2(-5,-17)]), Color("#e58aa0"))
				_add_eater_poly(detail, PackedVector2Array([Vector2(2,-20),Vector2(13,-32),Vector2(17,-12)]), Color("#e58aa0"))
				_add_eater_poly(detail, PackedVector2Array([Vector2(9,3),Vector2(25,-2),Vector2(20,14),Vector2(5,17)]), Color("#54283f"))
				_add_eater_poly(detail, PackedVector2Array([Vector2(10,5),Vector2(15,12),Vector2(18,4)]), Color("#f6c5b4"))
				_add_eater_poly(detail, PackedVector2Array([Vector2(-7,-12),Vector2(1,-19),Vector2(8,-11),Vector2(2,-3)]), Color("#ffe27a"))
				_add_eater_poly(detail, PackedVector2Array([Vector2(0,-11),Vector2(4,-16),Vector2(7,-10),Vector2(3,-5)]), Color("#321e38"))
			else:
				# Flyer: angular manta-like body with torn wings, tail and glowing eyes.
				spr.polygon = PackedVector2Array([Vector2(-4,-30),Vector2(12,-19),Vector2(34,-12),Vector2(21,2),Vector2(16,21),Vector2(0,14),Vector2(-16,21),Vector2(-21,2),Vector2(-34,-12),Vector2(-12,-19)])
				spr.color = Color("#8051b8")
				_add_eater_poly(detail, PackedVector2Array([Vector2(-12,-17),Vector2(-35,-25),Vector2(-25,-5),Vector2(-38,5),Vector2(-15,2)]), Color("#59347f"))
				_add_eater_poly(detail, PackedVector2Array([Vector2(12,-17),Vector2(35,-25),Vector2(25,-5),Vector2(38,5),Vector2(15,2)]), Color("#59347f"))
				_add_eater_poly(detail, PackedVector2Array([Vector2(-5,10),Vector2(0,18),Vector2(5,10),Vector2(0,34)]), Color("#b68be0"))
				_add_eater_poly(detail, PackedVector2Array([Vector2(-11,-10),Vector2(-3,-14),Vector2(-2,-5),Vector2(-9,-3)]), Color("#a9f7ff"))
				_add_eater_poly(detail, PackedVector2Array([Vector2(3,-14),Vector2(11,-10),Vector2(9,-3),Vector2(2,-5)]), Color("#a9f7ff"))
				_add_eater_poly(detail, PackedVector2Array([Vector2(-8,3),Vector2(0,8),Vector2(8,3),Vector2(0,13)]), Color("#321e48"))
			root.add_child(spr)
			root.add_child(detail)
			ent_layer.add_child(root)
			ev = {"root": root, "spr": spr, "detail": detail, "halo": halo, "pos": ed[1], "rot": 0.0}
			eviews[id] = ev
		var vel: Vector2 = ed[2]
		var tpos: Vector2 = ed[1] + vel * snap_age
		ev.pos = ev.pos.lerp(tpos, minf(1.0, 24.0 * dt)) if is_client else tpos
		var root: Node2D = ev.root
		var spr: Polygon2D = ev.spr
		var halo: Sprite2D = ev.halo
		halo.visible = not _is_potato()
		root.position = ev.pos
		if vel.length() > 5.0:
			ev.rot = lerp_angle(ev.rot, vel.angle(), minf(1.0, 12.0 * dt))
		spr.rotation = ev.rot
		var detail: Node2D = ev.detail
		detail.rotation = ev.rot
		var base := 0.62 if ed[3] == 0 else 0.42
		var pulse := 1.0 + 0.09 * sin(t * 9.0 + id)
		spr.scale = Vector2.ONE * base * pulse
		detail.scale = Vector2.ONE * base * pulse
		var c := Color(1.15, 0.35, 0.62) if ed[3] == 0 else Color(0.62, 0.38, 1.1)
		if ed[5] > 0.0:
			c = Color(3, 3, 3)
		spr.modulate = c if not _is_potato() else Color(c.r, c.g, c.b, 1.0)
		halo.visible = not _is_potato()
		if not _is_potato():
			halo.scale = Vector2.ONE * (1.3 if ed[3] == 0 else 0.9)
			halo.modulate = Color(c.r * 0.5, c.g * 0.3, c.b * 0.5, 0.45)
	for id in eviews.keys():
		if not seen.has(id):
			eviews[id].root.queue_free()
			eviews.erase(id)


func _add_eater_poly(parent: Node2D, points: PackedVector2Array, tint: Color) -> void:
	var part := Polygon2D.new()
	part.polygon = points
	part.color = tint
	parent.add_child(part)


func _add_eater_line(parent: Node2D, points: PackedVector2Array, tint: Color, thickness: float) -> void:
	var part := Line2D.new()
	part.points = points
	part.width = thickness
	part.default_color = tint
	part.begin_cap_mode = Line2D.LINE_CAP_ROUND
	part.end_cap_mode = Line2D.LINE_CAP_ROUND
	parent.add_child(part)


func _update_fx(dt: float) -> void:
	if _is_potato() or not is_instance_valid(fx_mat):
		return
	var fx: Dictionary = view.get("fx", {})
	invert_cur = move_toward(invert_cur, 1.0 if fx.has("invert") else 0.0, dt * 5.0)
	blind_cur = move_toward(blind_cur, 1.0 if fx.has("blind") else 0.0, dt * 4.0)
	fx_mat.set_shader_parameter("invert", invert_cur)
	fx_mat.set_shader_parameter("blind", blind_cur)
	var ws := Vector2(get_window().size)
	var sc := minf(ws.x / 1280.0, ws.y / 720.0)
	var wp: Vector2 = pviews[local_id].pos if pviews.has(local_id) else ARENA / 2.0
	var px: Vector2 = ws / 2.0 + (wp - ARENA / 2.0) * cam.zoom.x * sc
	fx_mat.set_shader_parameter("center", px / ws)
	fx_mat.set_shader_parameter("aspect", ws.x / ws.y)
	fx_mat.set_shader_parameter("radius", 200.0 * cam.zoom.x * sc / ws.y)


func _update_hud(dt: float) -> void:
	if pause_open:
		_layout_pause_menu()
	var over: bool = view.get("ph", "play") == "over"
	var elapsed := int(float(view.get("elapsed", 0.0)))
	stopwatch_lbl.text = "%02d:%02d" % [elapsed / 60, elapsed % 60]
	var active_chaos: Array[String] = []
	var fx: Dictionary = view.get("fx", {})
	for chaos_key in fx.keys():
		if float(fx[chaos_key]) > 0.0 and CHAOS_RU.has(chaos_key):
			active_chaos.append(str(CHAOS_RU[chaos_key]))
	if int(view.get("bomb", 0)) != 0:
		active_chaos.append("НЕОНОВАЯ БОМБА")
	var chaos_text := "[font_size=11][b][color=#74edff]АКТИВНЫЙ ХАОС[/color][/b][/font_size]\n[table=1]"
	if active_chaos.is_empty():
		chaos_text += "[cell][b][color=#a9efff]СЕЙЧАС ТИХО[/color][/b][/cell]"
	else:
		active_chaos.sort()
		for chaos_name in active_chaos:
			chaos_text += "[cell][b][color=#ffd47a]◆  %s[/color][/b][/cell]" % chaos_name
	if float(view.get("tl", 0.0)) > 75.0:
		chaos_text += "[cell][b][color=#ff9d72]СВЕТ АРЕНЫ УГАСАЕТ[/color][/b][/cell]"
	chaos_text += "[/table]"
	if timer_lbl.text != chaos_text:
		timer_lbl.text = chaos_text
	timer_lbl.modulate = Color.WHITE
	timer_shape.visible = false
	timer_outline.visible = false
	timer_lbl.anchor_top = 0.0
	timer_lbl.anchor_bottom = 0.0
	timer_lbl.anchor_left = 1.0
	timer_lbl.anchor_right = 1.0
	timer_lbl.offset_left = -370.0
	timer_lbl.offset_right = -24.0
	timer_lbl.offset_top = 18.0
	timer_lbl.offset_bottom = 116.0
	timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	timer_lbl.add_theme_stylebox_override("normal", _chaos_panel_style())
	var rows: Array = []
	var me: Dictionary = {}
	for pd in view.get("pl", []):
		if pd.i == local_id:
			me = pd
		if not pd.d:
			rows.append(pd)
	# Leaderboard follows the actual match objective: chaos first, then remaining light.
	rows.sort_custom(func(a, b):
		if bool(a.s) != bool(b.s):
			return not bool(a.s)
		if int(a.pt) != int(b.pt):
			return int(a.pt) > int(b.pt)
		return float(a.l) > float(b.l))
	var txt := "[font_size=12][color=#74edff][b]◈  РЕЙТИНГ МАТЧА[/b][/color][/font_size]\n"
	txt += "[table=4]"
	txt += "[cell][color=#718ba5]#[/color][/cell]"
	txt += "[cell][color=#718ba5]ИГРОК[/color][/cell]"
	txt += "[cell][color=#718ba5]СВЕТ[/color][/cell]"
	txt += "[cell][color=#718ba5]ХАОС[/color][/cell]"
	for rank_i in rows.size():
		var pd: Dictionary = rows[rank_i]
		var hex: String = G.col(pd.c).to_html(false)
		var state_text := "ТЕНЬ" if pd.s else "%d HP" % int(pd.l)
		var display_name: String = str(pd.n)
		if bool(pd.get("bot", false)):
			display_name += " [Б]"
		if display_name.length() > 13:
			display_name = display_name.substr(0, 12) + "…"
		var rank_color := "#ffd76a" if rank_i == 0 else ("#b9c9dc" if rank_i == 1 else "#8c9db2")
		var chaos_color := "#ffbd58" if int(pd.pt) > 0 else "#91a4b9"
		var current_marker := "▶ " if pd.i == local_id else ""
		txt += "[cell][color=%s]%s%02d[/color][/cell]" % [rank_color, current_marker, rank_i + 1]
		txt += "[cell][color=#%s]%s[/color][/cell]" % [hex, display_name]
		txt += "[cell][color=#9aacc0]%s[/color][/cell]" % state_text
		txt += "[cell][font_size=10][color=%s][b]%d[/b][/color][/font_size][/cell]" % [chaos_color, int(pd.pt)]
	txt += "[/table]"
	score_lbl.size.y = 48.0 + float(rows.size()) * 18.0
	if txt != last_score_text:  # re-parsing BBCode every frame was needless work
		last_score_text = txt
		score_lbl.text = txt
	if not me.is_empty():
		var is_shadow := bool(me.get("s", false))
		# A shadow has no light reserve: never leave the previous light fill visible.
		light_bar.visible = true
		light_bar.set_fill_ratio(0.0 if is_shadow else clampf(float(me.get("l", 0.0)) / maxf(float(me.get("hpmax", 1.0)), 1.0), 0.0, 1.0))
		var dash_cooldown := clampf(float(me.get("dc", 0.0)), 0.0, Sim.DASH_CD)
		var ability_cooldown := clampf(float(me.get("acd", 0.0)), 0.0, 9.0)
		dash_bar.set_fill_ratio(1.0 - dash_cooldown / Sim.DASH_CD)
		ability_bar.set_fill_ratio(1.0 - ability_cooldown / 9.0)
		var is_capsule := int(me.k) == 1 and not bool(me.s) and not over
		capsule_ammo_lbl.visible = is_capsule
		capsule_reload_bar.visible = is_capsule
		if is_capsule:
			var ammo := clampi(int(me.get("wa", 4)), 0, 4)
			var ammo_text := ""
			for charge_i in 4:
				ammo_text += "◆ " if charge_i < ammo else "◇ "
			capsule_ammo_lbl.text = "ВОЛНЫ  " + ammo_text + ("  +" + ("%.1f" % float(me.get("wr", 0.0))) + "с" if ammo < 4 else "  ГОТОВО")
			var reload_left := clampf(float(me.get("wr", 0.0)), 0.0, 1.5)
			capsule_reload_bar.set_fill_ratio(1.0 - reload_left / 1.5 if ammo < 4 else 1.0)
		var buff_names := {"swift": "УСКОРЕНИЕ", "overdrive": "УСИЛЕННЫЙ УРОН", "shield": "ЗАЩИТА", "battery": "БАТАРЕЯ"}
		if str(me.get("buff", "")) != "" and float(me.get("buff_t", 0.0)) > 0.0:
			timer_lbl.text += "\nВАШ БУСТ: %s (%.1fс)" % [buff_names.get(str(me.buff), "УЛУЧШЕНИЕ"), float(me.get("buff_t", 0.0))]
		var class_names := ["СВЕТЛЯК", "КАПСУЛА", "ПРИЗРАК", "КРИСТАЛЛ"]
		var ability_ready := "ГОТОВО" if me.acd <= 0.0 else "%.1fс" % me.acd
		help_lbl.text = "%s  /  %s\nСПОСОБНОСТЬ [Q]: %s" % [class_names[int(me.k) % 4], ["Перегрузка", "Энергощит", "Фазовый скачок", "Звёздный залп"][int(me.k) % 4], ability_ready]
		if me.s:
			help_lbl.text = "ТЫ — ТЕНЬ\nПКМ / E рядом с игроком — вселение"
	if over:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		over_rect.visible = true
		over_shape.visible = true
		over_outline.visible = true
		over_lbl.visible = not result_detail_open
		result_list_scroll.visible = result_detail_open
		over_restart_btn.visible = not is_client and not result_detail_open
		over_menu_btn.visible = true
		over_exit_btn.visible = result_detail_open
		if not result_detail_open:
			over_menu_btn.text = "В МЕНЮ"
			if not over_menu_btn.pressed.is_connected(_to_menu):
				over_menu_btn.pressed.connect(_to_menu)
			var winner_name := "никто"
			var final_rows: Array = []
			for pd in view.get("pl", []):
				if pd.i == view.get("wn", 0):
					winner_name = str(pd.n)
				if not pd.d:
					final_rows.append(pd)
			var category_ranks := [final_rows.duplicate(), final_rows.duplicate(), final_rows.duplicate(), final_rows.duplicate()]
			category_ranks[0].sort_custom(func(a, b): return float(a.get("dm", 0.0)) > float(b.get("dm", 0.0)))
			category_ranks[1].sort_custom(func(a, b): return float(a.get("hl", 0.0)) > float(b.get("hl", 0.0)))
			category_ranks[2].sort_custom(func(a, b): return int(a.ki) > int(b.ki))
			category_ranks[3].sort_custom(func(a, b): return int(a.pt) > int(b.pt))
			var category_names := ["⚔️ УРОН", "💚 ЛЕЧЕНИЕ", "☠️ УБИЙСТВА", "🌪️ ХАОС"]
			var stat_keys := ["dm", "hl", "ki", "pt"]
			var report := "[center][font_size=30][b][color=#68edff]◈  ИТОГИ МАТЧА  ◈[/color][/b][/font_size]\n"
			report += "[font_size=22][color=#ffffff]ПОБЕДИТЕЛЬ[/color]  [color=#ffd76a]%s[/color]\n" % winner_name
			report += "[font_size=16][color=#9ab8d4]ВРЕМЯ МАТЧА  %02d:%02d[/color][/font_size][/center]" % [int(float(view.get("elapsed", 0.0))) / 60, int(float(view.get("elapsed", 0.0))) % 60]
			over_lbl.scroll_active = false
			report = report.replace("[center]", "").replace("[/center]", "")
			over_lbl.text = report
			over_lbl.modulate = Color.WHITE
			for i in result_cards.size():
				var card := result_cards[i]
				var ranking: Array = category_ranks[i]
				var leader: Dictionary = ranking[0] if not ranking.is_empty() else {} 
				var accents := [Color("#ff9b67"), Color("#72f0b1"), Color("#b58aff"), Color("#ffd76a")]
				card.text = ""
				card.custom_minimum_size = Vector2(190, 118)
				if not card.has_meta("portrait_ready"):
					var portrait := SubViewportContainer.new()
					portrait.position = Vector2(card.size.x * 0.5 - 62.0, 48.0)
					portrait.size = Vector2(124, 132)
					portrait.stretch = true
					portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
					var portrait_vp := SubViewport.new()
					portrait_vp.size = Vector2i(120, 120)
					portrait_vp.transparent_bg = true
					portrait_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
					portrait.add_child(portrait_vp)
					var portrait_actor := VectorActor.new()
					portrait_actor.position = Vector2(60, 66)
					portrait_actor.scale = Vector2.ONE * 0.82
					portrait_vp.add_child(portrait_actor)
					if not ranking.is_empty():
						portrait_actor.setup(int(leader.k), G.col(int(leader.c)), int(leader.get("outfit", 0)), int(leader.get("hat", 0)))
					else:
						portrait_actor.setup(0, Color("#64eaff"), 0, 0)
					card.add_child(portrait)
					card.set_meta("portrait_ready", true)
					var category_label := Label.new()
					category_label.name = "CategoryTitle"
					category_label.position = Vector2(8, 8)
					category_label.size = Vector2(card.size.x - 16, 30)
					category_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					category_label.add_theme_font_size_override("font_size", 21)
					category_label.add_theme_color_override("font_color", accents[i])
					category_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
					card.add_child(category_label)
					var nick_label := Label.new()
					nick_label.name = "LeaderNick"
					nick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					nick_label.position = Vector2(8, card.size.y - 96)
					nick_label.size = Vector2(card.size.x - 16, 30)
					nick_label.add_theme_font_size_override("font_size", 19)
					nick_label.add_theme_color_override("font_color", Color("#f0f8ff"))
					nick_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
					card.add_child(nick_label)
					var value_label := Label.new()
					value_label.name = "LeaderValue"
					value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					value_label.position = Vector2(8, card.size.y - 62)
					value_label.size = Vector2(card.size.x - 16, 34)
					value_label.add_theme_font_size_override("font_size", 24)
					value_label.add_theme_color_override("font_color", accents[i].lightened(0.12))
					value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
					card.add_child(value_label)
				var category_label := card.get_node_or_null("CategoryTitle") as Label
				var nick_label := card.get_node_or_null("LeaderNick") as Label
				var value_label := card.get_node_or_null("LeaderValue") as Label
				if category_label: category_label.text = category_names[i]
				if nick_label: nick_label.text = str(leader.n) if not ranking.is_empty() else "НЕТ ЛИДЕРА"
				if value_label: value_label.text = str(int(leader.get(stat_keys[i], 0))) if not ranking.is_empty() else "0"
				card.visible = true
			_layout_game_over()
	else:
		over_rect.visible = false
		over_shape.visible = false
		over_outline.visible = false
		over_lbl.visible = false
		for card in result_cards:
			card.visible = false
		result_list_scroll.visible = false
		result_detail_open = false
		over_restart_btn.visible = false
		over_menu_btn.visible = false
		over_exit_btn.visible = false

func _open_result_category(category: String) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	result_detail_open = true
	var key: String = str({"УРОН":"dm", "ХИЛ":"hl", "УБИЙСТВА":"ki", "ХАОС":"pt"}.get(category, "pt"))
	var rows: Array = []
	for pd in view.get("pl", []):
		rows.append(pd)
	rows.sort_custom(func(a, b): return float(a.get(key, 0.0)) > float(b.get(key, 0.0)))
	var accent: String = str({"dm":"#ff9b67", "hl":"#72f0b1", "ki":"#b58aff", "pt":"#ffd76a"}.get(key, "#70eaff"))
	var category_titles := {"УРОН":"⚔️  УРОН", "ХИЛ":"💚  ЛЕЧЕНИЕ", "УБИЙСТВА":"☠️  УБИЙСТВА", "ХАОС":"🌪️  ХАОС"}
	var display_category: String = str(category_titles.get(category, category))
	var lines := "[font_size=27][b][color=%s]%s[/color][/b][/font_size]\n\n" % [accent, display_category]
	lines += "[table=3][cell][color=#829bb5]# / ПЕРСОНАЖ[/color][/cell][cell][color=#829bb5]ИГРОК[/color][/cell][cell][color=#829bb5]РЕЗУЛЬТАТ[/color][/cell]"
	for i in rows.size():
		var p: Dictionary = rows[i]
		var player_color := G.col(int(p.get("c", 0))).to_html(false)
		var amount := int(p.get(key, 0))
		lines += "[cell][color=%s]%02d[/color][/cell][cell][color=#%s]%s%s[/color][/cell][cell][b][color=%s]%d[/color][/b][/cell]" % [accent, i + 1, player_color, str(p.n), "  [Б]" if bool(p.get("bot", false)) else "", accent, amount]
	lines += "[/table]"
	over_lbl.scroll_active = false
	over_lbl.text = "[center][font_size=27][b][color=%s]%s[/color][/b][/font_size][/center]" % [accent, display_category]
	for child in result_list.get_children():
		child.queue_free()
	var category_header := Label.new()
	category_header.text = display_category
	category_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	category_header.custom_minimum_size = Vector2(0, 42)
	category_header.add_theme_font_size_override("font_size", 24)
	category_header.add_theme_color_override("font_color", Color(accent))
	category_header.add_theme_color_override("font_shadow_color", Color(accent, 0.28))
	category_header.add_theme_constant_override("shadow_offset_x", 0)
	category_header.add_theme_constant_override("shadow_offset_y", 2)
	result_list.add_child(category_header)
	for i in rows.size():
		var p: Dictionary = rows[i]
		var row_card := PanelContainer.new()
		row_card.custom_minimum_size = Vector2(0, 94)
		row_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color("#0b1b2d", 0.82)
		row_style.border_color = Color("#287e91", 0.82)
		row_style.set_border_width_all(1)
		row_style.set_corner_radius_all(0)
		row_style.content_margin_left = 8
		row_style.content_margin_right = 12
		row_style.content_margin_top = 4
		row_style.content_margin_bottom = 4
		row_card.add_theme_stylebox_override("panel", row_style)
		result_list.add_child(row_card)
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 12)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row_card.add_child(row)
		var portrait := SubViewportContainer.new()
		portrait.custom_minimum_size = Vector2(88, 82)
		portrait.size = Vector2(88, 82)
		portrait.stretch = true
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var portrait_vp := SubViewport.new()
		portrait_vp.size = Vector2i(120, 110)
		portrait_vp.transparent_bg = true
		portrait_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		portrait.add_child(portrait_vp)
		var portrait_actor := VectorActor.new()
		portrait_actor.position = Vector2(60, 58)
		portrait_actor.scale = Vector2.ONE * 0.72
		portrait_vp.add_child(portrait_actor)
		portrait_actor.setup(int(p.get("k", 0)), G.col(int(p.get("c", 0))), int(p.get("outfit", 0)), int(p.get("hat", 0)))
		row.add_child(portrait)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(details)
		var name_label := Label.new()
		name_label.text = "%02d   %s%s" % [i + 1, str(p.get("n", "Игрок")), "  •  БОТ" if bool(p.get("bot", false)) else ""]
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_color", G.col(int(p.get("c", 0))))
		details.add_child(name_label)
		var skin_label := Label.new()
		var outfits := ["Без костюма", "Броня", "Полосатый", "Неоновый", "Плащ"]
		var hats := ["Без шапки", "Корона", "Кепка", "Рожки", "Ауреол"]
		skin_label.text = "%s  •  %s" % [outfits[clampi(int(p.get("outfit", 0)), 0, outfits.size() - 1)], hats[clampi(int(p.get("hat", 0)), 0, hats.size() - 1)]]
		skin_label.add_theme_font_size_override("font_size", 12)
		skin_label.add_theme_color_override("font_color", Color("#91a9c2"))
		details.add_child(skin_label)
		var score_label := Label.new()
		score_label.text = "%s: %d" % [display_category, int(p.get(key, 0))]
		score_label.custom_minimum_size.x = 150
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score_label.add_theme_font_size_override("font_size", 20)
		score_label.add_theme_color_override("font_color", Color(accent))
		row.add_child(score_label)
	result_list_scroll.visible = true
	for card in result_cards:
		card.visible = false
	over_restart_btn.visible = false
	over_menu_btn.text = "К КАРТОЧКАМ"
	over_exit_btn.visible = true
	if over_menu_btn.pressed.is_connected(_to_menu):
		over_menu_btn.pressed.disconnect(_to_menu)
	over_menu_btn.pressed.connect(_close_result_category, CONNECT_ONE_SHOT)
	var tween := create_tween()
	var target_position := over_lbl.position
	over_lbl.position += Vector2(0, 26)
	over_lbl.modulate.a = 0.0
	tween.set_parallel(true)
	tween.tween_property(over_lbl, "modulate:a", 1.0, 0.35)
	tween.tween_property(over_lbl, "position", target_position, 0.35)


func _close_result_category() -> void:
	result_detail_open = false
	over_menu_btn.text = "К КАРТОЧКАМ"
	over_exit_btn.visible = false
	if over_menu_btn.pressed.is_connected(_close_result_category):
		over_menu_btn.pressed.disconnect(_close_result_category)
	if not over_menu_btn.pressed.is_connected(_to_menu):
		over_menu_btn.pressed.connect(_to_menu)
	for card in result_cards:
		card.visible = true
	result_list_scroll.visible = false
	over_lbl.visible = true
	over_restart_btn.visible = not is_client
	over_lbl.modulate.a = 1.0


func _rank_line(rank: Array, key: String) -> String:
	if rank.is_empty():
		return "—"
	var out: Array[String] = []
	for i in mini(3, rank.size()):
		var p: Dictionary = rank[i]
		var value := int(p.get(key, 0.0))
		out.append("%s %d" % [str(p.n), value])
	return " / ".join(out)


# -------------------------------------------------------------- эффекты ---

func _chaos_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#071625", 0.94)
	style.border_color = Color("#39d9f0", 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

func _style_result_button(button: Button, accent: Color) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#14243b", 0.96) if state != "pressed" else Color("#203b56", 0.98)
		style.border_color = accent.lightened(0.22) if state == "hover" else accent
		style.set_border_width_all(2)
		style.set_corner_radius_all(0)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("#eafaff"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 18)


func _layout_game_over() -> void:
	var vp := get_viewport().get_visible_rect().size
	var panel_size := Vector2(minf(1040.0, vp.x - 56.0), minf(700.0, vp.y - 48.0))
	var pos := (vp - panel_size) * 0.5
	var cut := 28.0
	var points := PackedVector2Array([
		Vector2(pos.x + cut, pos.y), Vector2(pos.x + panel_size.x - cut, pos.y),
		Vector2(pos.x + panel_size.x, pos.y + cut), Vector2(pos.x + panel_size.x, pos.y + panel_size.y - cut),
		Vector2(pos.x + panel_size.x - cut, pos.y + panel_size.y), Vector2(pos.x + cut, pos.y + panel_size.y),
		Vector2(pos.x, pos.y + panel_size.y - cut), Vector2(pos.x, pos.y + cut)
	])
	over_shape.polygon = points
	over_outline.points = points
	over_lbl.position = Vector2(pos.x + 52.0, pos.y + 38.0)
	over_lbl.size = Vector2(panel_size.x - 104.0, panel_size.y - 190.0)
	over_lbl.add_theme_font_size_override("normal_font_size", 20)
	over_lbl.add_theme_constant_override("line_separation", 5)
	var cards_y := pos.y + 168.0
	var card_width := (panel_size.x - 150.0) / 4.0
	var card_height := panel_size.y - 310.0
	for i in result_cards.size():
		var card := result_cards[i]
		card.position = Vector2(pos.x + 55.0 + float(i) * (card_width + 12.0), cards_y)
		card.size = Vector2(card_width, card_height)
		var portrait := card.get_child(0) as Control if card.get_child_count() > 0 else null
		if portrait:
			portrait.position = Vector2(card_width * 0.5 - 62.0, 48.0)
			portrait.size = Vector2(124, 132)
		var category_label := card.get_node_or_null("CategoryTitle") as Label
		if category_label:
			category_label.position = Vector2(8, 8)
			category_label.size = Vector2(card_width - 16, 30)
		var nick_label := card.get_node_or_null("LeaderNick") as Label
		if nick_label:
			nick_label.position = Vector2(8, card_height - 96)
			nick_label.size = Vector2(card_width - 16, 30)
		var value_label := card.get_node_or_null("LeaderValue") as Label
		if value_label:
			value_label.position = Vector2(8, card_height - 62)
			value_label.size = Vector2(card_width - 16, 34)
	over_lbl.size.y = 120.0
	result_list_scroll.position = Vector2(pos.x + 48.0, pos.y + 142.0)
	result_list_scroll.size = Vector2(panel_size.x - 96.0, panel_size.y - 238.0)
	var buttons_y := pos.y + panel_size.y - 82.0
	over_restart_btn.position = Vector2(pos.x + panel_size.x * 0.5 - 232.0, buttons_y)
	over_menu_btn.position = Vector2(pos.x + panel_size.x * 0.5 + 22.0, buttons_y)
	over_exit_btn.position = Vector2(pos.x + panel_size.x - 218.0, buttons_y)


func _restart_match() -> void:
	if sim == null:
		return
	sim.reset(G.cfg)
	_clear_views()
	view = sim.snapshot()


func _handle_events(evs: Array) -> void:
	for e in evs:
		var pos := Vector2(e.get("x", 0.0), e.get("y", 0.0))
		var col := G.col(e.get("c", 0))
		match e.t:
			"hurt":
				if int(e.get("id", 0)) == local_id and is_instance_valid(edge_feedback):
					edge_feedback.ping_damage(float(e.get("amount", 8.0)))
			"heal":
				if int(e.get("id", 0)) == local_id and is_instance_valid(edge_feedback):
					edge_feedback.ping_heal(float(e.get("amount", 8.0)))
			"shockwave":
				Sfx.play("dash", 1.0, -2.0)
				_outline_shockwave(pos, float(e.get("r", 172.0)), col)
				burst(pos, col, 18, 520.0, 0.28)
				shake = maxf(shake, 9.0)
			"shot":
				Sfx.play("shot", 1.0, -8.0)
				burst(pos, col, 4, 240.0, 0.18)
				for pv in pviews.values():
					if pv.ci == e.c:
						pv.kick = 1.0
			"hit":
				Sfx.play("hit", 1.0, -3.0)
				burst(pos, col, 10, 330.0, 0.35)
				shake = maxf(shake, 6.0)
			"death":
				Sfx.play("death")
				burst(pos, col, 46, 640.0, 0.85, true)
				flash(pos, 220.0, col, 0.5)
				shake = maxf(shake, 20.0 if e.get("id", 0) != local_id else 34.0)
			"dash":
				Sfx.play("dash", 1.0, -4.0)
				burst(pos, col, 8, 300.0, 0.25)
			"possess":
				Sfx.play("possess")
				burst(pos, Color(0.8, 0.25, 1.0), 34, 280.0, 0.9, true)
				flash(pos, 150.0, Color(0.8, 0.25, 1.0), 0.6)
			"eat":
				Sfx.play("eat")
				burst(pos, Color(1.0, 0.2, 0.45), 16, 360.0, 0.45)
			"streak":
				var combo_count := int(e.get("count", 2))
				var combo_bonus := int(e.get("bonus", 0))
				_show_banner("КОМБО ×%d   +%d ХАОСА" % [combo_count, combo_bonus])
				flash(pos, 90.0, Color(1.0, 0.72, 0.18), 0.3)
			"match_event":
				if e.get("kind", "") == "surge":
					_show_banner("ЭНЕРГОВЫБРОС  +18 СВЕТА")
					flash(pos, 180.0, Color(0.25, 1.0, 0.65), 0.5)
				else:
					_show_banner("ОХОТА ПОЖИРАТЕЛЕЙ")
					flash(Vector2(800, 450), 220.0, Color(1.0, 0.2, 0.55), 0.45)
			"upgrade_pick":
				_show_banner({"swift": "УСКОРЕНИЕ", "overdrive": "УСИЛЕНИЕ УРОНА", "shield": "ЭНЕРГОЩИТ", "battery": "ЗАРЯД СВЕТА"}.get(str(e.get("kind", "")), "УЛУЧШЕНИЕ"))
				flash(pos, 90.0, col, 0.35)
			"meteor_warn":
				Sfx.play("chaos", 0.75, -5.0)
				_show_banner("МЕТЕОРИТНЫЙ ДОЖДЬ")
				flash(pos, 110.0, Color(1.0, 0.32, 0.12), 0.35)
			"meteor_impact":
				Sfx.play("boom", 1.15, -1.0)
				flash(pos, float(e.get("r", 138.0)) * 1.5, Color(1.0, 0.3, 0.08), 0.55)
				burst(pos, Color(1.0, 0.38, 0.12), 72, 820.0, 0.75, true)
				shake = maxf(shake, 22.0)
			"boom":
				Sfx.play("boom")
				flash(pos, float(e.get("r", 260.0)) * 1.3, Color(1.0, 0.85, 0.4), 0.55)
				burst(pos, Color(1.0, 0.6, 0.2), 90, 900.0, 0.9, true)
				shake = maxf(shake, 48.0)
			"chaos":
				Sfx.play("chaos")
				shake = maxf(shake, 26.0)
				timer_glitch_until = Time.get_ticks_msec() + 1800
				_show_banner(CHAOS_RU.get(e.n, str(e.n)).to_upper())
				if is_instance_valid(fx_mat):
					var tw := create_tween()
					tw.tween_method(func(v: float): fx_mat.set_shader_parameter("aberr", v), 0.03, 0.0, 0.55)
			"ability":
				Sfx.play("dash", 1.0, -2.0)
				var ability_color: Color = [Color(0.2, 0.9, 1.0), Color(1.0, 0.75, 0.25), Color(0.65, 0.3, 1.0), Color(0.4, 0.9, 1.0)][int(e.get("kind", 0)) % 4]
				flash(pos, 190.0, ability_color, 0.45)
				burst(pos, ability_color, 28 if int(e.get("kind", 0)) != 3 else 52, 520.0, 0.55, true)
			"win":
				Sfx.play("win")


func _outline_shockwave(pos: Vector2, radius: float, col: Color) -> void:
	if _is_potato():
		return
	# A translucent filled pulse makes the released charge readable without hiding the arena.
	var wave := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 64:
		points.append(Vector2.from_angle(TAU * float(i) / 64.0) * radius)
	wave.polygon = points
	wave.color = Color(col.r, col.g, col.b, 0.34)
	wave.z_index = 30
	fx_layer.add_child(wave)
	wave.position = pos
	wave.scale = Vector2.ONE * 0.72
	var tw := create_tween().set_parallel(true)
	tw.tween_property(wave, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(wave, "modulate:a", 0.0, 0.24)
	tw.chain().tween_callback(wave.queue_free)

func burst(pos: Vector2, col: Color, amount: int, speed: float, life: float, important := false) -> void:
	if _is_potato():
		return
	# Keep event bursts lightweight: many overlapping CPU particle systems were a major frame-time spike.
	# Routine bursts (shots, hits) leave headroom so deaths, bombs and abilities are never starved.
	var active_bursts := 0
	for child in fx_layer.get_children():
		if child is CPUParticles2D:
			active_bursts += 1
	var burst_limit: int = [16, 10, 5, 2][G.graphics_quality] if important else [8, 5, 2, 1][G.graphics_quality]
	if active_bursts >= burst_limit:
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.texture = halo_tex
	p.material = add_mat
	var particle_cap: int = [30, 20, 10, 4][G.graphics_quality]
	p.amount = mini(amount, particle_cap)
	p.lifetime = minf(life, 0.65)
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector2.RIGHT
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed * 0.25
	p.initial_velocity_max = speed
	p.damping_min = 40.0
	p.damping_max = 140.0
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.16
	p.color = G.hdr(col, 3.0)
	p.color_ramp = fade_grad
	fx_layer.add_child(p)
	p.emitting = true
	get_tree().create_timer(minf(life, 0.65) + 0.3).timeout.connect(p.queue_free)


func flash(pos: Vector2, radius: float, col: Color, dur := 0.4) -> void:
	if _is_potato():
		return
	var s := Sprite2D.new()
	s.texture = halo_tex
	s.material = add_mat
	s.position = pos
	s.scale = Vector2.ONE * 0.2
	s.modulate = G.hdr(col, 3.0)
	fx_layer.add_child(s)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(s, "scale", Vector2.ONE * radius / 64.0, dur).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, dur)
	tw.chain().tween_callback(s.queue_free)


func _show_banner(text: String) -> void:
	banner.text = text
	banner.modulate = G.hdr(Color.from_hsv(randf(), 0.65, 1.0), 2.4)
	banner.scale = Vector2.ONE * 1.8
	var tw := create_tween().set_parallel(true)
	tw.tween_property(banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(banner, "modulate:a", 0.0, 1.4).set_delay(0.7)
