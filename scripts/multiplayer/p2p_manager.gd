extends Node
# چندنفره مستقیم رایگان با ENet: میزبان مرجع + فرمان‌محور + Snapshot امضاشده

const GameCommandClass = preload("res://scripts/core/command.gd")
const DEFAULT_PORT = 7777
const MAX_PEERS = 8
const MAX_PENDING_PER_PEER = 16

enum NetworkMode { LOCAL, HOST, CLIENT }

var mode: NetworkMode = NetworkMode.LOCAL
var is_host: bool = true
var host_id: String = "local_player"
var peers: Dictionary = {}
var pending_commands: Array = []
var received_per_peer: Dictionary = {}
var tick_rate: int = 1
var current_port: int = 0
var connected_address: String = ""
var external_address: String = ""
var upnp_mapped: bool = false
var _upnp: UPNP

signal peer_connected(peer_id)
signal peer_disconnected(peer_id)
signal command_received(cmd)
signal state_snapshot_received(state, version, tick)
signal network_status_changed(status)
signal network_error(message)

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	start_local_mode()

func start_local_mode():
	_remove_upnp_mapping()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	mode = NetworkMode.LOCAL
	is_host = true
	host_id = "local_player"
	peers.clear()
	pending_commands.clear()
	received_per_peer.clear()
	current_port = 0
	connected_address = ""
	external_address = ""
	upnp_mapped = false
	emit_signal("network_status_changed", get_status())

func host_game(port: int = DEFAULT_PORT, max_peers: int = MAX_PEERS) -> Dictionary:
	if port < 1024 or port > 65535:
		return _error("شماره پورت باید بین ۱۰۲۴ و ۶۵۵۳۵ باشد")
	_disconnect_transport()
	var peer = ENetMultiplayerPeer.new()
	var result = peer.create_server(port, clamp(max_peers, 2, 32))
	if result != OK:
		start_local_mode()
		return _error("ساخت میزبان روی پورت %d ناموفق بود" % port)
	multiplayer.multiplayer_peer = peer
	mode = NetworkMode.HOST
	is_host = true
	host_id = str(multiplayer.get_unique_id())
	current_port = port
	connected_address = "0.0.0.0"
	emit_signal("network_status_changed", get_status())
	return {"success": true, "mode": "host", "peer_id": host_id, "port": port}

func join_game(address: String, port: int = DEFAULT_PORT) -> Dictionary:
	var clean_address = address.strip_edges()
	if clean_address.is_empty():
		return _error("نشانی میزبان وارد نشده است")
	if port < 1024 or port > 65535:
		return _error("شماره پورت نامعتبر است")
	_disconnect_transport()
	var peer = ENetMultiplayerPeer.new()
	var result = peer.create_client(clean_address, port)
	if result != OK:
		start_local_mode()
		return _error("شروع اتصال به میزبان ناموفق بود")
	multiplayer.multiplayer_peer = peer
	mode = NetworkMode.CLIENT
	is_host = false
	host_id = "1"
	current_port = port
	connected_address = clean_address
	emit_signal("network_status_changed", get_status())
	return {"success": true, "mode": "client", "address": clean_address, "port": port}

func disconnect_game():
	start_local_mode()

func try_upnp_port_mapping() -> Dictionary:
	if mode != NetworkMode.HOST or current_port <= 0:
		return _error("ابتدا بازی را میزبانی کنید")
	_remove_upnp_mapping()
	_upnp = UPNP.new()
	var discover_result = _upnp.discover(2000, 2, "InternetGatewayDevice")
	if discover_result != UPNP.UPNP_RESULT_SUCCESS:
		_upnp = null
		return _error("روتر سازگار با UPnP پیدا نشد؛ اتصال LAN همچنان فعال است")
	var gateway = _upnp.get_gateway()
	if gateway == null or not gateway.is_valid_gateway():
		_upnp = null
		return _error("درگاه اینترنتی معتبر برای UPnP یافت نشد")
	var map_result = _upnp.add_port_mapping(current_port, current_port, "Country Simulator ENet", "UDP", 0)
	if map_result != UPNP.UPNP_RESULT_SUCCESS:
		_upnp = null
		return _error("بازکردن خودکار پورت روی روتر ناموفق بود")
	upnp_mapped = true
	external_address = _upnp.query_external_address()
	emit_signal("network_status_changed", get_status())
	return {"success": true, "external_address": external_address, "port": current_port}

func _remove_upnp_mapping():
	if upnp_mapped and _upnp != null and current_port > 0:
		_upnp.delete_port_mapping(current_port, "UDP")
	upnp_mapped = false
	_upnp = null

func is_network_active() -> bool:
	return mode != NetworkMode.LOCAL and multiplayer.multiplayer_peer != null

func can_advance_tick() -> bool:
	return mode != NetworkMode.CLIENT

