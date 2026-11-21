class_name Sim
extends RefCounted
## Вся игровая логика СВЕТОБАЛАМУТА. Работает на хосте / в одиночке.
## Клиенты эту симуляцию не считают — они рисуют снапшоты (см. snapshot()).

const A := Vector2(1600, 900)
const MAX_LIGHT := 125.0
const CLASS_STATS := [
	{"name": "Светляк", "hp": 125.0, "def": 0.95, "atk": 0.82, "speed": 1.12, "rate": 0.22, "ability": "Перегрузка"},
	{"name": "Капсула", "hp": 155.0, "def": 0.72, "atk": 1.35, "speed": 0.78, "rate": 0.56, "ability": "Энергощит"},
	{"name": "Призрак", "hp": 125.0, "def": 0.90, "atk": 0.95, "speed": 1.25, "rate": 0.26, "ability": "Фазовый скачок"},
	{"name": "Кристалл", "hp": 120.0, "def": 0.92, "atk": 1.65, "speed": 0.88, "rate": 0.68, "ability": "Звёздный залп"}
]
const SPEED := 470.0
const DASH_SPEED := 1550.0
const DASH_TIME := 0.18
const INV_TIME := 0.2
const DASH_CD := 1.5
const FIRE_CD := 0.1
const BULLET_SPEED := 1300.0
const BULLET_DMG := 9.0
const SHOT_COST := 1.0
const MOVE_COST := 1.8
const DASH_COST := 4.0
const REGEN_STILL := 10.0
const REGEN_ZONE := 30.0
const KILL_BONUS := 24.0
const MATCH_TIME := 240.0
const MIN_SURVIVAL_TIME := 60.0
const P_RADIUS := 28.0
const MAX_EATERS_RAIN := 16
const ZONES := [Vector3(420, 250, 125), Vector3(1180, 250, 125), Vector3(420, 650, 125), Vector3(1180, 650, 125), Vector3(800, 450, 95)]
const CHAOS := ["invert", "reverse", "blind", "bounce", "zerog", "rain", "steal", "doubles", "magnet", "bomb"]
const DUR := {"invert": 6.0, "reverse": 6.0, "blind": 5.0, "bounce": 8.0, "zerog": 6.0, "magnet": 5.0}

var players := {}
var bullets: Array = []
var eaters: Array = []
var effects := {}
var events: Array = []
var inputs := {}
var time_left := MATCH_TIME
var phase := "play"
var winner := 0
var chaos_timer := 4.0
var eater_timer := 3.0
var bomb_id := 0
var bomb_t := 0.0
var next_id := 1
var shake_req := 0.0
var rng := RandomNumberGenerator.new()
## Tutorial mode: the match never ends by itself and random chaos does not interrupt the lesson.
var endless := false
var chaos_enabled := true


func reset(cfg: Array) -> void:
	rng.randomize()
	players.clear()
	bullets.clear()
	eaters.clear()
	effects.clear()
	events.clear()
	inputs.clear()
	time_left = MATCH_TIME
	phase = "play"
	winner = 0
	chaos_timer = 10.0
	eater_timer = 4.0
	bomb_id = 0
	bomb_t = 0.0
	next_id = 1
	shake_req = 0.0
	var n := cfg.size()
	var shuffled := range(n)
	shuffled.shuffle()
	for i in n:
		var c: Dictionary = cfg[i]
		var ang := TAU * i / n
		var pos := A / 2.0 + Vector2(cos(ang) * 620.0, sin(ang) * 330.0)
		var ci: int = int(c.get("color", shuffled[i])) if c.human else shuffled[i] % G.PROFILE_COLORS.size()
		var kind: int = int(c.get("kind", ci % 4)) if c.human else ci % 4
		players[c.id] = _new_player(c.id, c.name, c.human, kind, ci, pos,
			int(c.get("hat", 0)), int(c.get("outfit", 0)))


