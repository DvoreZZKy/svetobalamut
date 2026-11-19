extends Node
## Сеть: ENet, хост-авторитарная модель.
## Клиенты шлют хосту ввод, хост считает всю симуляцию и рассылает снапшоты (20 Гц).
## Все RPC живут в этом автозагрузочном узле, чтобы путь /root/Net существовал у всех всегда.

signal lobby_changed
signal join_failed
signal disconnected
signal match_started
signal peer_left(id: int)
signal kicked

const PORT := 24680
const MAX_PLAYERS := 10
const MIN_FILL := 6

var is_host := false
var online := false
var names := {}            # peer_id -> имя (только лобби)
var profiles := {}         # peer_id -> внешний вид
var inputs := {}           # на хосте: peer_id -> dict ввода
var latest_snap := {}
var snap_seq := 0


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): leave(); join_failed.emit())
	multiplayer.server_disconnected.connect(func(): leave(); disconnected.emit())


func host() -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_host = true
	online = true
	G.mode = "host"
	names = {1: G.player_name}
	profiles = {1: _local_profile()}
	return OK


func join(address: String) -> int:
	var clean := address.strip_edges()
	var host_ip := clean
	var host_port := PORT
	# Numeric room code is the IPv4 address packed into one unsigned 32-bit number.
	if clean.is_valid_int() and not clean.contains("."):
		var room_code := int(clean)
		if room_code < 0 or room_code > 4294967295:
			return ERR_INVALID_PARAMETER
		host_ip = "%d.%d.%d.%d" % [
			(room_code >> 24) & 255, (room_code >> 16) & 255,
			(room_code >> 8) & 255, room_code & 255
		]
	var split_at := clean.rfind(":")
	if split_at > 0 and clean.find(".") >= 0:
		host_ip = clean.substr(0, split_at).strip_edges()
		var parsed_port := clean.substr(split_at + 1).strip_edges()
		if not parsed_port.is_valid_int():
			return ERR_INVALID_PARAMETER
		host_port = int(parsed_port)
	if host_ip.is_empty() or host_port < 1 or host_port > 65535:
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(host_ip, host_port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_host = false
	online = true
	G.mode = "client"
	return OK


func room_code_for_ip(ip: String) -> String:
	var parts := ip.split(".")
	if parts.size() != 4:
		return ""
	var value: int = 0
	for part in parts:
		if not part.is_valid_int():
			return ""
		var octet := int(part)
		if octet < 0 or octet > 255:
			return ""
		value = (value << 8) | octet
	return "%010d" % value


func leave() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	online = false
	is_host = false
	names.clear()
	profiles.clear()
	inputs.clear()
	latest_snap = {}
	snap_seq = 0


func _on_connected() -> void:
	_hello.rpc_id(1, G.player_name, _local_profile())


func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	if is_host:
		names.erase(id)
		profiles.erase(id)
		inputs.erase(id)
		_names.rpc(names, profiles)
		lobby_changed.emit()
	peer_left.emit(id)



func kick_peer(peer_id: int) -> void:
	if not is_host or not online or peer_id <= 1 or not names.has(peer_id):
		return
	_kick_notice.rpc_id(peer_id)
	# Let the reliable notice leave before ENet closes the peer.
	await get_tree().create_timer(0.25).timeout
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		multiplayer.multiplayer_peer.disconnect_peer(peer_id, true)
	names.erase(peer_id)
	profiles.erase(peer_id)
	inputs.erase(peer_id)
	_names.rpc(names, profiles)
	lobby_changed.emit()


@rpc("authority", "reliable")
func _kick_notice() -> void:
	leave()
	kicked.emit()
	disconnected.emit()


func _local_profile() -> Dictionary:
	return {"color": G.profile_color, "kind": G.profile_kind,
		"outfit": G.profile_outfit, "hat": G.profile_hat}


@rpc("any_peer", "reliable")
func _hello(pname: String, profile: Dictionary) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	names[id] = pname.substr(0, 16)
	profiles[id] = profile
	_names.rpc(names, profiles)
	lobby_changed.emit()


@rpc("authority", "reliable")
func _names(d: Dictionary, p: Dictionary) -> void:
	names = d
	profiles = p
	lobby_changed.emit()


## Хост: собрать конфиг (люди + боты до MIN_FILL) и запустить у всех.
func start_match() -> void:
	if not is_host:
		return
	var cfg: Array = []
	for id in names:
		var profile: Dictionary = profiles.get(id, {})
		cfg.append({"id": id, "name": names[id], "human": true,
			"color": profile.get("color", 0), "kind": profile.get("kind", 0),
			"outfit": profile.get("outfit", 0), "hat": profile.get("hat", 0)})
	var i := 0
	while cfg.size() < MIN_FILL:
		cfg.append({"id": -(i + 1), "name": G.BOT_NAMES[i % G.BOT_NAMES.size()], "human": false})
		i += 1
	_start.rpc(cfg)


@rpc("authority", "call_local", "reliable")
func _start(cfg: Array) -> void:
	G.cfg = cfg
	match_started.emit()


func set_local_profile() -> void:
	if not online:
		return
	var p := _local_profile()
	if is_host:
		profiles[1] = p
		_names.rpc(names, profiles)
		lobby_changed.emit()
	else:
		_profile_update.rpc_id(1, p)


@rpc("any_peer", "reliable")
func _profile_update(p: Dictionary) -> void:
	if not is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not names.has(sender):
		return
	profiles[sender] = p
	_names.rpc(names, profiles)
	lobby_changed.emit()


func send_input(d: Dictionary) -> void:
	if online and not is_host:
		_input_rpc.rpc_id(1, d)


@rpc("any_peer", "unreliable_ordered")
func _input_rpc(d: Dictionary) -> void:
	if is_host:
		inputs[multiplayer.get_remote_sender_id()] = d


func broadcast_snap(d: Dictionary) -> void:
	if online and is_host:
		_snap.rpc(d)


@rpc("authority", "unreliable_ordered")
func _snap(d: Dictionary) -> void:
	latest_snap = d
	snap_seq += 1
