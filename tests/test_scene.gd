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
	if not TechnologyManager.is_valid():
		failed.append("درخت فناوری داده‌محور نامعتبر است")
	if not WorldManager.is_valid() or GameState.state.get("diplomacy", {}).get("relations", {}).size() != 15:
		failed.append("داده جهان یا روابط ۱۶ کشور کامل نیست")
	else:
		var country_result = GameEngine.tick(GameState.state, 0, 0, [GameCommand.create_country_select("JPN")])
		if not country_result.success or country_result.state.get("country", {}).get("id", "") != "JPN":
			failed.append("انتخاب اتمی کشور آغازین شکست خورد")
		else:
			print("World data: 16 countries + atomic country selection OK")

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
			cmds.append(GameCommand.create_diplomacy_action("TUR", "improve_relations"))
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

	# درخت فناوری: پیش‌نیاز، هزینه و اثر واقعی تکمیل
	var research_state = s.duplicate(true)
	var research_id = "advanced_manufacturing"
	research_state["technology"]["research_points"] = TechnologyManager.get_cost(research_id)
	var productivity_before = float(research_state.get("industry", {}).get("productivity", 0.0))
	var research_result = GameEngine.tick(research_state, v, t, [GameCommand.create_research_start(research_id)])
	if not research_result.success or not research_result.state["technology"]["unlocked"].has(research_id):
		failed.append("فناوری انتخابی تکمیل و باز نشد")
	elif float(research_result.state.get("industry", {}).get("productivity", 0.0)) <= productivity_before:
		failed.append("اثر چندسیستمی فناوری اعمال نشد")
	else:
		var locked_result = GameEngine.tick(s, v, t, [GameCommand.create_research_start("quantum_radar")])
		if locked_result.success:
			failed.append("فناوری بدون پیش‌نیاز پذیرفته شد")
		else:
			print("Technology tree: prerequisites + cost + effects OK")

	# دیپلماسی حرفه‌ای: توافق تجاری، جنگ روزانه و صلح
	var trade_cmd = GameCommand.create_diplomacy_action("TUR", "trade_agreement")
	var trade_result = GameEngine.tick(s, v, t, [trade_cmd])
	if not trade_result.success or not trade_result.state.get("world", {}).get("trade_agreements", []).has("TUR"):
		failed.append("توافق تجاری بین‌المللی اعمال نشد")
	else:
		var war_state = s.duplicate(true)
		war_state["diplomacy"]["relations"]["USA"] = 20.0
		war_state["diplomacy"]["action_points"] = 5.0
		var war_result = GameEngine.tick(war_state, v, t, [GameCommand.create_diplomacy_action("USA", "declare_war")])
		if not war_result.success or not war_result.state.get("world", {}).get("wars", {}).has("USA"):
			failed.append("اعلام جنگ یا شبیه‌سازی نبرد فعال نشد")
		else:
			war_result.state["diplomacy"]["action_points"] = 5.0
			var peace_result = GameEngine.tick(war_result.state, war_result.version, war_result.tick, [GameCommand.create_diplomacy_action("USA", "offer_peace")])
			if not peace_result.success or peace_result.state.get("world", {}).get("wars", {}).has("USA"):
				failed.append("پیمان صلح جنگ را پایان نداد")
			else:
				print("World diplomacy: trade + war simulation + peace OK")

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

	# جایگاه‌های چندگانه و فراداده بدون بارگذاری کامل
	SaveManager.delete_save(SaveManager.slot_path(1))
	var slot_result = SaveManager.save_slot(1)
	var slot_metadata = SaveManager.list_slots()[0]
	GameState.state["economy"]["tax_rate"] = 0.66
	var slot_load = SaveManager.load_slot(1)
	if not slot_result.success or not slot_metadata.get("valid", false) or not slot_load.success:
		failed.append("جایگاه ذخیره یا فراداده آن نامعتبر است")
	elif not is_equal_approx(GameState.state["economy"]["tax_rate"], original_tax):
		failed.append("بارگذاری جایگاه وضعیت را بازیابی نکرد")
	else:
		print("Five save slots + metadata + load: OK")
	SaveManager.delete_save(SaveManager.slot_path(1))

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