func _new_player(id: int, pname: String, human: bool, kind: int, ci: int, pos: Vector2, hat: int = 0, outfit: int = 0) -> Dictionary:
	return {
		"id": id, "name": pname, "human": human, "kind": kind, "ci": ci, "hat": hat, "outfit": outfit,
		"pos": pos, "vel": Vector2.ZERO, "aim": (A / 2.0 - pos).normalized(),
		"light": CLASS_STATS[kind % 4].hp, "max_light": CLASS_STATS[kind % 4].hp,
		"defense": CLASS_STATS[kind % 4].def, "attack": CLASS_STATS[kind % 4].atk,
		"speed_mult": CLASS_STATS[kind % 4].speed, "fire_rate": CLASS_STATS[kind % 4].rate,
		"ability_cd": 0.0, "ability_t": 0.0,
		"shadow": false, "decoy": false, "life": 0.0,
		"dash_t": 0.0, "dash_dir": Vector2.RIGHT, "dash_cd": 0.0, "inv": 0.0, "fire_cd": 0.0,
		"pts": 0, "kills": 0, "last_hit": 0, "hit_age": 99.0, "hit_t": 0.0, "push_cd": 0.0,
		"derp_t": 0.0, "derp_by": 0, "derp": {"t": 0.0, "mv": Vector2.ZERO, "aim": pos, "fire": false, "dash": false},
		"poss_target": 0, "poss_cd": 0.0,
		"bot": {"t": 0.0, "strafe": 1.0, "want": 350.0},
	}


# ------------------------------------------------------------------ шаг ----
func step(dt: float) -> void:
	if phase != "play":
		return
	if not endless:
		time_left -= dt
	if chaos_enabled:
		_chaos_tick(dt)
	for k in effects.keys():
		effects[k] -= dt
		if effects[k] <= 0.0:
			effects.erase(k)
	eater_timer -= dt
	if eater_timer <= 0.0:
		eater_timer = 5.0
		if eaters.size() < 8:
			_spawn_eater(_edge_point(), rng.randi() % 100 < 60)
	for p in players.values():
		if not p.human:
			_bot_think(p, dt)
	for p in players.values():
		_update_player(p, dt)
	_collisions(dt)
	_update_bullets(dt)
	_update_eaters(dt)
	_bomb_tick(dt)
	for id in players.keys():
		var p: Dictionary = players[id]
		if p.decoy:
			p.life -= dt
			if p.life <= 0.0 or p.light <= 0.0:
				events.append({"t": "death", "x": p.pos.x, "y": p.pos.y, "c": p.ci, "id": id})
				players.erase(id)
	if not endless:
		_check_end()


