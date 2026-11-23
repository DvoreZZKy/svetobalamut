extends Node
signal maps_changed
const SAVE_DIR := "user://maps"
const MAPS := [
 {"id":"arena_original","name":"Первая арена","size":Vector2(1600,900),"theme":"cyan","zone_delay":60.0,"zone_duration":30.0,"objects":[{"type":"rock","x":800.0,"y":450.0,"r":54.0},{"type":"crystal","x":400.0,"y":225.0,"r":34.0},{"type":"crystal","x":1200.0,"y":675.0,"r":34.0}]},
 {"id":"neon_canyon","name":"Неоновый каньон","size":Vector2(2400,1500),"theme":"violet","zone_delay":60.0,"zone_duration":30.0,"objects":[{"type":"rock","x":760.0,"y":750.0,"r":82.0},{"type":"rock","x":1640.0,"y":750.0,"r":82.0},{"type":"cover","x":1200.0,"y":470.0,"r":65.0}]},
 {"id":"pulse_grid","name":"Импульсная сетка","size":Vector2(2400,1500),"theme":"cyan","zone_delay":60.0,"zone_duration":30.0,"objects":[{"type":"generator","x":1200.0,"y":750.0,"r":58.0},{"type":"cover","x":650.0,"y":750.0,"r":72.0},{"type":"cover","x":1750.0,"y":750.0,"r":72.0}]},
 {"id":"shard_labyrinth","name":"Лабиринт осколков","size":Vector2(2600,1600),"theme":"pink","zone_delay":60.0,"zone_duration":30.0,"objects":[{"type":"rock","x":780.0,"y":500.0,"r":72.0},{"type":"rock","x":1050.0,"y":800.0,"r":72.0},{"type":"rock","x":1350.0,"y":500.0,"r":72.0},{"type":"rock","x":1620.0,"y":800.0,"r":72.0}]},
 {"id":"dark_orbit","name":"Тёмная орбита","size":Vector2(2800,1700),"theme":"violet","zone_delay":60.0,"zone_duration":30.0,"objects":[{"type":"rock","x":1400.0,"y":850.0,"r":110.0},{"type":"teleporter","x":650.0,"y":850.0,"r":48.0},{"type":"teleporter","x":2150.0,"y":850.0,"r":48.0},{"type":"generator","x":1400.0,"y":400.0,"r":52.0}]},
 {"id":"light_garden","name":"Сад света","size":Vector2(2600,1600),"theme":"green","zone_delay":60.0,"zone_duration":30.0,"objects":[{"type":"plant","x":800.0,"y":500.0,"r":56.0},{"type":"plant","x":1800.0,"y":500.0,"r":56.0},{"type":"plant","x":800.0,"y":1100.0,"r":56.0},{"type":"plant","x":1800.0,"y":1100.0,"r":56.0},{"type":"generator","x":1300.0,"y":800.0,"r":58.0}]}
]
var selected_id := "arena_original"
var custom_maps: Array[Dictionary] = []

func _ready() -> void:
 _load_maps()
 G.selected_map = get_selected_map()

func all_maps() -> Array:
 var out: Array = MAPS.duplicate(true)
 for map_index in out.size():
  var map_item: Dictionary = out[map_index]
  match str(map_item.get("id", "")):
   "neon_canyon":
    map_item["size"] = Vector2(2600, 1300)
    map_item["objects"] = _canyon_objects()
   "pulse_grid":
    map_item["size"] = Vector2(1900, 1500)
    map_item["objects"] = _pulse_grid_objects()
   "shard_labyrinth":
    map_item["name"] = "Пещера разломов"
    map_item["size"] = Vector2(2200, 1600)
    map_item["objects"] = _cave_objects()
   "dark_orbit":
    map_item["size"] = Vector2(3200, 1200)
    map_item["objects"] = _orbit_objects()
   "light_garden":
    map_item["size"] = Vector2(1900, 1100)
    map_item["objects"] = _garden_objects()
  out[map_index] = map_item
 out.append_array(custom_maps.duplicate(true))
 return out


func _canyon_objects() -> Array:
 var result: Array = []
 for i in 5:
  var x := 340.0 + float(i) * 480.0
  var y := 280.0 if i % 2 == 0 else 1020.0
  result.append({"type": "rock", "x": x, "y": y, "r": 82.0})
  result.append({"type": "rock", "x": x + 150.0, "y": 1300.0 - y, "r": 62.0})
  result.append({"type": "cover", "x": x + 230.0, "y": 650.0, "r": 48.0})
 result.append({"type": "generator", "x": 1300.0, "y": 650.0, "r": 58.0})
 return result


