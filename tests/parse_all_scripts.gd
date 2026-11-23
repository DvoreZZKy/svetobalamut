extends SceneTree

var script_count: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _scan_directory(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		failures.append("Could not open directory: " + path)
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = directory.get_next()
			continue
		var child_path := path.path_join(entry)
		if directory.current_is_dir():
			_scan_directory(child_path)
		elif entry.ends_with(".gd"):
			var script_resource: Resource = load(child_path)
			script_count += 1
			if script_resource == null:
				failures.append(child_path)
		entry = directory.get_next()
	directory.list_dir_end()


func _run() -> void:
	_scan_directory("res://")
	if failures.is_empty():
		print("GDScript parse check passed: %d scripts loaded" % script_count)
		quit(0)
	else:
		for failed_path in failures:
			push_error("Could not parse script: " + failed_path)
		quit(1)
