extends SceneTree
# تست عمق بیشتر ۳: بانکداری، FDI، سفیران، دیجیتال، ورزش

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

	# ── ۱) بانکداری ──
	var stock0 := float(GS.state.get("banking", {}).get("stock_index", 55.0))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_banking_action("reserve", 0.08)])
	GS.set_state(r.state, r.version, r.tick)
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_banking_action("market")])
	GS.set_state(r.state, r.version, r.tick)
	var stock1 := float(GS.state.get("banking", {}).get("stock_index", 55.0))
	if stock1 <= stock0:
		fails.append("حمایت از بازار شاخص را بالا نبرد (%.1f → %.1f)" % [stock0, stock1])
	else:
		print("✓ بانکداری: ذخیره ۸٪ + صندوق تثبیت شاخص را از %.0f به %.0f رساند" % [stock0, stock1])
	# بحران بانکی: سلامت را پایین می‌آوریم
	GS.state["banking"]["bank_health"] = 0.2
	GS.state["banking"]["crisis"] = {"turn": GS.tick}
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_banking_action("bailout")])
	if not r.success:
		fails.append("نجات بانک‌ها در بحران ناموفق: " + str(r.get("reason", "")))
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state.get("banking", {}).get("crisis", {}).is_empty():
		fails.append("بحران بانکی با نجات حل نشد")
	else:
		print("✓ بانکداری: نجات بانک‌ها بحران را مهار کرد (بدهی سنگین ولی بازار نفس کشید)")

	# ── ۲) FDI ──
	# اثر مستقیم اکشن‌ها را می‌سنجیم (special_zones/ip_protection بالا رفته‌اند)
	# نه inflow نهایی که با شوک‌های جهانی و دلتای کوچک نوسان می‌کند
	# (عمق‌بخشی ۳۸: اصلاح تست منسوخ — پیش‌تر انتظار رشدِ ماندگار از دلتای
	#  کوچک را داشت که با افزودن بازار جهانی دیگر برقرار نیست).
	var zones0 := float(GS.state.get("fdi_policy", {}).get("special_zones", 0.2))
	var ip0 := float(GS.state.get("fdi_policy", {}).get("ip_protection", 0.4))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_fdi_action("zone"), CS.create_fdi_action("ip")])
	GS.set_state(r.state, r.version, r.tick)
	var zones1 := float(GS.state.get("fdi_policy", {}).get("special_zones", 0.2))
	var ip1 := float(GS.state.get("fdi_policy", {}).get("ip_protection", 0.4))
	if zones1 <= zones0 or ip1 <= ip0:
		fails.append("اکشن‌های FDI اعمال نشدند (zone %.2f→%.2f، ip %.2f→%.2f)" % [zones0, zones1, ip0, ip1])
	else:
		print("✓ FDI: منطقه ویژه (%.2f→%.2f) + مالکیت فکری (%.2f→%.2f) فعال شدند" % [zones0, zones1, ip0, ip1])

	# ── ۳) سفیران ──
	var tur0 := float(GS.state.get("diplomacy", {}).get("relations", {}).get("TUR", 50.0))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_ambassador_action("send", "TUR")])
	if not r.success:
		fails.append("اعزام سفیر ناموفق: " + str(r.get("reason", "")))
	GS.set_state(r.state, r.version, r.tick)
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_ambassador_action("negotiate", "TUR")])
	GS.set_state(r.state, r.version, r.tick)
	for i in range(4):
		r = GE.tick(GS.state, GS.version, GS.tick, [])
		GS.set_state(r.state, r.version, r.tick)
	var tur1 := float(GS.state.get("diplomacy", {}).get("relations", {}).get("TUR", 50.0))
	if tur1 <= tur0:
		fails.append("سفیر/مذاکره روابط را تقویت نکرد (%.0f → %.0f)" % [tur0, tur1])
	else:
		print("✓ دیپلماسی: سفیر + مذاکره روابط با ترکیه را از %.0f به %.0f رساند" % [tur0, tur1])

	# ── ۴) دیجیتال ──
	GS.state["technology"]["branch_levels"]["دیجیتال"] = 14
	var shadow0 := float(GS.state.get("shadow", {}).get("size", 0.18))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_digital_action("cbdc")])
	if not r.success:
		fails.append("ارز دیجیتال ناموفق: " + str(r.get("reason", "")))
	GS.set_state(r.state, r.version, r.tick)
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_digital_action("internet")])
	GS.set_state(r.state, r.version, r.tick)
	var shadow1 := float(GS.state.get("shadow", {}).get("size", 0.18))
	if shadow1 >= shadow0:
		fails.append("CBDC اقتصاد سایه را کم نکرد (%.2f → %.2f)" % [shadow0, shadow1])
	else:
		print("✓ دیجیتال: CBDC + اینترنت (اقتصاد سایه %.2f→%.2f)" % [shadow0, shadow1])

	# ── ۵) ورزش ──
	# اثر مستقیم اکشن‌ها (grassroots/pro_league بالا رفته‌اند) — اثر سلامت از
	# کانال تدریجی grassroots*0.001/ماه است و برای سنجش شاخص نهایی مناسب نیست
	# (عمق‌بخشی ۳۸: اصلاح تست منسوخ).
	var sport0 := float(GS.state.get("sports_policy", {}).get("grassroots", 0.3))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_sports_action("grassroots"), CS.create_sports_action("league")])
	GS.set_state(r.state, r.version, r.tick)
	var sport1 := float(GS.state.get("sports_policy", {}).get("grassroots", 0.3))
	if sport1 <= sport0:
		fails.append("ورزش همگانی فعال نشد (%.2f → %.2f)" % [sport0, sport1])
	else:
		print("✓ ورزش: همگانی از %.2f به %.2f تقویت شد" % [sport0, sport1])

	# ── ۶) دترمینیسم ──
	var s_a = GS.state.duplicate(true)
	var ra = GE.tick(s_a, GS.version, GS.tick, [])
	var s_b = GS.state.duplicate(true)
	var rb = GE.tick(s_b, GS.version, GS.tick, [])
	if JSON.stringify(ra.state) != JSON.stringify(rb.state):
		fails.append("عدم دترمینیسم در سیستم‌های عمق بیشتر ۳")
	else:
		print("✓ دترمینیسم کامل")

	print("")
	if fails.is_empty():
		print("=== ✅ DEEPER 3 TEST PASSED ===")
	else:
		for f in fails:
			print("❌ " + f)
		print("=== ❌ FAILED: %d ===" % fails.size())
	quit(fails.size())
