class_name Sim
extends RefCounted
## Вся игровая логика СВЕТОБАЛАМУТА. Работает на хосте / в одиночке.
## Клиенты эту симуляцию не считают — они рисуют снапшоты (см. snapshot()).

const A := Vector2(1600, 900)
const MAX_LIGHT := 125.0
const CLASS_STATS := [
	{"name":"Светляк","hp":125.0,"def":0.95,"atk":0.82,"speed":1.12,"rate":0.22,"ability":"Перегрузка"},
	{"name":"Капсула","hp":140.0,"def":0.88,"atk":1.35,"speed":0.78,"rate":0.56,"ability":"Энергощит"},
	{"name":"Призрак","hp":130.0,"def":0.88,"atk":1.0,"speed":1.20,"rate":0.26,"ability":"Фазовый скачок"},
	{"name":"Кристалл","hp":140.0,"def":0.96,"atk":1.65,"speed":1.0,"rate":0.46,"ability":"Звёздный залп"},
	{"name":"Импульс","hp":118.0,"def":1.02,"atk":0.95,"speed":1.22,"rate":0.24,"ability":"Разгон"},
	{"name":"Магнит","hp":132.0,"def":0.96,"atk":0.95,"speed":0.96,"rate":0.32,"ability":"Притяжение"},
	{"name":"Слизень","hp":155.0,"def":0.84,"atk":0.86,"speed":0.82,"rate":0.34,"ability":"Липкая броня"},
	{"name":"Сверхнова","hp":112.0,"def":1.08,"atk":1.18,"speed":0.94,"rate":0.38,"ability":"Вспышка"},
	{"name":"Мираж","hp":120.0,"def":1.0,"atk":0.96,"speed":1.16,"rate":0.28,"ability":"Смещение"},
	{"name":"Осколок","hp":126.0,"def":0.98,"atk":1.08,"speed":1.04,"rate":0.30,"ability":"Гранёный залп"},
	{"name":"Сингулярность","hp":138.0,"def":0.94,"atk":0.98,"speed":0.88,"rate":0.36,"ability":"Гравитационная яма"},
	{"name":"Рикошет","hp":122.0,"def":1.0,"atk":1.0,"speed":1.08,"rate":0.29,"ability":"Отскок"},
	{"name":"Вулкан","hp":145.0,"def":0.92,"atk":1.12,"speed":0.90,"rate":0.40,"ability":"Перегрев"},
	{"name":"Паразит","hp":128.0,"def":0.98,"atk":1.02,"speed":1.02,"rate":0.31,"ability":"Высасывание"},
	{"name":"Маятник","hp":130.0,"def":0.97,"atk":1.0,"speed":1.06,"rate":0.30,"ability":"Размах"},
	{"name":"Губка","hp":150.0,"def":0.86,"atk":0.90,"speed":0.88,"rate":0.35,"ability":"Поглощение"},
	{"name":"Генератор","hp":124.0,"def":0.98,"atk":0.92,"speed":0.98,"rate":0.33,"ability":"Автотурель"},
	{"name":"Полярность","hp":134.0,"def":0.94,"atk":1.0,"speed":1.0,"rate":0.32,"ability":"Отталкивание"},
	{"name":"Фантом","hp":116.0,"def":0.90,"atk":1.08,"speed":1.24,"rate":0.28,"ability":"Фазирование"}
]
const SPEED := 470.0
const DASH_SPEED := 1550.0
const DASH_TIME := 0.18
const INV_TIME := 0.2
const POSSESS_COOLDOWN := 5.0
const DASH_CD := 1.5
const FIRE_CD := 0.1
const BULLET_SPEED := 1300.0
const BULLET_DMG := 9.0
const SHOT_COST := 0.28
const MOVE_COST := 0.65
const DASH_COST := 2.0
const REGEN_PASSIVE := 2.5
const REGEN_STILL := 2.0
const REGEN_ZONE := 5.0
const KILL_BONUS := 24.0
const CAPSULE_WAVE_RADIUS := 190.0
const CAPSULE_WAVE_RELOAD := 1.5
const MATCH_TIME := 240.0
const MIN_SURVIVAL_TIME := 60.0
const P_RADIUS := 28.0
const MAX_EATERS_RAIN := 8
const ZONES := [Vector3(400, 225, 95), Vector3(1200, 225, 95), Vector3(400, 675, 95), Vector3(1200, 675, 95)]
const CHAOS := ["invert", "reverse", "blind", "bounce", "zerog", "rain", "steal", "doubles", "magnet", "bomb"]
const DUR := {"invert": 6.0, "reverse": 6.0, "blind": 5.0, "bounce": 8.0, "zerog": 6.0, "magnet": 5.0}

var players := {}
var bullets: Array = []
var eaters: Array = []
var lures: Array = []
var attack_zones: Array = []
var attack_turrets: Array = []
var attack_beams: Array = []
var pickups: Array = []
var pickup_timer := 9.0
var meteors: Array = []
var obstacles: Array = []
var meteor_burst_left := 0
var meteor_burst_timer := 0.0
var meteor_timer := 14.0
var match_event_timer := 28.0
var effects := {}
var events: Array = []
var inputs := {}
var time_left := 0.0
var elapsed_time := 0.0
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
	lures.clear()
	attack_zones.clear()
	attack_turrets.clear()
	attack_beams.clear()
	pickups.clear()
	pickup_timer = rng.randf_range(8.0, 13.0)
	meteors.clear()
	obstacles.clear()
	meteor_burst_left = 0
	meteor_burst_timer = 0.0
	meteor_timer = rng.randf_range(12.0, 18.0)
	match_event_timer = rng.randf_range(24.0, 32.0)
	effects.clear()
	events.clear()
	inputs.clear()
	time_left = 0.0
	elapsed_time = 0.0
	phase = "play"
	winner = 0
	chaos_timer = 15.0
	eater_timer = 7.0
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
		var kind: int = int(c.get("kind", ci % CLASS_STATS.size())) if c.human else rng.randi_range(0, CLASS_STATS.size() - 1)
		var bot_hat := rng.randi_range(1, 4) if not c.human else int(c.get("hat", 0))
		players[c.id] = _new_player(c.id, c.name, c.human, kind, ci, pos,
			bot_hat, int(c.get("outfit", 0)))


func _new_player(id: int, pname: String, human: bool, kind: int, ci: int, pos: Vector2, hat: int = 0, outfit: int = 0) -> Dictionary:
	return {
		"id": id, "name": pname, "human": human, "kind": kind, "ci": ci, "hat": hat, "outfit": outfit,
		"pos": pos, "vel": Vector2.ZERO, "aim": (A / 2.0 - pos).normalized(),
		"light": CLASS_STATS[posmod(kind, CLASS_STATS.size())].hp, "max_light": CLASS_STATS[posmod(kind, CLASS_STATS.size())].hp, "shield_hp": 0.0, "max_shield": 0.0,
		"defense": CLASS_STATS[posmod(kind, CLASS_STATS.size())].def, "attack": CLASS_STATS[posmod(kind, CLASS_STATS.size())].atk,
		"speed_mult": CLASS_STATS[posmod(kind, CLASS_STATS.size())].speed, "fire_rate": CLASS_STATS[posmod(kind, CLASS_STATS.size())].rate,
		"ability_cd": 0.0, "ability_t": 0.0, "extra_cd": 0.0, "phase_t": 0.0, "absorb_t": 0.0, "prism_shots": 0,
		"slow_t": 0.0, "polarity_mode": 1,
		"shadow": false, "decoy": false, "life": 0.0,
		"dash_t": 0.0, "dash_dir": Vector2.RIGHT, "dash_cd": 0.0, "inv": 0.0, "fire_cd": 0.0,
		"wave_charge": 0.0, "fire_was_down": false, "wave_released": false,
		"wave_ammo": 4, "wave_reload_t": 0.0, "buff": "", "buff_t": 0.0,
		"field_t": 0.0, "field_mode": 0, "special_shots": 0, "turret_t": 0.0, "turret_cd": 0.0,
		"pts": 0, "kills": 0, "damage_total": 0.0, "healing_total": 0.0, "kill_streak": 0, "kill_streak_t": 0.0, "last_hit": 0, "damage_by": {}, "hit_age": 99.0, "hit_t": 0.0, "push_cd": 0.0,
		"derp_t": 0.0, "derp_by": 0, "derp": {"t": 0.0, "mv": Vector2.ZERO, "aim": pos, "fire": false, "dash": false},
		"poss_target": 0, "poss_cd": 0.0, "poss_protect_cd": 0.0,
		"bot": {"t": 0.0, "strafe": 1.0, "want": 350.0, "skill": 0.08},
	}


