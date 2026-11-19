extends Node2D
## TRIBE: отдельная пещерная сессия. Вся экономика и прогресс существуют только в памяти матча.

const ACTOR = preload("res://scripts/vector_actor.gd")

class TribeMap extends Control:
	const MAP_WORLD := Vector2(2600.0, 1640.0)
	var explored_cells := {}
	var player_pos := Vector2.ZERO
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color("#040a13",0.94),true)
		draw_rect(Rect2(Vector2.ZERO,size),Color("#4edff4"),false,2.0)
		for key in explored_cells:
			var pos := Vector2((float(key.x)+0.5)/29.0*size.x,(float(key.y)+0.5)/19.0*size.y)
			draw_rect(Rect2(pos-Vector2(3,3),Vector2(6,6)),Color("#3a7586",0.8),true)
		
		draw_circle(player_pos/MAP_WORLD*size,4,Color.WHITE)
const WORLD := Vector2(2600.0, 1640.0)
const GOLD_RESPAWN_SECONDS := 180.0
const ORE_DATA := {
	"neon": {"name":"НЕОНОВЫЙ КРИСТАЛЛ","color":Color("#42eaff"),"xp":18,"money":8,"age":1,"time":1.0},
	"ice": {"name":"ЛЕДЯНАЯ РУДА","color":Color("#8bcfff"),"xp":26,"money":13,"age":2,"time":1.8},
	"magma": {"name":"МАГМА-РУДА","color":Color("#ff7044"),"xp":38,"money":28,"age":3,"time":2.4},
	"void": {"name":"ПУСТОТНЫЙ КРИСТАЛЛ","color":Color("#bd78ff"),"xp":75,"money":90,"age":6,"time":3.2},
	"gold": {"name":"ЗОЛОТАЯ ЖИЛА","color":Color("#ffe36a"),"xp":110,"money":180,"age":1,"time":4.0}
}
const FOOD_DATA := {
	"mushroom":{"name":"СВЕТЯЩИЙСЯ ГРИБ","heal":22,"color":Color("#7af5c8")},
	"fish":{"name":"НЕОНОВАЯ РЫБА","heal":38,"color":Color("#55cfff")},
	"meat":{"name":"МЯСО ПОЖИРАТЕЛЯ","heal":55,"color":Color("#ff9b78")}
}
const ZONES := [
	{"name":"ВЕРХНИЕ ГАЛЕРЕИ","center":Vector2(420,420),"radius":330,"depth":0},
	{"name":"МАГМАТИЧЕСКИЙ РАЗЛОМ","center":Vector2(1280,800),"radius":430,"depth":1},
	{"name":"ПУСТОТНАЯ БЕЗДНА","center":Vector2(2180,1240),"radius":340,"depth":2}
]

var players: Dictionary = {}
var ores: Array[Dictionary] = []
var foods: Array[Dictionary] = []
var devourers: Array[Dictionary] = []
var explored := {}
var local_id := 1
var host_authority := true
var elapsed := 0.0
var gold_timer := 0.0
var mine_target := -1
var mine_progress := 0.0
var attack_cd := 0.0
var hud_layer: CanvasLayer
var age_label: Label
var status_label: Label
var resource_label: Label
var health_bar: ProgressBar
var mine_bar: ProgressBar
var inventory_label: Label
var hint_label: Label
var map_widget: Control
var actor_nodes := {}
var cam: Camera2D
var rng := RandomNumberGenerator.new()
var send_timer := 0.0
var last_snapshot_seq := -1


func _ready() -> void:
	rng.randomize()
	local_id = multiplayer.get_unique_id() if G.mode != "single" else 1
	host_authority = G.mode != "client"
	var env := G.make_env()
	env.environment.glow_intensity = 0.82
	env.environment.glow_strength = 0.9
	env.environment.glow_bloom = 0.12
	add_child(env)
	cam = Camera2D.new()
	cam.zoom = Vector2(0.78, 0.78)
	add_child(cam)
	_seed_world()
	if host_authority:
		_create_players()
	else:
		players.clear()
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play_tribe_music()
	queue_redraw()