func send_command(cmd: GameCommandClass) -> bool:
	if not cmd is GameCommandClass:
		return false
	if mode == NetworkMode.LOCAL:
		cmd.player_id = "local_player"
		pending_commands.append(cmd)
		emit_signal("command_received", cmd)
		return true
	if mode == NetworkMode.HOST:
		cmd.player_id = host_id
		pending_commands.append(cmd)
		emit_signal("command_received", cmd)
		return true
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		_error("هنوز اتصال به میزبان برقرار نشده است")
		return false
	cmd.player_id = str(multiplayer.get_unique_id())
	cmd.tick = 0
	cmd.version = 0
	rpc_id(1, "_receive_client_command", cmd.to_dict())
	return true

func get_pending_commands() -> Array:
	if mode == NetworkMode.CLIENT:
		return []
	var cmds = pending_commands.duplicate()
	pending_commands.clear()
	received_per_peer.clear()
	return cmds

func broadcast_state(state: Dictionary, version: int, tick: int):
	if mode != NetworkMode.HOST or peers.is_empty():
		return
	var payload = JSON.stringify(state)
	var checksum = payload.sha256_text()
	rpc("_receive_state_snapshot", payload, checksum, version, tick)

func get_peers_count() -> int:
	return peers.size() + 1

func get_status() -> Dictionary:
	var mode_name = "local"
	if mode == NetworkMode.HOST:
		mode_name = "host"
	elif mode == NetworkMode.CLIENT:
		mode_name = "client"
	var connection = MultiplayerPeer.CONNECTION_DISCONNECTED
	if multiplayer.multiplayer_peer != null:
		connection = multiplayer.multiplayer_peer.get_connection_status()
	return {
		"mode": mode_name,
		"is_host": is_host,
		"host_id": host_id,
		"peers": get_peers_count(),
		"port": current_port,
		"address": connected_address,
		"external_address": external_address,
		"upnp_mapped": upnp_mapped,
		"connection": connection
	}

@rpc("any_peer", "call_remote", "reliable")
func _receive_client_command(data: Dictionary):
	if mode != NetworkMode.HOST:
		return
	var sender = multiplayer.get_remote_sender_id()
	var received = int(received_per_peer.get(sender, 0))
	if received >= MAX_PENDING_PER_PEER:
		_error("فرمان‌های بیش از حد از بازیکن %s رد شد" % str(sender))
		return
	if not _is_safe_command_packet(data):
		_error("بسته فرمان نامعتبر از بازیکن %s رد شد" % str(sender))
		return
	var cmd = GameCommandClass.from_dict(data)
	cmd.player_id = str(sender)
	cmd.tick = 0
	cmd.version = 0
	pending_commands.append(cmd)
	received_per_peer[sender] = received + 1
	emit_signal("command_received", cmd)

@rpc("authority", "call_remote", "reliable")
func _receive_state_snapshot(payload: String, checksum: String, version: int, tick: int):
	if mode != NetworkMode.CLIENT:
		return
	if payload.length() > 5_000_000:
		_error("Snapshot دریافتی بیش از حد بزرگ است")
		return
	if payload.sha256_text() != checksum:
		_error("صحت Snapshot دریافتی تأیید نشد")
		return
	var state = JSON.parse_string(payload)
	if not state is Dictionary:
		_error("Snapshot دریافتی قابل خواندن نیست")
		return
	if int(state.get("version", -1)) != version or int(state.get("tick", -1)) != tick:
		_error("نسخه Snapshot با بسته شبکه سازگار نیست")
		return
	if not state.has("economy") or not state.has("population") or not state.has("resources"):
		_error("Snapshot بخش‌های حیاتی را ندارد")
		return
	emit_signal("state_snapshot_received", state, version, tick)

func _is_safe_command_packet(data: Dictionary) -> bool:
	if not data.has("type") or not data.has("payload"):
		return false
	if not data["type"] is String or not data["payload"] is Dictionary:
		return false
	if str(data["type"]).length() > 64 or data["payload"].size() > 64:
		return false
	return true

func _on_peer_connected(peer_id: int):
	peers[peer_id] = {"connected_at": Time.get_unix_time_from_system()}
	emit_signal("peer_connected", peer_id)
	emit_signal("network_status_changed", get_status())

func _on_peer_disconnected(peer_id: int):
	peers.erase(peer_id)
	received_per_peer.erase(peer_id)
	emit_signal("peer_disconnected", peer_id)
	emit_signal("network_status_changed", get_status())

func _on_connected_to_server():
	host_id = "1"
	emit_signal("network_status_changed", get_status())

func _on_connection_failed():
	_error("اتصال به میزبان برقرار نشد")
	start_local_mode()

func _on_server_disconnected():
	_error("ارتباط با میزبان قطع شد؛ بازی به حالت تک‌نفره بازگشت")
	start_local_mode()

func _disconnect_transport():
	_remove_upnp_mapping()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	peers.clear()
	pending_commands.clear()
	received_per_peer.clear()

func _error(message: String) -> Dictionary:
	emit_signal("network_error", message)
	return {"success": false, "reason": message}
