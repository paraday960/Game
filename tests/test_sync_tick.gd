extends SceneTree
# تست تشخیصی: فقط tick همگام (بدون async) — برای جداسازی مشکل CI
func _init():
	await process_frame
	print("=== SYNC TEST START ===")
	var GS = root.get_node("GameState")
	var GE = root.get_node("GameEngine")
	var t0 = Time.get_ticks_msec()
	var result = GE.tick(GS.state.duplicate(true), 0, 0, [])
	var elapsed = (Time.get_ticks_msec() - t0) / 1000.0
	print("یک ماه tick همگام: %.2f ثانیه | success=%s" % [elapsed, result.success])
	if result.success:
		print("=== SYNC TEST PASSED ===")
		quit(0)
	else:
		printerr("=== SYNC TEST FAILED: " + str(result.reason))
		quit(1)