func _pulse_grid_objects() -> Array:
 var result: Array = []
 for row in 3:
  for column in 5:
   if (row + column) % 2 == 0:
    result.append({"type": "cover", "x": 260.0 + float(column) * 345.0, "y": 310.0 + float(row) * 440.0, "r": 52.0})
 result.append({"type": "generator", "x": 950.0, "y": 750.0, "r": 62.0})
 result.append({"type": "generator", "x": 430.0, "y": 1160.0, "r": 46.0})
 result.append({"type": "generator", "x": 1470.0, "y": 340.0, "r": 46.0})
 for x in [620.0, 1280.0]:
  result.append({"type": "container", "x": x, "y": 750.0, "r": 38.0})
 return result


func _cave_objects() -> Array:
    var result: Array = []
    var upper_poly := PackedVector2Array()
    var lower_poly := PackedVector2Array()
    var upper_parts: Array = []
    var lower_parts: Array = []
    # Two continuous compound walls replace hundreds of separate rock/crystal nodes.
    for column in range(0, 45):
    	var x := float(column) * 50.0
    	var passage_center := 800.0 + sin(x * 0.0032) * 145.0 + sin(x * 0.0071) * 52.0
    	var passage_half := 158.0 + sin(x * 0.0051 + 0.8) * 22.0
    	var ceiling_y := passage_center - passage_half
    	var floor_y := passage_center + passage_half
    	upper_poly.append(Vector2(x, 0.0))
    	lower_poly.append(Vector2(x, 1600.0))
    	if column % 3 == 0:
    		upper_parts.append({"x":x,"y":maxf(50.0,ceiling_y - 55.0),"r":72.0})
    		lower_parts.append({"x":x,"y":minf(1550.0,floor_y + 55.0),"r":72.0})
    for column in range(44, -1, -1):
    	var x := float(column) * 50.0
    	var passage_center := 800.0 + sin(x * 0.0032) * 145.0 + sin(x * 0.0071) * 52.0
    	var passage_half := 158.0 + sin(x * 0.0051 + 0.8) * 22.0
    	upper_poly.append(Vector2(x, passage_center - passage_half))
    	lower_poly.append(Vector2(x, passage_center + passage_half))
    result.append({"type":"cave_wall","x":1100.0,"y":0.0,"r":0.0,"poly":upper_poly,"parts":upper_parts})
    result.append({"type":"cave_wall","x":1100.0,"y":1600.0,"r":0.0,"poly":lower_poly,"parts":lower_parts})
    for item in [
    	{"type":"crystal","x":170.0,"y":790.0,"r":58.0},
    	{"type":"crystal","x":2030.0,"y":820.0,"r":62.0},
    	{"type":"generator","x":350.0,"y":800.0,"r":46.0},
    	{"type":"generator","x":1880.0,"y":800.0,"r":46.0},
    	{"type":"container","x":880.0,"y":300.0,"r":34.0},
    	{"type":"container","x":1370.0,"y":1320.0,"r":34.0}
    ]:
    	result.append(item)
    return result

func _orbit_objects() -> Array:
 var result: Array = []
 for i in 4:
  var angle := TAU * float(i) / 4.0
  var center := Vector2(1600.0, 600.0) + Vector2.from_angle(angle) * 430.0
  result.append({"type": "teleporter", "x": center.x, "y": center.y, "r": 48.0})
  result.append({"type": "crystal", "x": center.x + 120.0, "y": center.y, "r": 36.0})
 result.append({"type": "rock", "x": 1600.0, "y": 600.0, "r": 110.0})
 result.append({"type": "generator", "x": 1600.0, "y": 250.0, "r": 52.0})
 result.append({"type": "generator", "x": 1600.0, "y": 950.0, "r": 52.0})
 return result


