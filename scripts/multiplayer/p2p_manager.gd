extends Node
# مدیریت P2P - بخش ۳.۸ - بدون سرور مرکزی، پردازش روی گوشی
const GameCommandClass = preload("res://scripts/core/command.gd")

var is_host: bool = false
var host_id: String = ""
var peers: Dictionary = {}  # peer_id -> info
var pending_commands: Array = []
var tick_rate: int = 1  # تیک در ثانیه - برای نسخه اولیه کم

signal peer_connected(peer_id)
signal peer_disconnected(peer_id)
signal command_received(cmd)

func _ready():
    # حالت تک‌نفره پیش‌فرض
    is_host = true
    host_id = "local_player"

func host_game():
    is_host = true
    host_id = "player_%d" % (randi() % 100000)
    print("بازی میزبانی شد با شناسه: %s" % host_id)
    return host_id

func join_game(join_host_id: String):
    is_host = false
    host_id = join_host_id
    print("اتصال به میزبان: %s" % join_host_id)

func send_command(cmd: GameCommandClass):
    # در نسخه تک‌نفره مستقیم اعمال می‌شود
    # در نسخه P2P از طریق WebSocket ارسال می‌شود
    pending_commands.append(cmd)
    emit_signal("command_received", cmd)
    if is_host:
        # هاست فرمان‌ها را جمع و تیک می‌زند
        pass
    else:
        # کلاینت به هاست می‌فرستد
        pass

func get_pending_commands() -> Array:
    var cmds = pending_commands.duplicate()
    pending_commands.clear()
    return cmds

func get_peers_count() -> int:
    return peers.size() + 1

# مطابق قانون ۵ - فقط منابع رایگان: WebSocket رایگان Godot
func _migrate_host():
    # انتقال میزبانی در صورت خروج هاست - ۳.۸
    if peers.size() > 0:
        var new_host = peers.keys()[0]
        host_id = new_host
        if new_host == "local_player":
            is_host = true
        print("میزبانی منتقل شد به: %s" % host_id)
