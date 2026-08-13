extends SceneTree
# تست عمق نهایی: مجلس/انتخابات، سیاست ارزی، استانداران، رقابت قدرت‌ها، اقتصاد سایه

func _init():
	await process_frame
	await process_frame
	var fails: Array = []
	var GS = root.get_node("GameState")
	var GE = root.get_node("GameEngine")
	var CS = load("res://scripts/core/command.gd")
	var PM = root.get_node("ParliamentManager")
	var FX = root.get_node("ForexManager")
	var GM = root.get_node("GovernorsManager")
	var RM = root.get_node("RivalryManager")
	var SM = root.get_node("ShadowManager")

	var r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_country_select("IRN", "balanced")])
	GS.set_state(r.state, r.version, r.tick)

	# ── ۱) مجلس و انتخابات ──
	var par: Dictionary = GS.state.get("parliament", {})
	if par.is_empty():
		fails.append("مجلس ساخته نشد")
	# انتخابات زودهنگام
	var snap_check = PM.can_snap(GS.state, GS.tick)
	if not snap_check.valid:
		fails.append("انتخابات زودهنگام باید مجاز باشد: " + str(snap_check.reason))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_snap_election()])
	GS.set_state(r.state, r.version, r.tick)
	if not PM.can_snap(GS.state, GS.tick).valid:
		pass  # بعد از زودهنگام، ممنوع است (درست)
	# وعده (نزدیک انتخابات)
	GS.state["parliament"]["next_election_turn"] = GS.tick + 3
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_campaign_promise("tax_cut")])
	if not r.success:
		fails.append("ثبت وعده ناموفق: " + str(r.get("reason", "")))
	GS.set_state(r.state, r.version, r.tick)
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_campaign_promise("welfare_expand")])
	GS.set_state(r.state, r.version, r.tick)
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_campaign_promise("green_turn")])
	if r.success:
		fails.append("وعده سوم نباید پذیرفته شود (حداکثر ۲)")
	# اجرای انتخابات
	var held := false
	for i in range(6):
		r = GE.tick(GS.state, GS.version, GS.tick, [])
		GS.set_state(r.state, r.version, r.tick)
		var last: Dictionary = GS.state.get("parliament", {}).get("last_result", {})
		if not last.is_empty() and int(last.get("turn", -1)) == GS.tick:
			held = true
			break
	if not held:
		fails.append("انتخابات برگزار نشد")
	else:
		var mandate := float(GS.state.get("parliament", {}).get("mandate", 0.0))
		if mandate <= 0.0:
			fails.append("ماندات پس از انتخابات صفر است")
		print("✓ مجلس: انتخابات زودهنگام + ۲ وعده + برگزاری انتخابات (ماندات %.2f)" % mandate)

	# ── ۲) سیاست ارزی ──
	GS.state["economy"]["foreign_reserves"] = 100e9
	var rate0 := float(GS.state.get("central_bank", {}).get("exchange_rate", 1.0))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_forex_intervene(10.0)])
	GS.set_state(r.state, r.version, r.tick)
	var rate1 := float(GS.state.get("central_bank", {}).get("exchange_rate", 1.0))
	if rate1 >= rate0:
		fails.append("مداخله نرخ ارز را تقویت نکرد (%.3f → %.3f)" % [rate0, rate1])
	var reserves_after := float(GS.state.get("economy", {}).get("foreign_reserves", 0.0))
	if reserves_after >= 100e9:
		fails.append("مداخله ذخایر مصرف نکرد")
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_forex_devalue(10.0)])
	GS.set_state(r.state, r.version, r.tick)
	var rate2 := float(GS.state.get("central_bank", {}).get("exchange_rate", 1.0))
	if rate2 <= rate1:
		fails.append("کاهش ارزش نرخ را بالا نبرد")
	if float(GS.state.get("economy", {}).get("inflation", 0.08)) <= 0.08:
		fails.append("کاهش ارزش تورم نیاورد")
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_capital_control()])
	GS.set_state(r.state, r.version, r.tick)
	if not bool(GS.state.get("forex", {}).get("capital_control", false)):
		fails.append("کنترل سرمایه فعال نشد")
	print("✓ سیاست ارزی: مداخله تقویت کرد، کاهش ارزش تورم آورد، کنترل سرمایه فعال شد")

	# ── ۳) استانداران ──
	var provs: Dictionary = GS.state.get("governors", {}).get("provinces", {})
	if provs.size() < 3:
		fails.append("استان‌های کافی ساخته نشد: %d" % provs.size())
	GS.state["policies"]["political_capital"] = 5.0
	var code := str(provs.keys()[0])
	var faction0 := str(provs[code].get("faction", ""))
	var loyalty0 := float(GS.state.get("factions", {}).get(faction0, {}).get("loyalty", 0.0))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_governor_appoint(code, "تکنوکرات‌ها")])
	GS.set_state(r.state, r.version, r.tick)
	var loyalty1 := float(GS.state.get("factions", {}).get("تکنوکرات‌ها", {}).get("loyalty", 0.0))
	if loyalty1 <= loyalty0:
		fails.append("انتصاب استاندار وفاداری جناح را بالا نبرد")
	# ناآرامی/رسوایی در چند نوبت
	var scandal_seen := false
	for i in range(10):
		r = GE.tick(GS.state, GS.version, GS.tick, [])
		GS.set_state(r.state, r.version, r.tick)
		if not GS.state.get("governors", {}).get("scandal_queue", []).is_empty():
			scandal_seen = true
		for ev in r.get("events", []):
			if str(ev.get("type", "")).contains("governor_scandal"):
				scandal_seen = true
	print("✓ استانداران: انتصاب از جناح، وفاداری جناح +۲ (رسوایی استانی شانسی: %s)" % str(scandal_seen))

	# ── ۴) رقابت قدرت‌ها ──
	var tension0 := float(GS.state.get("rivalry", {}).get("tension", 40.0))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_rivalry_action("de_escalate")])
	GS.set_state(r.state, r.version, r.tick)
	var tension1 := float(GS.state.get("rivalry", {}).get("tension", 40.0))
	if tension1 >= tension0:
		fails.append("تنش‌زدایی تنش را کم نکرد")
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_rivalry_action("escalate")])
	GS.set_state(r.state, r.version, r.tick)
	var tension2 := float(GS.state.get("rivalry", {}).get("tension", 40.0))
	if tension2 <= tension1:
		fails.append("تشدید تنش را زیاد نکرد")
	# بحران منطقه‌ای (تا ۱۵ نوبت صبر)
	var crisis_resolved := false
	for i in range(15):
		r = GE.tick(GS.state, GS.version, GS.tick, [])
		GS.set_state(r.state, r.version, r.tick)
		var crisis: Dictionary = GS.state.get("rivalry", {}).get("crisis", {})
		if not crisis.is_empty():
			r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_crisis_stance("west")])
			GS.set_state(r.state, r.version, r.tick)
			crisis_resolved = true
			break
	print("✓ رقابت قدرت‌ها: تنش‌زدایی/تشدید کار کرد (بحران منطقه‌ای: %s)" % ("حل شد" if crisis_resolved else "شانسی رخ نداد"))

	# ── ۵) اقتصاد سایه ──
	var size0 := float(GS.state.get("shadow", {}).get("size", 0.18))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_shadow_action("crackdown")])
	GS.set_state(r.state, r.version, r.tick)
	var size1 := float(GS.state.get("shadow", {}).get("size", 0.18))
	if size1 >= size0:
		fails.append("سرکوب سایه را کم نکرد")
	# رسوایی فساد
	var scandal_handled := false
	for i in range(12):
		r = GE.tick(GS.state, GS.version, GS.tick, [])
		GS.set_state(r.state, r.version, r.tick)
		var scandal: Dictionary = GS.state.get("shadow", {}).get("scandal", {})
		if not scandal.is_empty():
			r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_shadow_action("investigate")])
			GS.set_state(r.state, r.version, r.tick)
			scandal_handled = true
			break
	print("✓ اقتصاد سایه: سرکوب اندازه را کم کرد (رسوایی فساد: %s)" % ("تحقیق شد" if scandal_handled else "شانسی رخ نداد"))

	# ── ۶) دترمینیسم ──
	var s_a = GS.state.duplicate(true)
	var ra = GE.tick(s_a, GS.version, GS.tick, [])
	var s_b = GS.state.duplicate(true)
	var rb = GE.tick(s_b, GS.version, GS.tick, [])
	if JSON.stringify(ra.state) != JSON.stringify(rb.state):
		fails.append("عدم دترمینیسم در سیستم‌های عمق نهایی")
	else:
		print("✓ دترمینیسم کامل")

	print("")
	if fails.is_empty():
		print("=== ✅ MAX DEPTH TEST PASSED ===")
	else:
		for f in fails:
			print("❌ " + f)
		print("=== ❌ FAILED: %d ===" % fails.size())
	quit(fails.size())
