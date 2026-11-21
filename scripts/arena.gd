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

var timer_lbl: Label
var timer_shape: Polygon2D
var timer_outline: Line2D
var ability_bar: ProgressBar
var capsule_ammo_lbl: Label
var capsule_reload_bar: ProgressBar
var cursor_layer: CanvasLayer
var cursor_canvas: Control
var banner: Label
var score_lbl: RichTextLabel
var help_lbl: Label
var light_bar: ProgressBar
var dash_bar: ProgressBar
var over_rect: ColorRect
var over_shape: Polygon2D
var over_outline: Line2D
var over_lbl: Label
var over_restart_btn: Button
var over_menu_btn: Button
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


func _label(text: String, size: int, pos: Vector2, sz: Vector2, parent: Node, center := false) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _bar(pos: Vector2, sz: Vector2, col: Color, parent: Node) -> ProgressBar:
	var b := ProgressBar.new()
	b.position = pos
	b.size = sz
	b.show_percentage = false
	b.max_value = 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.1, 0.8)
	bg.set_border_width_all(1)
	bg.border_color = Color(col.r, col.g, col.b, 0.6)
	var fl := StyleBoxFlat.new()
	fl.bg_color = col
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fl)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(b)
	return b


func _build_hud() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 10
	add_child(cl)
	timer_lbl = _label("4:00", 46, Vector2.ZERO, Vector2(220, 58), cl, true)
	timer_lbl.anchor_left = 0.5
	timer_lbl.anchor_right = 0.5
	timer_lbl.offset_left = -110
	timer_lbl.offset_right = 110
	timer_lbl.offset_top = 8
	timer_lbl.offset_bottom = 66
	timer_lbl.modulate = Color(0.6, 1.8, 2.2)
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
	score_lbl.fit_content = true
	score_lbl.scroll_active = false
	score_lbl.position = Vector2(16, 12)
	score_lbl.size = Vector2(390, 300)
	score_lbl.clip_contents = true
	score_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_lbl.add_theme_font_size_override("normal_font_size", 13)
	score_lbl.add_theme_constant_override("table_h_separation", 10)
	score_lbl.add_theme_constant_override("table_v_separation", 5)
	score_lbl.add_theme_color_override("default_color", Color("#eaf6ff"))
	var board_style := StyleBoxFlat.new()
	board_style.bg_color = Color("#071321", 0.88)
	board_style.border_color = Color("#42d9ed", 0.72)
	board_style.set_border_width_all(1)
	board_style.set_corner_radius_all(0)
	board_style.content_margin_left = 12
	board_style.content_margin_right = 12
	board_style.content_margin_top = 10
	board_style.content_margin_bottom = 10
	score_lbl.add_theme_stylebox_override("normal", board_style)
	cl.add_child(score_lbl)
	help_lbl = _label("", 15, Vector2.ZERO, Vector2(500, 112), cl)
	help_lbl.anchor_left = 1.0
	help_lbl.anchor_right = 1.0
	help_lbl.offset_left = -516
	help_lbl.offset_right = -16
	help_lbl.anchor_top = 0.0
	help_lbl.anchor_bottom = 0.0
	help_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_lbl.add_theme_font_size_override("font_size", 13)
	help_lbl.modulate = Color(0.7, 0.8, 1.0, 0.75)
	timer_shape = Polygon2D.new()
	timer_shape.position = Vector2(640, 38)
	timer_shape.polygon = PackedVector2Array([
		Vector2(-88, -28), Vector2(88, -28), Vector2(101, -15),
		Vector2(101, 15), Vector2(88, 28), Vector2(-88, 28),
		Vector2(-101, 15), Vector2(-101, -15)
	])
	timer_shape.color = Color("#0c1d31", 0.92)
	timer_shape.z_index = -1
	cl.add_child(timer_shape)
	timer_outline = Line2D.new()
	timer_outline.position = timer_shape.position
	timer_outline.points = timer_shape.polygon
	timer_outline.closed = true
	timer_outline.width = 2.0
	timer_outline.z_index = -1
	timer_outline.default_color = Color("#39d9f0", 0.92)
	cl.add_child(timer_outline)
	timer_lbl.size = Vector2(190, 58)
	timer_lbl.offset_left = -95
	timer_lbl.offset_right = 95
	timer_lbl.add_theme_font_size_override("font_size", 40)
	light_bar = _bar(Vector2.ZERO, Vector2(400, 18), Color(1.6, 1.4, 0.5), cl)
	light_bar.anchor_left = 0.5
	light_bar.anchor_right = 0.5
	light_bar.anchor_top = 1.0
	light_bar.anchor_bottom = 1.0
	light_bar.offset_left = -200
	light_bar.offset_right = 200
	light_bar.offset_top = -48
	light_bar.offset_bottom = -30
	dash_bar = _bar(Vector2.ZERO, Vector2(400, 7), Color(0.4, 1.6, 2.0), cl)
	dash_bar.anchor_left = 0.5
	dash_bar.anchor_right = 0.5
	dash_bar.anchor_top = 1.0
	dash_bar.anchor_bottom = 1.0
	dash_bar.offset_left = -200
	dash_bar.offset_right = 200
	dash_bar.offset_top = -39
	dash_bar.offset_bottom = -32
	ability_bar = _bar(Vector2.ZERO, Vector2(400, 7), Color(0.75, 0.45, 1.8), cl)
	ability_bar.anchor_left = 0.5
	ability_bar.anchor_right = 0.5
	ability_bar.anchor_top = 1.0
	ability_bar.anchor_bottom = 1.0
	ability_bar.offset_left = -200
	ability_bar.offset_right = 200
	ability_bar.offset_top = -26
	ability_bar.offset_bottom = -19
	capsule_ammo_lbl = _label("ВОЛНЫ  ◆ ◆ ◆ ◆", 16, Vector2(18, 0), Vector2(220, 24), cl)
	capsule_ammo_lbl.anchor_top = 1.0
	capsule_ammo_lbl.anchor_bottom = 1.0
	capsule_ammo_lbl.offset_top = -66
	capsule_ammo_lbl.offset_bottom = -42
	capsule_ammo_lbl.add_theme_color_override("font_color", Color("#75efff"))
	capsule_reload_bar = _bar(Vector2(18, 0), Vector2(180, 6), Color(0.25, 0.95, 1.0), cl)
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
	over_rect.mouse_filter = Control.MOUSE_FILTER_STOP
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
	over_lbl = _label("", 38, Vector2.ZERO, Vector2(720, 150), cl, true)
	over_lbl.add_theme_color_override("font_color", Color("#f0fbff"))
	over_lbl.visible = false
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
	over_restart_btn.visible = false
	over_menu_btn.visible = false


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
	for obstacle in view.get("ob", []):
		var center: Vector2 = obstacle[0]
		var radius: float = float(obstacle[1])
		var health: float = float(obstacle[2])
		var max_health: float = float(obstacle[3])
		var ratio := clampf(health / maxf(max_health, 1.0), 0.0, 1.0)
		var points := PackedVector2Array()
		for side in 9:
			var angle := TAU * float(side) / 9.0
			var uneven := radius * (0.88 + 0.12 * sin(float(side) * 7.1 + center.x))
			points.append(center + Vector2.from_angle(angle) * uneven)
		var rock_color := Color("#59616d").lerp(Color("#a65d45"), 1.0 - ratio)
		bullet_layer.draw_colored_polygon(points, rock_color)
		bullet_layer.draw_polyline(points, Color("#b9c6d4", 0.9), 3.0, true)
		bullet_layer.draw_line(center + Vector2(-radius * 0.35, -radius * 0.12), center + Vector2(radius * 0.1, radius * 0.3), Color("#343b48"), 3.0, true)
		bullet_layer.draw_line(center + Vector2(radius * 0.08, -radius * 0.32), center + Vector2(radius * 0.34, radius * 0.02), Color("#343b48"), 2.0, true)
		if ratio < 0.999:
			var bar_width := radius * 1.25
			var bar_y := center.y - radius - 13.0
			bullet_layer.draw_rect(Rect2(center.x - bar_width * 0.5, bar_y, bar_width, 5.0), Color("#202631"))
			bullet_layer.draw_rect(Rect2(center.x - bar_width * 0.5, bar_y, bar_width * ratio, 5.0), Color("#ffb45c"))
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
	cursor_canvas.size = Vector2(38, 38)
	cursor_canvas.z_index = 100
	cursor_canvas.draw.connect(_draw_aim_cursor)
	cursor_layer.add_child(cursor_canvas)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _draw_aim_cursor() -> void:
	if not is_instance_valid(cursor_canvas):
		return
	var center := Vector2(19, 19)
	var color := Color("#8df6ff")
	cursor_canvas.draw_arc(center, 10.0, 0.0, TAU, 32, Color(color, 0.9), 1.6, true)
	cursor_canvas.draw_line(Vector2(19, 1), Vector2(19, 8), color, 2.0, true)
	cursor_canvas.draw_line(Vector2(19, 30), Vector2(19, 37), color, 2.0, true)
	cursor_canvas.draw_line(Vector2(1, 19), Vector2(8, 19), color, 2.0, true)
	cursor_canvas.draw_line(Vector2(30, 19), Vector2(37, 19), color, 2.0, true)
	cursor_canvas.draw_circle(center, 2.0, Color.WHITE)


