extends Control
var draft: Dictionary = {}
var selected_type := "rock"
var canvas_rect := Rect2(30,100,900,560)
var info: Label
var map_picker: OptionButton
var object_picker: OptionButton
var name_edit: LineEdit

func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 draft = MapData.get_selected_map()
 var top := HBoxContainer.new()
 top.position = Vector2(24,20)
 top.size = Vector2(1230,54)
 add_child(top)
 var back := Button.new()
 back.text = "← МЕНЮ"
 back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"))
 top.add_child(back)
 map_picker = OptionButton.new()
 for m in MapData.all_maps():
  map_picker.add_item(str(m.get("name","Карта")))
 map_picker.item_selected.connect(_choose_map)
 top.add_child(map_picker)
 var create := Button.new()
 create.text = "НОВАЯ КАРТА"
 create.pressed.connect(_new_map)
 top.add_child(create)
 name_edit = LineEdit.new()
 name_edit.placeholder_text = "Название карты"
 name_edit.text = str(draft.get("name","Моя карта"))
 name_edit.custom_minimum_size.x = 190
 top.add_child(name_edit)
 object_picker = OptionButton.new()
 var labels := ["Камень","Кристалл","Энергоукрытие","Контейнер","Светорастение","Генератор","Телепорт"]
 var types := ["rock","crystal","cover","container","plant","generator","teleporter"]
 for i in labels.size():
  object_picker.add_item(labels[i])
 object_picker.item_selected.connect(func(i): selected_type = types[i])
 top.add_child(object_picker)
 var save := Button.new()
 save.text = "СОХРАНИТЬ"
 save.pressed.connect(_save)
 top.add_child(save)
 var play := Button.new()
 play.text = "ИГРАТЬ НА КАРТЕ"
 play.pressed.connect(_play)
 top.add_child(play)
 info = Label.new()
 info.position = Vector2(32,72)
 info.text = "ЛКМ — поставить объект • ПКМ — удалить ближайший • Колесо — размер"
 add_child(info)
 queue_redraw()

func _choose_map(index: int) -> void:
 var maps := MapData.all_maps()
 if index >= 0 and index < maps.size():
  draft = maps[index].duplicate(true)
  name_edit.text = str(draft.get("name",""))
  queue_redraw()

func _new_map() -> void:
 draft = MapData.new_custom_map()
 name_edit.text = str(draft.name)
 queue_redraw()

func _save() -> void:
 if not str(draft.get("id","")).begins_with("custom_"):
  var custom_copy: Dictionary = MapData.new_custom_map()
  custom_copy["objects"] = draft.get("objects", []).duplicate(true)
  custom_copy["size"] = draft.get("size", Vector2(2400,1500))
  draft = custom_copy
 draft.name = name_edit.text.strip_edges() if name_edit.text.strip_edges() != "" else "Моя карта"
 if MapData.save_custom_map(draft):
  info.text = "КАРТА СОХРАНЕНА ЛОКАЛЬНО • " + str(draft.objects.size()) + " объектов"
 else:
  info.text = "Не удалось сохранить карту"

func _play() -> void:
 _save()
 G.cfg = [{"id":1,"name":G.player_name,"human":true,"color":G.profile_color,"kind":G.profile_kind,"outfit":G.profile_outfit,"hat":G.profile_hat}]
 for i in 5:
  G.cfg.append({"id":-(i+1),"name":G.BOT_NAMES[i],"human":false})
 G.mode = "single"
 G.tutorial_active = false
 get_tree().change_scene_to_file("res://scenes/arena.tscn")

func _map_to_canvas(p: Vector2) -> Vector2:
 var size: Vector2 = draft.get("size",Vector2(2400,1500))
 return canvas_rect.position + Vector2(p.x/size.x*canvas_rect.size.x,p.y/size.y*canvas_rect.size.y)

func _canvas_to_map(p: Vector2) -> Vector2:
 var size: Vector2 = draft.get("size",Vector2(2400,1500))
 return Vector2((p.x-canvas_rect.position.x)/canvas_rect.size.x*size.x,(p.y-canvas_rect.position.y)/canvas_rect.size.y*size.y)

func _gui_input(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.pressed and canvas_rect.has_point(event.position):
  var world_pos := _canvas_to_map(event.position)
  if event.button_index == MOUSE_BUTTON_LEFT:
   draft.objects.append({"type":selected_type,"x":world_pos.x,"y":world_pos.y,"r":54.0})
   queue_redraw()
  elif event.button_index == MOUSE_BUTTON_RIGHT:
   var nearest := -1
   var best := 100000000.0
   for i in draft.objects.size():
    var o: Dictionary = draft.objects[i]
    var d := Vector2(float(o.x),float(o.y)).distance_squared_to(world_pos)
    if d < best:
     best = d
     nearest = i
   if nearest >= 0:
    draft.objects.remove_at(nearest)
    queue_redraw()
  elif event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
   if not draft.objects.is_empty():
    var o: Dictionary = draft.objects[-1]
    o.r = clampf(float(o.r)+(8.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -8.0),18.0,130.0)
    draft.objects[-1] = o
    queue_redraw()

func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO,size),Color("#050914"))
 draw_rect(canvas_rect,Color("#0b1428"))
 var cols := 20
 for i in cols+1:
  var x := canvas_rect.position.x + canvas_rect.size.x*float(i)/cols
  draw_line(Vector2(x,canvas_rect.position.y),Vector2(x,canvas_rect.end.y),Color("#20415d",0.55),1.0)
 for i in 12:
  var y := canvas_rect.position.y + canvas_rect.size.y*float(i)/12
  draw_line(Vector2(canvas_rect.position.x,y),Vector2(canvas_rect.end.x,y),Color("#20415d",0.55),1.0)
 for item in draft.get("objects",[]):
  var p := _map_to_canvas(Vector2(float(item.x),float(item.y)))
  var r := float(item.r)*canvas_rect.size.x/float(draft.size.x)
  var tint := {"rock":Color("#69a4c8"),"crystal":Color("#61efff"),"cover":Color("#b58aff"),"container":Color("#ff9d65"),"plant":Color("#69ffb3"),"generator":Color("#ffe47a"),"teleporter":Color("#e47aff")}.get(str(item.type),Color.CYAN)
  draw_circle(p,r+5,Color(tint,0.12))
  draw_arc(p,r,0.0,TAU,28,tint,3.0,true)
  draw_arc(p,r*0.65,0.0,TAU,24,Color(tint,0.55),1.5,true)
 draw_rect(canvas_rect,Color("#55eaff"),false,2.0)
 draw_string(ThemeDB.fallback_font,Vector2(32,canvas_rect.end.y+35),"КАРТА: "+str(draft.get("name",""))+"   •   "+str(draft.get("size",Vector2(2400,1500))),HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("#aeefff"))