# ------------------------------------------------------------- игроки ----
func _update_player(p: Dictionary, dt: float) -> void:
	var inp: Dictionary = inputs.get(p.id, {})
	var mv: Vector2 = inp.get("mv", Vector2.ZERO)
	var aim_pt: Vector2 = inp.get("aim", p.pos + p.aim * 100.0)
	var want_fire: bool = inp.get("fire", false)
	var want_dash: bool = inp.get("dash", false)
	var want_poss: bool = inp.get("poss", false)
	var want_ability: bool = inp.get("ability", false)
	if effects.has("reverse") and not p.decoy:
		mv = -mv
	if p.derp_t > 0.0:
		p.derp_t -= dt
		var d: Dictionary = p.derp
		d.t -= dt
		if d.t <= 0.0:
			d.t = 0.22
			d.mv = Vector2.from_angle(rng.randf() * TAU)
			d.aim = p.pos + Vector2.from_angle(rng.randf() * TAU) * 200.0
			d.fire = rng.randf() < 0.65
			d.dash = rng.randf() < 0.18
		mv = d.mv
		aim_pt = d.aim
		want_fire = d.fire
		want_dash = d.dash
		want_poss = false
		want_ability = false
		if p.derp_t <= 0.0:
			p.derp_by = 0
	p.dash_cd = maxf(0.0, p.dash_cd - dt)
	p.inv = maxf(0.0, p.inv - dt)
	p.fire_cd = maxf(0.0, p.fire_cd - dt)
	p.hit_t = maxf(0.0, p.hit_t - dt)
	p.hit_age += dt
	p.push_cd = maxf(0.0, p.push_cd - dt)
	p.poss_cd = maxf(0.0, p.poss_cd - dt)
	p.ability_cd = maxf(0.0, p.ability_cd - dt)
	p.ability_t = maxf(0.0, p.ability_t - dt)

	if p.shadow:
		_update_shadow(p, dt, mv, want_poss)
		return

	var to_aim: Vector2 = aim_pt - p.pos
	if to_aim.length() > 2.0:
		p.aim = to_aim.normalized()

	if p.dash_t > 0.0:
		p.dash_t -= dt
		p.vel = p.dash_dir * DASH_SPEED
	else:
		var k := 0.9 if effects.has("zerog") else 15.0
		var speed_boost := 1.55 if p.kind == 0 and p.ability_t > 0.0 else 1.0
		p.vel = p.vel.lerp(mv.limit_length(1.0) * SPEED * p.speed_mult * speed_boost, clampf(k * dt, 0.0, 1.0))
		if want_dash and p.dash_cd <= 0.0 and p.light > DASH_COST:
			p.dash_dir = mv.normalized() if mv.length() > 0.1 else p.aim
			p.dash_t = DASH_TIME
			p.inv = INV_TIME
			p.dash_cd = DASH_CD
			p.light -= DASH_COST
			events.append({"t": "dash", "x": p.pos.x, "y": p.pos.y, "c": p.ci})
	if want_ability and p.ability_cd <= 0.0:
		_use_ability(p)
	if effects.has("magnet"):
		var b := _brightest(p.id)
		if not b.is_empty():
			p.vel += (b.pos - p.pos).normalized() * 750.0 * dt
	p.pos += p.vel * dt
	_wall_bounce(p)

	var shot_cost: float = 1.5 if p.kind == 0 else SHOT_COST
	if want_fire and p.fire_cd <= 0.0 and p.light > shot_cost + 0.5:
		var spread_count := 3 if p.kind == 0 else 1
		for shot_i in spread_count:
			var spread := (float(shot_i) - 1.0) * 0.12 if spread_count == 3 else 0.0
			var ang: float = p.aim.angle() + spread + rng.randf_range(-0.018, 0.018)
			var dir := Vector2.from_angle(ang)
			var bolt_speed := 880.0 if p.kind == 1 else (960.0 if p.kind == 3 else (1480.0 if p.kind == 2 else BULLET_SPEED))
			var bolt_radius := 11.0 if p.kind == 3 else (10.0 if p.kind == 1 else 6.0)
			var damage_mult := 0.42 if p.kind == 0 else 1.0
			bullets.append({"id": next_id, "pos": p.pos + dir * 34.0, "vel": dir * bolt_speed + p.vel * 0.25,
				"owner": p.id, "life": 1.4, "bn": 0, "dmg": BULLET_DMG * p.attack * damage_mult,
				"radius": bolt_radius})
			next_id += 1
		p.light -= shot_cost
		var haste := 0.52 if p.kind == 0 and p.ability_t > 0.0 else 1.0
		p.fire_cd = p.fire_rate * haste
		p.vel -= p.aim * 55.0
		events.append({"t": "shot", "x": p.pos.x, "y": p.pos.y, "c": p.ci})

	var spd_ratio: float = p.vel.length() / SPEED
	p.light -= MOVE_COST * minf(spd_ratio, 1.2) * dt
	var in_zone := _in_zone(p.pos)
	if effects.has("invert"):
		in_zone = not in_zone
	if spd_ratio < 0.15:
		p.light += REGEN_STILL * dt
	if in_zone:
		p.light += REGEN_ZONE * dt
	p.light = clampf(p.light, 0.0, p.max_light)
	if p.light <= 0.0 and not p.decoy:
		# Credit a kill only for a recent hit; otherwise this is starvation (no stale kill credit).
		_make_shadow(p, p.last_hit if p.hit_age < 4.0 else 0, false)