# ------------------------------------------------------------------ шаг ----
func step(dt: float) -> void:
	if phase != "play":
		return
	elapsed_time += dt
	if not endless:
		time_left += dt
	if chaos_enabled:
		_chaos_tick(dt)
	for k in effects.keys():
		effects[k] -= dt
		if effects[k] <= 0.0:
			effects.erase(k)
	eater_timer -= dt
	if eater_timer <= 0.0:
		eater_timer = 8.0
		if eaters.size() < 5:
			_spawn_eater(_edge_point(), rng.randi() % 100 < 60)
	for p in players.values():
		if not p.human:
			_bot_think(p, dt)
	for p in players.values():
		_update_player(p, dt)
	_collisions(dt)
	_update_bullets(dt)
	_update_attack_zones(dt)
	_update_attack_turrets(dt)
	_update_attack_beams(dt)
	_update_lures(dt)
	_update_eaters(dt)
	_update_pickups(dt)
	_meteor_tick(dt)
	_match_event_tick(dt)
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
	var want_extra: bool = inp.get("extra_ability", false)
	if effects.has("reverse") and not p.decoy:
		mv = -mv
	# A shadow possessing this player directly drives their movement and actions.
	var possessor: Dictionary = {}
	var possessed_fire_press := false
	for candidate in players.values():
		if candidate.shadow and int(candidate.get("poss_target", 0)) == p.id:
			possessor = candidate
			break
	if not possessor.is_empty():
		var control: Dictionary = inputs.get(possessor.id, {})
		mv = control.get("mv", Vector2.ZERO)
		aim_pt = control.get("aim", aim_pt)
		want_fire = bool(control.get("fire", false))
		possessed_fire_press = want_fire and not bool(possessor.get("poss_fire_was_down", false))
		possessor.poss_fire_was_down = want_fire
		want_dash = bool(control.get("dash", false))
		want_ability = bool(control.get("ability", false))
		want_extra = bool(control.get("extra_ability", false))
		want_poss = false
	if p.derp_t > 0.0:
		p.derp_t -= dt
	if p.derp_t > 0.0 and possessor.is_empty():
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
	p.kill_streak_t = maxf(0.0, float(p.kill_streak_t) - dt)
	if p.kill_streak_t <= 0.0:
		p.kill_streak = 0
	p.push_cd = maxf(0.0, p.push_cd - dt)
	p.poss_cd = maxf(0.0, p.poss_cd - dt)
	p.poss_protect_cd = maxf(0.0, p.poss_protect_cd - dt)
	p.ability_cd = maxf(0.0, p.ability_cd - dt)
	p.ability_t = maxf(0.0, p.ability_t - dt)
	p.extra_cd = maxf(0.0, float(p.get("extra_cd", 0.0)) - dt)
	p.phase_t = maxf(0.0, float(p.phase_t) - dt)
	p.slow_t = maxf(0.0, float(p.get("slow_t", 0.0)) - dt)
	p.absorb_t = maxf(0.0, float(p.get("absorb_t", 0.0)) - dt)
	p.field_t = maxf(0.0, float(p.get("field_t", 0.0)) - dt)
	p.turret_t = maxf(0.0, float(p.get("turret_t", 0.0)) - dt)
	p.turret_cd = maxf(0.0, float(p.get("turret_cd", 0.0)) - dt)

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
		var speed_boost := 1.55 if p.kind == 0 and p.ability_t > 0.0 else (1.42 if (p.kind == 4 or p.kind == 14) and p.ability_t > 0.0 else 1.0)
		if float(p.get("slow_t", 0.0)) > 0.0:
			speed_boost *= 0.68
		if str(p.get("buff", "")) == "swift":
			speed_boost *= 1.28
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
	if want_extra and float(p.get("extra_cd", 0.0)) <= 0.0:
		_use_extra_ability(p)
	if effects.has("magnet"):
		var b := _brightest(p.id)
		if not b.is_empty():
			p.vel += (b.pos - p.pos).normalized() * 750.0 * dt
	p.pos += p.vel * dt
	_wall_bounce(p)

	var shot_cost: float = SHOT_COST
	if p.kind == 1:
		# Four stored shockwaves; recharge one charge at a time.
		if int(p.wave_ammo) < 4:
			p.wave_reload_t = maxf(0.0, float(p.wave_reload_t) - dt)
			if p.wave_reload_t <= 0.0:
				p.wave_ammo = int(p.wave_ammo) + 1
				p.wave_reload_t = CAPSULE_WAVE_RELOAD if int(p.wave_ammo) < 4 else 0.0
		# Fixed-radius shockwave fires immediately on a fresh press; holding does not charge it.
		if want_fire and (not p.fire_was_down or possessed_fire_press) and int(p.wave_ammo) > 0 and p.fire_cd <= 0.0 and p.light > shot_cost + 0.5:
			_capsule_shockwave(p)
			p.wave_ammo = int(p.wave_ammo) - 1
			if float(p.wave_reload_t) <= 0.0:
				p.wave_reload_t = CAPSULE_WAVE_RELOAD
		p.wave_charge = 0.0
		p.wave_released = false
		p.fire_was_down = want_fire
	elif want_fire and p.fire_cd <= 0.0 and p.light > shot_cost + 0.5:
		_fire_class_attack(p)


	var spd_ratio: float = p.vel.length() / SPEED
	p.light -= MOVE_COST * minf(spd_ratio, 1.2) * dt
	var in_zone := _in_zone(p.pos)
	if effects.has("invert"):
		in_zone = not in_zone
	p.light += REGEN_PASSIVE * dt
	if str(p.get("buff", "")) == "battery":
		p.light += 3.0 * dt
	if spd_ratio < 0.15:
		p.light += REGEN_STILL * dt
	if in_zone:
		p.light += REGEN_ZONE * dt
	# As the arena ages, its ambient energy fades; this is pressure, not a round timer.
	var arena_drain := clampf((time_left - 75.0) * 0.10, 0.0, 11.0)
	p.light -= arena_drain * dt
	p.light = clampf(p.light, 0.0, p.max_light)
	if p.light <= 0.0 and not p.decoy:
		# Credit a kill only for a recent hit; otherwise this is starvation (no stale kill credit).
		_make_shadow(p, p.last_hit if p.hit_age < 4.0 else 0, false)



func _spawn_class_bullet(p: Dictionary, direction: Vector2, speed: float, radius: float, damage_mult: float, life: float, extra: Dictionary = {}) -> void:
	var dir := direction.normalized()
	var bullet: Dictionary = {"id": next_id, "pos": p.pos + dir * 34.0, "vel": dir * speed + p.vel * 0.18,
		"owner": p.id, "life": life, "bn": 0, "ricochet": false,
		"dmg": BULLET_DMG * float(p.attack) * damage_mult * (1.35 if str(p.get("buff", "")) == "overdrive" else 1.0),
		"radius": radius, "vk": int(p.kind), "hit_ids": []}
	for key in extra:
		bullet[key] = extra[key]
	bullets.append(bullet)
	next_id += 1


