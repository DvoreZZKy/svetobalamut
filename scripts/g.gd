extends Node
## Глобальные данные: настройки, конфиг матча, input map, общий WorldEnvironment.

const SAVE_PATH := "user://settings.cfg"
const BOT_NAMES := ["Искра", "Вспышка", "Мерцай", "Блик", "Зарница", "Фотончик", "Луч", "Нимб", "Сияй"]

var player_name := "Светляк"
var vol_music := 0.7
var vol_sfx := 0.9
var shake_on := true
var fullscreen := false

var mode := "single"        # single | host | client
var cfg: Array = []         # [{id:int, name:String, human:bool}]


func _ready() -> void:
	_setup_input()
	load_settings()


func _setup_input() -> void:
	var keys := {
		"up": [KEY_W, KEY_UP],
		"down": [KEY_S, KEY_DOWN],
		"left": [KEY_A, KEY_LEFT],
		"right": [KEY_D, KEY_RIGHT],
		"dash": [KEY_SPACE, KEY_SHIFT],
		"possess": [KEY_E, KEY_F],
		"restart": [KEY_ENTER, KEY_KP_ENTER],
	}
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in keys[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)
	var mb := {"fire": MOUSE_BUTTON_LEFT, "possess": MOUSE_BUTTON_RIGHT}
	for a in mb:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		var e := InputEventMouseButton.new()
		e.button_index = mb[a]
		InputMap.action_add_event(a, e)


func col(ci: int) -> Color:
	return Color.from_hsv(fmod(ci * 0.1 + 0.52, 1.0), 0.85, 1.0)


func hdr(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)


func make_env() -> WorldEnvironment:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 1.1
	env.glow_strength = 1.15
	env.glow_bloom = 0.25
	env.glow_hdr_threshold = 0.7
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	for i in range(1, 7):
		env.set_glow_level(i, 1.0 if i != 1 else 0.6)
	var we := WorldEnvironment.new()
	we.environment = env
	return we


func local_ips() -> Array:
	var out := []
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254"):
			out.append(a)
	return out


func start_single() -> void:
	mode = "single"
	cfg = [{"id": 1, "name": player_name, "human": true}]
	for i in 5:
		cfg.append({"id": -(i + 1), "name": BOT_NAMES[i], "human": false})
	get_tree().change_scene_to_file("res://scenes/arena.tscn")


func save_settings() -> void:
	var c := ConfigFile.new()
	c.set_value("s", "name", player_name)
	c.set_value("s", "music", vol_music)
	c.set_value("s", "sfx", vol_sfx)
	c.set_value("s", "shake", shake_on)
	c.set_value("s", "fullscreen", fullscreen)
	c.save(SAVE_PATH)


func load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(SAVE_PATH) != OK:
		return
	player_name = c.get_value("s", "name", player_name)
	vol_music = c.get_value("s", "music", vol_music)
	vol_sfx = c.get_value("s", "sfx", vol_sfx)
	shake_on = c.get_value("s", "shake", shake_on)
	fullscreen = c.get_value("s", "fullscreen", fullscreen)
	apply_display()


func apply_display() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