func _read_input() -> Dictionary:
	return {
		"mv": Input.get_vector("left", "right", "up", "down"),
		"aim": get_global_mouse_position(),
		"fire": Input.is_action_pressed("fire"),
		"dash": Input.is_action_pressed("dash"),
		"poss": Input.is_action_pressed("possess"),
		"ability": Input.is_action_just_pressed("ability"),
	}


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
		inp = {"mv": Vector2.ZERO, "aim": get_global_mouse_position(),
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
	var bullet_count: int = view.get("bl", []).size()
	if bullet_count > 0 or bullet_count != last_bullet_count:
		bullet_layer.queue_redraw()
	last_bullet_count = bullet_count
	if is_instance_valid(cursor_canvas):
		cursor_canvas.position = get_viewport().get_mouse_position() - cursor_canvas.size * 0.5
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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if pause_open else Input.MOUSE_MODE_HIDDEN
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
		local_ring.visible = (id == local_id and not shadow and not _is_potato())
		local_ring.width = 4.0 + 1.5 * (0.5 + 0.5 * sin(t * 5.0))
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
			var c := col if _is_potato() else G.hdr(col, 0.78 + 0.42 * lf)
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
			hc.a = 0.12 + 0.22 * lf
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
			if int(ed[3]) == 0:
				spr.polygon = PackedVector2Array([Vector2(-24,-15),Vector2(-10,-27),Vector2(16,-24),Vector2(29,-7),Vector2(20,19),Vector2(-8,25),Vector2(-27,8)])
				spr.color = Color("#b84b72")
			else:
				spr.polygon = PackedVector2Array([Vector2(0,-29),Vector2(22,-5),Vector2(17,20),Vector2(0,29),Vector2(-17,20),Vector2(-22,-5)])
				spr.color = Color("#8051b8")
			root.add_child(spr)
			ent_layer.add_child(root)
			ev = {"root": root, "spr": spr, "halo": halo, "pos": ed[1], "rot": 0.0}
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
		var base := 0.62 if ed[3] == 0 else 0.42
		spr.scale = Vector2.ONE * base * (1.0 + 0.09 * sin(t * 9.0 + id))
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
	var secs := maxi(0, int(view.get("tl", Sim.MATCH_TIME)))
	timer_lbl.text = "%d:%02d" % [secs / 60, secs % 60]
	timer_lbl.modulate = Color("#ff789b") if secs <= 30 else Color("#b8f8ff")
	# Chaos messes with the HUD clock (display only; the real match clock is untouched).
	if not over and Time.get_ticks_msec() < timer_glitch_until:
		var step := int(Time.get_ticks_msec() / 85)
		if step != glitch_step:
			glitch_step = step
			glitch_text = "%d:%02d" % [randi() % 9, randi() % 60]
		timer_lbl.text = glitch_text
		timer_lbl.modulate = Color("#ffd45c")
	if over:
		timer_lbl.text = "0:00"
	var rows: Array = []
	var me: Dictionary = {}
	for pd in view.get("pl", []):
		if pd.i == local_id:
			me = pd
		if not pd.d:
			rows.append(pd)
	# Leaderboard follows the actual match objective: chaos first, then remaining light.
	rows.sort_custom(func(a, b): return a.pt > b.pt if a.pt != b.pt else a.l > b.l)
	var txt := "[font_size=17][color=#74edff][b]◈  ТАБЛИЦА ХАОСА[/b][/color][/font_size]\n"
	txt += "[table=4]"
	txt += "[cell][color=#718ba5]#[/color][/cell]"
	txt += "[cell][color=#718ba5]ИГРОК[/color][/cell]"
	txt += "[cell][color=#718ba5]СОСТОЯНИЕ[/color][/cell]"
	txt += "[cell][color=#718ba5]ХАОС[/color][/cell]"
	for rank_i in rows.size():
		var pd: Dictionary = rows[rank_i]
		var hex: String = G.col(pd.c).to_html(false)
		var state_text := "ТЕНЬ" if pd.s else "%d HP" % int(pd.l)
		var display_name: String = str(pd.n) + (" [бот]" if bool(pd.get("bot", false)) else "")
		var rank_color := "#ffd76a" if rank_i == 0 else ("#b9c9dc" if rank_i == 1 else "#8c9db2")
		var chaos_color := "#ffbd58" if int(pd.pt) > 0 else "#91a4b9"
		var current_marker := "▶ " if pd.i == local_id else ""
		txt += "[cell][color=%s]%s%02d[/color][/cell]" % [rank_color, current_marker, rank_i + 1]
		txt += "[cell][color=#%s]%s[/color][/cell]" % [hex, display_name]
		txt += "[cell][color=#9aacc0]%s[/color][/cell]" % state_text
		txt += "[cell][color=%s][b]%d[/b][/color][/cell]" % [chaos_color, int(pd.pt)]
	txt += "[/table]"
	if txt != last_score_text:  # re-parsing BBCode every frame was needless work
		last_score_text = txt
		score_lbl.text = txt
	if not me.is_empty():
		light_bar.max_value = me.hpmax
		light_bar.value = me.l
		dash_bar.value = 100.0 * (1.0 - clampf(me.dc / Sim.DASH_CD, 0.0, 1.0))
		ability_bar.value = 100.0 * (1.0 - clampf(me.acd / 9.0, 0.0, 1.0))
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
			capsule_reload_bar.value = 100.0 * (1.0 - reload_left / 1.5) if ammo < 4 else 100.0
		var class_names := ["СВЕТЛЯК", "КАПСУЛА", "ПРИЗРАК", "КРИСТАЛЛ"]
		var ability_ready := "ГОТОВО" if me.acd <= 0.0 else "%.1fс" % me.acd
		help_lbl.text = "%s • Q: %s (%s)\nЦЕЛЬ: остаться последним светящимся.\nWASD — движение • ЛКМ — атака • ПРОБЕЛ — рывок • ESC — меню" % [class_names[int(me.k) % 4], ["Перегрузка", "Энергощит", "Фазовый скачок", "Звёздный залп"][int(me.k) % 4], ability_ready]
		if me.s:
			help_lbl.text = "ТЫ — ТЕНЬ: подойди к живому игроку и нажми ПКМ / E, чтобы вселиться.\nВселение длится 2 секунды — используй их, чтобы вернуться в игру."
	if over:
		over_rect.visible = true
		over_shape.visible = true
		over_outline.visible = true
		over_lbl.visible = true
		over_restart_btn.visible = not is_client
		over_menu_btn.visible = true
		var wn := "никто"
		for pd in view.get("pl", []):
			if pd.i == view.get("wn", 0):
				wn = pd.n
		over_lbl.text = "ПОБЕДИТЕЛЬ\n%s" % wn
		over_lbl.modulate = Color(1.1, 1.35, 1.65)
		_layout_game_over()
	else:
		over_rect.visible = false
		over_shape.visible = false
		over_outline.visible = false
		over_lbl.visible = false
		over_restart_btn.visible = false
		over_menu_btn.visible = false


# -------------------------------------------------------------- эффекты ---
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
	var panel_size := Vector2(minf(760.0, vp.x - 48.0), 330.0)
	var pos := (vp - panel_size) * 0.5
	var cut := 22.0
	var points := PackedVector2Array([
		Vector2(pos.x + cut, pos.y), Vector2(pos.x + panel_size.x - cut, pos.y),
		Vector2(pos.x + panel_size.x, pos.y + cut), Vector2(pos.x + panel_size.x, pos.y + panel_size.y - cut),
		Vector2(pos.x + panel_size.x - cut, pos.y + panel_size.y), Vector2(pos.x + cut, pos.y + panel_size.y),
		Vector2(pos.x, pos.y + panel_size.y - cut), Vector2(pos.x, pos.y + cut)
	])
	over_shape.polygon = points
	over_outline.points = points
	over_lbl.position = Vector2(pos.x + 20.0, pos.y + 48.0)
	over_lbl.size = Vector2(panel_size.x - 40.0, 145.0)
	over_lbl.add_theme_font_size_override("font_size", 38)
	var buttons_y := pos.y + panel_size.y - 82.0
	over_restart_btn.position = Vector2(pos.x + panel_size.x * 0.5 - 222.0, buttons_y)
	over_menu_btn.position = Vector2(pos.x + panel_size.x * 0.5 + 12.0, buttons_y)


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