func _fire_class_attack(p: Dictionary) -> void:
	var kind := int(p.kind)
	var aim: Vector2 = p.aim.normalized()
	var prism_active: bool = kind == 3 and int(p.get("prism_shots", 0)) > 0
	if prism_active:
		for i in 3:
			_spawn_class_bullet(p, aim.rotated((float(i) - 1.0) * 0.24), 1180.0, 7.0, 0.72, 1.4, {"ricochet": true})
		p.prism_shots = int(p.prism_shots) - 1
	elif kind == 0:
		for i in 3:
			_spawn_class_bullet(p, aim.rotated((float(i) - 1.0) * 0.12), 1120.0, 5.0, 0.42, 1.4, {"homing": 1.8})
	elif kind == 2:
		_spawn_class_bullet(p, aim, 1480.0, 7.0, 0.82, 1.55, {"pierce": 2})
	elif kind == 3:
		_spawn_class_bullet(p, aim, 1180.0, 11.0, 1.0, 1.5, {"split_on_wall": true})
	elif kind == 4:
		_chain_lightning(p)
	elif kind == 5:
		_spawn_class_bullet(p, aim, 980.0, 8.0, 0.92, 1.5, {"homing": 3.4})
	elif kind == 6:
		_spawn_class_bullet(p, aim, 900.0, 10.0, 0.9, 1.5, {"zone_on_hit": "slime"})
	elif kind == 7:
		_spawn_class_bullet(p, aim, 1050.0, 9.0, 0.9, 1.35, {"explosive": true})
	elif kind == 8:
		for i in 2:
			_spawn_class_bullet(p, aim.rotated(-0.13 if i == 0 else 0.13), 1320.0, 5.5, 0.58, 1.25)
	elif kind == 9:
		for i in 3:
			_spawn_class_bullet(p, aim.rotated((float(i) - 1.0) * 0.24), 1370.0, 5.0, 0.48, 1.15)
	elif kind == 10:
		_spawn_class_bullet(p, aim, 760.0, 13.0, 0.9, 1.7, {"zone_on_hit": "gravity"})
	elif kind == 11:
		_spawn_class_bullet(p, aim, 1240.0, 8.0, 0.95, 1.55, {"ricochet": true})
	elif kind == 12:
		_spawn_class_bullet(p, aim, 830.0, 10.0, 0.92, 1.45, {"zone_on_hit": "lava", "lob": true})
	elif kind == 13:
		_parasite_basic_attack(p)
	elif kind == 14:
		_spawn_class_bullet(p, aim, 1180.0, 7.0, 0.9, 1.35, {"wave": true})
	elif kind == 15:
		_spawn_class_bullet(p, aim, 650.0, 11.0, 0.72, 1.8, {"absorb_bubble": true})
	elif kind == 16:
		var turret_pos: Vector2 = (p.pos + aim * 105.0).clamp(Vector2(50, 50), A - Vector2(50, 50))
		var found := false
		for turret in attack_turrets:
			if int(turret.owner) == int(p.id):
				turret.pos = turret_pos
				turret.t = 4.0
				found = true
				break
		if not found:
			attack_turrets.append({"pos": turret_pos, "owner": p.id, "t": 4.0, "cd": 0.12})
	elif kind == 17:
		var polarity := int(p.get("polarity_mode", 1))
		_spawn_class_bullet(p, aim, 1160.0, 8.0, 0.9, 1.35, {"polarity": polarity})
		p.polarity_mode = -1 if polarity > 0 else 1
	elif kind == 18:
		_spawn_class_bullet(p, aim, 1580.0, 13.0, 0.78, 0.62, {"pierce": 4, "slash": true})
	p.light -= SHOT_COST
	var haste := 0.52 if kind == 0 and p.ability_t > 0.0 else 1.0
	p.fire_cd = float(p.fire_rate) * haste
	p.vel -= aim * 42.0
	events.append({"t": "shot", "x": p.pos.x, "y": p.pos.y, "c": p.ci})


func _parasite_basic_attack(p: Dictionary) -> void:
	var best: Dictionary = {}
	var best_dot := 0.72
	for target in players.values():
		if target.id == p.id or target.shadow or target.decoy or target.inv > 0.0:
			continue
		var offset: Vector2 = target.pos - p.pos
		var distance := offset.length()
		if distance > 350.0 or distance < 1.0:
			continue
		var alignment: float = p.aim.normalized().dot(offset / distance)
		if alignment > best_dot:
			best_dot = alignment
			best = target
	if not best.is_empty():
		_add_attack_beam(p.pos, best.pos, 13, 0.12)
		_damage(best, 10.0 * float(p.attack), p.id, false)
		var old_light: float = float(p.light)
		p.light = minf(float(p.max_light), float(p.light) + 2.0)
		if float(p.light) > old_light:
			p.healing_total = float(p.get("healing_total", 0.0)) + float(p.light) - old_light
			events.append({"t": "heal", "id": p.id, "amount": float(p.light) - old_light})


func _add_attack_beam(start_pos: Vector2, end_pos: Vector2, beam_kind: int, duration: float) -> void:
	attack_beams.append({"a": start_pos, "b": end_pos, "kind": beam_kind, "t": duration})


func _update_attack_beams(dt: float) -> void:
	var keep: Array = []
	for beam in attack_beams:
		beam.t = float(beam.t) - dt
		if float(beam.t) > 0.0:
			keep.append(beam)
	attack_beams = keep


func _spawn_attack_zone(pos: Vector2, owner_id: int, zone_kind: String, radius: float, duration: float) -> void:
	attack_zones.append({"pos": pos, "owner": owner_id, "kind": zone_kind, "r": radius, "t": duration, "hit_cd": {}})


func _update_attack_zones(dt: float) -> void:
	var keep: Array = []
	for zone in attack_zones:
		zone.t = float(zone.t) - dt
		var hit_cd: Dictionary = zone.hit_cd
		for player in players.values():
			if player.shadow or player.decoy or int(player.id) == int(zone.owner):
				continue
			if (player.pos as Vector2).distance_to(zone.pos) > float(zone.r):
				continue
			match str(zone.kind):
				"slime":
					player.slow_t = maxf(float(player.get("slow_t", 0.0)), 0.24)
				"gravity":
					player.vel += (zone.pos - player.pos).normalized() * 340.0 * dt
					player.slow_t = maxf(float(player.get("slow_t", 0.0)), 0.12)
				"lava":
					var cd := float(hit_cd.get(int(player.id), 0.0)) - dt
					if cd <= 0.0:
						_damage(player, 3.0, int(zone.owner), false)
						hit_cd[int(player.id)] = 0.55
					else:
						hit_cd[int(player.id)] = cd
		zone.hit_cd = hit_cd
		if float(zone.t) > 0.0:
			keep.append(zone)
	attack_zones = keep


func _update_attack_turrets(dt: float) -> void:
	var keep: Array = []
	for turret in attack_turrets:
		turret.t = float(turret.t) - dt
		turret.cd = float(turret.cd) - dt
		if float(turret.t) <= 0.0:
			continue
		if float(turret.cd) <= 0.0:
			var owner_id := int(turret.owner)
			if players.has(owner_id) and not players[owner_id].shadow:
				var owner: Dictionary = players[owner_id]
				var target := _nearest(owner, false)
				if not target.is_empty() and (target.pos as Vector2).distance_to(turret.pos) < 620.0:
					var direction: Vector2 = (target.pos - turret.pos).normalized()
					bullets.append({"id": next_id, "pos": turret.pos + direction * 20.0, "vel": direction * 1080.0,
						"owner": owner_id, "life": 0.9, "bn": 0, "ricochet": false,
						"dmg": BULLET_DMG * float(owner.attack) * 0.38, "radius": 4.5, "vk": 16, "hit_ids": []})
					next_id += 1
			turret.cd = 0.68
		keep.append(turret)
	attack_turrets = keep


