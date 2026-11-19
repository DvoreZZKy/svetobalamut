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

var timer_lbl: Label
var timer_shape: Polygon2D
var timer_outline: Line2D
var ability_bar: ProgressBar
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


func _ready() -> void:
	is_client = G.mode == "client"
	local_id = multiplayer.get_unique_id() if G.mode != "single" else 1
	var arena_env := G.make_env()
	arena_env.environment.glow_enabled = true
	arena_env.environment.glow_intensity = 0.62
	arena_env.environment.glow_strength = 0.72
	arena_env.environment.glow_bloom = 0.08
	for glow_level in range(1, 7):
		arena_env.environment.set_glow_level(glow_level, 0.10 if glow_level <= 3 else 0.0)
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
		sim.reset(G.cfg)
		Net.peer_left.connect(_on_peer_left)
		view = sim.snapshot()
	if G.tutorial_active:
		var tutorial_controller := ArenaTutorial.new()
		add_child(tutorial_controller)
	Sfx.play_music()


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
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.35))
	halo_tex = GradientTexture2D.new()
	halo_tex.gradient = g
	halo_tex.fill = GradientTexture2D.FILL_RADIAL
	halo_tex.fill_from = Vector2(0.5, 0.5)
	halo_tex.fill_to = Vector2(1.0, 0.5)
	halo_tex.width = 128
	halo_tex.height = 128
	add_mat = CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
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
	score_lbl.size = Vector2(330, 340)
	score_lbl.clip_contents = true
	score_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_lbl.add_theme_font_size_override("normal_font_size", 17)
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
	for i in 22:
		ambient_motes.append({
			"p": Vector2(rng.randf_range(35.0, ARENA.x - 35.0), rng.randf_range(35.0, ARENA.y - 35.0)),
			"v": Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(7.0, 20.0),
			"r": rng.randf_range(2.0, 4.5),
			"phase": rng.randf_range(0.0, TAU),
			"tone": i % 3
		})


func _update_ambient(dt: float) -> void:
	if dt <= 0.0:
		return
	for mote in ambient_motes:
		mote.p += mote.v * dt
		if mote.p.x < 20.0 or mote.p.x > ARENA.x - 20.0:
			mote.v.x *= -1.0
		if mote.p.y < 20.0 or mote.p.y > ARENA.y - 20.0:
			mote.v.y *= -1.0
	ambient_layer.queue_redraw()


func _draw_ambient() -> void:
	var palette := [Color("#39dff5"), Color("#a77bff"), Color("#62f5d0")]
	for mote in ambient_motes:
		var p: Vector2 = mote.p
		var r: float = mote.r
		var pulse := 0.45 + 0.35 * sin(t * 1.7 + float(mote.phase))
		var color: Color = palette[int(mote.tone)]
		var points := PackedVector2Array([
			p + Vector2(0, -r * 2.0), p + Vector2(r, 0),
			p + Vector2(0, r * 2.0), p + Vector2(-r, 0)
		])
		ambient_layer.draw_colored_polygon(points, Color(color, pulse * 0.32))
		ambient_layer.draw_line(p + Vector2(-r * 3.0, 0), p + Vector2(r * 3.0, 0), Color(color, pulse * 0.22), 1.0, true)
		ambient_layer.draw_line(p + Vector2(0, -r * 3.0), p + Vector2(0, r * 3.0), Color(color, pulse * 0.22), 1.0, true)