func _seed_world() -> void:
	var placements := [
		["neon",Vector2(250,260)],["neon",Vector2(510,520)],["neon",Vector2(680,260)],
		["neon",Vector2(900,680)],["ice",Vector2(1030,720)],["ice",Vector2(1450,610)],
		["magma",Vector2(1230,930)],["magma",Vector2(1510,1020)],["void",Vector2(2130,1280)],
		["void",Vector2(2350,1410)]
	]
	for item in placements:
		ores.append({"kind":item[0],"pos":item[1],"hp":float(ORE_DATA[item[0]].time),"max_hp":float(ORE_DATA[item[0]].time)})
	for i in 10:
		foods.append({"kind":"mushroom" if i % 3 != 0 else "fish","pos":Vector2(rng.randf_range(160,2450),rng.randf_range(160,1480)),"active":true})
	for i in 4:
		devourers.append({"pos":Vector2(1180 + i*75,820 + (i%2)*80),"hp":70.0,"cooldown":0.0,"target":0})


func _create_players() -> void:
	players.clear()
	var configs: Array = G.cfg if not G.cfg.is_empty() else [{"id":1,"name":G.player_name,"human":true,"color":G.profile_color,"kind":G.profile_kind,"outfit":G.profile_outfit,"hat":G.profile_hat}]
	for i in configs.size():
		var c: Dictionary = configs[i]
		var pos := Vector2(300.0 + float(i % 4) * 70.0, 360.0 + float(i / 4) * 70.0)
		players[int(c.id)] = _new_player(c,pos)


func _new_player(c: Dictionary, pos: Vector2) -> Dictionary:
	return {"id":int(c.get("id",1)),"name":str(c.get("name","Путник")),"human":bool(c.get("human",false)),
		"kind":int(c.get("kind",0)),"color":int(c.get("color",0)),"outfit":int(c.get("outfit",0)),"hat":int(c.get("hat",0)),
		"pos":pos,"hp":100.0,"max_hp":100.0,"age":1,"xp":0.0,"money":0,"ore":0,"food":{"mushroom":0,"fish":0,"meat":0},
		"weapon":0,"attack_cd":0.0,"mine_cd":0.0,"slow":0.0,"alive":true}


func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 12
	add_child(hud_layer)
	var top := PanelContainer.new()
	top.position = Vector2(18,16)
	top.custom_minimum_size = Vector2(410,150)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#071421",0.9)
	style.border_color = Color("#39dff4",0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	top.add_theme_stylebox_override("panel",style)
	hud_layer.add_child(top)
	var col := VBoxContainer.new()
	top.add_child(col)
	age_label = _hud_label("AGE 01  •  0 / 100",25,Color("#8befff"))
	col.add_child(age_label)
	resource_label = _hud_label("Кристаллы 0   •   0 ¢",17,Color("#e4f7ff"))
	col.add_child(resource_label)
	health_bar = ProgressBar.new()
	health_bar.max_value = 100
	health_bar.value = 100
	health_bar.custom_minimum_size = Vector2(370,16)
	health_bar.show_percentage = false
	col.add_child(health_bar)
	inventory_label = _hud_label("ЕДА  •  Грибы 0 [F]",16,Color("#9fffd9"))
	col.add_child(inventory_label)
	status_label = _hud_label("E — добывать   •   WASD — движение",16,Color("#a9bdd1"))
	status_label.position = Vector2(20,176)
	hud_layer.add_child(status_label)
	mine_bar = ProgressBar.new()
	mine_bar.position = Vector2(450,650)
	mine_bar.size = Vector2(380,18)
	mine_bar.max_value = 1
	mine_bar.show_percentage = false
	mine_bar.visible = false
	hud_layer.add_child(mine_bar)
	hint_label = _hud_label("AGE 2: КЛИНОК   •   ЛКМ — удар   •   F — съесть еду",16,Color("#bba1ff"))
	hint_label.anchor_left = 0.5
	hint_label.anchor_right = 0.5
	hint_label.offset_left = -330
	hint_label.offset_right = 330
	hint_label.offset_top = -42
	hint_label.offset_bottom = -12
	hint_label.anchor_top = 1
	hint_label.anchor_bottom = 1
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_layer.add_child(hint_label)
	map_widget = TribeMap.new()
	map_widget.position = Vector2(1040,18)
	map_widget.size = Vector2(220,150)
	map_widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(map_widget)


func _hud_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	return label


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _process(dt: float) -> void:
	if G.mode == "client":
		var input_data := _read_input()
		Net.send_tribe_input(input_data)
		if Net.snap_seq != last_snapshot_seq:
			last_snapshot_seq = Net.snap_seq
			if not Net.latest_snap.is_empty() and Net.latest_snap.has("tribe_players"):
				players = Net.latest_snap.tribe_players
				ores = Net.latest_snap.tribe_ores
				foods = Net.latest_snap.tribe_foods
	else:
		var local_input := _read_input()
		if G.mode == "host":
			for peer_id in Net.tribe_inputs:
				if players.has(int(peer_id)):
					players[int(peer_id)]["input"] = Net.tribe_inputs[peer_id]
		if players.has(local_id):
			players[local_id]["input"] = local_input
		_simulate(dt)
		if G.mode == "host":
			send_timer += dt
			if send_timer >= 0.05:
				send_timer = 0.0
				Net.broadcast_tribe_snapshot({"tribe_players":players,"tribe_ores":ores,"tribe_foods":foods})
	_update_visuals(dt)
	_update_hud()
	queue_redraw()


func _read_input() -> Dictionary:
	var move := Vector2(Input.get_axis("left","right"),Input.get_axis("up","down")).normalized()
	var aim := (get_global_mouse_position() - (players[local_id].pos if players.has(local_id) else Vector2(300,360))).normalized()
	return {"move":move,"aim":aim,"mine":Input.is_action_pressed("interact"),"attack":Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),"eat":Input.is_action_just_pressed("eat")}