func _capsule_shockwave(p: Dictionary) -> void:
	const WAVE_DAMAGE := 32.0
	const WAVE_PUSH := 760.0
	var wave_radius := CAPSULE_WAVE_RADIUS
	var center: Vector2 = p.pos
	for target in players.values():
		if target.id == p.id or target.shadow or target.decoy or target.inv > 0.0:
			continue
		var offset: Vector2 = target.pos - center
		var distance := offset.length()
		if distance > wave_radius:
			continue
		var direction: Vector2 = offset.normalized() if distance > 0.01 else p.aim
		var wave_damage: float = WAVE_DAMAGE * float(p.attack) * (1.35 if str(p.get("buff", "")) == "overdrive" else 1.0)
		if p.kind == 1 and int(target.get("kind", -1)) == 1:
			wave_damage *= 2.0
		_damage(target, wave_damage, p.id, false)
		target.vel += direction * WAVE_PUSH * (1.0 - 0.25 * distance / wave_radius)
	for eater in eaters:
		if eater.dead:
			continue
		var offset: Vector2 = eater.pos - center
		var distance := offset.length()
		if distance > wave_radius:
			continue
		eater.hp -= 3
		eater.flash = 0.18
		eater.vel += (offset.normalized() if distance > 0.01 else p.aim) * WAVE_PUSH * 0.65
		if eater.hp <= 0:
			eater.dead = true
			events.append({"t": "eat", "x": eater.pos.x, "y": eater.pos.y, "c": p.ci})
			var old_light: float = float(p.light)
			p.light = minf(p.max_light, p.light + 9.0)
			var healed: float = float(p.light) - old_light
			if healed > 0.01:
				p.healing_total = float(p.get("healing_total", 0.0)) + healed
				events.append({"t": "heal", "id": p.id, "amount": healed})
		else:
			events.append({"t": "hit", "x": eater.pos.x, "y": eater.pos.y, "c": p.ci})
	p.light -= SHOT_COST
	p.fire_cd = 0.08 # Capsule can rapidly tap through its four stored charges.
	events.append({"t": "shockwave", "x": center.x, "y": center.y, "c": p.ci, "r": wave_radius})
	shake_req = maxf(shake_req, 5.0)


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
			p.ability_t = 0.65
			p.inv = 0.65
			events.append({"t": "ability", "x": p.pos.x, "y": p.pos.y, "c": p.ci, "kind": 2})
		3:
			for i in 10:
				var dir := Vector2.from_angle(TAU * float(i) / 10.0)
				bullets.append({"id": next_id, "pos": p.pos + dir * 40.0, "vel": dir * 760.0,
					"owner": p.id, "life": 1.25, "bn": 0, "ricochet": true, "dmg": BULLET_DMG * p.attack * 0.82 * (1.35 if str(p.get("buff", "")) == "overdrive" else 1.0), "radius": 10.0})
				next_id += 1
			events.append({"t": "ability", "x": p.pos.x, "y": p.pos.y, "c": p.ci, "kind": 3})

		4:
			p.ability_t = 2.2
		5:
			p.field_t = 2.8
			p.field_mode = 1
		6:
			p.max_shield = 22.0
			p.shield_hp = 22.0
		7:
			_character_pulse(p, 230.0, 28.0, 420.0)
		8:
			p.pos = (p.pos + p.aim * 280.0).clamp(Vector2(40,40), A - Vector2(40,40))
			p.inv = 0.28
		9:
			p.special_shots = 5
		10:
			p.field_t = 3.2
			p.field_mode = 1
		11:
			p.special_shots = 5
		12:
			p.buff = "overdrive"
			p.buff_t = 3.0
		13:
			_drain_nearest(p, 20.0, 12.0)
		14:
			p.ability_t = 3.2
		15:
			p.absorb_t = 2.8
			p.absorb_count = 0
		16:
			p.turret_t = 5.0
			p.turret_cd = 0.1
		17:
			p.field_t = 2.5
			p.field_mode = 2
		18:
			p.phase_t = 1.0
			p.inv = maxf(float(p.inv), 1.0)


func _use_extra_ability(p: Dictionary) -> void:
	p.extra_cd = 13.0
	match int(p.kind):
		0:
			# Fireflies use bioluminescent signals: lure eaters to a bright decoy.
			var lure_pos: Vector2 = (p.pos + p.aim * 145.0).clamp(Vector2(55, 55), A - Vector2(55, 55))
			lures.append({"pos": lure_pos, "t": 3.8, "owner": p.id})
			p.light = maxf(0.0, float(p.light) - 3.0)
			events.append({"t": "extra_ability", "x": lure_pos.x, "y": lure_pos.y, "c": p.ci, "kind": 0})
		1:
			# A sealed capsule catches incoming energy and converts it into light.
			p.absorb_t = 2.4
			p.absorb_count = 0
			events.append({"t": "extra_ability", "x": p.pos.x, "y": p.pos.y, "c": p.ci, "kind": 1})
		2:
			# Ghost matter briefly stops interacting with projectiles and eaters.
			p.phase_t = 1.25
			p.inv = maxf(float(p.inv), 1.25)
			events.append({"t": "extra_ability", "x": p.pos.x, "y": p.pos.y, "c": p.ci, "kind": 2})
		3:
			# A prism splits the next three shots into refracted rays.
			p.prism_shots = 3
			events.append({"t": "extra_ability", "x": p.pos.x, "y": p.pos.y, "c": p.ci, "kind": 3})
		4:
			_chain_lightning(p)
		5, 6:
			p.field_t = 2.5
			p.field_mode = 2
		7:
			_character_pulse(p, 280.0, 34.0, 520.0)
		8:
			p.pos = (p.pos + p.aim * 390.0).clamp(Vector2(40,40), A - Vector2(40,40))
			p.inv = 0.35
		9, 15:
			p.max_shield = 30.0
			p.shield_hp = 30.0
		10:
			p.field_t = 2.5
			p.field_mode = 1
		11:
			for i in 5:
				var dir := Vector2.from_angle(p.aim.angle() + (float(i) - 2.0) * 0.22)
				bullets.append({"id":next_id,"pos":p.pos + dir * 34.0,"vel":dir * 1050.0,"owner":p.id,"life":1.35,"bn":0,"ricochet":true,"dmg":BULLET_DMG * p.attack * 0.58,"radius":6.0})
				next_id += 1
		12:
			_character_pulse(p, 205.0, 22.0, 620.0)
		13:
			_drain_nearest(p, 28.0, 18.0)
		14:
			_character_pulse(p, 220.0, 20.0, 760.0)
		15:
			var recovered := minf(float(p.get("shield_hp",0.0)), 24.0)
			p.shield_hp = maxf(0.0, float(p.get("shield_hp",0.0)) - recovered)
			p.light = minf(float(p.max_light), float(p.light) + recovered)
		16:
			p.turret_t = 8.0
			p.turret_cd = 0.1
		17:
			p.field_t = 2.8
			p.field_mode = 1 if int(p.get("field_mode",0)) == 2 else 2
		18:
			p.pos = (p.pos + p.aim * 260.0).clamp(Vector2(40,40), A - Vector2(40,40))
			p.inv = maxf(float(p.inv), 0.55)



func _character_pulse(p: Dictionary, radius: float, damage: float, push: float) -> void:
	for target in players.values():
		if target.id == p.id or target.shadow or target.decoy or target.inv > 0.0:
			continue
		var offset: Vector2 = target.pos - p.pos
		var distance := offset.length()
		if distance <= radius:
			var direction: Vector2 = offset.normalized() if distance > 0.01 else p.aim
			_damage(target, damage * float(p.attack) * (1.0 - 0.35 * distance / radius), p.id, false)
			target.vel += direction * push * (1.0 - 0.3 * distance / radius)
	events.append({"t":"ability","x":p.pos.x,"y":p.pos.y,"c":p.ci,"kind":p.kind})
	shake_req = maxf(shake_req, 9.0)


