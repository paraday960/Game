extends Node
# تست رفع «فرمان تکراری»: چند فرمان از یک نوع با اهداف مختلف در یک نوبت
func _ready():
	print("=== MULTI COMMAND TEST ===")
	var s = GameState.get_state_copy()
	var v = GameState.version
	var t = GameState.tick

	# سناریوی ۱: دو اقدام دیپلماتیک به دو کشور مختلف (همان نوع، payload متفاوت)
	var cmds1: Array = [
		GameCommand.create_diplomacy_action("TUR", "improve_relations"),
		GameCommand.create_diplomacy_action("RUS", "improve_relations")
	]
	var r1 = GameEngine.tick(s.duplicate(true), v, t, cmds1)
	print("دو دیپلماسی (TUR+RUS): success=%s" % str(r1.success))
	if not r1.success:
		print("  reason: %s" % str(r1.reason))
		printerr("MULTI FAIL: دو اقدام دیپلماتیک متفاوت رد شد")
		get_tree().quit(1)
		return

	# سناریوی ۲: دو قانون مختلف در یک نوبت
	var cmds2: Array = [
		GameCommand.create_law_change("anti_corruption_act", "enact"),
		GameCommand.create_law_change("judicial_independence", "enact")
	]
	var r2 = GameEngine.tick(s.duplicate(true), v, t, cmds2)
	print("دو قانون: success=%s" % str(r2.success))
	if not r2.success:
		printerr("MULTI FAIL: دو قانون متفاوت رد شد")
		get_tree().quit(1)
		return

	# سناریوی ۳: دو پروژه ملی مختلف
	var cmds3: Array = [
		GameCommand.create_national_project("water_security"),
		GameCommand.create_national_project("highway_network")
	]
	var r3 = GameEngine.tick(s.duplicate(true), v, t, cmds3)
	print("دو پروژه: success=%s" % str(r3.success))
	if not r3.success:
		printerr("MULTI FAIL: دو پروژه متفاوت رد شد")
		get_tree().quit(1)
		return

	# سناریوی ۴: فرمان واقعاً تکراری (همان payload) باید رد شود
	var cmds4: Array = [
		GameCommand.create_diplomacy_action("TUR", "improve_relations"),
		GameCommand.create_diplomacy_action("TUR", "improve_relations")
	]
	var r4 = GameEngine.tick(s.duplicate(true), v, t, cmds4)
	print("دو فرمان یکسان: success=%s (باید false)" % str(r4.success))
	if r4.success:
		printerr("MULTI FAIL: فرمان واقعاً تکراری رد نشد!")
		get_tree().quit(1)
		return

	# سناریوی ۵: دو تصمیم رویداد (decision_resolve) با decision_id متفاوت
	var cmds5: Array = [
		GameCommand.create_decision_resolve("dec_1", "choice_a"),
		GameCommand.create_decision_resolve("dec_2", "choice_b")
	]
	var r5 = GameEngine.tick(s.duplicate(true), v, t, cmds5)
	print("دو تصمیم رویداد: success=%s" % str(r5.success))
	if not r5.success:
		# این ممکن است به دلیل نبود تصمیم pending رد شود — فقط بررسی کن که دلیلش «تکراری» نباشد
		if "تکراری" in str(r5.reason):
			printerr("MULTI FAIL: دو decision_resolve متفاوت به‌عنوان تکراری رد شد")
			get_tree().quit(1)
			return

	print("=== MULTI COMMAND TEST PASSED ===")
	get_tree().quit(0)
