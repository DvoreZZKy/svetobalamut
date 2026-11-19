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
var hitstop := 0.0
var shake := 0.0
var t := 0.0

var pviews := {}
var eviews := {}
var cis := {}

var cam: Camera2D
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
var invert_cur := 0.0
var blind_cur := 0.0

var timer_lbl: Label
var banner: Label
var score_lbl: RichTextLabel
var help_lbl: Label
var light_bar: ProgressBar
var dash_bar: ProgressBar
var over_rect: ColorRect
var over_lbl: Label
var wait_lbl: Label
var objective_lbl: Label


func _ready() -> void:
	is_client = G.mode == "client"
	local_id = multiplayer.get_unique_id() if G.mode != "single" else 1
	var arena_env := G.make_env()
	arena_env.environment.glow_enabled = false
	add_child(arena_env)
	cam = Camera2D.new()
	cam.position = ARENA / 2.0
	cam.zoom = Vector2(0.78, 0.78)
	add_child(cam)
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
	if is_client:
		Net.disconnected.connect(_to_menu)
	else:
		sim = Sim.new()
		sim.reset(G.cfg)
		Net.peer_left.connect(_on_peer_left)
		view = sim.snapshot()
	Sfx.play_music()


func _on_peer_left(id: int) -> void:
	if sim and sim.players.has(id):
		sim.players[id].human = false
	Net.inputs.erase(id)


func _to_menu() -> void:
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
	timer_lbl = _label("4:00", 46, Vector2(540, 10), Vector2(200, 56), cl, true)
	timer_lbl.modulate = Color(0.6, 1.8, 2.2)
	banner = _label("", 70, Vector2(0, 190), Vector2(1280, 100), cl, true)
	banner.pivot_offset = Vector2(640, 50)
	banner.modulate.a = 0.0
	score_lbl = RichTextLabel.new()
	score_lbl.bbcode_enabled = true
	score_lbl.fit_content = true
	score_lbl.scroll_active = false
	score_lbl.position = Vector2(16, 12)
	score_lbl.size = Vector2(340, 300)
	score_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_lbl.add_theme_font_size_override("normal_font_size", 17)
	cl.add_child(score_lbl)
	help_lbl = _label("", 15, Vector2(850, 12), Vector2(420, 92), cl)
	help_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_lbl.add_theme_font_size_override("font_size", 13)
	help_lbl.modulate = Color(0.7, 0.8, 1.0, 0.75)
	light_bar = _bar(Vector2(440, 672), Vector2(400, 18), Color(1.6, 1.4, 0.5), cl)
	dash_bar = _bar(Vector2(440, 696), Vector2(400, 7), Color(0.4, 1.6, 2.0), cl)
	wait_lbl = _label("Ждём хоста…", 30, Vector2(0, 330), Vector2(1280, 60), cl, true)
	wait_lbl.visible = is_client
	over_rect = ColorRect.new()
	over_rect.color = Color(0, 0, 0, 0.72)
	over_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	over_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over_rect.visible = false
	cl.add_child(over_rect)
	over_lbl = _label("", 44, Vector2(0, 220), Vector2(1280, 300), over_rect, true)


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
		draw_circle(c, z.z, Color(0, 0, 0, 0.6))
		draw_arc(c, z.z, 0.0, TAU, 72, Color(0.28, 0.16, 0.52, 0.42), 3.0, true)
		draw_arc(c, z.z * 0.6, 0.0, TAU, 48, Color(0.22, 0.12, 0.42, 0.22), 2.0, true)
	draw_rect(Rect2(Vector2.ZERO, ARENA), Color(0.48, 0.2, 0.72), false, 3.0)


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
		bullet_layer.draw_line(tail, pos, G.hdr(col, 3.5), width * 0.45, true)
		bullet_layer.draw_circle(pos, 6.0, Color(4, 4, 4))


