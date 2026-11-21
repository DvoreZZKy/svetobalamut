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
var mouse_sensitivity := 1.35
var match_mouse_sensitivity := true
var shake_on := true
var fullscreen := false
var graphics_quality := 0 # 0: high, 1: medium, 2: low, 3: potato
var control_keys := {"up": KEY_W, "down": KEY_S, "left": KEY_A, "right": KEY_D, "dash": KEY_SPACE, "ability": KEY_Q, "possess": KEY_E}
const GRAPHICS_PRESETS := ["Высокая", "Средняя", "Низкая", "Режим картошки"]
var tutorial_done := false
const TUTORIAL_VERSION := 4
var tutorial_active := false
var tutorial_return_to_lobby := false
var tutorial_previous_mode := "single"

var mode := "single"        # single | host | client
var cfg: Array = []         # [{id:int, name:String, human:bool}]


func _ready() -> void:
	_setup_input()
	load_settings()


func _notification(what: int) -> void:
	# Closing the window (Alt+F4, the X button) must not lose changed settings.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_settings()


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



func set_control_key(action: String, keycode: int) -> void:
	if not control_keys.has(action) or keycode <= 0:
		return
	control_keys[action] = keycode
	apply_control_keys()
	save_settings()


func apply_control_keys() -> void:
	for action in control_keys.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				InputMap.action_erase_event(action, event)
		var key_event := InputEventKey.new()
		key_event.physical_keycode = int(control_keys[action])
		InputMap.action_add_event(action, key_event)


func col(ci: int) -> Color:
	return PROFILE_COLORS[posmod(ci, PROFILE_COLORS.size())]


func hdr(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)


# Shared render resources live in this autoload, so scene changes and match restarts
# do not recreate the same halo texture/material.
var _shared_halo_texture: GradientTexture2D
var _shared_additive_material: CanvasItemMaterial


func get_halo_texture() -> GradientTexture2D:
	if _shared_halo_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.35, Color(1, 1, 1, 0.35))
		_shared_halo_texture = GradientTexture2D.new()
		_shared_halo_texture.gradient = gradient
		_shared_halo_texture.fill = GradientTexture2D.FILL_RADIAL
		_shared_halo_texture.fill_from = Vector2(0.5, 0.5)
		_shared_halo_texture.fill_to = Vector2(1.0, 0.5)
		_shared_halo_texture.width = 128
		_shared_halo_texture.height = 128
	return _shared_halo_texture


func get_additive_material() -> CanvasItemMaterial:
	if _shared_additive_material == null:
		_shared_additive_material = CanvasItemMaterial.new()
		_shared_additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _shared_additive_material


func make_env() -> WorldEnvironment:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	_configure_environment(env)
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
	# First launch after tutorial update always enters the guided flow.
	tutorial_return_to_lobby = false
	if not tutorial_done:
		start_tutorial_game(false)
	else:
		start_single_game()


func start_tutorial_game(return_to_lobby: bool) -> void:
	tutorial_return_to_lobby = return_to_lobby
	if return_to_lobby:
		tutorial_previous_mode = mode
	tutorial_active = true
	mode = "single"
	cfg = [{"id": 1, "name": player_name, "human": true, "color": profile_color,
		"kind": profile_kind, "outfit": profile_outfit, "hat": profile_hat}]
	for i in 3:
		cfg.append({"id": -(i + 1), "name": BOT_NAMES[i], "human": false})
	get_tree().change_scene_to_file("res://scenes/arena.tscn")


func start_single_game() -> void:
	tutorial_active = false
	tutorial_return_to_lobby = false
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
	c.set_value("s", "mouse_sensitivity", mouse_sensitivity)
	c.set_value("s", "match_mouse_sensitivity", match_mouse_sensitivity)
	c.set_value("s", "shake", shake_on)
	c.set_value("s", "fullscreen", fullscreen)
	c.set_value("s", "graphics_quality", graphics_quality)
	c.set_value("s", "tutorial_done", tutorial_done)
	c.set_value("s", "tutorial_version", TUTORIAL_VERSION)
	for action in control_keys.keys():
		c.set_value("controls", action, int(control_keys[action]))
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
	mouse_sensitivity = clampf(float(c.get_value("s", "mouse_sensitivity", mouse_sensitivity)), 0.5, 3.0)
	match_mouse_sensitivity = bool(c.get_value("s", "match_mouse_sensitivity", match_mouse_sensitivity))
	shake_on = c.get_value("s", "shake", shake_on)
	fullscreen = c.get_value("s", "fullscreen", fullscreen)
	graphics_quality = clampi(int(c.get_value("s", "graphics_quality", graphics_quality)), 0, 3)
	var saved_tutorial_version := int(c.get_value("s", "tutorial_version", 0))
	tutorial_done = bool(c.get_value("s", "tutorial_done", false)) if saved_tutorial_version >= TUTORIAL_VERSION else false
	for action in control_keys.keys():
		control_keys[action] = int(c.get_value("controls", action, control_keys[action]))
	apply_control_keys()
	apply_display()
	apply_graphics()


func apply_display() -> void:
	var window_id := DisplayServer.MAIN_WINDOW_ID
	var screen := DisplayServer.window_get_current_screen(window_id)
	if fullscreen:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false, window_id)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN, window_id)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED, window_id)
		DisplayServer.window_set_size(Vector2i(1280, 720), window_id)
		var screen_size := DisplayServer.screen_get_size(screen)
		var screen_pos := DisplayServer.screen_get_position(screen)
		DisplayServer.window_set_position(screen_pos + (screen_size - Vector2i(1280, 720)) / 2, window_id)


func _configure_environment(env: Environment) -> void:
	var glow_enabled := graphics_quality <= 1
	env.glow_enabled = glow_enabled
	env.glow_intensity = [0.62, 0.34, 0.0, 0.0][graphics_quality]
	env.glow_strength = [0.72, 0.38, 0.0, 0.0][graphics_quality]
	env.glow_bloom = [0.08, 0.035, 0.0, 0.0][graphics_quality]
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	for i in range(1, 7):
		var level := 0.10 if i <= 3 else 0.0
		if graphics_quality == 1:
			level *= 0.55
		env.set_glow_level(i, level if glow_enabled else 0.0)


func apply_graphics() -> void:
	for node in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		var world_env := node as WorldEnvironment
		if world_env != null and world_env.environment != null:
			_configure_environment(world_env.environment)
