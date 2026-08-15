extends SceneTree
# تست رفع «فرمان تکراری»: چند فرمان از یک نوع با اهداف مختلف در یک نوبت
# (با -s اجرا می‌شود؛ autoload ها از root گرفته می‌شوند مثل test_ui.gd)
func _init():
	await process_frame
	await process_frame
	print("=== MULTI COMMAND TEST ===")
	var gs: Node = root.get_node("GameState")
	var engine: Node = root.get_node("GameEngine")
	var s: Dictionary = gs.get_state_copy()
	var v: int = gs.version
	var t: int = gs.tick

	# سناریوی ۱: دو اقدام دیپلماتیک به دو کشور مختلف (همان نوع، payload متفاوت)
	var cmds1: Array = [
		GameCommand.create_diplomacy_action("TUR", "improve_relations"),
		GameCommand.create_diplomacy_action("RUS", "improve_relations")
	]
	var r1: Dictionary = engine.tick(s.duplicate(true), v, t, cmds1)
	print("دو دیپلماسی (TUR+RUS): success=%s" % str(r1.success))
	if not r1.success:
		print("  reason: %s" % str(r1.reason))
		printerr("MULTI FAIL: دو اقدام دیپلماتیک متفاوت رد شد")
		quit(1)
		return

	# سناریوی ۲: دو قانون مختلف در یک نوبت
	var cmds2: Array = [
		GameCommand.create_law_change("anti_corruption_act", "enact"),
		GameCommand.create_law_change("judicial_independence", "enact")
	]
	var r2: Dictionary = engine.tick(s.duplicate(true), v, t, cmds2)
	print("دو قانون: success=%s" % str(r2.success))
	if not r2.success:
		print("  reason: %s" % str(r2.reason))
		printerr("MULTI FAIL: دو قانون متفاوت رد شد")
		quit(1)
		return

	# سناریوی ۳: دو پروژه ملی مختلف
	var cmds3: Array = [
		GameCommand.create_national_project("water_security"),
		GameCommand.create_national_project("highway_network")
	]
	var r3: Dictionary = engine.tick(s.duplicate(true), v, t, cmds3)
	print("دو پروژه: success=%s" % str(r3.success))
	if not r3.success:
		print("  reason: %s" % str(r3.reason))
		printerr("MULTI FAIL: دو پروژه متفاوت رد شد")
		quit(1)
		return

	# سناریوی ۴: فرمان واقعاً تکراری (همان payload) باید رد شود
	var cmds4: Array = [
		GameCommand.create_diplomacy_action("TUR", "improve_relations"),
		GameCommand.create_diplomacy_action("TUR", "improve_relations")
	]
	var r4: Dictionary = engine.tick(s.duplicate(true), v, t, cmds4)
	print("دو فرمان یکسان: success=%s (باید false)" % str(r4.success))
	if r4.success:
		printerr("MULTI FAIL: فرمان واقعاً تکراری رد نشد!")
		quit(1)
		return

	# سناریوی ۵: دو تصمیم رویداد (decision_resolve) با decision_id متفاوت
	var cmds5: Array = [
		GameCommand.create_decision_resolve("dec_1", "choice_a"),
		GameCommand.create_decision_resolve("dec_2", "choice_b")
	]
	var r5: Dictionary = engine.tick(s.duplicate(true), v, t, cmds5)
	print("دو تصمیم رویداد: success=%s" % str(r5.success))
	if not r5.success and "تکراری" in str(r5.reason):
		printerr("MULTI FAIL: دو decision_resolve متفاوت به‌عنوان تکراری رد شد")
		quit(1)
		return

	print("=== MULTI COMMAND TEST PASSED ===")
	quit(0)
