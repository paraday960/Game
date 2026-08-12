extends SceneTree
# تست عمق بیشتر ۲: زیرساخت، اقلیم، رفاه، فضا، تجارت راهبردی

func _init():
	await process_frame
	await process_frame
	var fails: Array = []
	var GS = root.get_node("GameState")
	var GE = root.get_node("GameEngine")
	var CS = load("res://scripts/core/command.gd")

	var r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_country_select("IRN", "balanced")])
	GS.set_state(r.state, r.version, r.tick)
	GS.state["policies"]["political_capital"] = 5.0

	# ── ۱) زیرساخت ──
	var decay0 := float(GS.state.get("infra_policy", {}).get("decay", 0.3))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_infra_action("maintenance", 0.8)])
	GS.set_state(r.state, r.version, r.tick)
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_infra_action("focus_power")])
	GS.set_state(r.state, r.version, r.tick)
	if str(GS.state.get("infra_policy", {}).get("focus", "")) != "power":
		fails.append("اولویت زیرساخت تغییر نکرد")
	for i in range(6):
		r = GE.tick(GS.state, GS.version, GS.tick, [])
		GS.set_state(r.state, r.version, r.tick)
	var decay1 := float(GS.state.get("infra_policy", {}).get("decay", 0.3))
	if decay1 >= decay0 + 0.1:
		fails.append("نگهداری بالا پوسیدگی را مهار نکرد (%.2f → %.2f)" % [decay0, decay1])
	else:
		print("✓ زیرساخت: نگهداری ۸۰٪ پوسیدگی را مهار کرد (%.2f→%.2f)" % [decay0, decay1])

	# ── ۲) اقلیم ──
	var poll0 := float(GS.state.get("climate_policy", {}).get("pollution", 0.5))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_climate_action("carbon", 0.5)])
	GS.set_state(r.state, r.version, r.tick)
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_climate_action("reforest")])
	GS.set_state(r.state, r.version, r.tick)
	for i in range(4):
		r = GE.tick(GS.state, GS.version, GS.tick, [])
		GS.set_state(r.state, r.version, r.tick)
	var poll1 := float(GS.state.get("climate_policy", {}).get("pollution", 0.5))
	if poll1 >= poll0 + 0.1:
		fails.append("مالیات کربن آلودگی را کم نکرد (%.2f → %.2f)" % [poll0, poll1])
	else:
		print("✓ اقلیم: مالیات کربن + جنگل‌کاری آلودگی را مهار کرد (%.2f→%.2f)" % [poll0, poll1])

	# ── ۳) رفاه ──
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_welfare_action("pension", 70)])
	GS.set_state(r.state, r.version, r.tick)
	if int(GS.state.get("welfare_policy", {}).get("pension_age", 65)) != 70:
		fails.append("سن بازنشستگی تغییر نکرد")
	# افزایش سن → فشار صندوق کم می‌شود
	var pressure := float(GS.state.get("welfare", {}).get("pension_pressure", 0.0))
	if pressure > 0.2:
		fails.append("فشار صندوق بازنشستگی با سن ۷۰ بالا ماند: %.2f" % pressure)
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_welfare_action("benefit", 0.6)])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("welfare_policy", {}).get("unemployment_benefit", 0.0)) < 0.5:
		fails.append("بیمه بیکاری تنظیم نشد")
	print("✓ رفاه: سن بازنشستگی ۷۰ (فشار صندوق %.2f) + بیمه بیکاری ۶۰٪" % pressure)

	# ── ۴) فضا ──
	GS.state["technology"]["branch_levels"]["فضا"] = 13
	var soft0 := float(GS.state.get("culture_policy", {}).get("soft_power", 40.0))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_space_action("comm")])
	if not r.success:
		fails.append("ماهواره ارتباطی ناموفق: " + str(r.get("reason", "")))
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("space_policy", {}).get("satellites_comm", 0.0)) <= 0.0:
		fails.append("ماهواره پرتاب نشد")
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_space_action("launcher")])
	if not r.success:
		fails.append("پرتاب‌گر بومی ناموفق: " + str(r.get("reason", "")))
	GS.set_state(r.state, r.version, r.tick)
	if not bool(GS.state.get("space_policy", {}).get("launcher", false)):
		fails.append("پرتاب‌گر ساخته نشد")
	print("✓ فضا: ماهواره ارتباطی + پرتاب‌گر بومی (قدرت نرم %s→%s)" % [soft0, GS.state.get("culture_policy", {}).get("soft_power", 0.0)])

	# ── ۵) تجارت راهبردی ──
	var oil_share0 := float(GS.state.get("trade", {}).get("oil_export_share", 0.7))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_trade_policy_action("diversify")])
	GS.set_state(r.state, r.version, r.tick)
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_trade_policy_action("mission")])
	if not r.success:
		fails.append("مأموریت تجاری ناموفق: " + str(r.get("reason", "")))
	GS.set_state(r.state, r.version, r.tick)
	for i in range(3):
		r = GE.tick(GS.state, GS.version, GS.tick, [])
		GS.set_state(r.state, r.version, r.tick)
	var oil_share1 := float(GS.state.get("trade", {}).get("oil_export_share", 0.7))
	if oil_share1 >= oil_share0:
		fails.append("تنوع صادرات سهم نفت را کم نکرد (%.2f → %.2f)" % [oil_share0, oil_share1])
	else:
		print("✓ تجارت: تنوع صادرات سهم نفت را از %.2f به %.2f رساند" % [oil_share0, oil_share1])

	# ── ۶) دترمینیسم ──
	var s_a = GS.state.duplicate(true)
	var ra = GE.tick(s_a, GS.version, GS.tick, [])
	var s_b = GS.state.duplicate(true)
	var rb = GE.tick(s_b, GS.version, GS.tick, [])
	if JSON.stringify(ra.state) != JSON.stringify(rb.state):
		fails.append("عدم دترمینیسم در سیستم‌های عمق بیشتر ۲")
	else:
		print("✓ دترمینیسم کامل")

	print("")
	if fails.is_empty():
		print("=== ✅ EVEN DEEPER TEST PASSED ===")
	else:
		for f in fails:
			print("❌ " + f)
		print("=== ❌ FAILED: %d ===" % fails.size())
	quit(fails.size())