func _use_ability(p: Dictionary) -> void:
	p.ability_cd = 9.0
	match p.kind:
		0:
			p.ability_t = 2.8
			events.append({"t": "ability", "x": p.pos.x, "y": p.pos.y, "c": p.ci, "kind": 0})
		1:
			p.ability_t = 2.8
			events.append({"t": "ability", "x": p.pos.x, "y": p.pos.y, "c": p.ci, "kind": 1})
		2:
			p.pos = (p.pos + p.aim * 320.0).clamp(Vector2(40, 40), A - Vector2(40, 40))
			p.inv = 0.65
			events.append({"t": "ability", "x": p.pos.x, "y": p.pos.y, "c": p.ci, "kind": 2})
		3:
			for i in 10:
				var dir := Vector2.from_angle(TAU * float(i) / 10.0)
				bullets.append({"id": next_id, "pos": p.pos + dir * 40.0, "vel": dir * 760.0,
					"owner": p.id, "life": 1.1, "bn": 0, "dmg": BULLET_DMG * p.attack * 0.62, "radius": 9.0})
				next_id += 1
			events.append({"t": "ability", "x": p.pos.x, "y": p.pos.y, "c": p.ci, "kind": 3})


func _update_shadow(p: Dictionary, dt: float, mv: Vector2, want_poss: bool) -> void:
	if p.poss_target != 0:
		var v = players.get(p.poss_target)
		if v == null or v.shadow or v.derp_t <= 0.0:
			p.poss_target = 0
		else:
			p.pos = v.pos
			return
	p.vel = p.vel.lerp(mv.limit_length(1.0) * SPEED * 1.35, clampf(16.0 * dt, 0.0, 1.0))
	p.pos += p.vel * dt
	_wall_bounce(p)
	if want_poss and p.poss_cd <= 0.0:
		var best: Dictionary = {}
		var bd := 145.0 * 145.0
		for o in players.values():
			if o.shadow or o.derp_t > 0.0:
				continue
			var d: float = (o.pos - p.pos).length_squared()
			if d < bd:
				bd = d
				best = o
		if not best.is_empty():
			best.derp_t = 2.0
			best.derp_by = p.id
			p.poss_target = best.id
			p.poss_cd = 4.5
			events.append({"t": "possess", "x": best.pos.x, "y": best.pos.y, "c": p.ci})


func _wall_bounce(p: Dictionary) -> void:
	var m := 30.0
	var pos: Vector2 = p.pos
	var vel: Vector2 = p.vel
	if pos.x < m:
		pos.x = m
		vel.x = absf(vel.x) * 0.5
	elif pos.x > A.x - m:
		pos.x = A.x - m
		vel.x = -absf(vel.x) * 0.5
	if pos.y < m:
		pos.y = m
		vel.y = absf(vel.y) * 0.5
	elif pos.y > A.y - m:
		pos.y = A.y - m
		vel.y = -absf(vel.y) * 0.5
	p.pos = pos
	p.vel = vel


func _in_zone(pos: Vector2) -> bool:
	for z in ZONES:
		if pos.distance_to(Vector2(z.x, z.y)) < z.z:
			return true
	return false


func _make_shadow(p: Dictionary, killer: int, silent: bool) -> void:
	p.shadow = true
	p.light = 0.0
	p.dash_t = 0.0
	p.vel = Vector2.ZERO
	p.poss_target = 0
	events.append({"t": "death", "x": p.pos.x, "y": p.pos.y, "c": p.ci, "id": p.id})
	shake_req = maxf(shake_req, 18.0)
	if killer != 0 and killer != p.id and players.has(killer):
		var k: Dictionary = players[killer]
		if not k.shadow:
			k.light = minf(k.max_light, k.light + KILL_BONUS)
			k.kills += 1
		if k.derp_t > 0.0 and players.has(k.derp_by):
			players[k.derp_by].pts += 2
	else:
		p.pts += 3                      # смешная смерть (еда пожирателей, бомба, сам себя)
	if p.derp_t > 0.0 and players.has(p.derp_by):
		players[p.derp_by].pts += 3     # вселённый умер — шутка удалась
	p.derp_t = 0.0
	for o in players.values():
		if o.poss_target == p.id:
			o.poss_target = 0


