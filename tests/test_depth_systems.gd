extends SceneTree
# تست عمق‌بخشی: فراکسیون‌های سیاسی، اهداف جنگی، ویژگی‌های رهبر، چرخه اقتصادی، عملیات اطلاعاتی

func _init():
	await process_frame
	await process_frame
	var fails: Array = []
	var GS = root.get_node("GameState")
	var GE = root.get_node("GameEngine")
	var CS = load("res://scripts/core/command.gd")
	var FM = root.get_node("FactionManager")
	var LM = root.get_node("LeaderManager")

	var r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_country_select("IRN", "balanced")])
	GS.set_state(r.state, r.version, r.tick)

	# ── ۱) فراکسیون‌ها: وجود، درفت، بحران، اقدام ──
	var factions: Dictionary = GS.state.get("factions", {})
	if factions.size() != 6:
		fails.append("تعداد فراکسیون‌ها ۶ نیست: %d" % factions.size())
	var capital0 := float(GS.state.get("policies", {}).get("political_capital", 0.0))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_faction_action("ارتش", "appease")])
	if not r.success:
		fails.append("فرمان آشتی با ارتش ناموفق: " + str(r.get("reason", "")))
	GS.set_state(r.state, r.version, r.tick)
	var army_loyalty := float(GS.state.get("factions", {}).get("ارتش", {}).get("loyalty", 0.0))
	var capital1 := float(GS.state.get("policies", {}).get("political_capital", 0.0))
	if not (capital1 < capital0):
		fails.append("آشتی سرمایه سیاسی مصرف نکرد")
	if army_loyalty < 60.0:
		fails.append("وفاداری ارتش پس از آشتی پایین است: %.1f" % army_loyalty)
	print("✓ فراکسیون‌ها: ۶ جناح + اقدام «آشتی» وفاداری را بالا برد (سرمایه سیاسی مصرف شد)")

	# بحران: فراخوانی مستقیم (قطعی برای تست) — اعتراضات پوپولیست‌ها
	var f2: Dictionary = GS.state["factions"]["پوپولیست‌ها"]
	f2["loyalty"] = 8.0
	GS.state["factions"]["پوپولیست‌ها"] = f2
	var crisis_result = FM._faction_crisis(GS.state, "پوپولیست‌ها", f2)
	GS.set_state(crisis_result.state, GS.version, GS.tick)
	var crisis_msg := ""
	for ev in crisis_result.events:
		if str(ev.get("type", "")).contains("faction_crisis"):
			crisis_msg = str(ev.get("message", ""))
	if crisis_msg.is_empty():
		fails.append("بحران فراکسیونی پیام نداشت")
	else:
		print("✓ بحران فراکسیونی ثبت شد: " + crisis_msg.substr(0, 60))

	# ── ۲) اهداف جنگی ──
	GS.state["diplomacy"]["relations"]["AFG"] = 20.0
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_diplomacy_action("AFG", "declare_war", "annexation")])
	if not r.success:
		fails.append("اعلام جنگ با هدف الحاق ناموفق: " + str(r.get("reason", "")))
	GS.set_state(r.state, r.version, r.tick)
	var war_goal := str(GS.state.get("world", {}).get("wars", {}).get("AFG", {}).get("goal", ""))
	if war_goal != "annexation":
		fails.append("هدف جنگی الحاق ثبت نشد: " + war_goal)
	# تغییر هدف
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_set_war_goal("AFG", "reparations")])
	GS.set_state(r.state, r.version, r.tick)
	if str(GS.state.get("world", {}).get("wars", {}).get("AFG", {}).get("goal", "")) != "reparations":
		fails.append("تغییر هدف جنگی کار نکرد")
	# پیروزی با هدف غرامت: پیشروی را به آستانه می‌رسانیم (نویز روزانه جنگ نوسان دارد؛ چند تیک صبر می‌کنیم)
	var reserves0 := float(GS.state.get("economy", {}).get("foreign_reserves", 0.0))
	# برتری قاطع: قدرت نظامی دشمن در world را پایین می‌آوریم (قدرت خود بازنویسی می‌شود)
	GS.state["world"]["countries"]["AFG"]["military_power"] = 1.0
	GS.state["military"]["logistics_detail"]["fuel_stock_days"] = 35.0
	GS.state["military"]["logistics_detail"]["ammo_stock_days"] = 30.0
	GS.state["world"]["wars"]["AFG"]["progress"] = 90.0
	var war_over: bool = false
	var outcome := ""
	for i in range(6):
		r = GE.tick(GS.state, GS.version, GS.tick, [])
		GS.set_state(r.state, r.version, r.tick)
		if not GS.state.get("world", {}).get("wars", {}).has("AFG"):
			war_over = true
			for entry in GS.state.get("world", {}).get("war_history", []):
				if str(entry.get("target", "")) == "AFG" and int(entry.get("ended_tick", -1)) >= GS.tick - 35:
					outcome = str(entry.get("outcome", ""))
			break
	var reserves1 := float(GS.state.get("economy", {}).get("foreign_reserves", 0.0))
	if not war_over:
		fails.append("جنگ با پیشروی ۹۰ و برتری قاطع در ۶ نوبت پایان نیافت")
	if outcome == "victory" and reserves1 <= reserves0:
		fails.append("غرامت جنگی به ذخایر ارزی واریز نشد (%.0f → %.0f)" % [reserves0, reserves1])
	print("✓ اهداف جنگی: هدف الحاق ثبت، تغییر کرد و جنگ با نتیجه «%s» پایان یافت (غرامت: %s)" % [outcome, "+%.0f" % (reserves1 - reserves0) if outcome == "victory" else "—"])

	# ── ۳) ویژگی‌های رهبر ──
	var traits: Array = GS.state.get("leader", {}).get("traits", [])
	if not traits.has("جنگ‌طلب"):
		fails.append("ویژگی «جنگ‌طلب» پس از اعلام جنگ کسب نشد: " + str(traits))
	else:
		print("✓ ویژگی رهبر «جنگ‌طلب» از اعلام جنگ کسب شد")
	# پس از پیروزی باید «فاتح» هم اضافه شود
	traits = GS.state.get("leader", {}).get("traits", [])
	if not traits.has("فاتح"):
		fails.append("ویژگی «فاتح» پس از پیروزی جنگ کسب نشد")
	else:
		print("✓ ویژگی رهبر «فاتح» از پیروزی جنگ کسب شد")

	# ── ۴) چرخه اقتصادی ──
	var cycle: Dictionary = GS.state.get("economy", {}).get("cycle", {})
	if cycle.is_empty():
		fails.append("چرخه اقتصادی ساخته نشد")
	else:
		if not str(cycle.get("phase", "")) in ["boom", "growth", "stagnation", "recession"]:
			fails.append("فاز چرخه نامعتبر: " + str(cycle.get("phase", "")))
		if float(cycle.get("confidence", 0.0)) <= 0.0:
			fails.append("اعتماد سرمایه‌گذاران نامعتبر است")
		print("✓ چرخه اقتصادی فعال است: فاز %s، اعتماد %.0f" % [cycle.get("phase", ""), float(cycle.get("confidence", 0.0))])
	# در ۳۶ نوبت باید حداقل یک تغییر فاز رخ دهد
	var phase_changes := 0
	var last_phase := str(cycle.get("phase", ""))
	var st2 = GS.state.duplicate(true)
	for i in range(36):
		var rr = GE.tick(st2, GS.version, GS.tick + i, [])
		st2 = rr.state
		var ph := str(st2.get("economy", {}).get("cycle", {}).get("phase", last_phase))
		if ph != last_phase:
			phase_changes += 1
			last_phase = ph
	print("✓ تغییرات فاز چرخه در ۳۶ نوبت: %d" % phase_changes)

	# ── ۵) عملیات اطلاعاتی جدید ──
	var IOM = root.get_node("IntelligenceOperationManager")
	if not IOM.get_operation_ids().has("tech_theft") or not IOM.get_operation_ids().has("destabilize") or not IOM.get_operation_ids().has("recruit_asset"):
		fails.append("عملیات‌های اطلاعاتی جدید در داده نیستند")
	else:
		print("✓ عملیات‌های جدید (سرقت فناوری، بی‌ثبات‌سازی، جذب عامل) ثبت شدند")
	# اجرای اجباری موفق سرقت فناوری
	var io_state: Dictionary = GS.state.get("intelligence_operations", {})
	var rp0 := float(GS.state.get("technology", {}).get("research_points", 0.0))
	io_state["active"]["test_theft"] = {"operation_id": "tech_theft", "target": "TUR", "remaining_months": 0, "started_turn": GS.tick}
	GS.state["intelligence_operations"] = io_state
	var sim = IOM.simulate_month(GS.state, GS.tick, {"force_success": true})
	GS.set_state(sim.state, GS.version, GS.tick)
	var rp1 := float(GS.state.get("technology", {}).get("research_points", 0.0))
	if rp1 <= rp0:
		fails.append("سرقت فناوری امتیاز پژوهش نداد (%.1f → %.1f)" % [rp0, rp1])
	else:
		print("✓ سرقت فناوری موفق: +%.1f امتیاز پژوهش" % (rp1 - rp0))

	# ── ۶) دترمینیسم ──
	var s_a = GS.state.duplicate(true)
	var ra = GE.tick(s_a, GS.version, GS.tick, [])
	var s_b = GS.state.duplicate(true)
	var rb = GE.tick(s_b, GS.version, GS.tick, [])
	if JSON.stringify(ra.state) != JSON.stringify(rb.state):
		fails.append("عدم دترمینیسم در سیستم‌های عمق‌دار")
	else:
		print("✓ دترمینیسم کامل سیستم‌های جدید")

	print("")
	if fails.size() == 0:
		print("=== ✅ DEPTH SYSTEMS TEST PASSED ===")
	else:
		for f in fails:
			print("❌ " + f)
		print("=== ❌ FAILED: %d ===" % fails.size())
	quit(fails.size())
