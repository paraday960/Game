extends Node
# چندنفره مستقیم رایگان با ENet: میزبان مرجع + فرمان‌محور + Snapshot امضاشده

const GameCommandClass = preload("res://scripts/core/command.gd")
const DEFAULT_PORT = 7777
const MAX_PEERS = 8
const MAX_PENDING_PER_PEER = 16
# سرورهای STUN عمومی رایگان (برای کشف آدرس عمومی و اتصال راه دور بدون سرور)
const STUN_SERVERS = [
	["stun.l.google.com", 19302],
	["stun1.l.google.com", 19302],
	["stun.cloudflare.com", 3478],
	["stun.stunprotocol.org", 3478]
]

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
var public_address: String = ""  # آدرس عمومی (IP:port) برای اتصال راه دور
var competitive_mode: bool = false
var campaign_player_name: String = "بازیکن"
var campaign_country_id: String = ""
var _upnp: UPNP

signal peer_connected(peer_id)
signal peer_disconnected(peer_id)
signal command_received(cmd)
signal state_snapshot_received(state, version, tick)
signal campaign_lobby_received(lobby)
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
	competitive_mode = false
	campaign_country_id = ""
	MultiplayerCampaignManager.reset()
	emit_signal("network_status_changed", get_status())

func host_game(port: int = DEFAULT_PORT, max_peers: int = MAX_PEERS) -> Dictionary:
	if port < 1024 or port > 65535:
		return _error("شماره پورت باید بین ۱۰۲۴ و ۶۵۵۳۵ باشد")
	# بستن کامل ترنسپورت قبلی تا پورت واقعاً آزاد شود (مهم در اندروید)
	_disconnect_transport()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	# تلاش مجدد خودکار: پورت ممکن است لحظه‌ای در حال استفاده باشد (زمان آزادسازی)
	var last_error := ERR_CANT_CREATE
	var peer: ENetMultiplayerPeer = null
	for attempt in range(3):
		peer = ENetMultiplayerPeer.new()
		last_error = peer.create_server(port, clamp(max_peers, 2, 32))
		if last_error == OK:
			break
		peer = null
		if attempt < 2:
			OS.delay_msec(150)
	if last_error != OK:
		start_local_mode()
		return _error("ساخت میزبان روی پورت %d ناموفق بود (کد خطا %d)؛ پورت ممکن است در حال استفاده باشد — پورت دیگری امتحان کنید" % [port, last_error])
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
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	var last_error := ERR_CANT_CREATE
	var peer: ENetMultiplayerPeer = null
	for attempt in range(3):
		peer = ENetMultiplayerPeer.new()
		last_error = peer.create_client(clean_address, port)
		if last_error == OK:
			break
		peer = null
		if attempt < 2:
			OS.delay_msec(150)
	if last_error != OK:
		start_local_mode()
		return _error("شروع اتصال به میزبان ناموفق بود (کد خطا %d)" % last_error)
	multiplayer.multiplayer_peer = peer
	mode = NetworkMode.CLIENT
	is_host = false
	host_id = "1"
	current_port = port
	connected_address = clean_address
	emit_signal("network_status_changed", get_status())
	return {"success": true, "mode": "client", "address": clean_address, "port": port}

func host_competitive(player_name:String,country_id:String,port:int=DEFAULT_PORT)->Dictionary:
	var result=host_game(port,MAX_PEERS)
	if not result.success:return result
	competitive_mode=true;campaign_player_name=player_name;campaign_country_id=country_id
	var lobby=MultiplayerCampaignManager.create_lobby(host_id,player_name,country_id)
	emit_signal("campaign_lobby_received",MultiplayerCampaignManager.get_lobby_snapshot())
	return lobby

func join_competitive(address:String,port:int,player_name:String,country_id:String)->Dictionary:
	competitive_mode=true;campaign_player_name=player_name;campaign_country_id=country_id
	var result=join_game(address,port)
	if not result.success:competitive_mode=false
	return result

func set_campaign_ready(value:bool):
	if not competitive_mode:return
	if is_host:
		MultiplayerCampaignManager.set_ready(host_id,value);_broadcast_lobby()
	else:rpc_id(1,"_receive_campaign_ready",value)

func start_competitive_campaign()->Dictionary:
	if not competitive_mode or not is_host:return _error("فقط میزبان رقابتی می‌تواند کمپین را آغاز کند")
	var result=MultiplayerCampaignManager.start_campaign(GameState.state)
	if result.success:_broadcast_lobby();_broadcast_campaign_states()
	return result