func _garden_objects() -> Array:
 var result: Array = []
 for row in 3:
  for column in 5:
   var x := 230.0 + float(column) * 360.0
   var y := 180.0 + float(row) * 360.0
   if (row + column) % 3 == 0:
    result.append({"type": "plant", "x": x, "y": y, "r": 58.0})
   else:
    result.append({"type": "cover", "x": x, "y": y, "r": 40.0})
 result.append({"type": "generator", "x": 950.0, "y": 550.0, "r": 60.0})
 result.append({"type": "teleporter", "x": 280.0, "y": 550.0, "r": 42.0})
 result.append({"type": "teleporter", "x": 1620.0, "y": 550.0, "r": 42.0})
 return result

func get_selected_map() -> Dictionary:
 for item in all_maps():
  if str(item.get("id","")) == selected_id:
   return item.duplicate(true)
 return MAPS[0].duplicate(true)

func select_map(id: String) -> bool:
 for item in all_maps():
  if str(item.get("id","")) == id:
   selected_id = id
   G.selected_map = item.duplicate(true)
   return true
 return false

func new_custom_map(name: String = "Моя карта") -> Dictionary:
 return {"id":"custom_" + str(Time.get_unix_time_from_system()) + "_" + str(randi()),"name":name.substr(0,32),"size":Vector2(2400,1500),"theme":"cyan","zone_delay":60.0,"zone_duration":30.0,"objects":[]}

func save_custom_map(data: Dictionary) -> bool:
 var clean := _sanitize_map(data)
 if clean.is_empty():
  return false
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
 var found := false
 for i in custom_maps.size():
  if str(custom_maps[i].get("id","")) == str(clean.id):
   custom_maps[i] = clean
   found = true
   break
 if not found:
  custom_maps.append(clean)
 selected_id = str(clean.id)
 G.selected_map = clean.duplicate(true)
 _write_maps()
 maps_changed.emit()
 return true

func receive_map(data: Dictionary) -> void:
 var clean := _sanitize_map(data)
 if clean.is_empty():
  return
 for item in custom_maps:
  if str(item.get("id","")) == str(clean.id):
   return
 for item in MAPS:
  if str(item.id) == str(clean.id):
   return
 custom_maps.append(clean)
 _write_maps()
 maps_changed.emit()

func _sanitize_map(data: Dictionary) -> Dictionary:
 var size_value: Variant = data.get("size", Vector2(2400,1500))
 var size: Vector2 = Vector2(2400,1500)
 if size_value is Vector2:
  size = size_value
 elif size_value is Array and size_value.size() >= 2:
  size = Vector2(float(size_value[0]),float(size_value[1]))
 elif size_value is Dictionary:
  size = Vector2(float(size_value.get("x",2400)),float(size_value.get("y",1500)))
 size.x = clampf(size.x,1600.0,5000.0)
 size.y = clampf(size.y,900.0,3000.0)
 var objects: Array = []
 for raw in data.get("objects",[]):
  if not raw is Dictionary or objects.size() >= 180:
   continue
  var kind := str(raw.get("type","rock"))
  if not ["rock","crystal","cover","container","plant","generator","teleporter"].has(kind):
   continue
  objects.append({"type":kind,"x":clampf(float(raw.get("x",size.x*0.5)),40.0,size.x-40.0),"y":clampf(float(raw.get("y",size.y*0.5)),40.0,size.y-40.0),"r":clampf(float(raw.get("r",48.0)),18.0,130.0)})
 return {"id":str(data.get("id","custom")),"name":str(data.get("name","Моя карта")).substr(0,32),"size":size,"theme":str(data.get("theme","cyan")),"zone_delay":clampf(float(data.get("zone_delay",35.0)),5.0,180.0),"zone_duration":clampf(float(data.get("zone_duration",180.0)),30.0,360.0),"objects":objects}

func _write_maps() -> void:
 var serializable: Array = []
 for item in custom_maps:
  var copy: Dictionary = item.duplicate(true)
  var map_size: Vector2 = copy.get("size",Vector2(2400,1500))
  copy["size"] = [map_size.x,map_size.y]
  serializable.append(copy)
 var file := FileAccess.open(SAVE_DIR + "/library.json",FileAccess.WRITE)
 if file:
  file.store_string(JSON.stringify(serializable))

func _load_maps() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
 if not FileAccess.file_exists(SAVE_DIR + "/library.json"):
  return
 var file := FileAccess.open(SAVE_DIR + "/library.json",FileAccess.READ)
 if file == null:
  return
 var parsed: Variant = JSON.parse_string(file.get_as_text())
 if parsed is Array:
  for item in parsed:
   if item is Dictionary:
    custom_maps.append(_sanitize_map(item))
