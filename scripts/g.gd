extends Node
## Глобальные данные: настройки, конфиг матча, input map, общий WorldEnvironment.

const SAVE_PATH := "user://settings.cfg"
const BOT_NAMES := ["Искра", "Вспышка", "Мерцай", "Блик", "Зарница", "Фотончик", "Луч", "Нимб", "Сияй"]

var player_name := "Светляк"
var profile_color := 0
var profile_kind := 0
var profile_outfit := 0
var profile_hat := 0
const PROFILE_COLORS := [
	Color("#54eaff"), Color("#ff5c87"), Color("#ffd45c"), Color("#a77bff"),
	Color("#67f59a"), Color("#ff914d"), Color("#f4f4ff"), Color("#ff6df0")
]
var vol_music := 0.7
var vol_sfx := 0.9
var shake_on := true
var fullscreen := false
var tutorial_done := false
var tutorial_return_to_lobby := false

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
		"ability": [KEY_Q],
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
	return PROFILE_COLORS[posmod(ci, PROFILE_COLORS.size())]


func hdr(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)


func make_env() -> WorldEnvironment:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.32
	env.glow_strength = 0.3
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	for i in range(1, 7):
		env.set_glow_level(i, 0.12 if i != 1 else 0.08)
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
	tutorial_return_to_lobby = false
	if not tutorial_done:
		get_tree().change_scene_to_file("res://scenes/tutorial.tscn")
		return
	start_single_game()


func start_single_game() -> void:
	mode = "single"
	cfg = [{"id": 1, "name": player_name, "human": true, "color": profile_color,
		"kind": profile_kind, "outfit": profile_outfit, "hat": profile_hat}]
	for i in 5:
		cfg.append({"id": -(i + 1), "name": BOT_NAMES[i], "human": false})
	get_tree().change_scene_to_file("res://scenes/arena.tscn")


func save_settings() -> void:
	var c := ConfigFile.new()
	c.set_value("s", "name", player_name)
	c.set_value("s", "profile_color", profile_color)
	c.set_value("s", "profile_kind", profile_kind)
	c.set_value("s", "profile_outfit", profile_outfit)
	c.set_value("s", "profile_hat", profile_hat)
	c.set_value("s", "music", vol_music)
	c.set_value("s", "sfx", vol_sfx)
	c.set_value("s", "shake", shake_on)
	c.set_value("s", "fullscreen", fullscreen)
	c.set_value("s", "tutorial_done", tutorial_done)
	c.save(SAVE_PATH)


func load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(SAVE_PATH) != OK:
		return
	player_name = c.get_value("s", "name", player_name)
	profile_color = c.get_value("s", "profile_color", profile_color)
	profile_kind = c.get_value("s", "profile_kind", profile_kind)
	profile_outfit = c.get_value("s", "profile_outfit", profile_outfit)
	profile_hat = c.get_value("s", "profile_hat", profile_hat)
	vol_music = c.get_value("s", "music", vol_music)
	vol_sfx = c.get_value("s", "sfx", vol_sfx)
	shake_on = c.get_value("s", "shake", shake_on)
	fullscreen = c.get_value("s", "fullscreen", fullscreen)
	tutorial_done = c.get_value("s", "tutorial_done", tutorial_done)
	apply_display()


func apply_display() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
		var screen := DisplayServer.window_get_current_screen()
		var screen_size := DisplayServer.screen_get_size(screen)
		var screen_pos := DisplayServer.screen_get_position(screen)
		DisplayServer.window_set_position(screen_pos + (screen_size - Vector2i(1280, 720)) / 2)