func _drain_nearest(p: Dictionary, damage: float, healing: float) -> void:
	var target := _nearest(p, false)
	if target.is_empty() or (target.pos as Vector2).distance_to(p.pos) > 360.0:
		return
	_damage(target, damage * float(p.attack), p.id, false)
	var old_light: float = float(p.light)
	p.light = minf(float(p.max_light), float(p.light) + healing)
	var restored := float(p.light) - old_light
	if restored > 0.01:
		p.healing_total = float(p.get("healing_total",0.0)) + restored
		events.append({"t":"heal","id":p.id,"amount":restored})


func _chain_lightning(p: Dictionary) -> void:
	var first := _nearest(p, false)
	if first.is_empty() or (first.pos as Vector2).distance_to(p.pos) > 300.0:
		return
	var origin: Vector2 = first.pos
	_add_attack_beam(p.pos, origin, 4, 0.14)
	_damage(first, 24.0 * float(p.attack), p.id, false)
	var second: Dictionary = {}
	var best_distance := 220.0 * 220.0
	for candidate in players.values():
		if candidate.id == p.id or candidate.id == first.id or candidate.shadow or candidate.decoy:
			continue
		var distance: float = candidate.pos.distance_squared_to(origin)
		if distance < best_distance:
			best_distance = distance
			second = candidate
	if not second.is_empty():
		_add_attack_beam(origin, second.pos, 4, 0.14)
		_damage(second, 15.0 * float(p.attack), p.id, false)


func _tick_character_fields(p: Dictionary, dt: float) -> void:
	if p.field_t > 0.0:
		for target in players.values():
			if target.id == p.id or target.shadow or target.decoy:
				continue
			var offset: Vector2 = p.pos - target.pos
			var distance := offset.length()
			if distance < 310.0 and distance > 1.0:
				var strength := (1.0 - distance / 310.0) * 520.0
				target.vel += offset.normalized() * strength * dt * (1.0 if int(p.field_mode) == 1 else -1.0)
	if p.turret_t > 0.0 and p.turret_cd <= 0.0:
		var target := _nearest(p, false)
		if not target.is_empty():
			var direction: Vector2 = (target.pos - p.pos).normalized()
			bullets.append({"id":next_id,"pos":p.pos + direction * 38.0,"vel":direction * 1050.0,"owner":p.id,"life":1.0,"bn":0,"ricochet":false,"dmg":BULLET_DMG * float(p.attack) * 0.55,"radius":5.0})
			next_id += 1
			p.turret_cd = 0.72

func _update_lures(dt: float) -> void:
	var keep: Array = []
	for lure in lures:
		lure.t = float(lure.t) - dt
		if float(lure.t) > 0.0:
			keep.append(lure)
	lures = keep


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
			if o.shadow or o.derp_t > 0.0 or o.poss_protect_cd > 0.0:
				continue
			var d: float = (o.pos - p.pos).length_squared()
			if d < bd:
				bd = d
				best = o
		if not best.is_empty():
			best.derp_t = 2.0
			best.derp_by = p.id
			best.poss_protect_cd = POSSESS_COOLDOWN
			p.poss_target = best.id
			p.poss_cd = POSSESS_COOLDOWN
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
	var damage_by: Dictionary = p.get("damage_by", {})
	var total_damage := 0.0
	for attacker_id in damage_by:
		total_damage += maxf(0.0, float(damage_by[attacker_id]))
	if total_damage > 0.0:
		# Split the kill heal between every living contributor by their share of damage.
		for attacker_id in damage_by:
			if not players.has(attacker_id):
				continue
			var contributor: Dictionary = players[attacker_id]
			if contributor.shadow or contributor.decoy:
				continue
			var share := KILL_BONUS * maxf(0.0, float(damage_by[attacker_id])) / total_damage
			var old_light: float = float(contributor.light)
			contributor.light = minf(contributor.max_light, contributor.light + share)
			contributor.healing_total = float(contributor.get("healing_total", 0.0)) + maxf(0.0, float(contributor.light) - old_light)
			var healed: float = float(contributor.light) - old_light
			if healed > 0.01:
				events.append({"t": "heal", "id": contributor.id, "amount": healed})
	elif killer != 0 and killer != p.id and players.has(killer):
		var fallback: Dictionary = players[killer]
		if not fallback.shadow and not fallback.decoy:
			var old_light: float = float(fallback.light)
			fallback.light = minf(fallback.max_light, fallback.light + KILL_BONUS)
			fallback.healing_total = float(fallback.get("healing_total", 0.0)) + maxf(0.0, float(fallback.light) - old_light)
			var healed: float = float(fallback.light) - old_light
			if healed > 0.01:
				events.append({"t": "heal", "id": fallback.id, "amount": healed})
	if killer != 0 and killer != p.id and players.has(killer):
		var k: Dictionary = players[killer]
		if not k.shadow:
			k.kills += 1
			if float(k.kill_streak_t) > 0.0:
				k.kill_streak = int(k.kill_streak) + 1
			else:
				k.kill_streak = 1
			k.kill_streak_t = 8.0
			var streak_bonus: int = mini(3, maxi(0, int(k.kill_streak) - 1))
			k.pts += 2 + streak_bonus
			if int(k.kill_streak) >= 2:
				events.append({"t": "streak", "id": k.id, "count": k.kill_streak, "bonus": streak_bonus})
		else:
			k.pts += 2 # Shadows still earn base chaos for a confirmed elimination.
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
	if float(p.get("phase_t", 0.0)) > 0.0:
		return
	var reduced: float = dmg * float(p.get("defense", 1.0)) * 0.90
	if p.kind == 1 and p.ability_t > 0.0:
		reduced *= 0.72
	var shield_before: float = float(p.get("shield_hp", 0.0))
	var shield_absorbed: float = minf(shield_before, reduced)
	p.shield_hp = maxf(0.0, shield_before - shield_absorbed)
	var health_damage: float = reduced - shield_absorbed
	p.light -= health_damage
	if shield_absorbed > 0.01:
		events.append({"t": "shield_hit", "id": p.id, "amount": shield_absorbed, "remaining": p.shield_hp})
	if health_damage > 0.01:
		events.append({"t": "hurt", "id": p.id, "amount": health_damage})
	if src != 0 and src != p.id and players.has(src) and not players[src].shadow and not players[src].decoy:
		players[src].damage_total = float(players[src].get("damage_total", 0.0)) + reduced
		var damage_by: Dictionary = p.get("damage_by", {})
		damage_by[src] = float(damage_by.get(src, 0.0)) + reduced
		p.damage_by = damage_by
	p.last_hit = src
	p.hit_age = 0.0
	p.hit_t = 0.14
	events.append({"t": "hit", "x": p.pos.x, "y": p.pos.y, "c": p.ci})
	shake_req = maxf(shake_req, 7.0)
	if src != 0 and players.has(src):
		var a: Dictionary = players[src]
		if not a.shadow:
			var old_light: float = float(a.light)
			a.light = minf(a.max_light, a.light + reduced * 0.35)
			var healed: float = float(a.light) - old_light
			if healed > 0.01:
				a.healing_total = float(a.get("healing_total", 0.0)) + healed
				events.append({"t": "heal", "id": a.id, "amount": healed})
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


