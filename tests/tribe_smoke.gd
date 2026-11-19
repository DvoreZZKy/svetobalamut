extends SceneTree
## Headless smoke test for the independent TRIBE scene and its core loop.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state := root.get_node("G")
	state.set("mode", "single")
	state.set("game_mode", "tribe")
	state.set("cfg", [
		{"id": 1, "name": "QA", "human": true, "color": 0, "kind": 0, "outfit": 0, "hat": 0},
		{"id": -1, "name": "Bot", "human": false}
	])
	var result := change_scene_to_file("res://scenes/tribe.tscn")
	if result != OK:
		push_error("Could not load TRIBE scene: %s" % error_string(result))
		quit(1)
		return
	await process_frame
	await process_frame
	var scene := current_scene
	if not is_instance_valid(scene) or scene.get_script() != load("res://scripts/tribe.gd"):
		push_error("TRIBE scene did not mount its dedicated controller")
		quit(1)
		return
	if scene.players.size() != 2 or scene.ores.size() < 8 or scene.foods.is_empty():
		push_error("TRIBE world did not initialize players, ores, and food")
		quit(1)
		return
	var player: Dictionary = scene.players[1]
	player.pos = scene.ores[0].pos
	player["input"] = {"move": Vector2.ZERO, "mine": true, "eat": false, "attack": false, "aim": Vector2.RIGHT}
	scene._simulate(1.25)
	if int(player.ore) != 1 or int(player.money) <= 0 or float(player.xp) <= 0.0:
		push_error("Mining did not grant ore, currency, and age experience")
		quit(1)
		return
	player.xp = 100.0
	scene._level_up(player)
	if int(player.age) != 2 or int(player.weapon) < 1:
		push_error("Age progression did not unlock the basic weapon")
		quit(1)
		return
	print("TRIBE smoke test passed: scene, players, resources, mining, and age unlock")
	quit(0)
