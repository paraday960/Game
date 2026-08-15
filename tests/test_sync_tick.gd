extends Node
# تست تشخیصی: فقط tick همگام (بدون async) — برای جداسازی مشکل CI
func _ready():
	print("=== SYNC TEST START ===")
	var t0 = Time.get_ticks_msec()
	var result = GameEngine.tick(GameState.state.duplicate(true), 0, 0, [])
	var elapsed = (Time.get_ticks_msec() - t0) / 1000.0
	print("یک ماه tick همگام: %.2f ثانیه | success=%s" % [elapsed, result.success])
	if result.success:
		print("=== SYNC TEST PASSED ===")
		get_tree().quit(0)
	else:
		printerr("=== SYNC TEST FAILED: " + str(result.reason))
		get_tree().quit(1)