func _damage(p: Dictionary, dmg: float, src: int, bounced: bool) -> void:
	# During the guided solo tutorial the learner cannot be knocked out by bots or hazards.
	# The tutorial's scripted _make_shadow() call remains available, so the shadow lesson still works.
	var global_state := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("G")
	if global_state != null and bool(global_state.get("tutorial_active")) and bool(p.get("human", false)):
		return
	var reduced: float = dmg * float(p.get("defense", 1.0))
	if p.kind == 1 and p.ability_t > 0.0:
		reduced *= 0.25
	p.light -= reduced
	p.last_hit = src
	p.hit_age = 0.0
	p.hit_t = 0.14
	events.append({"t": "hit", "x": p.pos.x, "y": p.pos.y, "c": p.ci})
	shake_req = maxf(shake_req, 7.0)
	if src != 0 and players.has(src):
		var a: Dictionary = players[src]
		if not a.shadow:
			a.light = minf(a.max_light, a.light + reduced * 0.35)
	if p.light <= 0.0 and not p.decoy and not p.shadow:
		_make_shadow(p, src, false)
		if bounced and players.has(src) and src != p.id:
			players[src].pts += 2


func _brightest(exclude: int) -> Dictionary:
	var best: Dictionary = {}
	var bl := -1.0
	for o in players.values():
		if o.id == exclude or o.shadow or o.decoy:
			continue
		if o.light > bl:
			bl = o.light
			best = o
	return best


func _nearest(p: Dictionary, include_decoy: bool) -> Dictionary:
	var best: Dictionary = {}
	var bd := 1e18
	for o in players.values():
		if o.id == p.id or o.shadow:
			continue
		if o.decoy and not include_decoy:
			continue
		var d: float = (o.pos - p.pos).length_squared()
		if d < bd:
			bd = d
			best = o
	return best


func _collisions(_dt: float) -> void:
	var list := players.values()
	for i in list.size():
		var a: Dictionary = list[i]
		if a.shadow:
			continue
		for j in range(i + 1, list.size()):
			var b: Dictionary = list[j]
			if b.shadow:
				continue
			var d: Vector2 = b.pos - a.pos
			var l := d.length()
			if l < P_RADIUS * 2.0 and l > 0.01:
				var n := d / l
				var push := (P_RADIUS * 2.0 - l) * 0.5
				a.pos -= n * push
				b.pos += n * push
				if a.dash_t > 0.0 and b.dash_t <= 0.0 and a.push_cd <= 0.0:
					b.vel += n * 900.0
					a.push_cd = 0.6
					a.pts += 1
					shake_req = maxf(shake_req, 5.0)
				elif b.dash_t > 0.0 and a.dash_t <= 0.0 and b.push_cd <= 0.0:
					a.vel -= n * 900.0
					b.push_cd = 0.6
					b.pts += 1
					shake_req = maxf(shake_req, 5.0)
				# Separation must never push anyone out of the arena.
				a.pos = (a.pos as Vector2).clamp(Vector2(30, 30), A - Vector2(30, 30))
				b.pos = (b.pos as Vector2).clamp(Vector2(30, 30), A - Vector2(30, 30))


func _update_bullets(dt: float) -> void:
	var keep: Array = []
	var bright := _brightest(0)
	for b in bullets:
		b.life -= dt
		if effects.has("magnet") and not bright.is_empty() and bright.id != b.owner:
			var sp: float = b.vel.length()
			b.vel = (b.vel + (bright.pos - b.pos).normalized() * 2600.0 * dt).normalized() * sp
		b.pos += b.vel * dt
		var dead: bool = b.life <= 0.0
		var bounce_on: bool = effects.has("bounce")
		var bp: Vector2 = b.pos
		var bv: Vector2 = b.vel
		if bp.x < 0.0 or bp.x > A.x:
			if bounce_on and b.bn < 4:
				bv.x = -bv.x
				bp.x = clampf(bp.x, 0.0, A.x)
				b.bn += 1
			else:
				dead = true
		if bp.y < 0.0 or bp.y > A.y:
			if bounce_on and b.bn < 4:
				bv.y = -bv.y
				bp.y = clampf(bp.y, 0.0, A.y)
				b.bn += 1
			else:
				dead = true
		b.pos = bp
		b.vel = bv
		if not dead:
			for p in players.values():
				if p.shadow or p.inv > 0.0:
					continue
				if p.id == b.owner and b.bn == 0:
					continue
				if (p.pos - b.pos).length_squared() < pow(P_RADIUS + float(b.get("radius", 6.0)), 2):
					_damage(p, float(b.get("dmg", BULLET_DMG)), b.owner, b.bn > 0)
					dead = true
					break
		if not dead:
			for e in eaters:
				if (e.pos - b.pos).length_squared() < pow(e.r + 8.0, 2):
					e.hp -= 1
					e.flash = 0.1
					dead = true
					if e.hp <= 0:
						e.dead = true
						events.append({"t": "eat", "x": e.pos.x, "y": e.pos.y, "c": 0})
						if players.has(b.owner) and not players[b.owner].shadow:
							players[b.owner].light = minf(players[b.owner].max_light, players[b.owner].light + 9.0)
					else:
						events.append({"t": "hit", "x": e.pos.x, "y": e.pos.y, "c": 0})
					break
		if not dead:
			keep.append(b)
	bullets = keep


