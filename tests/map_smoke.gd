extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var map_service: Node = root.get_node_or_null("MapData")
	if map_service == null:
		push_error("MapData autoload is missing")
		quit(1)
		return
	var maps: Array = map_service.call("all_maps")
	if maps.size() < 6:
		push_error("Expected the original arena and five additional maps")
		quit(1)
		return
	var custom: Dictionary = map_service.call("new_custom_map", "Map smoke test")
	custom["objects"] = [{"type":"rock","x":400.0,"y":400.0,"r":50.0}]
	if not bool(map_service.call("save_custom_map", custom)):
		push_error("Could not save a custom map")
		quit(1)
		return
	var count_after_save: int = (map_service.call("all_maps") as Array).size()
	map_service.call("receive_map", custom)
	if (map_service.call("all_maps") as Array).size() != count_after_save:
		push_error("Receiving the same map created a duplicate")
		quit(1)
		return
	var editor_scene: PackedScene = load("res://scenes/map_editor.tscn")
	if editor_scene == null:
		push_error("Map editor scene could not be loaded")
		quit(1)
		return
	var editor: Node = editor_scene.instantiate()
	root.add_child(editor)
	await process_frame
	if editor.get_child_count() < 5:
		push_error("Map editor controls were not created")
		quit(1)
		return
	editor.queue_free()
	await process_frame
	print("Map smoke test passed: six base maps, custom map save/deduplication, editor startup")
	quit(0)
