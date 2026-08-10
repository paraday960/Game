extends SceneTree
# نیمه کلاینت تست یکپارچه ENet؛ فرمان می‌فرستد و Snapshot امضاشده می‌گیرد.

signal test_finished
var passed := false
var p2p

func _init():
	await process_frame
	p2p = root.get_node("P2PManager")
	p2p.state_snapshot_received.connect(_on_snapshot)
	var result = p2p.join_game("127.0.0.1", 18777)
	if not result.success:
		printerr("NETWORK CLIENT START FAILED: " + result.reason)
		quit(1)
		return
	await create_timer(0.8).timeout
	var command_class = load("res://scripts/core/command.gd")
	if not p2p.send_command(command_class.create_tax_set(0.31)):
		printerr("NETWORK CLIENT SEND FAILED")
		quit(1)
		return
	var timeout = create_timer(10.0)
	timeout.timeout.connect(_on_timeout)
	await test_finished
	p2p.disconnect_game()
	quit(0 if passed else 1)

func _on_snapshot(state: Dictionary, version: int, tick: int):
	if version == 1 and tick == 1 and is_equal_approx(state["economy"]["tax_rate"], 0.31):
		passed = true
		print("=== ✅ ENET CLIENT SIGNED SNAPSHOT PASSED ===")
	else:
		printerr("NETWORK CLIENT SNAPSHOT INVALID")
	test_finished.emit()

func _on_timeout():
	if not passed:
		printerr("NETWORK CLIENT TIMEOUT")
		test_finished.emit()