func advance_competitive_month(local_commands:Array)->Dictionary:
	if not competitive_mode or not is_host or not MultiplayerCampaignManager.started:return {"success":false,"reason":"کمپین رقابتی آماده نیست"}
	for command in local_commands:MultiplayerCampaignManager.enqueue_command(host_id,command)
	var result=MultiplayerCampaignManager.advance_month()
	if not result.success:return result
	_broadcast_campaign_states()
	return {"success":true,"state":MultiplayerCampaignManager.get_state_for_peer(host_id),"turn":result.turn}

func disconnect_game():
	start_local_mode()

# ════════════════════════════════════════════════════════════════
# اتصال رایگان از راه دور (اینترنت): STUN + کد اتصال + سوراخ‌کاری NAT
# ════════════════════════════════════════════════════════════════

# پرس‌وجوی STUN: آدرس عمومی (نقشه‌شده توسط NAT) را از سرور عمومی می‌گیرد
func _stun_query(stun_host: String, stun_port: int) -> Dictionary:
	var sock := PacketPeerUDP.new()
	if sock.bind(0) != OK:
		return {}
	var msg := PackedByteArray()
	msg.resize(20)
	msg.encode_u16(0, 0x0001)          # Binding Request
	msg.encode_u16(2, 0)
	msg.encode_u32(4, 0x2112A442)      # magic cookie
	for i in range(12):
		msg[8 + i] = (randi() & 0xFF)
	sock.set_dest_address(stun_host, stun_port)
	sock.put_packet(msg)
	var deadline := Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < deadline:
		if sock.get_available_packet_count() > 0:
			var resp := sock.get_packet()
			if resp.size() >= 20 and resp.decode_u32(4) == 0x2112A442:
				var i := 20
				while i + 4 <= resp.size():
					var atype := resp.decode_u16(i)
					var alen := resp.decode_u16(i + 2)
					if atype == 0x0020 and i + 4 + 8 <= resp.size():  # XOR-MAPPED-ADDRESS
						var family := resp[i + 4 + 1]
						if family == 0x01:  # IPv4
							var xport := resp.decode_u16(i + 4 + 2) ^ 0x2112
							var ip := "%d.%d.%d.%d" % [
								resp[i + 4 + 4] ^ msg[8], resp[i + 4 + 5] ^ msg[9],
								resp[i + 4 + 6] ^ msg[10], resp[i + 4 + 7] ^ msg[11]]
							sock.close()
							return {"ip": ip, "port": xport}
					elif atype == 0x0001 and i + 4 + 8 <= resp.size():  # MAPPED-ADDRESS
						var family2 := resp[i + 4 + 1]
						if family2 == 0x01:
							var port2 := resp.decode_u16(i + 4 + 2)
							var ip2 := "%d.%d.%d.%d" % [resp[i + 4 + 4], resp[i + 4 + 5], resp[i + 4 + 6], resp[i + 4 + 7]]
							sock.close()
							return {"ip": ip2, "port": port2}
					i += 4 + alen
		await get_tree().create_timer(0.05).timeout
	sock.close()
	return {}

# کشف آدرس عمومی: چند سرور STUN را امتحان می‌کند
func detect_public_address() -> String:
	for server in STUN_SERVERS:
		var result: Dictionary = await _stun_query(str(server[0]), int(server[1]))
		if not result.is_empty():
			public_address = "%s:%d" % [str(result.get("ip", "")), int(result.get("port", 0))]
			return public_address
	return ""

# میزبانی راه دور: میزبانی + بازکردن خودکار پورت (UPnP) + کشف آدرس عمومی
func host_remote(port: int = DEFAULT_PORT, max_peers: int = MAX_PEERS) -> Dictionary:
	var result := host_game(port, max_peers)
	if not result.success:
		return result
	# UPnP و STUN به‌صورت غیرمسدودکننده اجرا می‌شوند تا ENet بتواند اتصال‌ها را بپذیرد
	var upnp_result := try_upnp_port_mapping()
	var pub: String = await detect_public_address()
	return {
		"success": true, "mode": "host", "peer_id": host_id, "port": port,
		"public_address": pub, "upnp": bool(upnp_result.get("success", false))
	}

# ارسال چند بسته به آدرس عمومی میزبان برای بازکردن سوراخ NAT (به‌ترین تلاش)
func _poke_public(address: String, port: int, local_port: int):
	var sock := PacketPeerUDP.new()
	if sock.bind(local_port) != OK:
		return
	sock.set_dest_address(address, port)
	var payload := PackedByteArray([0x43, 0x53, 0x31, 0x00])  # "CS1"
	for i in range(4):
		sock.put_packet(payload)
		await get_tree().create_timer(0.1).timeout
	sock.close()

