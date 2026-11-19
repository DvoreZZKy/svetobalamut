extends Node
## Сеть: ENet, хост-авторитарная модель.
## Клиенты шлют хосту ввод, хост считает всю симуляцию и рассылает снапшоты (20 Гц).
## Все RPC живут в этом автозагрузочном узле, чтобы путь /root/Net существовал у всех всегда.

signal lobby_changed
signal join_failed
signal disconnected
signal match_started
signal peer_left(id: int)

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


func join(ip: String) -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip.strip_edges(), PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_host = false
	online = true
	G.mode = "client"
	return OK


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