# ------------------------------------------------------- пожиратели ------
func _edge_point() -> Vector2:
	match rng.randi() % 4:
		0: return Vector2(rng.randf_range(0, A.x), -30)
		1: return Vector2(rng.randf_range(0, A.x), A.y + 30)
		2: return Vector2(-30, rng.randf_range(0, A.y))
		_: return Vector2(A.x + 30, rng.randf_range(0, A.y))


func _spawn_eater(pos: Vector2, crawler: bool) -> void:
	eaters.append({"id": next_id, "pos": pos, "vel": Vector2.ZERO, "type": 0 if crawler else 1,
		"hp": 3 if crawler else 1, "r": 34.0 if crawler else 24.0, "cd": 0.0, "flash": 0.0, "dead": false})
	next_id += 1


func _update_eaters(dt: float) -> void:
	var tgt := _brightest(0)
	var keep: Array = []
	for e in eaters:
		if e.dead:
			continue
		e.cd = maxf(0.0, e.cd - dt)
		e.flash = maxf(0.0, e.flash - dt)
		if not tgt.is_empty():
			var sp := 250.0 if e.type == 0 else 430.0
			var dir: Vector2 = (tgt.pos - e.pos).normalized()
			e.vel = e.vel.lerp(dir * sp, clampf(3.5 * dt, 0.0, 1.0))
			if e.type == 1:
				e.vel += dir.orthogonal() * sin(time_left * 9.0 + e.id) * 260.0 * dt * 8.0
		e.pos += e.vel * dt
		for p in players.values():
			if p.shadow:
				continue
			if (p.pos - e.pos).length_squared() < pow(e.r + P_RADIUS - 6.0, 2):
				if p.inv <= 0.0 and e.cd <= 0.0:
					e.cd = 0.45
					_damage(p, 10.0, 0, false)
					p.vel += (p.pos - e.pos).normalized() * 500.0
		keep.append(e)
	eaters = keep


# --------------------------------------------------------------- хаос ----
func _chaos_tick(dt: float) -> void:
	chaos_timer -= dt
	if chaos_timer > 0.0:
		return
	chaos_timer = 9.5 + rng.randf_range(-2.5, 2.5)
	trigger(CHAOS[rng.randi() % CHAOS.size()])
	if time_left < MATCH_TIME * 0.4 and rng.randf() < 0.35:
		trigger(CHAOS[rng.randi() % CHAOS.size()])


func trigger(name: String) -> void:
	events.append({"t": "chaos", "n": name})
	shake_req = maxf(shake_req, 26.0)
	var lit: Array = []
	for p in players.values():
		if not p.shadow and not p.decoy:
			lit.append(p)
	match name:
		"rain":
			for i in 8:
				if eaters.size() >= MAX_EATERS_RAIN:
					break  # repeated rains must not bury the arena in never-expiring eaters
				_spawn_eater(Vector2(rng.randf_range(60, A.x - 60), -40.0 - i * 20.0), rng.randf() < 0.5)
		"steal":
			if lit.size() >= 2:
				lit.shuffle()
				var a: Dictionary = lit[0]
				var b: Dictionary = lit[1]
				var amt: float = b.light * 0.4
				var old_kind: int = a.kind
				var old_color: int = a.ci
				# Swap class AND its stats together; otherwise a swapped sprite keeps the old class's stats.
				_set_kind(a, b.kind)
				a.ci = b.ci
				_set_kind(b, old_kind)
				b.ci = old_color
				a.light = minf(a.max_light, a.light + amt)
				b.light = maxf(1.0, b.light - amt)
		"doubles":
			if not lit.is_empty():
				for i in 3:
					var src: Dictionary = lit[rng.randi() % lit.size()]
					var id := -(1000 + next_id)
					next_id += 1
					var d := _new_player(id, "двойник", false, src.kind, src.ci, _edge_point().clamp(Vector2(60, 60), A - Vector2(60, 60)), src.hat, src.outfit)
					d.decoy = true
					d.life = 12.0
					d.light = 45.0
					players[id] = d
		"bomb":
			if not lit.is_empty() and bomb_id == 0:
				var v: Dictionary = lit[rng.randi() % lit.size()]
				bomb_id = v.id
				bomb_t = 4.0
		_:
			# Stacking extends the effect, but never beyond twice its base duration.
			var base: float = DUR.get(name, 5.0)
			effects[name] = minf(base + effects.get(name, 0.0), base * 2.0)