func _meteor_tick(dt: float) -> void:
	meteor_timer -= dt
	if meteor_timer <= 0.0 and meteor_burst_left <= 0:
		meteor_burst_left = 9
		meteor_burst_timer = 0.0
		meteor_timer = rng.randf_range(20.0, 27.0)
	if meteor_burst_left > 0:
		meteor_burst_timer -= dt
		if meteor_burst_timer <= 0.0:
			var target := Vector2(rng.randf_range(100.0, A.x - 100.0), rng.randf_range(100.0, A.y - 100.0))
			meteors.append({"pos": target, "t": rng.randf_range(0.85, 1.25), "id": next_id})
			next_id += 1
			events.append({"t": "meteor_warn", "x": target.x, "y": target.y, "c": 0})
			meteor_burst_left -= 1
			meteor_burst_timer = 0.18
	var keep: Array = []
	for meteor in meteors:
		meteor.t -= dt
		if meteor.t > 0.0:
			keep.append(meteor)
			continue
		var center: Vector2 = meteor.pos
		const RADIUS := 138.0
		for p in players.values():
			if p.shadow or p.decoy:
				continue
			var offset: Vector2 = p.pos - center
			var distance := offset.length()
			if distance < RADIUS:
				var strength := 1.0 - distance / RADIUS
				var meteor_reduction: float = float(p.get("defense", 1.0)) * 0.90 * (0.72 if p.kind == 1 and p.ability_t > 0.0 else 1.0)
				var meteor_damage: float = float(p.max_light) * 0.5 / maxf(meteor_reduction, 0.01)
				_damage(p, meteor_damage, 0, false)
				p.vel += (offset.normalized() if distance > 0.01 else Vector2.UP) * (420.0 + 520.0 * strength)
		for eater in eaters:
			if not eater.dead and eater.pos.distance_to(center) < RADIUS:
				eater.hp -= 5
				eater.flash = 0.25
				if eater.hp <= 0:
					eater.dead = true
		events.append({"t": "meteor_impact", "x": center.x, "y": center.y, "c": 0, "r": RADIUS})
		shake_req = maxf(shake_req, 16.0)
	meteors = keep


func _match_event_tick(dt: float) -> void:
	if endless or not chaos_enabled:
		return
	match_event_timer -= dt
	if match_event_timer > 0.0:
		return
	match_event_timer = rng.randf_range(32.0, 42.0)
	if rng.randf() < 0.5:
		events.append({"t": "match_event", "kind": "surge"})
		for p in players.values():
			if not p.shadow and not p.decoy:
				var old_light: float = float(p.light)
				p.light = minf(p.max_light, p.light + 18.0)
				var healed: float = float(p.light) - old_light
				if healed > 0.01:
					p.healing_total = float(p.get("healing_total", 0.0)) + healed
					events.append({"t": "heal", "id": p.id, "amount": healed})
	else:
		events.append({"t": "match_event", "kind": "hunt"})
		for i in 3:
			if eaters.size() >= 7:
				break
			_spawn_eater(Vector2(rng.randf_range(80.0, A.x - 80.0), rng.randf_range(80.0, A.y - 80.0)), rng.randf() < 0.5)


func _update_bullets(dt: float) -> void:
	var keep: Array = []
	var bright := _brightest(0)
	var consumed_ids: Array = []
	for b in bullets:
		if consumed_ids.has(int(b.id)):
			continue
		b.life -= dt
		if float(b.get("homing", 0.0)) > 0.0:
			var target: Dictionary = {}
			var nearest_d := 1e18
			for candidate in players.values():
				if candidate.shadow or candidate.decoy or int(candidate.id) == int(b.owner):
					continue
				var candidate_d: float = b.pos.distance_squared_to(candidate.pos)
				if candidate_d < nearest_d:
					nearest_d = candidate_d
					target = candidate
			if not target.is_empty():
				var current_speed: float = b.vel.length()
				var desired: Vector2 = (target.pos - b.pos).normalized()
				b.vel = b.vel.normalized().lerp(desired, clampf(float(b.homing) * dt, 0.0, 1.0)).normalized() * current_speed
		if bool(b.get("lob", false)):
			b.vel.y += 390.0 * dt
		if effects.has("magnet") and not bright.is_empty() and bright.id != b.owner:
			var sp: float = b.vel.length()
			b.vel = (b.vel + (bright.pos - b.pos).normalized() * 2600.0 * dt).normalized() * sp
		if bool(b.get("wave", false)):
			b.wave_t = float(b.get("wave_t", 0.0)) + dt
			b.pos += b.vel * dt + b.vel.normalized().orthogonal() * sin(float(b.wave_t) * 8.0) * 78.0 * dt
		else:
			b.pos += b.vel * dt
		var dead: bool = b.life <= 0.0
		var bounce_on: bool = effects.has("bounce") or bool(b.get("ricochet", false))
		var bounce_limit: int = 2 if bool(b.get("ricochet", false)) else 4
		var bp: Vector2 = b.pos
		var bv: Vector2 = b.vel
		var hit_wall := bp.x < 0.0 or bp.x > A.x or bp.y < 0.0 or bp.y > A.y
		if hit_wall and bool(b.get("split_on_wall", false)):
			var split_dir: Vector2 = bv.normalized()
			for split_i in 3:
				var child_dir := split_dir.rotated((float(split_i) - 1.0) * 0.42)
				keep.append({"id": next_id, "pos": bp.clamp(Vector2(8, 8), A - Vector2(8, 8)), "vel": child_dir * 980.0,
					"owner": b.owner, "life": 0.8, "bn": 0, "ricochet": false, "dmg": float(b.dmg) * 0.42,
					"radius": 5.0, "vk": 3, "hit_ids": []})
				next_id += 1
			dead = true
		elif bp.x < 0.0 or bp.x > A.x:
			if bounce_on and b.bn < bounce_limit:
				bv.x = -bv.x
				bp.x = clampf(bp.x, 0.0, A.x)
				b.bn += 1
			else:
				dead = true
		if bp.y < 0.0 or bp.y > A.y:
			if bounce_on and b.bn < bounce_limit:
				bv.y = -bv.y
				bp.y = clampf(bp.y, 0.0, A.y)
				b.bn += 1
			else:
				dead = true
		b.pos = bp
		b.vel = bv
		if not dead:
			for p in players.values():
				if p.shadow or int(p.kind) != 1 or float(p.get("absorb_t", 0.0)) <= 0.0 or int(p.id) == int(b.owner):
					continue
				if p.pos.distance_squared_to(b.pos) <= 118.0 * 118.0:
					p.absorb_count = int(p.get("absorb_count", 0)) + 1
					var light_before: float = float(p.light)
					p.light = minf(float(p.max_light), float(p.light) + 4.0)
					var gained: float = float(p.light) - light_before
					if gained > 0.01:
						p.healing_total = float(p.get("healing_total", 0.0)) + gained
						events.append({"t": "heal", "id": p.id, "amount": gained})
					dead = true
					events.append({"t": "capsule_absorb", "x": b.pos.x, "y": b.pos.y, "c": p.ci, "id": p.id})
					break
		if not dead and bool(b.get("absorb_bubble", false)):
			for other in bullets:
				if int(other.id) == int(b.id) or int(other.owner) == int(b.owner) or consumed_ids.has(int(other.id)):
					continue
				var absorb_distance := float(b.get("radius", 11.0)) + float(other.get("radius", 6.0)) + 4.0
				if (other.pos as Vector2).distance_squared_to(b.pos) <= absorb_distance * absorb_distance:
					consumed_ids.append(int(other.id))
					b.radius = minf(21.0, float(b.radius) + 2.0)
					b.dmg = float(b.dmg) + 1.0
					break
		if not dead:
			for p in players.values():
				if p.shadow or p.inv > 0.0 or float(p.get("phase_t", 0.0)) > 0.0:
					continue
				if p.id == b.owner and b.bn == 0:
					continue
				if int(p.id) in b.get("hit_ids", []):
					continue
				if (p.pos - b.pos).length_squared() < pow(P_RADIUS + float(b.get("radius", 6.0)), 2):
					var hit_damage := float(b.get("dmg", BULLET_DMG))
					if players.has(b.owner) and int(players[b.owner].get("kind", -1)) == 1 and int(p.get("kind", -1)) == 1:
						hit_damage *= 2.0
					_damage(p, hit_damage, b.owner, b.bn > 0)
					if bool(b.get("explosive", false)):
						for splash_target in players.values():
							if splash_target.id == p.id or splash_target.id == b.owner or splash_target.shadow or splash_target.decoy:
								continue
							if (splash_target.pos as Vector2).distance_to(b.pos) <= 92.0:
								_damage(splash_target, hit_damage * 0.34, b.owner, false)
					var zone_kind := str(b.get("zone_on_hit", ""))
					if not zone_kind.is_empty():
						_spawn_attack_zone(b.pos, int(b.owner), zone_kind, 118.0 if zone_kind == "gravity" else 86.0, 2.8 if zone_kind == "slime" else 2.2)
					if int(b.get("polarity", 0)) != 0:
						p.vel += (p.pos - b.pos).normalized() * 430.0 * float(b.polarity)
					var pierce_left := int(b.get("pierce", 0))
					if pierce_left > 0:
						var hit_ids: Array = b.get("hit_ids", [])
						hit_ids.append(int(p.id))
						b.hit_ids = hit_ids
						b.pierce = pierce_left - 1
					else:
						dead = true
					break
		if not dead:
			for e in eaters:
				if (e.pos - b.pos).length_squared() < pow(e.r + float(b.get("radius", 8.0)), 2):
					e.hp -= 1
					e.flash = 0.1
					var zone_kind := str(b.get("zone_on_hit", ""))
					if not zone_kind.is_empty():
						_spawn_attack_zone(b.pos, int(b.owner), zone_kind, 84.0, 2.0)
					dead = true
					if e.hp <= 0:
						e.dead = true
						events.append({"t": "eat", "x": e.pos.x, "y": e.pos.y, "c": 0})
						if players.has(b.owner) and not players[b.owner].shadow:
							var eater_healer: Dictionary = players[b.owner]
							var old_light: float = float(eater_healer.light)
							eater_healer.light = minf(eater_healer.max_light, eater_healer.light + 9.0)
							var healed: float = float(eater_healer.light) - old_light
							if healed > 0.01:
								eater_healer.healing_total = float(eater_healer.get("healing_total", 0.0)) + healed
								events.append({"t": "heal", "id": eater_healer.id, "amount": healed})
					else:
						events.append({"t": "hit", "x": e.pos.x, "y": e.pos.y, "c": 0})
					break
		if not dead:
			keep.append(b)
	bullets = keep
	if not consumed_ids.is_empty():
		var filtered: Array = []
		for kept_bullet in bullets:
			if not consumed_ids.has(int(kept_bullet.id)):
				filtered.append(kept_bullet)
		bullets = filtered


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
		var target_pos: Vector2 = tgt.pos if not tgt.is_empty() else e.pos
		var lure_distance := 430.0 * 430.0
		for lure in lures:
			var lure_d: float = e.pos.distance_squared_to(lure.pos)
			if lure_d < lure_distance:
				lure_distance = lure_d
				target_pos = lure.pos
		if not tgt.is_empty() or lure_distance < 430.0 * 430.0:
			var sp := 180.0 if e.type == 0 else 300.0
			var dir: Vector2 = (target_pos - e.pos).normalized()
			e.vel = e.vel.lerp(dir * sp, clampf(3.5 * dt, 0.0, 1.0))
			if e.type == 1:
				e.vel += dir.orthogonal() * sin(time_left * 9.0 + e.id) * 260.0 * dt * 8.0
		e.pos += e.vel * dt
		for p in players.values():
			if p.shadow or float(p.get("phase_t", 0.0)) > 0.0:
				continue
			if (p.pos - e.pos).length_squared() < pow(e.r + P_RADIUS - 6.0, 2):
				if p.inv <= 0.0 and e.cd <= 0.0:
					e.cd = 0.85
					_damage(p, 5.0, 0, false)
					p.vel += (p.pos - e.pos).normalized() * 500.0
		keep.append(e)
	eaters = keep


