extends SceneTree
# تست عمق تداوم: قوه قضائیه، انرژی، صنعت، جانشینی، اتحادیه‌های کارگری

func _init():
	await process_frame
	await process_frame
	var fails: Array = []
	var GS = root.get_node("GameState")
	var GE = root.get_node("GameEngine")
	var CS = load("res://scripts/core/command.gd")
	var JM = root.get_node("JudiciaryManager")
	var EM = root.get_node("EnergyManager")
	var IM = root.get_node("IndustryManager")
	var SM = root.get_node("SuccessionManager")
	var LM = root.get_node("LaborManager")

	var r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_country_select("IRN", "balanced")])
	GS.set_state(r.state, r.version, r.tick)
	GS.state["policies"]["political_capital"] = 5.0

	# ── ۱) قوه قضائیه ──
	var ind0 := float(GS.state.get("judiciary", {}).get("independence", 0.5))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_court_action("fund")])
	GS.set_state(r.state, r.version, r.tick)
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_court_action("reform")])
	if not r.success:
		fails.append("اصلاحات قضایی ناموفق: " + str(r.get("reason", "")))
	GS.set_state(r.state, r.version, r.tick)
	var ind1 := float(GS.state.get("judiciary", {}).get("independence", 0.5))
	if ind1 <= ind0:
		fails.append("اصلاحات قضایی استقلال را بالا نبرد")
	# پرونده بزرگ
	var ruling_seen := false
	for i in range(14):
		r = GE.tick(GS.state, GS.version, GS.tick, [])
		GS.set_state(r.state, r.version, r.tick)
		var ruling: Dictionary = GS.state.get("judiciary", {}).get("pending_ruling", {})
		if not ruling.is_empty():
			ruling_seen = true
			r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_court_action("free")])
			if not r.success:
				fails.append("پاسخ به پرونده قضایی ناموفق: " + str(r.get("reason", "")))
			GS.set_state(r.state, r.version, r.tick)
			break
	print("✓ قوه قضائیه: اصلاحات استقلال را بالا برد (%.2f→%.2f)؛ پرونده بزرگ: %s" % [ind0, ind1, "حل شد" if ruling_seen else "شانسی رخ نداد"])

	# ── ۲) انرژی ──
	var ren0 := float(GS.state.get("energy_policy", {}).get("mix", {}).get("renewable", 0.1))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_energy_action("renewable")])
	if not r.success:
		fails.append("سرمایه سبز ناموفق")
	GS.set_state(r.state, r.version, r.tick)
	var ren1 := float(GS.state.get("energy_policy", {}).get("mix", {}).get("renewable", 0.1))
	if ren1 <= ren0:
		fails.append("سرمایه سبز سهم تجدیدپذیر را بالا نبرد")
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_energy_action("subsidy")])
	GS.set_state(r.state, r.version, r.tick)
	var sub := float(GS.state.get("energy_policy", {}).get("subsidies", 0.45))
	if sub >= 0.45:
		fails.append("اصلاح یارانه یارانه را کم نکرد")
	print("✓ انرژی: سهم سبز %s→%s و اصلاح یارانه (%s)" % [ren0, ren1, sub])

	# ── ۳) صنعت ──
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_industry_action("strategy", "high_tech")])
	if not r.success:
		fails.append("راهبرد صنعتی ناموفق: " + str(r.get("reason", "")))
	GS.set_state(r.state, r.version, r.tick)
	if str(GS.state.get("industry_policy", {}).get("strategy", "")) != "high_tech":
		fails.append("راهبرد تغییر نکرد")
	var soe0 := float(GS.state.get("industry_policy", {}).get("soe_share", 0.3))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_industry_action("privatize")])
	GS.set_state(r.state, r.version, r.tick)
	var soe1 := float(GS.state.get("industry_policy", {}).get("soe_share", 0.3))
	if soe1 >= soe0:
		fails.append("خصوصی‌سازی سهم دولتی را کم نکرد")
	print("✓ صنعت: راهبرد فناوری‌محور + خصوصی‌سازی (سهم دولتی %.2f→%.2f)" % [soe0, soe1])

	# ── ۴) جانشینی ──
	var heir0 := str(GS.state.get("succession", {}).get("heir", ""))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_succession_action("train")])
	if not r.success:
		fails.append("تربیت وارث ناموفق: " + str(r.get("reason", "")))
	GS.set_state(r.state, r.version, r.tick)
	var heir1 := str(GS.state.get("succession", {}).get("heir", ""))
	if heir1 == "":
		fails.append("وارث تربیت نشد")
	var approval := float(GS.state.get("succession", {}).get("heir_approval", 0.0))
	if approval <= 0.0:
		fails.append("آمادگی وارث نامعتبر")
	# بحران جانشینی (تا ۵۰ نوبت)
	var crisis_seen := false
	for i in range(50):
		r = GE.tick(GS.state, GS.version, GS.tick, [])
		GS.set_state(r.state, r.version, r.tick)
		var crisis: Dictionary = GS.state.get("succession", {}).get("crisis", {})
		if not crisis.is_empty():
			crisis_seen = true
			break
	print("✓ جانشینی: وارث «%s» تربیت شد (آمادگی %.2f)؛ بحران: %s" % [heir1, approval, "رخ داد" if crisis_seen else "شانسی رخ نداد"])

	# ── ۵) کارگری ──
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_labor_action("minimum_up")])
	if not r.success:
		fails.append("سیاست دستمزدی ناموفق")
	GS.set_state(r.state, r.version, r.tick)
	if str(GS.state.get("labor", {}).get("wage_policy", "")) != "minimum_up":
		fails.append("سیاست دستمزدی تغییر نکرد")
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_labor_action("negotiate")])
	GS.set_state(r.state, r.version, r.tick)
	var risk := float(GS.state.get("labor", {}).get("strike_risk", 0.2))
	if risk > 0.6:
		fails.append("ریسک اعتصاب بعد از مذاکره بالاست: %.2f" % risk)
	print("✓ کارگری: افزایش حداقل دستمزد + مذاکره (ریسک اعتصاب %.2f)" % risk)

	# ── ۶) دترمینیسم ──
	var s_a = GS.state.duplicate(true)
	var ra = GE.tick(s_a, GS.version, GS.tick, [])
	var s_b = GS.state.duplicate(true)
	var rb = GE.tick(s_b, GS.version, GS.tick, [])
	if JSON.stringify(ra.state) != JSON.stringify(rb.state):
		fails.append("عدم دترمینیسم در سیستم‌های عمق تداوم")
	else:
		print("✓ دترمینیسم کامل")

	print("")
	if fails.is_empty():
		print("=== ✅ CONTINUED DEPTH TEST PASSED ===")
	else:
		for f in fails:
			print("❌ " + f)
		print("=== ❌ FAILED: %d ===" % fails.size())
	quit(fails.size())
