extends SceneTree
## Headless integration check: verifies that the arena actually mounts the guided tutorial.

const TUTORIAL_SCRIPT := preload("res://scripts/arena_tutorial.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var global_state := root.get_node("G")
	global_state.set("mode", "single")
	global_state.set("tutorial_active", true)
	global_state.set("tutorial_return_to_lobby", false)
	global_state.set("cfg", [
		{"id": 1, "name": "QA", "human": true, "color": 0, "kind": 0, "outfit": 0, "hat": 0},
		{"id": -1, "name": "Training bot A", "human": false},
		{"id": -2, "name": "Training bot B", "human": false},
		{"id": -3, "name": "Training bot C", "human": false}
	])
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
	var tutorial_controller: Node
	for child in arena.get_children():
		if child.get_script() == TUTORIAL_SCRIPT:
			tutorial_controller = child
			break
	if not is_instance_valid(tutorial_controller):
		push_error("Interactive tutorial controller was not attached to the arena")
		quit(1)
		return
	var tutorial_panel := tutorial_controller.get("panel") as Control
	if not is_instance_valid(tutorial_panel) or not tutorial_panel.visible:
		push_error("Interactive tutorial overlay panel is not visible")
		quit(1)
		return
	if not bool(global_state.get("tutorial_active")):
		push_error("Tutorial flag was unexpectedly cleared during arena startup")
		quit(1)
		return
	print("Tutorial smoke test passed: arena, controller and visible tutorial overlay are active")
	arena.queue_free()
	await process_frame
	quit(0)