func _simulate(dt: float) -> void:
	elapsed += dt
	gold_timer += dt
	if gold_timer >= GOLD_RESPAWN_SECONDS:
		gold_timer = 0.0
		var gold := {"kind":"gold","pos":Vector2(rng.randf_range(1650,2380),rng.randf_range(950,1450)),"hp":4.0,"max_hp":4.0}
		 ores.append(gold)
	for id in players:
		var p: Dictionary = players[id]
		if not p.alive:
			continue
		var input_data: Dictionary = p.get("input",{})
		var move: Vector2 = input_data.get("move",Vector2.ZERO)
		if not bool(p.human):
			move = _bot_move(p)
			input_data = _bot_input(p, move)
		p.pos += move * (300.0 if float(p.slow) <= 0.0 else 185.0) * dt
		p.pos.x = clampf(p.pos.x,90,WORLD.x-90)
		p.pos.y = clampf(p.pos.y,90,WORLD.y-90)
		p.attack_cd = maxf(0.0,float(p.attack_cd)-dt)
		p.slow = maxf(0.0,float(p.slow)-dt)
		var grid := Vector2i(int(p.pos.x/90),int(p.pos.y/90))
		explored[grid] = true
		if bool(input_data.get("mine",false)):
			_mine_nearest(p,dt)
		else:
			p.mine_target = -1
			p.mine_progress = 0.0
		if bool(input_data.get("eat",false)):
			_eat(p)
		if bool(input_data.get("attack",false)) and p.age >= 2 and p.attack_cd <= 0.0:
			p.attack_cd = 0.65
			_attack(p,input_data.get("aim",Vector2.RIGHT))
	_update_devourers(dt)
	for p in players.values():
		if p.hp <= 0.0:
			_respawn(p)
			if G.mode == "host":
				Net.tribe_inputs.erase(p.id)


func _bot_move(p: Dictionary) -> Vector2:
	var nearest := Vector2(300,360)
	var best := 1e20
	for ore in ores:
		if int(p.age) < int(ORE_DATA[ore.kind].age):
			continue
		var d: float = p.pos.distance_squared_to(ore.pos)
		if d < best:
			best = d
			nearest = ore.pos
	return p.pos.direction_to(nearest) if best < 1e20 else Vector2.ZERO