func _draw_bullets() -> void:
	for b in view.get("bl", []):
		var vel: Vector2 = b[2]
		var pos: Vector2 = b[1] + vel * snap_age
		var col: Color = G.col(cis.get(b[3], 0))
		if b[4] > 0:
			col = Color(1, 1, 1)
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
		if Net.online and not G.tutorial_active and snap_timer <= 0.0:
			snap_timer = 0.05
			view["ev"] = net_ev
			net_ev = []
			Net.broadcast_snap(view)
			view.erase("ev")
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
			_handle_events(view.get("ev", []))
		else:
			snap_age = minf(snap_age + dt, 0.12)
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
	var sm := ShaderMaterial.new()
	sm.shader = trail_shader
	line.material = sm
	trail_layer.add_child(line)
	return {"root": root, "halo": halo, "actor": actor, "lbl": lbl, "line": line, "mat": sm,
		"local_ring": local_ring, "pos": pd.p, "rot": (pd.a as Vector2).angle(),
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
		var lf: float = pd.l / 100.0
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
		local_ring.visible = (id == local_id and not shadow)
		local_ring.width = 4.0 + 1.5 * (0.5 + 0.5 * sin(t * 5.0))
		line.visible = vis
		root.position = pv.pos
		pv.rot = lerp_angle(pv.rot, (pd.a as Vector2).angle(), minf(1.0, 30.0 * dt))
		actor.rotation = pv.rot
		pv.kick = maxf(0.0, pv.kick - dt * 7.0)
		var pulse := 1.0 + 0.07 * sin(t * 11.0 + id)
		actor.scale = Vector2.ONE * (0.92 + 0.18 * lf) * pulse * (1.0 + pv.kick * 0.35)
		halo.scale = Vector2.ONE * (0.55 + 0.75 * lf)
		if shadow:
			var ghost_alpha := 0.66 + 0.10 * sin(t * 3.6 + float(id))
			actor.modulate = Color(0.20, 0.11, 0.38, ghost_alpha)
			halo.modulate = Color(0.48, 0.12, 1.35, 0.42 + 0.10 * sin(t * 2.8 + float(id)))
			actor.scale = Vector2.ONE * 0.62 * (1.0 + 0.025 * sin(t * 4.0 + float(id)))
		else:
			var c := G.hdr(col, 0.78 + 0.42 * lf)
			if pd.h > 0.0:
				c = Color(3.2, 3.2, 3.2)
			if pd.iv > 0.0:
				c.a = 0.45 + 0.4 * sin(t * 70.0)
			if bomb_id == id:
				c = Color(3.4, 0.5, 0.3) if sin(t * (9.0 + (4.0 - bomb_t) * 7.0)) > 0.0 else Color(3.4, 3.4, 3.4)
			if pd.dr > 0.0:
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
		root.position = ev.pos
		if vel.length() > 5.0:
			ev.rot = lerp_angle(ev.rot, vel.angle(), minf(1.0, 12.0 * dt))
		spr.rotation = ev.rot
		var base := 0.62 if ed[3] == 0 else 0.42
		spr.scale = Vector2.ONE * base * (1.0 + 0.09 * sin(t * 9.0 + id))
		var c := Color(1.15, 0.35, 0.62) if ed[3] == 0 else Color(0.62, 0.38, 1.1)
		if ed[5] > 0.0:
			c = Color(3, 3, 3)
		spr.modulate = c
		halo.scale = Vector2.ONE * (1.3 if ed[3] == 0 else 0.9)
		halo.modulate = Color(c.r * 0.5, c.g * 0.3, c.b * 0.5, 0.45)
	for id in eviews.keys():
		if not seen.has(id):
			eviews[id].root.queue_free()
			eviews.erase(id)


func _update_fx(dt: float) -> void:
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
	if over:
		timer_lbl.text = "0:00"
	var rows: Array = []
	var me: Dictionary = {}
	for pd in view.get("pl", []):
		if pd.i == local_id:
			me = pd
		if not pd.d:
			rows.append(pd)
	rows.sort_custom(func(a, b): return a.l > b.l if a.l != b.l else a.pt > b.pt)
	var txt := ""
	for pd in rows:
		var hex: String = G.col(pd.c).to_html(false)
		var st := "ТЕНЬ" if pd.s else str(int(pd.l))
		var display_name: String = str(pd.n) + (" (бот)" if bool(pd.get("bot", false)) else "")
		txt += "[color=#%s]%s%s[/color]  %s  [color=#8890aa]хаос %d[/color]\n" % [hex, "> " if pd.i == local_id else "", display_name, st, pd.pt]
	score_lbl.text = txt
	if not me.is_empty():
		light_bar.max_value = me.hpmax
		light_bar.value = me.l
		dash_bar.value = 100.0 * (1.0 - clampf(me.dc / Sim.DASH_CD, 0.0, 1.0))
		ability_bar.value = 100.0 * (1.0 - clampf(me.acd / 9.0, 0.0, 1.0))
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
				burst(pos, col, 46, 640.0, 0.85)
				flash(pos, 220.0, col, 0.5)
				shake = maxf(shake, 20.0 if e.get("id", 0) != local_id else 34.0)
			"dash":
				Sfx.play("dash", 1.0, -4.0)
				burst(pos, col, 8, 300.0, 0.25)
			"possess":
				Sfx.play("possess")
				burst(pos, Color(0.8, 0.25, 1.0), 34, 280.0, 0.9)
				flash(pos, 150.0, Color(0.8, 0.25, 1.0), 0.6)
			"eat":
				Sfx.play("eat")
				burst(pos, Color(1.0, 0.2, 0.45), 16, 360.0, 0.45)
			"boom":
				Sfx.play("boom")
				flash(pos, float(e.get("r", 260.0)) * 1.3, Color(1.0, 0.85, 0.4), 0.55)
				burst(pos, Color(1.0, 0.6, 0.2), 90, 900.0, 0.9)
				shake = maxf(shake, 48.0)
			"chaos":
				Sfx.play("chaos")
				shake = maxf(shake, 26.0)
				_show_banner(CHAOS_RU.get(e.n, str(e.n)).to_upper())
				var tw := create_tween()
				tw.tween_method(func(v: float): fx_mat.set_shader_parameter("aberr", v), 0.03, 0.0, 0.55)
			"ability":
				Sfx.play("dash", 1.0, -2.0)
				var ability_color: Color = [Color(0.2, 0.9, 1.0), Color(1.0, 0.75, 0.25), Color(0.65, 0.3, 1.0), Color(0.4, 0.9, 1.0)][int(e.get("kind", 0)) % 4]
				flash(pos, 190.0, ability_color, 0.45)
				burst(pos, ability_color, 28 if int(e.get("kind", 0)) != 3 else 52, 520.0, 0.55)
			"win":
				Sfx.play("win")


func burst(pos: Vector2, col: Color, amount: int, speed: float, life: float) -> void:
	# Keep event bursts lightweight: many overlapping CPU particle systems were a major frame-time spike.
	var active_bursts := 0
	for child in fx_layer.get_children():
		if child is CPUParticles2D:
			active_bursts += 1
	if active_bursts >= 10:
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.texture = halo_tex
	p.material = add_mat
	p.amount = mini(amount, 30)
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
