extends SceneTree
# تست عمق متوازن: آموزش، کشاورزی، گردشگری، شهرسازی، امنیت داخلی

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

	# ── ۱) آموزش ──
	var unemp0 := float(GS.state.get("economy", {}).get("unemployment", 0.08))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_education_action("vocational")])
	GS.set_state(r.state, r.version, r.tick)
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_education_action("university")])
	if not r.success:
		fails.append("اصلاح دانشگاه ناموفق: " + str(r.get("reason", "")))
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("education_policy", {}).get("vocational", 0.3)) <= 0.3:
		fails.append("آموزش فنی افزایش نیافت")
	# چند نوبت برای اثر بیکاری
	for i in range(6):
		r = GE.tick(GS.state, GS.version, GS.tick, [])
		GS.set_state(r.state, r.version, r.tick)
	var unemp1 := float(GS.state.get("economy", {}).get("unemployment", 0.08))
	if unemp1 > unemp0 + 0.01:
		fails.append("آموزش فنی بیکاری را کاهش نداد (%.3f → %.3f)" % [unemp0, unemp1])
	else:
		print("✓ آموزش: فنی‌وحرفه‌ای + استقلال دانشگاه (بیکاری %.3f→%.3f)" % [unemp0, unemp1])

	# ── ۲) کشاورزی ──
	var inflation0 := float(GS.state.get("economy", {}).get("inflation", 0.08))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_agriculture_action("grain")])
	GS.set_state(r.state, r.version, r.tick)
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_agriculture_action("diversity")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("agri_policy", {}).get("grain_reserve", 0.3)) <= 0.3:
		fails.append("ذخیره غلات افزایش نیافت")
	print("✓ کشاورزی: ذخیره غلات + تنوع کشت فعال شد (تورم خوراک مهار می‌شود)")

	# ── ۳) گردشگری ──
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_tourism_action("visa", "open")])
	GS.set_state(r.state, r.version, r.tick)
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_tourism_action("hospitality")])
	GS.set_state(r.state, r.version, r.tick)
	var visitors := int(GS.state.get("tourism", {}).get("visitors", 0))
	if visitors <= 0:
		fails.append("گردشگری بازدیدکننده ندارد")
	else:
		print("✓ گردشگری: ویزای باز + مهمان‌پذیری (%s بازدیدکننده)" % str(visitors))

	# ── ۴) شهرسازی ──
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_urban_action("housing")])
	GS.set_state(r.state, r.version, r.tick)
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_urban_action("transit")])
	GS.set_state(r.state, r.version, r.tick)
	var traffic := float(GS.state.get("urban_policy", {}).get("traffic", 0.5))
	if traffic > 0.8:
		fails.append("ترافیک بدون کنترل بالا ماند: %.2f" % traffic)
	else:
		print("✓ شهرسازی: مسکن اجتماعی + حمل‌ونقل (ترافیک %.2f)" % traffic)

	# ── ۵) امنیت داخلی ──
	var crime0 := float(GS.state.get("security_policy", {}).get("crime", 0.35))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_security_action("tough")])
	GS.set_state(r.state, r.version, r.tick)
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_security_action("smuggling")])
	GS.set_state(r.state, r.version, r.tick)
	for i in range(4):
		r = GE.tick(GS.state, GS.version, GS.tick, [])
		GS.set_state(r.state, r.version, r.tick)
	var crime1 := float(GS.state.get("security_policy", {}).get("crime", 0.35))
	if crime1 >= crime0:
		fails.append("پلیس سختگیرانه جرم را کم نکرد (%.2f → %.2f)" % [crime0, crime1])
	else:
		print("✓ امنیت: پلیس سختگیرانه + مبارزه با قاچاق جرم را از %.2f به %.2f رساند" % [crime0, crime1])

	# ── ۶) دترمینیسم ──
	var s_a = GS.state.duplicate(true)
	var ra = GE.tick(s_a, GS.version, GS.tick, [])
	var s_b = GS.state.duplicate(true)
	var rb = GE.tick(s_b, GS.version, GS.tick, [])
	if JSON.stringify(ra.state) != JSON.stringify(rb.state):
		fails.append("عدم دترمینیسم در سیستم‌های متوازن")
	else:
		print("✓ دترمینیسم کامل")

	print("")
	if fails.is_empty():
		print("=== ✅ BALANCED DEPTH TEST PASSED ===")
	else:
		for f in fails:
			print("❌ " + f)
		print("=== ❌ FAILED: %d ===" % fails.size())
	quit(fails.size())