## Switch a player's class while keeping the light ratio and applying that class's real stats.
func _set_kind(p: Dictionary, kind: int) -> void:
	var k: int = posmod(kind, CLASS_STATS.size())
	var st: Dictionary = CLASS_STATS[k]
	var ratio: float = float(p.light) / maxf(float(p.max_light), 1.0)
	p.kind = k
	p.max_light = st.hp
	p.light = clampf(ratio * float(st.hp), 0.0, float(st.hp))
	p.defense = st.def
	p.attack = st.atk
	p.speed_mult = st.speed
	p.fire_rate = st.rate
	p.ability_t = 0.0


func _bomb_tick(dt: float) -> void:
	if bomb_id == 0:
		return
	var v = players.get(bomb_id)
	if v == null:
		bomb_id = 0
		return
	bomb_t -= dt
	if bomb_t <= 0.0 or v.shadow:
		var c: Vector2 = v.pos
		events.append({"t": "boom", "x": c.x, "y": c.y, "r": 260.0})
		shake_req = maxf(shake_req, 45.0)
		var holder := bomb_id
		bomb_id = 0
		for p in players.values():
			if p.shadow:
				continue
			var d: float = (p.pos - c).length()
			if d < 260.0:
				var dmg: float = 100.0 if p.id == holder else 65.0 * (1.0 - d / 330.0)
				p.vel += (p.pos - c).normalized() * 800.0
				_damage(p, dmg, holder, false)
				if p.id != holder and players.has(holder):
					players[holder].pts += 1