# ---------------------------------------------------------- улучшения ----
func _update_pickups(dt: float) -> void:
	pickup_timer -= dt
	if pickup_timer <= 0.0:
		pickup_timer = rng.randf_range(13.0, 19.0)
		if pickups.size() < 3:
			var kinds := ["swift", "overdrive", "shield", "battery"]
			var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
			var pos := Vector2(rng.randf_range(100.0, A.x - 100.0), rng.randf_range(100.0, A.y - 100.0))
			pickups.append({"pos": pos, "kind": kind, "t": 13.0})
	var keep: Array = []
	for pickup in pickups:
		pickup.t -= dt
		if pickup.t <= 0.0:
			continue
		var collected := false
		for p in players.values():
			if p.shadow or p.decoy:
				continue
			if p.pos.distance_squared_to(pickup.pos) > 48.0 * 48.0:
				continue
			p.buff = pickup.kind
			p.buff_t = 9.0
			if pickup.kind == "shield":
				p.max_shield = float(p.max_light) * 0.40
				p.shield_hp = p.max_shield
			if pickup.kind == "battery":
				var old_light: float = float(p.light)
				p.light = minf(p.max_light, p.light + 32.0)
				var healed := float(p.light) - old_light
				p.healing_total = float(p.get("healing_total", 0.0)) + healed
				if healed > 0.01:
					events.append({"t": "heal", "id": p.id, "amount": healed})
			events.append({"t": "upgrade_pick", "id": p.id, "kind": pickup.kind, "x": p.pos.x, "y": p.pos.y, "c": p.ci})
			collected = true
			break
		if not collected:
			keep.append(pickup)
	pickups = keep
	for p in players.values():
		p.buff_t = maxf(0.0, float(p.get("buff_t", 0.0)) - dt)
		if p.buff_t <= 0.0:
			p.buff = ""
			p.shield_hp = 0.0
			p.max_shield = 0.0


# --------------------------------------------------------------- хаос ----
func _chaos_tick(dt: float) -> void:
	chaos_timer -= dt
	if chaos_timer > 0.0:
		return
	chaos_timer = 14.0 + rng.randf_range(-3.0, 3.0)
	trigger(CHAOS[rng.randi() % CHAOS.size()])
	var living_count := 0
	for p in players.values():
		if not p.shadow and not p.decoy:
			living_count += 1
	if living_count <= 3 and rng.randf() < 0.12:
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
			for i in 4:
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
				var old_light: float = float(a.light)
				a.light = minf(a.max_light, a.light + amt)
				var healed: float = float(a.light) - old_light
				if healed > 0.01:
					a.healing_total = float(a.get("healing_total", 0.0)) + healed
					events.append({"t": "heal", "id": a.id, "amount": healed})
				b.light = maxf(1.0, b.light - amt)
				events.append({"t": "hurt", "id": b.id, "amount": amt})
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
				var dmg: float = 48.0 if p.id == holder else 36.0 * (1.0 - d / 330.0)
				p.vel += (p.pos - c).normalized() * 800.0
				_damage(p, dmg, holder, false)
				if p.id != holder and players.has(holder):
					players[holder].pts += 1


