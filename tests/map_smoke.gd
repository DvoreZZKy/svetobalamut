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
	var cave_found := false
	var builtin_sizes: Array[String] = []
	var unique_sizes := {}
	for map_item in maps:
		var map_id := str(map_item.get("id", ""))
		if map_id.begins_with("custom_"):
			continue
		var map_size: Vector2 = Vector2(map_item.get("size", Vector2.ZERO))
		builtin_sizes.append(str(map_size))
		unique_sizes[str(map_size)] = true
		if map_id == "shard_labyrinth":
			cave_found = true
			if str(map_item.get("name", "")) != "Пещера разломов" or map_size != Vector2(2200, 1600):
				push_error("Cave map name or dimensions are incorrect")
				quit(1)
				return
			var cave_objects: Array = map_item.get("objects", [])
			if cave_objects.size() > 10:
				push_error("Cave walls were not merged into compound objects")
				quit(1)
			var wall_count := 0
			for cave_object in cave_objects:
				if str(cave_object.get("type", "")) == "cave_wall":
					wall_count += 1
					if (cave_object.get("poly", []) as PackedVector2Array).size() < 40:
						push_error("Compound cave wall polygon is incomplete")
						quit(1)
			if wall_count != 2:
				push_error("Cave must consist of two merged wall objects")
				quit(1)
	if not cave_found or builtin_sizes.size() != 6 or unique_sizes.size() != 6:
		push_error("Built-in maps do not have six distinct layouts and dimensions")
		quit(1)
		return
	if Sim.regen_zones_for(Vector2(2200, 1600)).size() != 4:
		push_error("Map-scaled regeneration zones were not created")
		quit(1)
		return
	var custom: Dictionary = map_service.call("new_custom_map", "Map smoke test")
	custom["objects"] = [{"type":"container","x":1200.0,"y":750.0,"r":35.0}]
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
	var sim_script: Script = load("res://scripts/sim.gd")
	var sim: Variant = sim_script.new()
	sim.reset([{"id":1,"name":"Map QA","human":true,"color":0,"kind":0,"outfit":0,"hat":0}])
	if sim.world_size != Vector2(2400,1500):
		push_error("Custom map dimensions were not loaded into the simulation")
		quit(1)
		return
	sim.bullets = [{"id":1,"pos":Vector2(1200,750),"vel":Vector2.ZERO,"owner":1,"life":1.0,"bn":0,"ricochet":false,"dmg":100.0,"radius":6.0,"hit_ids":[]}]
	sim.call("_update_bullets",1.0/60.0)
	if not sim.map_data.get("objects",[]).is_empty() or sim.pickups.size() != 1:
		push_error("A destroyed container did not disappear and drop its battery")
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
	if editor.get_child_count() < 2 or editor.get_child(0).get_child_count() < 7:
		push_error("Map editor controls were not created")
		quit(1)
		return
	editor.queue_free()
	await process_frame
	print("Map smoke test passed: six base maps, custom map save/deduplication, editor startup")
	quit(0)
