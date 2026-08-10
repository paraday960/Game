extends Node
# تست خودکار موتور در حالت بازی واقعی - با autoloadهای واقعی

func _ready():
	print("=== TEST START ===")
	print("Systems loaded: %d" % GameEngine.systems.size())
	var failed: Array = []

	if not BalanceConfig.is_valid():
		failed.append("فایل بالانس نامعتبر است: " + str(BalanceConfig.get_errors()))
	elif not GameState.state.has("country"):
		failed.append("وضعیت آغازین داده‌محور بارگذاری نشد")
	else:
		print("Balance config + initial state data: OK")

	for n in GameEngine.system_order:
		if not GameEngine.systems.has(n):
			failed.append("در ترتیب اجراست ولی لود نشده: " + n)
	for n in GameEngine.systems.keys():
		if not GameEngine.system_order.has(n):
			failed.append("لود شده ولی در ترتیب اجرا نیست: " + n)

	var s = GameState.state
	var v = GameState.version
	var t = GameState.tick

	for i in range(10):
		var cmds: Array = []
		if i == 2:
			cmds.append(GameCommand.create_tax_set(0.25))
		if i == 5:
			cmds.append(GameCommand.create_budget_allocate({"آموزش":0.1,"بهداشت":0.1,"ارتش":0.1,"زیرساخت":0.15,"رفاه":0.15,"فناوری":0.05,"امنیت":0.05,"اداره":0.05,"محیط":0.05,"ذخیره":0.2}))
		if i == 7:
			cmds.append(GameCommand.create_diplomacy_action("همسایه_شرقی", "improve_relations"))
		var result = GameEngine.tick(s, v, t, cmds)
		if result.success:
			s = result.state
			v = result.version
			t = result.tick
			print("tick %2d OK | GDP=%.0f | pop=%d | happy=%.3f | stab=%.3f | score=%.1f | %d/%02d/%02d" % [
				t, s["economy"]["gdp"], s["population"]["total"], s["population"]["happiness"],
				s["politics"]["stability"], s.get("score", 0),
				s["clock"]["year"], s["clock"]["month"], s["clock"]["day"]])
			for key in ["economy","population","politics","military","resources","indicators","clock"]:
				if not s.has(key):
					failed.append("کلید گمشده پس از تیک: " + key)
			var g = s["economy"]["gdp"]
			if is_nan(g) or is_inf(g):
				failed.append("GDP نامعتبر در تیک %d" % t)
				break
		else:
			failed.append("تیک %d شکست: %s" % [i, result.reason])
			break

	var clock_ok = (s["clock"]["day"] == 11)  # ۱۰ تیک از روز ۱ → روز ۱۱
	print("Clock advanced: %s (day=%d season=%s)" % ["YES" if clock_ok else "NO", s["clock"]["day"], s["clock"]["season"]])
	if not clock_ok:
		failed.append("ساعت بازی پیش نرفت")

	print("Events logged: %d" % EventLog.count())

	var progression = s.get("progression", {})
	if progression.get("achievements", []).size() < 2 or int(progression.get("best_streak", 0)) < 7:
		failed.append("دستاورد یا استریک پیشرفت ثبت نشد")
	else:
		print("Progression: streak + combo + achievements OK")

	# دترمینستیک؟
	GameState.init_default_state()
	var r1 = GameEngine.tick(GameState.state, 0, 0, [])
	GameState.init_default_state()
	var r2 = GameEngine.tick(GameState.state, 0, 0, [])
	var det_ok = JSON.stringify(r1.get("state", {})) == JSON.stringify(r2.get("state", {}))
	print("Deterministic: %s" % ("OK" if det_ok else "MISMATCH"))
	if not det_ok:
		failed.append("تیک غیرقطعی")

	# ذخیره/بارگذاری
	var json = JSON.stringify(s)
	var parsed = JSON.parse_string(json)
	print("Save/Load JSON: %s" % ("OK" if parsed != null and parsed.has("economy") else "FAIL"))
	if parsed == null:
		failed.append("ذخیره JSON خراب")

	# سیستم‌های فیزیکی جدید ۳.۴۵-۳.۴۷
	for newkey in ["retail", "fuel_stations", "urban_facilities"]:
		if not s.has(newkey):
			failed.append("state سیستم جدید گمشده: " + newkey)
		else:
			print("  ✓ state: %s" % newkey)

	# تست همه AIها - هر کدام decide قابل اجرا بدون خطا
	var ai_dir = DirAccess.open("res://scripts/ai/")
	var ai_ok = 0
	var ai_fail = 0
	if ai_dir:
		for fname in ai_dir.get_files():
			if fname.ends_with("_ai.gd") and fname != "base_ai.gd":
				var ai = load("res://scripts/ai/" + fname).new()
				if ai.has_method("decide"):
					var d = ai.decide(s, t)
					if d is Array:
						ai_ok += 1
					else:
						ai_fail += 1
						failed.append("AI خروجی نامعتبر: " + fname)
	print("AI check: %d OK, %d failed" % [ai_ok, ai_fail])

	# هماهنگ‌کننده باید همه هوش‌ها را تحلیل و یک پیشنهاد معتبر تولید کند.
	var diagnoses = AIAdvisor.analyze(s, t)
	if AIAdvisor.agents.size() != 65 or diagnoses.size() != 65:
		failed.append("شورای هوشمند همه ۶۵ سامانه را تحلیل نکرد")
	else:
		var advisor_cmds = AIAdvisor.build_autonomous_commands(s, t, 1)
		if advisor_cmds.is_empty():
			failed.append("شورای هوشمند هیچ پیشنهاد اجرایی نساخت")
		else:
			var advisor_result = GameEngine.tick(s, v, t, advisor_cmds)
			if not advisor_result.success:
				failed.append("پیشنهاد شورای هوشمند نامعتبر بود: " + advisor_result.reason)
			else:
				print("AI advisor: 65 diagnoses + valid action OK")

	# تبدیل رویداد به تصمیم، اجرای گزینه در موتور اتمی و ثبت تاریخچه
	var decision_manager = load("res://scripts/core/decision_manager.gd")
	var decision_state = s.duplicate(true)
	decision_state = decision_manager.update_pending(decision_state, [
		{"system": "environment", "event": {"type": "drought"}}
	], t)
	var pending_test: Array = decision_state.get("pending_decisions", [])
	if pending_test.is_empty():
		failed.append("رویداد خشکسالی به تصمیم تبدیل نشد")
	else:
		var decision_id = str(pending_test[0]["id"])
		var decision_cmd = GameCommand.create_decision_resolve(decision_id, "irrigation")
		var decision_result = GameEngine.tick(decision_state, v, t, [decision_cmd])
		var history: Array = decision_result.get("state", {}).get("decision_history", [])
		if not decision_result.success or history.is_empty() or history[-1].get("decision_id", "") != decision_id:
			failed.append("گزینه تصمیم اتمی اجرا یا ثبت نشد")
		else:
			print("Interactive event decision + consequence: OK")

	# ذخیره اتمی نسخه‌دار + بارگذاری + تشخیص دستکاری checksum
	var save_path = "user://automated-test-save.json"
	SaveManager.delete_save(save_path)
	var original_tax = GameState.state["economy"]["tax_rate"]
	var save_result = SaveManager.save_game(save_path)
	GameState.state["economy"]["tax_rate"] = 0.77
	var load_result = SaveManager.load_game(save_path)
	if not save_result.success or not load_result.success or not is_equal_approx(GameState.state["economy"]["tax_rate"], original_tax):
		failed.append("ذخیره/بارگذاری نسخه‌دار شکست خورد")
	else:
		var save_file = FileAccess.open(save_path, FileAccess.READ)
		var wrapped = JSON.parse_string(save_file.get_as_text())
		save_file.close()
		wrapped["payload"] += " "
		var tampered = FileAccess.open(save_path, FileAccess.WRITE)
		tampered.store_string(JSON.stringify(wrapped))
		tampered.close()
		var tamper_result = SaveManager.load_game(save_path)
		if tamper_result.success:
			failed.append("فایل ذخیره دستکاری‌شده پذیرفته شد")
		else:
			print("Versioned atomic save + checksum: OK")
	SaveManager.delete_save(save_path)

	# اعتبارسنجی سخت‌گیرانه فرمان ناشناخته
	var bad_cmd = GameCommand.new("unknown_command", {})
	var before_bad_state = JSON.stringify(GameState.state)
	var bad_result = GameEngine.tick(GameState.state, GameState.version, GameState.tick, [bad_cmd])
	if bad_result.success or JSON.stringify(GameState.state) != before_bad_state:
		failed.append("فرمان ناشناخته رد نشد یا وضعیت را تغییر داد")
	else:
		print("Unknown command rejected: OK")

	# رویدادهای میانی یک تراکنش Rollback نباید در لاگ باقی بمانند
	var event_count_before = EventLog.count()
	if not EventLog.begin_transaction():
		failed.append("تراکنش آزمایشی EventLog باز نشد")
	else:
		EventLog.log_event("test_uncommitted", {"should_disappear": true})
		EventLog.rollback_transaction()
		if EventLog.count() != event_count_before:
			failed.append("Rollback رویداد میانی را حذف نکرد")
		else:
			print("Atomic event rollback: OK")

	print("")
	if failed.size() == 0:
		print("=== ✅ ALL TESTS PASSED (%d systems) ===" % GameEngine.systems.size())
	else:
		print("=== ❌ ISSUES FOUND: %d ===" % failed.size())
		var seen = {}
		for f in failed:
			if not seen.has(f):
				print("  ✗ " + f)
				seen[f] = true

	get_tree().quit(0 if failed.size() == 0 else 1)
