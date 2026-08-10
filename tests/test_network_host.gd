extends SceneTree
# نیمه میزبان تست یکپارچه ENet؛ همراه test_network_client.gd اجرا می‌شود.

signal test_finished
var passed := false
var p2p

func _init():
	await process_frame
	p2p = root.get_node("P2PManager")
	p2p.command_received.connect(_on_command_received)
	var result = p2p.host_game(18777, 4)
	if not result.success:
		printerr("NETWORK HOST FAILED: " + result.reason)
		quit(1)
		return
	var timeout = create_timer(10.0)
	timeout.timeout.connect(_on_timeout)
	await test_finished
	# فرصت تحویل RPC مربوط به Snapshot پیش از بستن ENet
	await create_timer(0.8).timeout
	p2p.disconnect_game()
	quit(0 if passed else 1)

func _on_command_received(_cmd):
	if passed:
		return
	var commands = p2p.get_pending_commands()
	if commands.is_empty():
		return
	var state = root.get_node("GameState")
	var engine = root.get_node("GameEngine")
	var tick_result = engine.tick(state.state, state.version, state.tick, commands)
	if not tick_result.success:
		printerr("NETWORK HOST TICK FAILED: " + tick_result.reason)
		test_finished.emit()
		return
	state.set_state(tick_result.state, tick_result.version, tick_result.tick)
	p2p.broadcast_state(tick_result.state, tick_result.version, tick_result.tick)
	if is_equal_approx(tick_result.state["economy"]["tax_rate"], 0.31):
		passed = true
		print("=== ✅ ENET HOST COMMAND COMMIT PASSED ===")
	else:
		printerr("NETWORK HOST TAX COMMAND NOT APPLIED")
	test_finished.emit()

func _on_timeout():
	if not passed:
		printerr("NETWORK HOST TIMEOUT")
		test_finished.emit()