# ---------------------------------------------------------------- боты ---
func _bot_think(p: Dictionary, dt: float) -> void:
	var inp := {"mv": Vector2.ZERO, "aim": p.pos + p.aim * 100.0, "fire": false, "dash": false, "poss": false, "ability": false, "extra_ability": false}
	var b: Dictionary = p.bot
	# Bots stay deliberately imperfect: they improve a little, but never become expert marksmen.
	b.skill = minf(0.38, float(b.get("skill", 0.04)) + dt * 0.0008)
	var skill: float = float(b.skill)
	b.t -= dt
	if p.shadow:
		var target := _nearest(p, false)
		if not target.is_empty():
			var to: Vector2 = target.pos - p.pos
			var distance := to.length()
			inp.mv = to.normalized() if distance > 1.0 else Vector2.ZERO
			inp.poss = distance < 125.0 and rng.randf() < 0.45
			if distance > 260.0 and p.dash_cd <= 0.0 and rng.randf() < 0.025:
				inp.dash = true
		inputs[p.id] = inp
		return
	if b.t <= 0.0:
		# Slow reactions and inconsistent movement make bots easier to read.
		b.t = lerpf(1.45, 0.85, skill) * rng.randf_range(0.75, 1.35)
		b.strafe = -1.0 if rng.randf() < 0.5 else 1.0
		b.want = lerpf(500.0, 420.0, skill) + rng.randf_range(-110.0, 110.0)
		b.seek_pickup = not pickups.is_empty() and rng.randf() < 0.48
	var mv := Vector2.ZERO
	if bool(b.get("seek_pickup", false)) and not pickups.is_empty():
		var nearest_pickup: Dictionary = {}
		var nearest_pickup_d := 520.0 * 520.0
		for pickup in pickups:
			var pickup_d: float = p.pos.distance_squared_to(pickup.pos)
			if pickup_d < nearest_pickup_d:
				nearest_pickup_d = pickup_d
				nearest_pickup = pickup
		if not nearest_pickup.is_empty():
			var pickup_dir: Vector2 = (nearest_pickup.pos - p.pos).normalized()
			mv += pickup_dir * 1.55
	for ghost in players.values():
		if ghost.id == p.id or not ghost.shadow:
			continue
		var ghost_delta: Vector2 = p.pos - ghost.pos
		var ghost_distance := ghost_delta.length()
		if ghost_distance < 165.0:
			mv += ghost_delta.normalized() * (1.2 if ghost_distance < 85.0 else 0.65)
	var tgt := _nearest(p, true)
	if not tgt.is_empty():
		var to: Vector2 = tgt.pos - p.pos
		var d := to.length()
		if p.ability_cd <= 0.0 and rng.randf() < dt * lerpf(0.10, 0.24, skill):
			inp.ability = true
		if float(p.get("extra_cd", 0.0)) <= 0.0 and rng.randf() < dt * 0.12:
			inp.extra_ability = true
		var dirv := to / maxf(d, 1.0)
		mv += dirv.orthogonal() * b.strafe * lerpf(0.35, 0.62, skill)
		if d > b.want + 90.0:
			mv += dirv * 0.75
		elif d < b.want - 100.0:
			mv -= dirv * 0.65
		# Bots lead targets poorly and their aim drifts noticeably.
		var lead: Vector2 = tgt.pos + tgt.vel * (d / BULLET_SPEED) * lerpf(0.12, 0.38, skill)
		var aim_error := lerpf(175.0, 105.0, skill)
		lead += Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * aim_error
		inp.aim = lead
		inp.fire = d < 620.0 and p.light > 20.0 and rng.randf() < 0.78
		if p.kind == 1:
			inp.fire = d < lerpf(185.0, 270.0, skill) and p.light > 20.0 and not p.fire_was_down and rng.randf() < 0.72
	if p.light < 20.0:
		var bz := Vector2(ZONES[0].x, ZONES[0].y)
		var bdz := 1e18
		for z in ZONES:
			var zp := Vector2(z.x, z.y)
			var dz := zp.distance_squared_to(p.pos)
			if dz < bdz:
				bdz = dz
				bz = zp
		mv = (bz - p.pos).normalized() * 0.65 + mv * 0.2
		if p.light < 8.0:
			inp.fire = false
	for e in eaters:
		var de: float = (e.pos - p.pos).length()
		if de < 170.0:
			mv += (p.pos - e.pos).normalized() * 0.8
			# They sometimes notice nearby eaters, but don't instantly snap aim to them.
			if de < 300.0 and p.light > 20.0 and rng.randf() < 0.18:
				inp.aim = e.pos + Vector2(rng.randf_range(-90.0, 90.0), rng.randf_range(-90.0, 90.0))
				if p.kind != 1:
					inp.fire = true
	if p.pos.x < 120.0: mv.x += 0.8
	if p.pos.x > A.x - 120.0: mv.x -= 0.8
	if p.pos.y < 120.0: mv.y += 0.8
	if p.pos.y > A.y - 120.0: mv.y -= 0.8
	if p.dash_cd <= 0.0:
		for bl in bullets:
			if bl.owner == p.id:
				continue
			var rel: Vector2 = p.pos - bl.pos
			var dodge_range := lerpf(72.0, 105.0, skill)
			if rel.length() < dodge_range and rel.length() > 0.01 and rel.normalized().dot(bl.vel.normalized()) > 0.94:
				inp.dash = rng.randf() < lerpf(0.08, 0.24, skill)
				mv += bl.vel.normalized().orthogonal() * b.strafe * 0.25
				break
		if not inp.dash and rng.randf() < 0.0015:
			inp.dash = true
	inp.mv = mv.limit_length(1.0)
	if effects.has("reverse"):
		inp.mv = -inp.mv
	inputs[p.id] = inp
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


func _end(id: int) -> void:
	phase = "over"
	winner = id
	events.append({"t": "win", "id": id})


# ------------------------------------------------------------ снапшот ----
func snapshot() -> Dictionary:
	var pl: Array = []
	for p in players.values():
		var lure_remaining := 0.0
		for lure in lures:
			if int(lure.get("owner", 0)) == int(p.id):
				lure_remaining = maxf(lure_remaining, float(lure.get("t", 0.0)))
		pl.append({"i": p.id, "n": p.name, "p": p.pos, "v": p.vel, "a": p.aim, "l": p.light,
			"s": p.shadow, "k": p.kind, "c": p.ci, "hat": p.hat, "outfit": p.outfit,
			"iv": p.inv, "dc": p.dash_cd, "pt": p.pts, "wc": 0.0, "wa": int(p.wave_ammo), "wr": float(p.wave_reload_t),
			"hpmax": p.max_light, "sh": float(p.get("shield_hp", 0.0)), "shmax": float(p.get("max_shield", 0.0)), "acd": p.ability_cd, "ab": p.ability_t, "excd": float(p.get("extra_cd", 0.0)), "phs": float(p.get("phase_t", 0.0)), "abs": float(p.get("absorb_t", 0.0)), "lu_t": lure_remaining, "pr": int(p.get("prism_shots", 0)), "bot": not p.human,
			"ki": p.kills, "dm": float(p.get("damage_total", 0.0)), "hl": float(p.get("healing_total", 0.0)), "buff": str(p.get("buff", "")), "buff_t": float(p.get("buff_t", 0.0)), "dr": p.derp_t, "d": p.decoy, "h": p.hit_t, "dt": p.dash_t > 0.0})
	var pu: Array = []
	for pickup in pickups:
		pu.append([pickup.pos, pickup.kind, pickup.t])
	var lu: Array = []
	for lure in lures:
		lu.append([lure.pos, float(lure.t)])
	var mt: Array = []
	for meteor in meteors:
		mt.append([meteor.pos, float(meteor.t)])
	var ob: Array = []
	for obstacle in obstacles:
		ob.append([obstacle.pos, float(obstacle.r), float(obstacle.hp), float(obstacle.max_hp)])
	var bl: Array = []
	for b in bullets:
		var visual_kind := int(b.get("vk", players.get(b.owner, {}).get("kind", 0)))
		bl.append([b.id, b.pos, b.vel, b.owner, b.bn, visual_kind, float(b.get("radius", 6.0)), bool(b.get("absorb_bubble", false)), int(b.get("polarity", 0))])
	var az: Array = []
	for zone in attack_zones:
		az.append([zone.pos, str(zone.kind), float(zone.r), float(zone.t)])
	var at: Array = []
	for turret in attack_turrets:
		at.append([turret.pos, int(turret.owner), float(turret.t)])
	var abm: Array = []
	for beam in attack_beams:
		abm.append([beam.a, beam.b, int(beam.kind), float(beam.t)])
	var ea: Array = []
	for e in eaters:
		ea.append([e.id, e.pos, e.vel, e.type, e.hp, e.flash])
	return {"pl": pl, "bl": bl, "ea": ea, "lu": lu, "az": az, "at": at, "abm": abm, "fx": effects.duplicate(), "tl": time_left,
		"ph": phase, "wn": winner, "bomb": bomb_id, "bt": bomb_t, "mt": mt, "ob": ob, "pu": pu, "elapsed": elapsed_time}
