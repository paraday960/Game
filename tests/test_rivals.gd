extends SceneTree
# تست رقبای داخلی و توطئه (عمق‌بخشی ۴۹):
# ساختار ۳ رقیب، همکاری، مذاکره، زیر نظر گرفتن (افشای توطئه + کول‌داون)،
# تبعید (حذف + کول‌داون)، کودتای همیشه-شکست‌خورده و سقف تعداد رقبا.

func _init():
	await process_frame
	var fails: Array = []
	var GS = root.get_node("GameState")
	var GE = root.get_node("GameEngine")
	var CS = load("res://scripts/core/command.gd")
	var RM = root.get_node("RivalsManager")

	# ── سناریو ۱: ساختار اولیه ──
	var rv_state: Dictionary = GS.state.duplicate(true)
	rv_state = RM.ensure(rv_state)
	var rv_figures: Array = rv_state["rivals"].get("figures", [])
	if rv_figures.size() != 3:
		fails.append("سه رقیب اولیه ساخته نشد: %d" % rv_figures.size())
	else:
		var rv_threat := float(rv_state["rivals"].get("threat", -1.0))
		if rv_threat < 0.0 or rv_threat > 1.0:
			fails.append("شاخص تهدید خارج از بازه است: %f" % rv_threat)
		else:
			print("✓ رقبا: ۳ چهره + شاخص تهدید %.2f" % rv_threat)

	# ── سناریو ۲: همکاری — توطئه‌گر به هیئت دولت می‌پیوندد ──
	var rc_state: Dictionary = GS.state.duplicate(true)
	rc_state = RM.ensure(rc_state)
	rc_state["rivals"]["figures"][0]["status"] = "plotting"
	rc_state["rivals"]["figures"][0]["support"] = 70.0
	rc_state["rivals"]["figures"][0]["loyalty"] = 30.0
	var rc_id := str(rc_state["rivals"]["figures"][0]["id"])
	var rc_cap0 := float(rc_state["policies"]["political_capital"])
	var rc_res = GE.tick(rc_state, GS.version, 0, [CS.create_rivals_action("coopt", rc_id)])
	if not rc_res.success:
		fails.append("همکاری ناموفق: %s" % rc_res.reason)
	else:
		rc_state = rc_res.state
		var rc_found: Dictionary = {}
		for f in rc_state["rivals"].get("figures", []):
			if str(f.get("id", "")) == rc_id:
				rc_found = f
		if str(rc_found.get("status", "")) != "coopted":
			fails.append("همکاری وضعیت را به هم‌پیمان نبرد")
		elif float(rc_state["policies"]["political_capital"]) >= rc_cap0 - 0.4:
			fails.append("همکاری سرمایهٔ سیاسی را کم نکرد")
		else:
			print("✓ همکاری: «%s» هم‌پیمان شد؛ سرمایه %.2f → %.2f" % [str(rc_found.get("name_fa", "")), rc_cap0, float(rc_state["policies"]["political_capital"])])

	# ── سناریو ۳: مذاکره — وفاداری بالا، جاه‌طلبی پایین ──
	var rn_state: Dictionary = GS.state.duplicate(true)
	rn_state = RM.ensure(rn_state)
	rn_state["rivals"]["figures"][0]["status"] = "restless"
	rn_state["rivals"]["figures"][0]["loyalty"] = 30.0
	rn_state["rivals"]["figures"][0]["ambition"] = 70.0
	var rn_id := str(rn_state["rivals"]["figures"][0]["id"])
	var rn_res = GE.tick(rn_state, GS.version, 0, [CS.create_rivals_action("negotiate", rn_id)])
	if not rn_res.success:
		fails.append("مذاکره ناموفق: %s" % rn_res.reason)
	else:
		rn_state = rn_res.state
		var rn_found: Dictionary = {}
		for f in rn_state["rivals"].get("figures", []):
			if str(f.get("id", "")) == rn_id:
				rn_found = f
		var rn_loyalty := float(rn_found.get("loyalty", 0.0))
		var rn_ambition := float(rn_found.get("ambition", 100.0))
		if rn_loyalty < 45.0:
			fails.append("مذاکره وفاداری را بالا نبرد (%.1f)" % rn_loyalty)
		elif rn_ambition >= 70.0:
			fails.append("مذاکره جاه‌طلبی را کم نکرد")
		else:
			print("✓ مذاکره: وفاداری %.1f و جاه‌طلبی %.1f" % [rn_loyalty, rn_ambition])

	# ── سناریو ۴: زیر نظر گرفتن — توطئه افشا می‌شود + کول‌داون ──
	var rs_state: Dictionary = GS.state.duplicate(true)
	rs_state = RM.ensure(rs_state)
	rs_state["rivals"]["figures"][0]["status"] = "plotting"
	rs_state["rivals"]["figures"][0]["support"] = 80.0
	rs_state["rivals"]["figures"][0]["loyalty"] = 40.0
	var rs_id := str(rs_state["rivals"]["figures"][0]["id"])
	var rs_res = GE.tick(rs_state, GS.version, 0, [CS.create_rivals_action("surveil", rs_id)])
	if not rs_res.success:
		fails.append("نظارت ناموفق: %s" % rs_res.reason)
	else:
		rs_state = rs_res.state
		var rs_found: Dictionary = {}
		for f in rs_state["rivals"].get("figures", []):
			if str(f.get("id", "")) == rs_id:
				rs_found = f
		var rs_support := float(rs_found.get("support", 99.0))
		if str(rs_found.get("status", "")) == "plotting":
			fails.append("نظارت توطئه را نشکست")
		elif rs_support > 55.0:
			fails.append("نظارت حمایت توطئه‌گر را نریخت (%.1f)" % rs_support)
		else:
			print("✓ نظارت: توطئه شکست و حمایت به %.1f ریخت" % rs_support)
		var rs_res2 = GE.tick(rs_state, rs_res.version, rs_res.tick, [CS.create_rivals_action("surveil", str(rs_state["rivals"]["figures"][1]["id"]))])
		if rs_res2.success:
			fails.append("نظارت دوم در دورهٔ کول‌داون پذیرفته شد")
		else:
			print("✓ کول‌داون نظارت کار می‌کند")

	# ── سناریو ۵: تبعید — حذف توطئه‌گر + کول‌داون ──
	var rx_state: Dictionary = GS.state.duplicate(true)
	rx_state = RM.ensure(rx_state)
	rx_state["rivals"]["figures"][0]["status"] = "plotting"
	var rx_id := str(rx_state["rivals"]["figures"][0]["id"])
	var rx_res = GE.tick(rx_state, GS.version, 0, [CS.create_rivals_action("exile", rx_id)])
	if not rx_res.success:
		fails.append("تبعید ناموفق: %s" % rx_res.reason)
	else:
		rx_state = rx_res.state
		var rx_size := rx_state["rivals"].get("figures", []).size()
		if rx_size != 2:
			fails.append("تبعید رقیب را حذف نکرد (اندازه %d)" % rx_size)
		else:
			print("✓ تبعید: رقیب حذف شد (۳ → ۲)")
		rx_state["rivals"]["figures"][1]["status"] = "plotting"
		var rx_res2 = GE.tick(rx_state, rx_res.version, rx_res.tick, [CS.create_rivals_action("exile", str(rx_state["rivals"]["figures"][1]["id"]))])
		if rx_res2.success:
			fails.append("تبعید دوم در دورهٔ کول‌داون پذیرفته شد")
		else:
			print("✓ کول‌داون تبعید کار می‌کند")

	# ── سناریو ۶: کودتا همیشه می‌شکند — رهبر برکنارنشدنی است ──
	var rp_state: Dictionary = GS.state.duplicate(true)
	rp_state = RM.ensure(rp_state)
	rp_state["rivals"]["figures"][0]["status"] = "plotting"
	rp_state["rivals"]["figures"][0]["support"] = 90.0
	rp_state["rivals"]["figures"][0]["ambition"] = 90.0
	rp_state["rivals"]["figures"][0]["loyalty"] = 20.0
	var rp_id := str(rp_state["rivals"]["figures"][0]["id"])
	var rp_stab0 := float(rp_state["politics"]["stability"])
	var rp_cap0 := float(rp_state["policies"]["political_capital"])
	var rp_coup = RM._attempt_coup(rp_state, rp_id, 5)
	rp_state = rp_coup.state
	if str(rp_state["leader"].get("mode", "")) != "leader" or not bool(rp_state["leader"].get("alive", true)):
		fails.append("کودتا رهبر را برکنار کرد — نقض قانون بازی")
	elif rp_state["rivals"].get("figures", []).size() != 2:
		fails.append("کودتا توطئه‌گر را حذف نکرد")
	elif float(rp_state["politics"]["stability"]) >= rp_stab0:
		fails.append("کودتا ثبات را نشکست")
	elif float(rp_state["policies"]["political_capital"]) <= rp_cap0:
		fails.append("رهبرِ بازمانده سرمایهٔ سیاسی نگرفت")
	else:
		print("✓ کودتا شکست: رهبر پابرجا، ثبات %.2f → %.2f، سرمایه %.2f → %.2f" % [rp_stab0, float(rp_state["politics"]["stability"]), rp_cap0, float(rp_state["policies"]["political_capital"])])

	# ── سناریو ۷: سقف تعداد و شاخص تهدید بعد از یک نوبت ──
	var rt_state: Dictionary = GS.state.duplicate(true)
	rt_state = RM.ensure(rt_state)
	var rt_res = GE.tick(rt_state, GS.version, 0, [])
	if not rt_res.success:
		fails.append("نوبت رقبا ناموفق: %s" % rt_res.reason)
	else:
		rt_state = rt_res.state
		var rt_size := rt_state["rivals"].get("figures", []).size()
		var rt_threat := float(rt_state["rivals"].get("threat", -1.0))
		if rt_size > 3:
			fails.append("آرایهٔ رقبا بی‌سقف رشد کرد: %d" % rt_size)
		elif rt_threat < 0.0 or rt_threat > 1.0:
			fails.append("شاخص تهدید بعد از نوبت نامعتبر: %f" % rt_threat)
		else:
			print("✓ سقف ۳ رقیب + تهدید %.2f بعد از نوبت" % rt_threat)

	if fails.is_empty():
		print("\n=== ✅ RIVALS TEST PASSED ===")
		quit(0)
	else:
		print("\n=== ❌ RIVALS FAILED (%d) ===" % fails.size())
		for f in fails:
			print("  - " + f)
		quit(1)
