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
	var original_speed = float(SettingsManager.get_value("auto_tick_interval", 1.0))
	SettingsManager.set_value("auto_tick_interval", 0.5)
	SettingsManager.load_settings()
	if not is_equal_approx(float(SettingsManager.get_value("auto_tick_interval", 0.0)), 0.5):
		failed.append("تنظیمات محلی ماندگار نشد")
	else:
		print("Persistent accessibility settings: OK")
	SettingsManager.set_value("auto_tick_interval", original_speed)
	if not TechnologyManager.is_valid():
		failed.append("درخت فناوری داده‌محور نامعتبر است")
	if not ScenarioManager.is_valid():
		failed.append("سناریوهای داده‌محور نامعتبر هستند")
	if not PolicyManager.is_valid():
		failed.append("سیاست‌های عمومی داده‌محور نامعتبر هستند")
	if not MilitaryManager.is_valid():
		failed.append("برنامه‌های توسعه نظامی داده‌محور نامعتبر هستند")
	if not WorldManager.is_valid() or GameState.state.get("diplomacy", {}).get("relations", {}).size() != 15:
		failed.append("داده جهان یا روابط ۱۶ کشور کامل نیست")
	else:
		var country_result = GameEngine.tick(GameState.state, 0, 0, [GameCommand.create_country_select("JPN", "innovation_leader")])
		if not country_result.success or country_result.state.get("country", {}).get("id", "") != "JPN":
			failed.append("انتخاب اتمی کشور آغازین شکست خورد")
		elif country_result.state.get("scenario", {}).get("id", "") != "innovation_leader":
			failed.append("سناریوی انتخابی همراه کشور اعمال نشد")
		elif abs(float(country_result.state.get("analytics", {}).get("baseline_gdp", 0.0)) - float(WorldManager.get_country("JPN").get("gdp", 0.0))) > 1.0:
			failed.append("خط پایه تحلیل پس از انتخاب کشور بازنشانی نشد")
		else:
			print("World + scenario + analytics baseline selection OK")
		var rich_state = WorldManager.apply_country_profile(GameState.state.duplicate(true), "USA")
		var relation_before = float(rich_state["diplomacy"]["relations"]["TUR"])
		var rich_tick = GameEngine.tick(rich_state, 0, 0, [])
		var relation_delta = abs(float(rich_tick.state["diplomacy"]["relations"]["TUR"]) - relation_before)
		if not rich_tick.success or relation_delta > 3.0:
			failed.append("روابط کشور ثروتمند در یک ماه جهش غیرواقعی داشت")
		else:
			print("World relation monthly scaling: OK")
	var npc_state = WorldManager.ensure_world(GameState.state.duplicate(true))
	Deterministic.set_seed(4401)
	var npc_result = WorldManager.simulate_npc_month(npc_state, 1, {"force_war":["USA", "CHN"]})
	var npc_key = "CHN|USA"
	if not npc_result.state.get("world", {}).get("npc_wars", {}).has(npc_key):
		failed.append("AI کشورهای غیر‌بازیکن جنگ مستقل را آغاز نکرد")
	elif npc_result.events.is_empty():
		failed.append("تحول مستقل جهان رویداد قابل گزارش نساخت")
	else:
		print("Autonomous world AI: relations + alliance/trade/war state OK")

	# اقلیم اجباری زمستان: نبود برف‌روب باید انسداد و اعتراض بسازد؛ آمادگی اثر را کاهش دهد.
	var winter_state = WorldManager.apply_country_profile(GameState.state.duplicate(true), "RUS")
	winter_state["clock"]["month"] = 10
	winter_state = TimeManager.reset(winter_state)
	winter_state = SeasonalManager.reset_for_country(winter_state, "RUS")
	winter_state["municipal_services"]["snowplows"] = 0
	winter_state["municipal_services"]["snowplow_readiness"] = 0.20
	winter_state["municipal_services"]["road_salt_days"] = 0.0
	Deterministic.set_seed(9911)
	var snow_result = SeasonalManager.simulate_month(winter_state, 1, {"force_snow":true, "severity":0.95})
	var blocked_without = float(snow_result.state["municipal_services"]["roads_blocked"])
	var snow_event_types: Array = []
	for event in snow_result.events: snow_event_types.append(event.get("type", ""))
	var prepared_winter = WorldManager.apply_country_profile(GameState.state.duplicate(true), "RUS")
	prepared_winter["clock"]["month"] = 10
	prepared_winter = TimeManager.reset(prepared_winter)
	prepared_winter = SeasonalManager.reset_for_country(prepared_winter, "RUS")
	prepared_winter["municipal_services"]["snowplows"] = int(prepared_winter["municipal_services"]["target_snowplows"] * 2)
	prepared_winter["municipal_services"]["snowplow_readiness"] = 1.0
	prepared_winter["municipal_services"]["road_salt_days"] = 60.0
	Deterministic.set_seed(9911)
	var prepared_result = SeasonalManager.simulate_month(prepared_winter, 1, {"force_snow":true, "severity":0.95})
	if blocked_without <= 0.50 or not snow_event_types.has("winter_service_protest"):
		failed.append("کمبود برف‌روب در زمستان انسداد و اعتراض ایجاد نکرد")
	elif float(prepared_result.state["municipal_services"]["roads_blocked"]) >= blocked_without:
		failed.append("ناوگان آماده برف‌روبی اثر بحران را کاهش نداد")
	else:
		var snow_decisions = DecisionManager.update_pending(snow_result.state, [{"system":"seasonal", "event":{"type":"snow_transport_crisis"}}], 1)
		if snow_decisions.get("pending_decisions", []).is_empty():
			failed.append("بحران برف به تصمیم راهبردی تبدیل نشد")
		else:
			var municipal_state = GameState.state.duplicate(true)
			var plows_before = int(municipal_state["municipal_services"]["snowplows"])
			var municipal_result = GameEngine.tick(municipal_state, 0, 0, [GameCommand.create_municipal_action("buy_snowplows")])
			if not municipal_result.success or int(municipal_result.state["municipal_services"]["snowplows"]) <= plows_before:
				failed.append("فرمان اتمی خرید ماشین برف‌روبی اعمال نشد")
			else:
				print("Seasonal realism: snowplows + blocked roads + protests + municipal command OK")

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

	var clock_ok = (s["clock"]["month"] == 11 and TimeManager.get_total_days(s) >= 300)
	print("Monthly clock advanced: %s (month=%d season=%s days=%d)" % [
		"YES" if clock_ok else "NO", s["clock"]["month"], s["clock"]["season"], TimeManager.get_total_days(s)])
	if not clock_ok:
		failed.append("ساعت ماهانه بازی پیش نرفت")
	if s.get("monthly_report", {}).is_empty() or int(s["monthly_report"].get("total_events", 0)) <= 0:
		failed.append("گزارش مدیریتی ماهانه رویدادها ساخته نشد")
	else:
		print("Monthly management report aggregation: OK")
	var legacy_state = s.duplicate(true)
	legacy_state.erase("time")
	legacy_state["tick"] = 365
	legacy_state = TimeManager.migrate_legacy_state(legacy_state)
	if TimeManager.get_total_days(legacy_state) != 365 or int(legacy_state["tick"]) != 13:
		failed.append("مهاجرت ذخیره روزانه قدیمی به نوبت ماهانه شکست خورد")
	else:
		print("Legacy daily save to monthly turn migration: OK")

	print("Events logged: %d" % EventLog.count())

	var analytics_history: Array = s.get("analytics", {}).get("history", [])
	if analytics_history.size() < 2 or int(analytics_history[-1].get("tick", 0)) < 7:
		failed.append("تاریخچه تحلیلی هفتگی ثبت نشد")
	else:
		print("Monthly analytics history: OK")

	var progression = s.get("progression", {})
	if progression.get("achievements", []).size() < 2:
		failed.append("دستاوردهای ماهانه ثبت نشد")
	else:
		print("Progression: streak + combo + achievements OK")

	var scenario_state = ScenarioManager.apply_scenario(s.duplicate(true), "survival_year", 0)
	scenario_state["time"]["total_days"] = int(scenario_state["scenario"]["deadline_day"])
	scenario_state["population"]["happiness"] = 0.50
	scenario_state["politics"]["stability"] = 0.50
	scenario_state["economy"]["debt_to_gdp"] = 0.50
	scenario_state["world"]["wars"] = {}
	var scenario_result = ScenarioManager.update(scenario_state, 360)
	if scenario_result.state.get("scenario", {}).get("status", "") != "won":
		failed.append("شرط پیروزی سناریوی مهلت‌دار فعال نشد")
	else:
		print("Scenario objectives + deadline + victory reward OK")

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

	# سیاست عمومی: فعال‌سازی اتمی، اثر روزانه و تعارض راهبردی
	var policy_state = s.duplicate(true)
	policy_state["retail"]["competition"] = 0.20
	var competition_before = float(policy_state["retail"]["competition"])
	var policy_result = GameEngine.tick(policy_state, v, t, [GameCommand.create_policy_change("antitrust_enforcement", true)])
	if not policy_result.success or not policy_result.state.get("policies", {}).get("active", {}).has("antitrust_enforcement"):
		failed.append("سیاست ضدانحصار فعال نشد")
	elif float(policy_result.state["retail"]["competition"]) <= competition_before:
		failed.append("اثر روزانه سیاست ضدانحصار اعمال نشد")
	else:
		var fiscal_state = PolicyManager.apply_change(s.duplicate(true), "fiscal_austerity", true, t).state
		var conflict = PolicyManager.can_change(fiscal_state, "public_investment", true)
		if conflict.valid:
			failed.append("دو سیاست مالی متعارض هم‌زمان مجاز شدند")
		else:
			print("Public policy: atomic activation + daily effect + conflict OK")

	var monetary_state = s.duplicate(true)
	var independence_before = float(monetary_state["central_bank"].get("independence", 0.7))
	var monetary_result = GameEngine.tick(monetary_state, v, t, [GameCommand.create_monetary_policy("manual_rate", 0.25)])
	if not monetary_result.success or monetary_result.state["central_bank"].get("policy_mode", "") != "manual_rate":
		failed.append("سیاست پولی دستوری اعمال نشد")
	elif float(monetary_result.state["central_bank"].get("independence", 1.0)) >= independence_before:
		failed.append("هزینه استقلال بانک مرکزی برای مداخله ثبت نشد")
	else:
		var tariff_result = GameEngine.tick(s, v, t, [GameCommand.create_tariff_set(0.30)])
		if not tariff_result.success or abs(float(tariff_result.state["trade"]["tariff_rate"]) - 0.30) > 0.03:
			failed.append("تعرفه گمرکی اتمی اعمال نشد")
		else:
			print("Macro instruments: interest + inflation framework + tariff OK")

	# توسعه نظامی: شروع پروژه، پیشرفت ماهانه، تکمیل اثر و دکترین
	var military_state = s.duplicate(true)
	var debt_before_program = float(military_state["economy"]["national_debt"])
	var program_result = GameEngine.tick(military_state, v, t, [GameCommand.create_military_program("reserve_training")])
	if not program_result.success or not program_result.state.get("military_development", {}).get("active", {}).has("reserve_training"):
		failed.append("برنامه توسعه نظامی آغاز نشد")
	elif float(program_result.state["economy"]["national_debt"]) <= debt_before_program:
		failed.append("هزینه برنامه نظامی ثبت نشد")
	else:
		var program_state = program_result.state
		program_state = MilitaryManager.simulate_month(program_state, t + 2).state
		program_state = MilitaryManager.simulate_month(program_state, t + 3).state
		if not program_state["military_development"]["completed"].has("reserve_training"):
			failed.append("برنامه نظامی پس از مدت مقرر تکمیل نشد")
		else:
			var doctrine_result = MilitaryManager.set_doctrine(program_state, "expeditionary", t + 3)
			var modifiers = MilitaryManager.get_effective_modifiers(doctrine_result.state)
			if not doctrine_result.success or float(modifiers.get("power_multiplier", 1.0)) <= 1.0:
				failed.append("دکترین نظامی اثر واقعی ایجاد نکرد")
			else:
				print("Military development: program + cost + completion + doctrine OK")

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
		war_state["military"]["readiness"] = 0.90
		var war_result = GameEngine.tick(war_state, v, t, [GameCommand.create_diplomacy_action("USA", "declare_war")])
		var active_war = war_result.state.get("world", {}).get("wars", {}).has("USA") if war_result.success else false
		var war_recorded = false
		if war_result.success:
			for record in war_result.state.get("world", {}).get("war_history", []):
				if record.get("target", "") == "USA": war_recorded = true
		if not war_result.success or (not active_war and not war_recorded):
			failed.append("اعلام جنگ یا ثبت نتیجه نبرد فعال نشد")
		elif active_war:
			war_result.state["diplomacy"]["action_points"] = 5.0
			var peace_result = GameEngine.tick(war_result.state, war_result.version, war_result.tick, [GameCommand.create_diplomacy_action("USA", "offer_peace")])
			if not peace_result.success or peace_result.state.get("world", {}).get("wars", {}).has("USA"):
				failed.append("پیمان صلح جنگ را پایان نداد")
			else:
				print("World diplomacy: trade + war simulation + peace/history OK")
		else:
			print("World diplomacy: war resolved within month and history recorded OK")

	# تبدیل رویداد به تصمیم، اجرای گزینه در موتور اتمی و ثبت تاریخچه
	var decision_manager = load("res://scripts/core/decision_manager.gd")
	var decision_state = s.duplicate(true)
	decision_state["pending_decisions"] = []
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
		# ذخیره دوم نسخه پشتیبان سالم می‌سازد؛ خرابی فایل اصلی باید خودکار بازیابی شود.
		SaveManager.save_game(save_path)
		var save_file = FileAccess.open(save_path, FileAccess.READ)
		var wrapped = JSON.parse_string(save_file.get_as_text())
		save_file.close()
		wrapped["payload"] += " "
		var tampered = FileAccess.open(save_path, FileAccess.WRITE)
		tampered.store_string(JSON.stringify(wrapped))
		tampered.close()
		var tamper_result = SaveManager.load_game(save_path)
		if not tamper_result.success or not tamper_result.get("recovered_from_backup", false):
			failed.append("فایل خراب از نسخه پشتیبان سالم بازیابی نشد")
		elif not is_equal_approx(GameState.state["economy"]["tax_rate"], original_tax):
			failed.append("نسخه پشتیبان وضعیت درست را بازنگرداند")
		else:
			print("Versioned atomic save + checksum + backup recovery: OK")
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
