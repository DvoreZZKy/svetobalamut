extends SceneTree
## Headless simulation check: bots play full matches, every chaos effect is triggered,
## and core invariants (effects expire, stats stay consistent, match ends) are verified.
## Run: godot --headless --path . --script res://tests/sim_smoke.gd

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	failures.append(msg)
	push_error("SIM TEST FAILED: " + msg)


func _run() -> void:
	var global_state := root.get_node("G")
	global_state.set("mode", "single")
	global_state.set("tutorial_active", false)
	var cfg: Array = [{"id": 1, "name": "QA", "human": true, "color": 0, "kind": 0, "outfit": 0, "hat": 0}]
	for i in 5:
		cfg.append({"id": -(i + 1), "name": "Bot %d" % i, "human": false})
	global_state.set("cfg", cfg)
	var result := change_scene_to_file("res://scenes/arena.tscn")
	if result != OK:
		push_error("Could not load arena scene")
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	arena.set_process(false)  # this test steps the simulation by hand
	var sim = arena.sim
	if sim == null:
		push_error("Arena has no simulation")
		quit(1)
		return

	# 1) Every chaos effect can be triggered, timed effects stay within 2x duration, nothing crashes.
	sim.reset(cfg)
	for name in Sim.CHAOS:
		sim.trigger(name)
		sim.trigger(name)  # stacking
		for pid in sim.players:
			var p: Dictionary = sim.players[pid]
			if is_nan(float(p.light)) or float(p.light) > float(p.max_light) + 0.01:
				_fail("light out of range after chaos '%s'" % name)
	for name in Sim.DUR:
		if sim.effects.has(name) and float(sim.effects[name]) > float(Sim.DUR[name]) * 2.0 + 0.01:
			_fail("effect '%s' stacked beyond twice its duration" % name)

	# 2) Class swap ('steal') keeps class stats consistent with the class.
	sim.reset(cfg)
	for i in 10:
		sim.trigger("steal")
	for pid in sim.players:
		var p: Dictionary = sim.players[pid]
		var st: Dictionary = Sim.CLASS_STATS[int(p.kind)]
		if not is_equal_approx(float(p.max_light), float(st.hp)) or not is_equal_approx(float(p.defense), float(st.def)):
			_fail("player %s has stats that don't match class %d after steal" % [str(pid), int(p.kind)])

	# 2a) The arena has four corner regeneration zones.
	if Sim.ZONES.size() != 4:
		_fail("arena must have four regeneration zones")

	# 2aa) Kill healing is split between all damage contributors by damage share.
	var heal_cfg: Array = [
		{"id": 1, "name": "Attacker A", "human": true, "color": 0, "kind": 0, "outfit": 0, "hat": 0},
		{"id": 2, "name": "Attacker B", "human": true, "color": 1, "kind": 1, "outfit": 0, "hat": 0},
		{"id": 3, "name": "Victim", "human": true, "color": 2, "kind": 2, "outfit": 0, "hat": 0}
	]
	sim.reset(heal_cfg)
	sim.chaos_enabled = false
	var attacker_a: Dictionary = sim.players[1]
	var attacker_b: Dictionary = sim.players[2]
	var victim: Dictionary = sim.players[3]
	attacker_a.light = 80.0
	attacker_b.light = 80.0
	victim.light = 40.0
	sim._damage(victim, 10.0, 1, false)
	sim._damage(victim, 30.0, 2, false)
	sim._damage(victim, 25.0, 2, false)
	var damage_a := 10.0 * float(victim.defense) * 0.90
	var damage_b := 55.0 * float(victim.defense) * 0.90
	var total_damage := damage_a + damage_b
	var expected_a := 80.0 + damage_a * 0.35 + Sim.KILL_BONUS * (damage_a / total_damage)
	var expected_b := 80.0 + damage_b * 0.35 + Sim.KILL_BONUS * (damage_b / total_damage)
	if not victim.shadow or not is_equal_approx(float(attacker_a.light), expected_a) or not is_equal_approx(float(attacker_b.light), expected_b):
		_fail("kill healing was not split proportionally between damage contributors")

	# 2a) Sustained class damage must exceed the strongest possible stationary zone regeneration.
	if not is_equal_approx(Sim.REGEN_PASSIVE, 2.5) or not is_equal_approx(Sim.REGEN_STILL, 2.0) or not is_equal_approx(Sim.REGEN_ZONE, 5.0):
		_fail("light regeneration constants do not match the current balance")
	var max_regen := Sim.REGEN_PASSIVE + Sim.REGEN_STILL + Sim.REGEN_ZONE
	for kind in 4:
		var st: Dictionary = Sim.CLASS_STATS[kind]
		var raw_dps: float
		if kind == 0:
			raw_dps = 3.0 * Sim.BULLET_DMG * float(st.atk) * 0.42 / float(st.rate)
		elif kind == 1:
			raw_dps = 24.0 * float(st.atk) / float(st.rate)
		else:
			raw_dps = Sim.BULLET_DMG * float(st.atk) / float(st.rate)
		var dps_vs_toughest := raw_dps * 0.95
		if dps_vs_toughest <= max_regen:
			_fail("class %d sustained DPS (%.2f) does not beat max regeneration (%.2f)" % [kind, dps_vs_toughest, max_regen])

	# 2b) Every class must sustain active movement + continuous firing for a meaningful interval.
	for kind in 4:
		var class_cfg: Array = [{"id": 1, "name": "QA", "human": true, "color": 0, "kind": kind, "outfit": 0, "hat": 0}]
		sim.reset(class_cfg)
		sim.chaos_enabled = false
		sim.eater_timer = 999.0
		sim.meteor_timer = 9999.0
		sim.pickup_timer = 9999.0
		var player: Dictionary = sim.players[1]
		if float(player.max_light) < 120.0:
			_fail("class %d starts with too little light" % kind)
		sim.inputs[1] = {"mv": Vector2(1, 0), "aim": player.pos + Vector2.LEFT * 500.0, "fire": true}
		for frame in int(30.0 * 60.0):
			sim.step(1.0 / 60.0)
		if not sim.players.has(1) or float(sim.players[1].light) < 80.0:
			_fail("class %d cannot sustain 30 seconds of movement and firing" % kind)
		# Contact with one hazard should be pressure, not a near-instant knockout.
		sim.reset(class_cfg)
		sim.chaos_enabled = false
		sim.eater_timer = 999.0
		sim.meteor_timer = 9999.0
		sim.pickup_timer = 9999.0
		player = sim.players[1]
		sim._spawn_eater(player.pos + Vector2(18, 0), false)
		for frame in int(5.0 * 60.0):
			sim.step(1.0 / 60.0)
		if not sim.players.has(1) or float(sim.players[1].light) < 80.0:
			_fail("class %d takes excessive damage from a single eater" % kind)
	sim.chaos_enabled = true

	# 2a9) Ghost's Q phase window is timed and exposed like other active abilities.
	sim.reset([{"id": 1, "name": "Ghost", "human": true, "color": 0, "kind": 2, "outfit": 0, "hat": 0}])
	sim.chaos_enabled = false
	var ghost_duration_player: Dictionary = sim.players[1]
	sim._use_ability(ghost_duration_player)
	if not is_equal_approx(float(ghost_duration_player.ability_t), 0.65):
		_fail("ghost's timed Q ability duration was not started")

	# 2aa) Timed ability durations are exposed to the HUD snapshot and count down.
	sim.reset(cfg)
	sim.chaos_enabled = false
	var duration_player: Dictionary = sim.players[1]
	duration_player.ability_t = 2.8
	sim.lures.append({"pos": duration_player.pos, "t": 3.8, "owner": duration_player.id})
	var duration_snapshot: Dictionary = sim.snapshot()
	var duration_snapshot_player: Dictionary = duration_snapshot.pl[0]
	if not is_equal_approx(float(duration_snapshot_player.get("ab", 0.0)), 2.8) or not is_equal_approx(float(duration_snapshot_player.get("lu_t", 0.0)), 3.8):
		_fail("active ability durations were not included in the player snapshot")
	sim.step(0.5)
	duration_snapshot = sim.snapshot()
	duration_snapshot_player = duration_snapshot.pl[0]
	if not is_equal_approx(float(duration_snapshot_player.get("ab", 0.0)), 2.3) or not is_equal_approx(float(duration_snapshot_player.get("lu_t", 0.0)), 3.3):
		_fail("active ability duration indicators did not count down")

	# 2ab) Meteor impact removes half of the player's maximum light reserve.
	sim.reset(cfg)
	sim.chaos_enabled = false
	sim.meteor_timer = 9999.0
	var meteor_target: Dictionary = sim.players[1]
	meteor_target.pos = Vector2(800, 450)
	var meteor_light_before := float(meteor_target.light)
	sim.meteors.append({"pos": meteor_target.pos, "t": 0.0, "id": 500})
	sim._meteor_tick(1.0 / 60.0)
	if not is_equal_approx(meteor_light_before - float(meteor_target.light), float(meteor_target.max_light) * 0.5):
		_fail("meteor impact did not remove 50% of maximum light")

	# 2ac) Shield durability absorbs damage before light and is replicated in snapshots.
	sim.reset(cfg)
	sim.chaos_enabled = false
	var shield_target: Dictionary = sim.players[1]
	shield_target.shield_hp = 20.0
	shield_target.max_shield = 50.0
	var shield_light_before := float(shield_target.light)
	var expected_shield_damage := 10.0 * float(shield_target.defense) * 0.90
	sim._damage(shield_target, 10.0, 0, false)
	var expected_shield_left := 20.0 - expected_shield_damage
	if not is_equal_approx(float(shield_target.shield_hp), expected_shield_left) or not is_equal_approx(float(shield_target.light), shield_light_before):
		_fail("shield did not absorb incoming damage before light")
	var shield_snapshot: Dictionary = sim.snapshot()
	var shield_snapshot_player: Dictionary = shield_snapshot.pl[0]
	if not is_equal_approx(float(shield_snapshot_player.get("sh", 0.0)), expected_shield_left) or not is_equal_approx(float(shield_snapshot_player.get("shmax", 0.0)), 50.0):
		_fail("shield durability was not included in the player snapshot")

	# 2d) Capsule's primary attack is a radial melee shockwave, not a projectile.
	var melee_cfg: Array = [
		{"id": 1, "name": "Capsule", "human": true, "color": 0, "kind": 1, "outfit": 0, "hat": 0},
		{"id": 2, "name": "Nearby", "human": true, "color": 1, "kind": 0, "outfit": 0, "hat": 0},
		{"id": 3, "name": "Far", "human": true, "color": 2, "kind": 0, "outfit": 0, "hat": 0}
	]
	sim.reset(melee_cfg)
	sim.chaos_enabled = false
	var capsule: Dictionary = sim.players[1]
	var nearby: Dictionary = sim.players[2]
	var far_player: Dictionary = sim.players[3]
	capsule.pos = Vector2(800, 450)
	nearby.pos = capsule.pos + Vector2(100, 0)
	far_player.pos = capsule.pos + Vector2(260, 0)
	var nearby_light := float(nearby.light)
	var far_light := float(far_player.light)
	sim._capsule_shockwave(capsule)
	if float(nearby.light) >= nearby_light or nearby.vel.length() < 100.0:
		_fail("capsule shockwave did not damage and push a nearby player")
	if not is_equal_approx(float(far_player.light), far_light):
		_fail("capsule shockwave damaged a player outside its radius")
	if not sim.bullets.is_empty():
		_fail("capsule shockwave unexpectedly spawned a projectile")

	# 2e) Every class has a working secondary ability on the dedicated F input.
	for kind in 4:
		var extra_cfg: Array = [{"id": 1, "name": "Extra QA", "human": true, "color": 0, "kind": kind, "outfit": 0, "hat": 0}]
		sim.reset(extra_cfg)
		sim.chaos_enabled = false
		var extra_player: Dictionary = sim.players[1]
		sim._use_extra_ability(extra_player)
		if float(extra_player.extra_cd) <= 0.0:
			_fail("class %d secondary ability did not start its cooldown" % kind)
		match kind:
			0:
				if sim.lures.size() != 1:
					_fail("firefly bioluminescence did not create a lure")
			1:
				if float(extra_player.absorb_t) <= 0.0:
					_fail("capsule shell did not activate")
			2:
				if float(extra_player.phase_t) <= 0.0:
					_fail("ghost phasing did not activate")
			3:
				if int(extra_player.prism_shots) != 3:
					_fail("crystal prism did not charge three refracted shots")
	# Crystal's prism charges are visible in the HUD snapshot and consumed one per shot.
	sim.reset([{"id": 1, "name": "Crystal", "human": true, "color": 0, "kind": 3, "outfit": 0, "hat": 0}])
	sim.chaos_enabled = false
	var crystal_charge_player: Dictionary = sim.players[1]
	sim._use_extra_ability(crystal_charge_player)
	if int(sim.snapshot().pl[0].get("pr", 0)) != 3:
		_fail("crystal prism charges were not exposed to the HUD snapshot")
	sim.inputs[1] = {"fire": true, "aim": crystal_charge_player.pos + Vector2.RIGHT * 300.0}
	sim._update_player(crystal_charge_player, 1.0 / 60.0)
	if int(crystal_charge_player.get("prism_shots", 0)) != 2:
		_fail("crystal did not consume exactly one prism charge per shot")

	# Expanded character roster: every new class has a distinct profile and both abilities activate.
	if Sim.CLASS_STATS.size() != 18:
		_fail("expected 18 playable classes, found %d" % Sim.CLASS_STATS.size())
	var class_names: Array[String] = []
	for kind in Sim.CLASS_STATS.size():
		var class_data: Dictionary = Sim.CLASS_STATS[kind]
		if class_names.has(str(class_data.name)):
			_fail("duplicate class name: %s" % str(class_data.name))
		class_names.append(str(class_data.name))
		if kind < 4:
			continue
		sim.reset([{"id": 1, "name": "Roster QA", "human": true, "color": 0, "kind": kind, "outfit": 0, "hat": 0}])
		sim.chaos_enabled = false
		var roster_player: Dictionary = sim.players[1]
		sim._use_ability(roster_player)
		if float(roster_player.ability_cd) <= 0.0:
			_fail("class %d Q ability did not start cooldown" % kind)
		sim._use_extra_ability(roster_player)
		if float(roster_player.extra_cd) <= 0.0:
			_fail("class %d F ability did not start cooldown" % kind)
		if float(roster_player.max_light) < 100.0 or float(roster_player.max_light) > 160.0:
			_fail("class %d has invalid max light" % kind)

	# Capsule shell absorbs an incoming shot and converts it into light.
	sim.reset(melee_cfg)
	sim.chaos_enabled = false
	capsule = sim.players[1]
	capsule.pos = Vector2(800, 450)
	capsule.absorb_t = 1.0
	capsule.light = 80.0
	var shell_light: float = float(capsule.light)
	sim.bullets.append({"id": 99, "pos": capsule.pos + Vector2(70, 0), "vel": Vector2.ZERO, "owner": 2, "life": 1.0, "bn": 0, "ricochet": false, "dmg": 10.0, "radius": 6.0})
	sim._update_bullets(1.0 / 60.0)
	if not sim.bullets.is_empty() or float(capsule.light) <= shell_light:
		_fail("capsule shell failed to absorb a nearby projectile")
	# Ghost phase must reject direct damage as well as projectile/eater collisions.
	sim.reset(melee_cfg)
	sim.chaos_enabled = false
	var ghost: Dictionary = sim.players[1]
	ghost.phase_t = 1.0
	var ghost_light: float = float(ghost.light)
	sim._damage(ghost, 20.0, 2, false)
	if not is_equal_approx(float(ghost.light), ghost_light):
		_fail("ghost took damage while phased")

	# 2c) A match does not end because of elapsed time; the last glowing player wins.
	var winner_cfg: Array = [
		{"id": 1, "name": "Last Light", "human": true, "color": 0, "kind": 0, "outfit": 0, "hat": 0},
		{"id": 2, "name": "Shadow A", "human": true, "color": 1, "kind": 1, "outfit": 0, "hat": 0},
		{"id": 3, "name": "Shadow B", "human": true, "color": 2, "kind": 2, "outfit": 0, "hat": 0}
	]
	sim.reset(winner_cfg)
	sim.chaos_enabled = false
	sim.time_left = 99999.0
	sim._check_end()
	if sim.phase != "play":
		_fail("match ended because of elapsed time")
	sim.players[2].shadow = true
	sim.players[3].shadow = true
	sim._check_end()
	if sim.winner != 1:
		_fail("the last glowing player was not declared winner")

	# 2c) Possession cooldown applies to both the shadow and the possessed player.
	var poss_cfg: Array = [
		{"id": 1, "name": "Shadow A", "human": true, "color": 0, "kind": 0, "outfit": 0, "hat": 0},
		{"id": 2, "name": "Target", "human": true, "color": 1, "kind": 1, "outfit": 0, "hat": 0},
		{"id": 3, "name": "Shadow B", "human": true, "color": 2, "kind": 2, "outfit": 0, "hat": 0}
	]
	sim.reset(poss_cfg)
	sim.chaos_enabled = false
	var shadow_a: Dictionary = sim.players[1]
	var target: Dictionary = sim.players[2]
	var shadow_b: Dictionary = sim.players[3]
	shadow_a.shadow = true
	shadow_b.shadow = true
	shadow_a.pos = Vector2(700, 450)
	target.pos = Vector2(720, 450)
	shadow_b.pos = Vector2(710, 450)
	sim.inputs[1] = {"poss": true}
	sim.step(1.0 / 60.0)
	if int(shadow_a.poss_target) != 2:
		_fail("first shadow could not possess a nearby target")
	if not is_equal_approx(float(shadow_a.poss_cd), Sim.POSSESS_COOLDOWN):
		_fail("possessor did not receive the possession cooldown")
	if not is_equal_approx(float(target.poss_protect_cd), Sim.POSSESS_COOLDOWN - 1.0 / 60.0):
		_fail("target did not receive possession protection cooldown")
	sim.inputs[1] = {}
	sim.inputs[3] = {"poss": true}
	for frame in int(2.5 * 60.0):
		sim.step(1.0 / 60.0)
	if int(shadow_b.poss_target) != 0:
		_fail("a protected player was possessed again before cooldown expired")

	# 3) Effects and temporary state expire; eaters stay capped under repeated rain.
	sim.reset(cfg)
	for i in 6:
		sim.trigger("rain")
	if sim.eaters.size() > Sim.MAX_EATERS_RAIN:
		_fail("rain exceeded eater cap: %d" % sim.eaters.size())
	sim.reset(cfg)
	sim.chaos_enabled = false
	sim.trigger("invert")
	sim.trigger("reverse")
	sim.trigger("blind")
	for i in int(20.0 * 60.0):
		sim.step(1.0 / 60.0)
	if not sim.effects.is_empty():
		_fail("effects did not expire: %s" % str(sim.effects.keys()))
	sim.chaos_enabled = true

	# 4) A full bot match always finishes with a winner; no NaN positions.
	var finished := 0
	for match_i in 3:
		sim.reset(cfg)
		var steps := 0
		while sim.phase == "play" and steps < 16000:
			sim.step(1.0 / 60.0)
			sim.events.clear()
			steps += 1
			for pid in sim.players:
				var pos: Vector2 = sim.players[pid].pos
				if is_nan(pos.x) or is_nan(pos.y):
					_fail("NaN position in match %d" % match_i)
					break
		if sim.phase == "over" and sim.players.has(sim.winner):
			finished += 1
		else:
			_fail("match %d did not finish with a valid winner (steps=%d)" % [match_i, steps])
	# 5) Tutorial mode never ends by itself.
	sim.reset(cfg)
	sim.endless = true
	sim.chaos_enabled = false
	for i in int(300.0 * 60.0):
		sim.step(1.0 / 60.0)
	if sim.phase != "play":
		_fail("endless (tutorial) simulation ended on its own")
	sim.endless = false

	# 6) Network input from a client is sanitised.
	var net := root.get_node("Net")
	var cleaned: Dictionary = net.call("sanitize_input", {"mv": Vector2(50, 50), "aim": "junk", "fire": "yes", "ability": true})
	if (cleaned["mv"] as Vector2).length() > 1.001:
		_fail("client movement vector was not clamped")
	if cleaned["fire"] != false or cleaned["ability"] != true:
		_fail("client booleans were not sanitised")
	var profile: Dictionary = net.call("sanitize_profile", {"color": 99, "kind": -4, "outfit": "x", "hat": 2})
	if profile["color"] != 7 or profile["kind"] != 0 or profile["outfit"] != 0 or profile["hat"] != 2:
		_fail("client profile was not clamped: %s" % str(profile))

	arena.queue_free()
	await process_frame
	if failures.is_empty():
		print("Sim smoke test passed: chaos, class swap, expiry, full bot matches, tutorial endless mode, net sanitising")
		quit(0)
	else:
		quit(1)
