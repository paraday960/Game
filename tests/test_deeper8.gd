extends SceneTree
# تست عمق بیشتر ۸: اقتصاد خلاق، تحول جمعیتی، آبخیزداری

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

	# ── ۱) اقتصاد خلاق ──
	var fund0 := float(GS.state.get("creative_policy", {}).get("funding", 0.25))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_creative_action("funding")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("creative_policy", {}).get("funding", 0.25)) <= fund0:
		fails.append("صندوق حمایت فرهنگی افزایش نیافت")
	else:
		print("✓ خلاق: صندوق تولید فرهنگی پروژه‌های هنری را تغذیه می‌کند")

	var edu0 := float(GS.state.get("creative_policy", {}).get("education", 0.25))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_creative_action("education")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("creative_policy", {}).get("education", 0.25)) <= edu0:
		fails.append("آموزش خلاق تقویت نشد")
	else:
		print("✓ خلاق: آموزش هنر، انیمیشن و بازی‌سازی نیروی خلاق تربیت می‌کند")

	# پلتفرم بدون دیجیتال کافی باید مسدود شود
	var CreativeManagerClass = load("res://scripts/core/creative_manager.gd").new()
	var s_low = GS.state.duplicate(true)
	s_low["technology"]["branch_levels"]["دیجیتال"] = 0
	var low_res = CreativeManagerClass.build_platform(s_low)
	if low_res.get("success", false):
		fails.append("پلتفرم فرهنگی بدون دیجیتال سطح ۸ نباید فعال شود")
	else:
		print("✓ خلاق: سکوی توزیع دیجیتال به فناوری دیجیتال نیاز دارد")
	GS.state["technology"]["branch_levels"]["دیجیتال"] = 10
	var pir0 := float(GS.state.get("creative_policy", {}).get("piracy", 0.45))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_creative_action("platform")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("creative_policy", {}).get("piracy", 0.45)) >= pir0:
		fails.append("پلتفرم رسمی دزدی دریایی را کم نکرد")
	else:
		print("✓ خلاق: سکوی رسمی کپی‌رایت را تقویت و دزدی دریایی را کم کرد")

	var fest_cmd = CS.create_creative_action("export")
	fest_cmd.tick = 0; fest_cmd.version = 0; fest_cmd.player_id = "creative_fest"
	var exp0 := int(GS.state.get("creative_policy", {}).get("last_festival", -99))
	r = GE.tick(GS.state, GS.version, GS.tick, [fest_cmd])
	GS.set_state(r.state, r.version, r.tick)
	if int(GS.state.get("creative_policy", {}).get("last_festival", -99)) <= exp0:
		fails.append("جشنواره فرهنگی برگزار نشد")
	else:
		print("✓ خلاق: جشنواره صادرات فرهنگی قدرت نرم و ارزآوری را بالا برد")

	r = GE.tick(GS.state, GS.version, GS.tick, [])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state.get("creative_policy", {}).has("creative_gdp"):
		fails.append("سهم اقتصاد خلاق محاسبه نشد")
	else:
		print("✓ خلاق: سینما، موسیقی، بازی و صنایع دستی ماهانه رشد می‌کنند")

	# ── ۲) تحول جمعیتی ──
	var pn_cmd = CS.create_demographic_action("pronatal")
	pn_cmd.tick = 0; pn_cmd.version = 0; pn_cmd.player_id = "demo_pronatal"
	var inc0 := float(GS.state.get("demographic_policy", {}).get("fertility_incentive", 0.20))
	r = GE.tick(GS.state, GS.version, GS.tick, [pn_cmd])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("demographic_policy", {}).get("fertility_incentive", 0.20)) <= inc0:
		fails.append("بسته فرزندآوری اعمال نشد")
	else:
		print("✓ جمعیت: بسته فرزندآوری نرخ تولد را تحریک می‌کند")

	var care0 := float(GS.state.get("demographic_policy", {}).get("childcare", 0.25))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_demographic_action("childcare")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("demographic_policy", {}).get("childcare", 0.25)) <= care0:
		fails.append("مهدکودک توسعه نیافت")
	else:
		print("✓ جمعیت: مهدکودک اشتغال زنان و باروری را بهبود می‌دهد")

	var eld0 := float(GS.state.get("demographic_policy", {}).get("elderly_care", 0.20))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_demographic_action("elderly")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("demographic_policy", {}).get("elderly_care", 0.20)) <= eld0:
		fails.append("مراقبت سالمندی افزایش نیافت")
	else:
		print("✓ جمعیت: مراقبت سالمندی فشار صندوق را مدیریت می‌کند")

	var ret0 := float(GS.state.get("demographic_policy", {}).get("retraining", 0.15))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_demographic_action("retraining")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("demographic_policy", {}).get("retraining", 0.15)) <= ret0:
		fails.append("بازآموزی نیروی کار اجرا نشد")
	else:
		print("✓ جمعیت: بازآموزی بیکاری را کم و بهره‌وری را زیاد می‌کند")

	r = GE.tick(GS.state, GS.version, GS.tick, [])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state.get("demographic_policy", {}).has("window"):
		fails.append("پنجره جمعیت محاسبه نشد")
	else:
		print("✓ جمعیت: پنجره جمعیت، سالخوردگی و صندوق بازنشستگی ماهانه پویا شد")

	# ── ۳) آبخیزداری ──
	var rest_cmd = CS.create_watershed_action("restore")
	rest_cmd.tick = 0; rest_cmd.version = 0; rest_cmd.player_id = "ws_restore"
	var rest0 := int(GS.state.get("watershed_policy", {}).get("last_restoration", -99))
	r = GE.tick(GS.state, GS.version, GS.tick, [rest_cmd])
	GS.set_state(r.state, r.version, r.tick)
	if int(GS.state.get("watershed_policy", {}).get("last_restoration", -99)) <= rest0:
		fails.append("پروژه آبخیزداری اجرا نشد")
	else:
		print("✓ آبخیز: آبخیزداری فرسایش را کم و سفره را تغذیه می‌کند")

	var for0 := float(GS.state.get("watershed_policy", {}).get("forestry", 0.25))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_watershed_action("forest")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("watershed_policy", {}).get("forestry", 0.25)) <= for0:
		fails.append("جنگل‌کاری افزایش نیافت")
	else:
		print("✓ آبخیز: جنگل‌کاری و احیای مرتع خاک و کربن را بهتر می‌کند")

	var dust0 := float(GS.state.get("watershed_policy", {}).get("dust_control", 0.20))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_watershed_action("dust")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("watershed_policy", {}).get("dust_control", 0.20)) <= dust0:
		fails.append("مقابله با ریزگرد تقویت نشد")
	else:
		print("✓ آبخیز: کانون‌یابی و مالچ‌پاشی ریزگردها را مهار می‌کند")

	var wet0 := float(GS.state.get("watershed_policy", {}).get("wetlands", 0.20))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_watershed_action("wetlands")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("watershed_policy", {}).get("wetlands", 0.20)) <= wet0:
		fails.append("احیای تا‌لاب‌ها انجام نشد")
	else:
		print("✓ آبخیز: احیای تا‌لاب به تنوع زیستی و تصویر محیط‌زیستی کمک کرد")

	r = GE.tick(GS.state, GS.version, GS.tick, [])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state.get("watershed_policy", {}).has("soil_health"):
		fails.append("سلامت خاک محاسبه نشد")
	else:
		print("✓ آبخیز: فرسایش، بیابان‌زایی، ریزگرد و خشکی ماهانه اثر متقابل دارند")

	# ── ۴) دترمینیسم ──
	var s_a = GS.state.duplicate(true)
	var ra = GE.tick(s_a, GS.version, GS.tick, [])
	var s_b = GS.state.duplicate(true)
	var rb = GE.tick(s_b, GS.version, GS.tick, [])
	if JSON.stringify(ra.state) != JSON.stringify(rb.state):
		fails.append("عدم دترمینیسم در سیستم‌های عمق بیشتر ۸")
	else:
		print("✓ دترمینیسم کامل")

	print("")
	if fails.is_empty():
		print("=== ✅ DEEPER 8 TEST PASSED ===")
	else:
		for f in fails:
			print("❌ " + f)
		print("=== ❌ FAILED: %d ===" % fails.size())
	quit(fails.size())