func _bot_input(p: Dictionary, move: Vector2) -> Dictionary:
	var target := -1
	var best := 82.0 * 82.0
	for i in ores.size():
		var ore: Dictionary = ores[i]
		if int(p.age) < int(ORE_DATA[ore.kind].age):
			continue
		var d: float = p.pos.distance_squared_to(ore.pos)
		if d < best:
			best = d
			target = i
	var attack := false
	for other in players.values():
		if int(other.id) != int(p.id) and bool(other.alive) and p.pos.distance_to(other.pos) < 82.0:
			attack = int(p.age) >= 2
	return {"move":move,"mine":target >= 0 and best < 76.0 * 76.0,"attack":attack,"aim":move if move.length_squared() > 0.01 else Vector2.RIGHT,"eat":p.hp < p.max_hp * 0.55}


func _mine_nearest(p: Dictionary, dt: float) -> void:
	var best := -1
	var best_dist := 82.0 * 82.0
	for i in ores.size():
		var ore: Dictionary = ores[i]
		if int(p.age) < int(ORE_DATA[ore.kind].age):
			continue
		var d: float = p.pos.distance_squared_to(ore.pos)
		if d < best_dist:
			best_dist = d
			best = i
	for i in foods.size():
		var food: Dictionary = foods[i]
		if not food.active:
			continue
		var d: float = p.pos.distance_squared_to(food.pos)
		if d < best_dist:
			best_dist = d
			best = ores.size() + i
	if best < 0:
		p.mine_target = -1
		p.mine_progress = 0.0
		return
	if int(p.get("mine_target",-1)) != best:
		p.mine_target = best
		p.mine_progress = 0.0
	var duration := 1.2
	if best < ores.size():
		duration = float(ORE_DATA[ores[best].kind].time)
		if ores[best].kind == "ice":
			p.slow = maxf(float(p.slow),0.25)
	else:
		duration = 1.1
	p.mine_progress = float(p.get("mine_progress",0.0)) + dt
	if p.mine_progress >= duration:
		if best < ores.size():
			var ore: Dictionary = ores[best]
			var data: Dictionary = ORE_DATA[ore.kind]
			p.xp += float(data.xp)
			p.money += int(data.money)
			p.ore += 1
			if ore.kind == "magma":
				p.hp -= 12.0
				Sfx.play("boom",0.8,-8.0)
			elif ore.kind == "void":
				p.weapon = maxi(p.weapon,2)
			_level_up(p)
			ores.remove_at(best)
			Sfx.play("hit",1.1,-10.0)
		else:
			var food: Dictionary = foods[best-ores.size()]
			p.food[food.kind] = int(p.food.get(food.kind,0))+1
			food.active = false
			Sfx.play("eat",1.0,-8.0)
		p.mine_target = -1
		p.mine_progress = 0.0


func _level_up(p: Dictionary) -> void:
	while p.age < 10 and p.xp >= float(p.age)*100.0:
		p.xp -= float(p.age)*100.0
		p.age += 1
		p.max_hp += 10.0
		p.hp = minf(p.max_hp,p.hp+10.0)
		if p.age >= 2:
			p.weapon = maxi(p.weapon,1)
		if p.age >= 4:
			p.weapon = maxi(p.weapon,2)
		if p.age >= 5:
			p.weapon = maxi(p.weapon,3)
		if p.age >= 8:
			p.weapon = maxi(p.weapon,4)
		if p.age >= 10:
			p.weapon = maxi(p.weapon,5)


func _eat(p: Dictionary) -> void:
	for kind in ["meat","fish","mushroom"]:
		if int(p.food.get(kind,0)) > 0 and p.hp < p.max_hp:
			p.food[kind] -= 1
			p.hp = minf(p.max_hp,p.hp+float(FOOD_DATA[kind].heal))
			Sfx.play("eat")
			return