# ----------------------------------------------------------------- цикл ---
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
	t += dt
	var inp := _read_input()
	if not is_client:
		sim.inputs[local_id] = inp
		for pid in Net.inputs:
			sim.inputs[pid] = Net.inputs[pid]
		if hitstop > 0.0:
			hitstop -= dt
		else:
			sim.step(minf(dt, 0.05))
			if sim.hitstop_req > 0.0:
				hitstop = sim.hitstop_req
				sim.hitstop_req = 0.0
		sim.shake_req = 0.0
		view = sim.snapshot()
		var ev: Array = sim.events
		sim.events = []
		_handle_events(ev)
		net_ev.append_array(ev)
		snap_timer -= dt
		if Net.online and snap_timer <= 0.0:
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
	if Input.is_action_just_pressed("ui_cancel"):
		_to_menu()
		return
	if not view.is_empty():
		_update_views(dt)
		_update_fx(dt)
		_update_hud(dt)
	bullet_layer.queue_redraw()
	shake = maxf(0.0, shake - (shake * 8.0 + 25.0) * dt)
	var s: float = shake if G.shake_on else 0.0
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * s
	cam.rotation = randf_range(-1, 1) * s * 0.0006


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
	var outfit := Polygon2D.new()
	outfit.z_index = 2
	var outfit_shapes := [
		PackedVector2Array(),
		PackedVector2Array([Vector2(-13, -5), Vector2(13, -5), Vector2(10, 12), Vector2(-10, 12)]),
		PackedVector2Array([Vector2(-16, -7), Vector2(16, -7), Vector2(8, 5), Vector2(12, 14), Vector2(-12, 14), Vector2(-8, 5)]),
		PackedVector2Array([Vector2(-13, -7), Vector2(13, -7), Vector2(7, 13), Vector2(-7, 13)]),
		PackedVector2Array([Vector2(-11, -5), Vector2(11, -5), Vector2(17, 17), Vector2(-17, 17)])
	]
	
	
	var local_ring := Line2D.new()
	local_ring.width = 5.0
	local_ring.default_color = Color(0.25, 0.95, 1.0, 0.95)
	local_ring.closed = true
	for i in 32:
		local_ring.add_point(Vector2.from_angle(TAU * float(i) / 32.0) * 49.0)
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
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
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
		pv.ci = pd.c
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
		var actor: Node2D = pv.actor
		var halo: Sprite2D = pv.halo
		var local_ring: Line2D = pv.local_ring
		actor.setup(int(pd.k), G.col(int(pd.c)), int(pd.get("outfit", 0)), int(pd.get("hat", 0)))
		var lbl: Label = pv.lbl
		root.visible = vis
		local_ring.visible = (id == local_id and not shadow)
		local_ring.width = 4.0 + 1.5 * (0.5 + 0.5 * sin(t * 5.0))
		line.visible = vis
		root.position = pv.pos
		if pv.kind != pd.k:
			pv.kind = pd.k
		pv.rot = lerp_angle(pv.rot, (pd.a as Vector2).angle(), minf(1.0, 30.0 * dt))
		actor.rotation = pv.rot
		pv.kick = maxf(0.0, pv.kick - dt * 7.0)
		var pulse := 1.0 + 0.07 * sin(t * 11.0 + id)
		actor.scale = Vector2.ONE * (0.92 + 0.18 * lf) * pulse * (1.0 + pv.kick * 0.35)
		halo.scale = Vector2.ONE * (0.9 + 1.8 * lf)
		if shadow:
			actor.modulate = Color(0.65, 0.45, 0.95, 0.9)
			halo.modulate = Color(0.5, 0.15, 1.2, 0.5)
			actor.scale = Vector2.ONE * 0.5
		else:
			var c := G.hdr(col, 0.9 + 1.5 * lf)
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
			var hc := G.hdr(col, 0.3 + 1.3 * lf)
			hc.a = 0.25 + 0.65 * lf
			halo.modulate = hc
		lbl.visible = vis and not shadow
		var nm: String = pd.n
		if pd.d:
			nm = ci_name.get(pd.c, "?")
		lbl.text = ("> " + nm) if id == local_id else nm
		if bomb_id == id:
			lbl.text = "БОМБА %.1f" % maxf(bomb_t, 0.0)
		lbl.modulate = Color(1, 1, 1, 0.85)
		# трейл
		var moving: bool = vel.length() > 60.0 or pd.dt
		if moving:
			line.add_point(pv.pos)
			var maxp := 40 if pd.dt else 26
			while line.get_point_count() > maxp:
				line.remove_point(0)
		elif line.get_point_count() > 0:
			line.remove_point(0)
		var sm: ShaderMaterial = pv.mat
		sm.set_shader_parameter("tint", Color(0.6, 0.2, 1.0) if shadow else col)
		sm.set_shader_parameter("hdr", 5.0 if pd.dt else 2.2 + 1.6 * lf)
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
		var spr: Sprite2D = ev.spr
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
	var over: bool = view.get("ph", "play") == "over"
	var secs := maxi(0, int(view.get("tl", Sim.MATCH_TIME)))
	timer_lbl.text = "%d:%02d" % [secs / 60, secs % 60]
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
		txt += "[color=#%s]%s%s[/color]  %s  [color=#8890aa]хаос %d[/color]\n" % [hex, "> " if pd.i == local_id else "", pd.n, st, pd.pt]
	score_lbl.text = txt
	if not me.is_empty():
		light_bar.max_value = me.hpmax
		light_bar.value = me.l
		dash_bar.value = 100.0 * (1.0 - clampf(me.dc / Sim.DASH_CD, 0.0, 1.0))
		var class_names := ["СВЕТЛЯК", "КАПСУЛА", "ПРИЗРАК", "КРИСТАЛЛ"]
		var ability_ready := "ГОТОВО" if me.acd <= 0.0 else "%.1fс" % me.acd
		help_lbl.text = "%s • Q: %s (%s)\nЦЕЛЬ: остаться последним светящимся.\nWASD — движение • ЛКМ — атака • ПРОБЕЛ — рывок • ESC — меню" % [class_names[int(me.k) % 4], ["Перегрузка", "Энергощит", "Фазовый скачок", "Звёздный залп"][int(me.k) % 4], ability_ready]
		if me.s:
			help_lbl.text = "ТЫ — ТЕНЬ: подойди к живому игроку и нажми ПКМ / E, чтобы вселиться.\nВселение длится 2 секунды — используй их, чтобы вернуться в игру."
	if over:
		over_rect.visible = true
		var wn := "никто"
		for pd in view.get("pl", []):
			if pd.i == view.get("wn", 0):
				wn = pd.n
		var tail := "ENTER — реванш   •   ESC — в меню" if not is_client else "Ждём реванш от хоста   •   ESC — в меню"
		over_lbl.text = "ПОБЕДИЛ(А): %s\n\n%s" % [wn, tail]
		over_lbl.modulate = Color(1.6, 1.6, 1.0)
	else:
		over_rect.visible = false


# -------------------------------------------------------------- эффекты ---
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
	var p := CPUParticles2D.new()
	p.position = pos
	p.texture = halo_tex
	p.material = add_mat
	p.amount = amount
	p.lifetime = life
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
	get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)


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