# اتصال راه دور با کد: «IP عمومی میزبان:پورت» — پوک + اتصال با همان پورت محلی
func join_remote(code: String) -> Dictionary:
	var clean := code.strip_edges()
	if clean.is_empty():
		return _error("کد اتصال راه دور وارد نشده است")
	var parts := clean.split(":")
	var address := str(parts[0]).strip_edges()
	if address.is_empty() or not address.contains("."):
		return _error("کد اتصال نامعتبر است؛ باید به شکل آدرس:پورت باشد")
	var port := DEFAULT_PORT
	if parts.size() >= 2:
		port = int(parts[1])
	if port < 1024 or port > 65535:
		return _error("پورت کد اتصال نامعتبر است")
	# پوکینگ: پورت محلی ثابت انتخاب کن تا نگاشت NAT با ENet یکی بماند
	var local_port := port + 1
	await _poke_public(address, port, local_port)
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(address, port, local_port)
	if result != OK:
		start_local_mode()
		return _error("شروع اتصال راه دور ناموفق بود (کد خطا %d)" % result)
	multiplayer.multiplayer_peer = peer
	mode = NetworkMode.CLIENT
	is_host = false
	host_id = "1"
	current_port = port
	connected_address = address
	emit_signal("network_status_changed", get_status())
	return {"success": true, "mode": "client", "address": address, "port": port, "remote": true}

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
		if competitive_mode and MultiplayerCampaignManager.started:
			return MultiplayerCampaignManager.enqueue_command(host_id,cmd).success
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
		"competitive_mode": competitive_mode,
		"campaign_started": MultiplayerCampaignManager.started,
		"campaign_players": MultiplayerCampaignManager.peer_registry.size(),
		"connection": connection
	}

@rpc("any_peer","call_remote","reliable")
func _request_campaign_join(player_name:String,country_id:String):
	if not is_host or not competitive_mode:return
	var sender=str(multiplayer.get_remote_sender_id());var result=MultiplayerCampaignManager.register_peer(sender,player_name,country_id)
	if not result.success:rpc_id(int(sender),"_campaign_join_rejected",str(result.reason))
	_broadcast_lobby()

@rpc("any_peer","call_remote","reliable")
func _receive_campaign_ready(value:bool):
	if is_host and competitive_mode:MultiplayerCampaignManager.set_ready(str(multiplayer.get_remote_sender_id()),value);_broadcast_lobby()

@rpc("authority","call_remote","reliable")
func _receive_campaign_lobby(lobby:Dictionary):
	emit_signal("campaign_lobby_received",lobby)

@rpc("authority","call_remote","reliable")
func _campaign_join_rejected(reason:String):
	_error("ورود به کمپین رد شد: "+reason)

@rpc("authority","call_remote","reliable")
func _receive_campaign_snapshot(payload:String,checksum:String,version:int,tick:int):
	if payload.sha256_text()!=checksum:return _error("صحت Snapshot کشور تأیید نشد")
	var state=JSON.parse_string(payload)
	if not state is Dictionary:return _error("Snapshot کشور نامعتبر است")
	emit_signal("state_snapshot_received",state,version,tick)

func _broadcast_lobby():
	var lobby=MultiplayerCampaignManager.get_lobby_snapshot();emit_signal("campaign_lobby_received",lobby)
	if mode==NetworkMode.HOST and not peers.is_empty():rpc("_receive_campaign_lobby",lobby)

func _broadcast_campaign_states():
	if not is_host:return
	for peer_id in MultiplayerCampaignManager.peer_registry.keys():
		var state=MultiplayerCampaignManager.get_state_for_peer(str(peer_id));var payload=JSON.stringify(state);var checksum=payload.sha256_text()
		if str(peer_id)==host_id:emit_signal("state_snapshot_received",state,int(state.get("version",0)),int(state.get("tick",0)))
		elif int(peer_id)>0:rpc_id(int(peer_id),"_receive_campaign_snapshot",payload,checksum,int(state.get("version",0)),int(state.get("tick",0)))

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
	if competitive_mode and MultiplayerCampaignManager.started:
		var routed=MultiplayerCampaignManager.enqueue_command(str(sender),cmd)
		if not routed.success:_error(str(routed.reason));return
	else:
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
	if competitive_mode:MultiplayerCampaignManager.unregister_peer(str(peer_id));_broadcast_lobby()
	emit_signal("peer_disconnected", peer_id)
	emit_signal("network_status_changed", get_status())

func _on_connected_to_server():
	host_id = "1"
	if competitive_mode:rpc_id(1,"_request_campaign_join",campaign_player_name,campaign_country_id)
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
