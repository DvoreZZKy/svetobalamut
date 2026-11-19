extends SceneTree

const TUTORIAL_SCRIPT := preload("res://scripts/arena_tutorial.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	G.mode = "single"
	G.tutorial_active = true
	G.tutorial_return_to_lobby = false
	G.cfg = [
		{"id": 1, "name": "QA", "human": true, "color": 0, "kind": 0, "outfit": 0, "hat": 0},
		{"id": -1, "name": "Training bot A", "human": false},
		{"id": -2, "name": "Training bot B", "human": false},
		{"id": -3, "name": "Training bot C", "human": false}
	]
	var result := change_scene_to_file("res://scenes/arena.tscn")
	if result != OK:
		push_error("Could not load arena scene: %s" % error_string(result))
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	if not is_instance_valid(arena):
		push_error("Arena scene did not become current_scene")
		quit(1)
		return
	var tutorial_found := false
	for child in arena.get_children():
		if child.get_script() == TUTORIAL_SCRIPT:
			tutorial_found = true
			break
	if not tutorial_found:
		push_error("Interactive tutorial controller was not attached to the arena")
		quit(1)
		return
	if not G.tutorial_active:
		push_error("Tutorial flag was unexpectedly cleared during arena startup")
		quit(1)
		return
	print("Tutorial smoke test passed: arena and interactive tutorial controller are active")
	quit(0)