func _attack(p: Dictionary, aim: Vector2) -> void:
	for other in players.values():
		if other.id == p.id or not other.alive:
			continue
		if p.pos.distance_to(other.pos) < 95.0 and p.pos.direction_to(other.pos).dot(aim) > 0.1:
			other.hp -= 24.0
	for enemy in devourers:
		if p.pos.distance_to(enemy.pos) < 110.0 and p.pos.direction_to(enemy.pos).dot(aim) > -0.1:
			enemy.hp -= 35.0
			if enemy.hp <= 0.0:
				p.food.meat = int(p.food.get("meat",0))+1
				p.xp += 25.0
				_level_up(p)
				devourers.erase(enemy)
				break


func _update_devourers(dt: float) -> void:
	for enemy in devourers:
		var target: Dictionary = {}
		var dist := 1e20
		for p in players.values():
			if not p.alive:
				continue
			var d: float = enemy.pos.distance_squared_to(p.pos)
			if d < dist:
				dist = d
				target = p
		if target.is_empty():
			continue
		var dir: Vector2 = enemy.pos.direction_to(target.pos)
		enemy.pos += dir * 105.0 * dt
		if dist < 48.0*48.0:
			target.hp -= 9.0*dt


func _respawn(p: Dictionary) -> void:
	p.age = 1
	p.xp = 0.0
	p.money = 0
	p.ore = 0
	p.food = {"mushroom":0,"fish":0,"meat":0}
	p.weapon = 0
	p.max_hp = 100.0
	p.hp = p.max_hp
	p.pos = Vector2(300,360)
	p.mine_target = -1
	p.mine_progress = 0.0
	p.alive = true


func _update_visuals(_dt: float) -> void:
	for id in players:
		if not actor_nodes.has(id):
			var actor: Node2D = ACTOR.new()
			add_child(actor)
			actor.setup(int(players[id].kind),G.col(int(players[id].color)),int(players[id].outfit),int(players[id].hat))
			actor_nodes[id] = actor
		actor_nodes[id].position = players[id].pos
		actor_nodes[id].rotation = players[id].pos.angle_to_point(get_global_mouse_position()) + PI/2.0 if int(id) == local_id else 0.0
	if players.has(local_id):
		cam.position = cam.position.lerp(players[local_id].pos,0.12)


func _update_hud() -> void:
	_draw_minimap()
	if not players.has(local_id):
		return
	var p: Dictionary = players[local_id]
	var next_xp := float(p.age)*100.0
	age_label.text = "AGE %02d  •  %.0f / %.0f" % [p.age,p.xp,next_xp] if p.age < 10 else "AGE 10  •  МАКСИМУМ"
	resource_label.text = "Кристаллы %d   •   %d ¢" % [p.ore,p.money]
	health_bar.max_value = p.max_hp
	health_bar.value = p.hp
	inventory_label.text = "ЕДА  •  Грибы %d  Рыба %d  Мясо %d  [F]" % [p.food.mushroom,p.food.fish,p.food.meat]
	hint_label.text = "AGE 2: КЛИНОК" if p.age >= 2 else "СОБИРАЙ КРИСТАЛЛЫ: E — ДОБЫЧА   •   F — ЕДА"
	var target_index := int(p.get("mine_target",-1))
	mine_bar.visible = target_index >= 0
	if mine_bar.visible:
		var duration := 1.2
		if target_index < ores.size():
			duration = float(ORE_DATA[ores[target_index].kind].time)
		mine_bar.value = clampf(float(p.get("mine_progress",0.0))/duration,0,1)


func _draw() -> void:
	_draw_cave()
	_draw_ores()
	_draw_food()
	_draw_devourers()
	for p in players.values():
		if int(p.id) != local_id:
			draw_circle(p.pos,52,Color("#5cecff",0.035))
			draw_arc(p.pos,52,0,TAU,48,Color("#5cecff",0.45),2.0,true)


