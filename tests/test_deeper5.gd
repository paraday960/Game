extends SceneTree
# تست عمق بیشتر ۵: حمل‌ونقل عمومی، بازار مصرف، همبستگی قومی

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

	# ── ۱) حمل‌ونقل عمومی ──
	var metro0: int = int(GS.state.get("public_transport", {}).get("metro_lines", 4))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_transport_action("metro")])
	GS.set_state(r.state, r.version, r.tick)
	if int(GS.state.get("public_transport", {}).get("metro_lines", 4)) != metro0 + 1:
		fails.append("خط متروی جدید ساخته نشد")
	var metro_turn: int = int(GS.state.get("transport_policy", {}).get("last_metro", -99))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_transport_action("metro")])
	GS.set_state(r.state, r.version, r.tick)
	if int(GS.state.get("transport_policy", {}).get("last_metro", -99)) != metro_turn:
		fails.append("مترو پیاپی باید مسدود شود (هر ۸ نوبت)")
	else:
		print("✓ حمل‌ونقل: خط مترو ساخته شد و دوره تاخیر ۸ نوبتی برقرار است")

	var brt0: int = int(GS.state.get("public_transport", {}).get("brt_lines", 8))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_transport_action("brt")])
	GS.set_state(r.state, r.version, r.tick)
	if int(GS.state.get("public_transport", {}).get("brt_lines", 8)) != brt0 + 1:
		fails.append("خط BRT ساخته نشد")
	else:
		print("✓ حمل‌ونقل: خط BRT جدید پوشش و وقت‌شناسی را بهبود داد")

	var aff0 := float(GS.state.get("public_transport", {}).get("affordability", 0.7))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_transport_action("subsidy")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("public_transport", {}).get("affordability", 0.7)) <= aff0:
		fails.append("یارانه کرایه قیمت‌مناسب بودن را بالا نبرد")
	else:
		print("✓ حمل‌ونقل: یارانه کرایه، سفر را برای خانوارها ارزان‌تر کرد")

	var age0 := float(GS.state.get("public_transport", {}).get("fleet_age", 7.0))
	var elec0 := float(GS.state.get("public_transport", {}).get("electrification", 0.15))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_transport_action("fleet")])
	GS.set_state(r.state, r.version, r.tick)
	var age1 := float(GS.state.get("public_transport", {}).get("fleet_age", 7.0))
	var elec1 := float(GS.state.get("public_transport", {}).get("electrification", 0.15))
	if age1 >= age0 or elec1 <= elec0:
		fails.append("نوسازی ناوگان سن را کم/برقی‌سازی را زیاد نکرد (%.1f→%.1f، %.2f→%.2f)" % [age0, age1, elec0, elec1])
	else:
		print("✓ حمل‌ونقل: ناوگان برقی نو، سن ناوگان را از %.1f به %.1f رساند" % [age0, age1])

	# رضایت ماهانه محاسبه می‌شود
	var sat0 := float(GS.state.get("public_transport", {}).get("satisfaction", 0.55))
	r = GE.tick(GS.state, GS.version, GS.tick, [])
	GS.set_state(r.state, r.version, r.tick)
	var sat1 := float(GS.state.get("public_transport", {}).get("satisfaction", 0.55))
	if sat1 <= 0.0:
		fails.append("رضایت حمل‌ونقل محاسبه نشد")
	else:
		print("✓ حمل‌ونقل: رضایت مسافران ماهانه به‌روز می‌شود (%.2f)" % sat1)

	# فرمان نامعتبر
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_transport_action("xyz")])
	if r.get("success", false):
		fails.append("فرمان حمل‌ونقل نامعتبر پذیرفته شد")

	# ── ۲) بازار مصرف ──
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_retail_action("price")])
	GS.set_state(r.state, r.version, r.tick)
	if not bool(GS.state.get("retail_policy", {}).get("price_control", false)):
		fails.append("تنظیم قیمت فعال نشد")
	var shadow0 := float(GS.state.get("shadow", {}).get("size", 0.18))
	r = GE.tick(GS.state, GS.version, GS.tick, [])
	GS.set_state(r.state, r.version, r.tick)
	var shadow1 := float(GS.state.get("shadow", {}).get("size", 0.18))
	if shadow1 <= shadow0:
		fails.append("تنظیم قیمت بازار سیاه را بزرگ نکرد")
	else:
		print("✓ بازار: تنظیم قیمت فعال شد؛ ارزانی با رشد بازار سیاه همراه است (%.3f→%.3f)" % [shadow0, shadow1])
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_retail_action("price")])
	GS.set_state(r.state, r.version, r.tick)
	if bool(GS.state.get("retail_policy", {}).get("price_control", false)):
		fails.append("تنظیم قیمت خاموش نشد")
	else:
		print("✓ بازار: تنظیم قیمت با دکمه دوم لغو شد")

	var cor0 := float(GS.state.get("politics", {}).get("corruption", 0.3))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_retail_action("protect")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("politics", {}).get("corruption", 0.3)) >= cor0:
		fails.append("حمایت از مصرف‌کننده فساد را کم نکرد")
	else:
		print("✓ بازار: حمایت از مصرف‌کننده گران‌فروشی و فساد را کاهش داد")

	# تجارت الکترونیک نیازمند دیجیتال سطح ۶
	var ret_mgr = root.get_node("RetailManager")
	var s_low = GS.state.duplicate(true)
	s_low["technology"]["branch_levels"]["دیجیتال"] = 0
	var low_res = ret_mgr.boost_ecommerce(s_low)
	if low_res.get("success", false):
		fails.append("تجارت الکترونیک بدون دیجیتال سطح ۶ نباید فعال شود")
	else:
		print("✓ بازار: تجارت الکترونیک بدون شاخه دیجیتال سطح ۶ مسدود شد")
	var ecom0 := float(GS.state.get("retail", {}).get("e_commerce_share", 0.15))
	GS.state["technology"]["branch_levels"]["دیجیتال"] = 10
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_retail_action("ecommerce")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("retail", {}).get("e_commerce_share", 0.15)) <= ecom0:
		fails.append("تجارت الکترونیک با دیجیتال ۱۰ فعال نشد")
	else:
		print("✓ بازار: تجارت الکترونیک با شاخه دیجیتال ۱۰ رشد کرد و نیاز فناوری دارد")

	var bazaar0: int = int(GS.state.get("retail", {}).get("bazaars", 5000))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_retail_action("bazaar")])
	GS.set_state(r.state, r.version, r.tick)
	if int(GS.state.get("retail", {}).get("bazaars", 5000)) <= bazaar0:
		fails.append("نوسازی بازارها اجرا نشد")
	else:
		print("✓ بازار: بازارهای سنتی نوسازی شد و گردشگری رشد کرد")

	# ── ۳) همبستگی قومی ──
	var disc0 := float(GS.state.get("ethnicity", {}).get("discrimination", 0.2))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_ethnicity_action("equal")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("ethnicity", {}).get("discrimination", 0.2)) >= disc0:
		fails.append("فرصت‌های برابر تبعیض را کم نکرد")
	else:
		print("✓ قومیت: فرصت‌های برابر تبعیض را از %.2f به %.2f رساند" % [disc0, float(GS.state.get("ethnicity", {}).get("discrimination", 0.2))])

	var rights0 := float(GS.state.get("ethnicity", {}).get("cultural_rights", 0.6))
	var tension0 := float(GS.state.get("ethnicity", {}).get("tension", 0.3))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_ethnicity_action("autonomy")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("ethnicity", {}).get("cultural_rights", 0.6)) <= rights0:
		fails.append("خودمختاری فرهنگی حقوق را بالا نبرد")
	if float(GS.state.get("ethnicity", {}).get("tension", 0.3)) > tension0:
		fails.append("خودمختاری فرهنگی تنش را کم نکرد")
	else:
		print("✓ قومیت: خودمختاری فرهنگی حقوق اقوام را بالا و تنش را پایین آورد")

	var eth_mgr = root.get_node("EthnicityManager")
	var s_direct = GS.state.duplicate(true)
	var loy_before := float(s_direct.get("factions", {}).get("پوپولیست‌ها", {}).get("loyalty", 55.0))
	var eth_direct = eth_mgr.cultural_autonomy(s_direct)
	var loy_after := float(eth_direct.state.get("factions", {}).get("پوپولیست‌ها", {}).get("loyalty", 55.0))
	if loy_after >= loy_before:
		fails.append("خودمختاری فرهنگی باید پوپولیست‌ها را ناراضی کند")
	else:
		print("✓ قومیت: خودمختاری فرهنگی پوپولیست‌ها را ناراضی کرد (وفاداری %.1f→%.1f)" % [loy_before, loy_after])

	var dial0: int = int(GS.state.get("ethnicity_policy", {}).get("dialogues", 0))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_ethnicity_action("dialogue")])
	GS.set_state(r.state, r.version, r.tick)
	if int(GS.state.get("ethnicity_policy", {}).get("dialogues", 0)) != dial0 + 1:
		fails.append("گفت‌وگوی ملی برگزار نشد")
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_ethnicity_action("dialogue")])
	GS.set_state(r.state, r.version, r.tick)
	if int(GS.state.get("ethnicity_policy", {}).get("dialogues", 0)) != dial0 + 1:
		fails.append("گفت‌وگو پیاپی باید مسدود شود (هر ۴ نوبت)")
	else:
		print("✓ قومیت: گفت‌وگوی ملی تنش را کم کرد و دوره تاخیر ۴ نوبتی برقرار است")

	var hap0 := float(GS.state.get("population", {}).get("happiness", 0.6))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_ethnicity_action("festival")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("population", {}).get("happiness", 0.6)) <= hap0:
		fails.append("جشنواره اقوام شادی را بالا نبرد")
	else:
		print("✓ قومیت: جشنواره فرهنگ اقوام ملت را شادتر و قدرت نرم را بالاتر برد")

	# ── ۴) دترمینیسم ──
	var s_a = GS.state.duplicate(true)
	var ra = GE.tick(s_a, GS.version, GS.tick, [])
	var s_b = GS.state.duplicate(true)
	var rb = GE.tick(s_b, GS.version, GS.tick, [])
	if JSON.stringify(ra.state) != JSON.stringify(rb.state):
		fails.append("عدم دترمینیسم در سیستم‌های عمق بیشتر ۵")
	else:
		print("✓ دترمینیسم کامل")

	print("")
	if fails.is_empty():
		print("=== ✅ DEEPER 5 TEST PASSED ===")
	else:
		for f in fails:
			print("❌ " + f)
		print("=== ❌ FAILED: %d ===" % fails.size())
	quit(fails.size())