# ---------------------------------------------------------------- боты ---
func _bot_think(p: Dictionary, dt: float) -> void:
	var inp := {"mv": Vector2.ZERO, "aim": p.pos + p.aim * 100.0, "fire": false, "dash": false, "poss": false, "ability": false}
	var b: Dictionary = p.bot
	b.t -= dt
	if p.shadow:
		var target := _nearest(p, false)
		if not target.is_empty():
			var to: Vector2 = target.pos - p.pos
			var distance := to.length()
			inp.mv = to.normalized()
			inp.poss = distance < 145.0
			if distance > 190.0 and p.dash_cd <= 0.0 and rng.randf() < 0.055:
				inp.dash = true
		inputs[p.id] = inp
		return
	if b.t <= 0.0:
		b.t = rng.randf_range(0.25, 0.7)
		b.strafe = -1.0 if rng.randf() < 0.5 else 1.0
		b.want = rng.randf_range(260.0, 480.0)
	var mv := Vector2.ZERO
	for ghost in players.values():
		if ghost.id == p.id or not ghost.shadow:
			continue
		var ghost_delta: Vector2 = p.pos - ghost.pos
		var ghost_distance := ghost_delta.length()
		if ghost_distance < 230.0:
			mv += ghost_delta.normalized() * (2.1 if ghost_distance < 115.0 else 1.25)
	var tgt := _nearest(p, true)
	if not tgt.is_empty():
		var to: Vector2 = tgt.pos - p.pos
		var d := to.length()
		if p.ability_cd <= 0.0 and rng.randf() < dt * 0.72:
			inp.ability = true
		var dirv := to / maxf(d, 1.0)
		mv += dirv.orthogonal() * b.strafe * 0.9
		if d > b.want + 60.0:
			mv += dirv
		elif d < b.want - 80.0:
			mv -= dirv
		var lead: Vector2 = tgt.pos + tgt.vel * (d / BULLET_SPEED) * 0.8
		lead += Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 38.0
		inp.aim = lead
		inp.fire = d < 820.0 and p.light > 14.0
	if p.light < 32.0:
		var bz := Vector2(ZONES[0].x, ZONES[0].y)
		var bdz := 1e18
		for z in ZONES:
			var zp := Vector2(z.x, z.y)
			var dz := zp.distance_squared_to(p.pos)
			if dz < bdz:
				bdz = dz
				bz = zp
		mv = (bz - p.pos).normalized() + mv * 0.25
		if p.light < 12.0:
			inp.fire = false
	for e in eaters:
		var de: float = (e.pos - p.pos).length()
		if de < 230.0:
			mv += (p.pos - e.pos).normalized() * 1.6
			if de < 380.0 and p.light > 14.0:
				inp.aim = e.pos
				inp.fire = true
	if p.pos.x < 120.0: mv.x += 1.0
	if p.pos.x > A.x - 120.0: mv.x -= 1.0
	if p.pos.y < 120.0: mv.y += 1.0
	if p.pos.y > A.y - 120.0: mv.y -= 1.0
	if p.dash_cd <= 0.0:
		for bl in bullets:
			if bl.owner == p.id:
				continue
			var rel: Vector2 = p.pos - bl.pos
			if rel.length() < 150.0 and rel.normalized().dot(bl.vel.normalized()) > 0.85:
				inp.dash = true
				mv = bl.vel.normalized().orthogonal() * b.strafe
				break
		if not inp.dash and rng.randf() < 0.004:
			inp.dash = true
	inp.mv = mv.limit_length(1.0)
	inputs[p.id] = inp


# --------------------------------------------------------------- финал ---
func _check_end() -> void:
	var lit: Array = []
	var real: Array = []
	for p in players.values():
		if p.decoy:
			continue
		real.append(p)
		if not p.shadow:
			lit.append(p)
	# The last remaining light wins immediately; no arbitrary 60-second delay.
	if real.size() >= 2 and lit.size() == 1:
		_end(lit[0].id)
		return
	if lit.is_empty() and not real.is_empty():
		var best := -1
		var cand: Array = []
		for p in real:
			if p.pts > best:
				best = p.pts
				cand = [p]
			elif p.pts == best:
				cand.append(p)
		_end(cand[rng.randi() % cand.size()].id)
		return
	if time_left <= 0.0:
		# лотерея по хаос-поинтам: билетов = 1 + pts
		var total := 0
		for p in real:
			total += 1 + p.pts
		var r := rng.randi() % total
		for p in real:
			r -= 1 + p.pts
			if r < 0:
				_end(p.id)
				return


func _end(id: int) -> void:
	phase = "over"
	winner = id
	events.append({"t": "win", "id": id})


# ------------------------------------------------------------ снапшот ----
func snapshot() -> Dictionary:
	var pl: Array = []
	for p in players.values():
		pl.append({"i": p.id, "n": p.name, "p": p.pos, "v": p.vel, "a": p.aim, "l": p.light,
			"s": p.shadow, "k": p.kind, "c": p.ci, "hat": p.hat, "outfit": p.outfit,
			"iv": p.inv, "dc": p.dash_cd, "pt": p.pts,
			"hpmax": p.max_light, "acd": p.ability_cd, "ab": p.ability_t, "bot": not p.human,
			"ki": p.kills, "dr": p.derp_t, "d": p.decoy, "h": p.hit_t, "dt": p.dash_t > 0.0})
	var bl: Array = []
	for b in bullets:
		bl.append([b.id, b.pos, b.vel, b.owner, b.bn, int(players.get(b.owner, {}).get("kind", 0)), float(b.get("radius", 6.0))])
	var ea: Array = []
	for e in eaters:
		ea.append([e.id, e.pos, e.vel, e.type, e.hp, e.flash])
	return {"pl": pl, "bl": bl, "ea": ea, "fx": effects.duplicate(), "tl": time_left,
		"ph": phase, "wn": winner, "bomb": bomb_id, "bt": bomb_t}