func _draw_cave() -> void:
	draw_rect(Rect2(Vector2.ZERO,WORLD),Color("#02040b"))
	for i in 8:
		var shift := Vector2(float(i)*340.0, float((i%3)*390))
		draw_circle(shift+Vector2(150,130),220,Color("#152034",0.14))
	for zone in ZONES:
		var c: Vector2 = zone.center
		var radius: float = zone.radius
		var tint: Color = [Color("#1c6b7a"),Color("#7b352c"),Color("#542c82")][zone.depth]
		draw_circle(c,radius,tint*Color(1,1,1,0.13))
		draw_arc(c,radius,0,TAU,96,Color(tint,0.65),5.0,true)
	for i in 28:
		var x := float((i*173)%2500)+50.0
		var y := float((i*293)%1500)+50.0
		var length := 22.0 + float(i%5)*9.0
		var color := Color("#1a4b5b",0.65) if i%2==0 else Color("#4c376b",0.6)
		draw_colored_polygon(PackedVector2Array([Vector2(x-10,y),Vector2(x+10,y),Vector2(x+3,y+length),Vector2(x-2,y+length+8)]),color)
		draw_line(Vector2(x,y),Vector2(x,y+length),Color(color,0.85),2.0,true)
	for pool in [Vector2(520,600),Vector2(1370,1040),Vector2(2200,1380)]:
		draw_circle(pool,82,Color("#24bde0",0.08))
		draw_arc(pool,82,0,TAU,56,Color("#42dff4",0.55),3.0,true)
		draw_arc(pool,58,0,TAU,48,Color("#8af7ff",0.2),2.0,true)
	draw_polyline(PackedVector2Array([Vector2(70,70),Vector2(2500,70),Vector2(2530,95),Vector2(2530,1540),Vector2(2500,1570),Vector2(70,1570),Vector2(40,1540),Vector2(40,100),Vector2(70,70)]),Color("#31516b"),12.0,true)


func _draw_ores() -> void:
	for ore in ores:
		var data: Dictionary = ORE_DATA[ore.kind]
		var pos: Vector2 = ore.pos
		var color: Color = data.color
		draw_circle(pos,30,Color(color,0.10))
		draw_colored_polygon(PackedVector2Array([pos+Vector2(0,-24),pos+Vector2(20,-5),pos+Vector2(13,20),pos+Vector2(-12,22),pos+Vector2(-23,-4)]),color.darkened(0.35))
		draw_polyline(PackedVector2Array([pos+Vector2(0,-24),pos+Vector2(20,-5),pos+Vector2(13,20),pos+Vector2(-12,22),pos+Vector2(-23,-4),pos+Vector2(0,-24)]),color.lightened(0.5),3.0,true)
		draw_line(pos+Vector2(-2,-15),pos+Vector2(7,8),Color("#ffffff",0.7),2.0,true)


func _draw_food() -> void:
	for food in foods:
		if not food.active:
			continue
		var color: Color = FOOD_DATA[food.kind].color
		draw_circle(food.pos,22,Color(color,0.10))
		draw_colored_polygon(PackedVector2Array([food.pos+Vector2(0,-17),food.pos+Vector2(14,-3),food.pos+Vector2(9,13),food.pos+Vector2(-9,13),food.pos+Vector2(-14,-3)]),color)
		draw_line(food.pos+Vector2(0,12),food.pos+Vector2(0,25),Color("#d2fff2"),3.0,true)


func _draw_devourers() -> void:
	for enemy in devourers:
		draw_circle(enemy.pos,35,Color("#ff684f",0.12))
		draw_colored_polygon(PackedVector2Array([enemy.pos+Vector2(-26,5),enemy.pos+Vector2(-15,-20),enemy.pos+Vector2(14,-24),enemy.pos+Vector2(29,3),enemy.pos+Vector2(9,24),enemy.pos+Vector2(-18,22)]),Color("#612c49"))
		draw_arc(enemy.pos,30,0,TAU,32,Color("#ff8068"),3.0,true)
		draw_circle(enemy.pos+Vector2(-8,-3),3,Color("#fff1bd"))
		draw_circle(enemy.pos+Vector2(8,-3),3,Color("#fff1bd"))


func _draw_minimap() -> void:
	if not is_instance_valid(map_widget):
		return
	map_widget.explored_cells = explored.duplicate()
	if players.has(local_id):
		map_widget.player_pos = players[local_id].pos
	map_widget.queue_redraw()


func _exit_tree() -> void:
	if is_instance_valid(Sfx.music):
		Sfx.music.stop()
	if Net.online and G.mode == "host":
		Net.tribe_inputs.clear()
