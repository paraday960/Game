extends SceneTree
# تست عمق بیشتر ۴: بورس اوراق بهادار، بنیاد ایثارگران، میراث فرهنگی

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

	# ── ۱) بورس اوراق بهادار ──
	# اثر مستقیم IPO: شرکت‌های پذیرفته‌شده +۱ و شمار ipos ثبت. بدهی و شاخص را
	# نمی‌سنجیم: در همان تیک هزینه‌های ماهانه و شوک‌های بازار بازمحاسبه می‌شوند
	# و اثر خالص را می‌پوشانند (عمق‌بخشی ۳۸: اصلاح تست منسوخ).
	var sm0: Dictionary = GS.state.get("stock_market", {})
	var companies0 := int(sm0.get("listed_companies", 100))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_stock_action("ipo")])
	if not r.success:
		fails.append("عرضه اولیه سهام ناموفق: " + str(r.get("reason", "")))
	GS.set_state(r.state, r.version, r.tick)
	var companies1 := int(GS.state.get("stock_market", {}).get("listed_companies", 100))
	if companies1 <= companies0:
		fails.append("عرضه اولیه شرکت جدیدی وارد بورس نکرد (%d → %d)" % [companies0, companies1])
	else:
		print("✓ بورس: عرضه اولیه شرکت‌ها را از %d به %d رساند" % [companies0, companies1])
	if int(GS.state.get("stock_policy", {}).get("ipos", 0)) != 1:
		fails.append("شمار عرضه‌های اولیه ثبت نشد")

	# مالیات عایدی
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_stock_action("capgains")])
	GS.set_state(r.state, r.version, r.tick)
	if str(GS.state.get("stock_policy", {}).get("policy", "")) != "capgains":
		fails.append("مالیات عایدی فعال نشد")
	var rev_before := float(GS.state.get("economy", {}).get("government_revenue", 0.0))
	for i in range(2):
		r = GE.tick(GS.state, GS.version, GS.tick, [])
		GS.set_state(r.state, r.version, r.tick)
	var rev_after := float(GS.state.get("economy", {}).get("government_revenue", 0.0))
	if rev_after <= rev_before:
		fails.append("مالیات عایدی درآمد ماهانه نیاورد")
	else:
		print("✓ بورس: مالیات عایدی سرمایه درآمد تازه به خزانه داد")

	# حمایت از بازار + دوره‌های تاخیر
	var bubble_high := 0.9
	GS.state["stock_policy"]["bubble"] = bubble_high
	GS.state["stock_market"]["investor_confidence"] = 0.3
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_stock_action("support")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("stock_policy", {}).get("bubble", 0.0)) >= bubble_high:
		fails.append("حمایت دولت حباب را تخلیه نکرد")
	var support_turn: int = int(GS.state.get("stock_policy", {}).get("last_support", -99))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_stock_action("support")])
	GS.set_state(r.state, r.version, r.tick)
	if int(GS.state.get("stock_policy", {}).get("last_support", -99)) != support_turn:
		fails.append("حمایت پیاپی باید مسدود شود (دوره ۶ نوبتی)")
	else:
		print("✓ بورس: حمایت بازار حباب را تخلیه کرد و دوره تاخیر ۶ نوبتی فعال شد")

	# ناظر
	var trans0 := float(GS.state.get("stock_market", {}).get("transparency", 0.55))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_stock_action("watchdog")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("stock_market", {}).get("transparency", 0.55)) <= trans0:
		fails.append("تقویت ناظر شفافیت را بالا نبرد")
	else:
		print("✓ بورس: نهاد ناظر شفافیت و نظارت را تقویت کرد")

	# فرمان نامعتبر باید رد شود
	var bad = CS.create_stock_action("xyz")
	var vres = GE.tick(GS.state, GS.version, GS.tick, [bad])
	if vres.get("success", false):
		fails.append("فرمان بورسی نامعتبر پذیرفته شد")
	else:
		GS.set_state(GS.state, GS.version, GS.tick)

	# ── ۲) بنیاد ایثارگران ──
	var sat0 := float(GS.state.get("veterans_policy", {}).get("satisfaction", 0.6))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_veterans_action("pension")])
	if not r.success:
		fails.append("افزایش مستمری ناموفق: " + str(r.get("reason", "")))
	GS.set_state(r.state, r.version, r.tick)
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_veterans_action("employment")])
	GS.set_state(r.state, r.version, r.tick)
	r = GE.tick(GS.state, GS.version, GS.tick, [])
	GS.set_state(r.state, r.version, r.tick)
	var sat1 := float(GS.state.get("veterans_policy", {}).get("satisfaction", 0.6))
	if sat1 <= sat0:
		fails.append("افزایش مستمری و اشتغال رضایت را بالا نبرد (%.2f → %.2f)" % [sat0, sat1])
	else:
		print("✓ ایثارگران: مستمری + اشتغال رضایت کهنه‌سربازان را از %.2f به %.2f رساند" % [sat0, sat1])

	# بیمارستان
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_veterans_action("clinic")])
	GS.set_state(r.state, r.version, r.tick)
	if not bool(GS.state.get("veterans_policy", {}).get("clinic", false)):
		fails.append("وضعیت بیمارستان ثبت نشد")
	var care0 := float(GS.state.get("veterans", {}).get("health_care", 0.65))
	r = GE.tick(GS.state, GS.version, GS.tick, [])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("veterans", {}).get("health_care", 0.65)) <= care0:
		fails.append("بیمارستان تخصصی پوشش درمانی جانبازان را بالا نبرد")
	else:
		print("✓ ایثارگران: بیمارستان تخصصی پوشش درمانی جانبازان را از %.2f به %.2f رساند" % [care0, float(GS.state.get("veterans", {}).get("health_care", 0.65))])

	# بزرگداشت: بار دوم در همان نوبت باید رد شود
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_veterans_action("parade")])
	GS.set_state(r.state, r.version, r.tick)
	var pop0 := float(GS.state.get("leader", {}).get("popularity_world", 50.0))
	if pop0 <= 50.0:
		fails.append("بزرگداشت محبوبیت جهانی رهبر را بالا نبرد")
	var parade_count: int = int(GS.state.get("veterans_policy", {}).get("parades", 0))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_veterans_action("parade")])
	GS.set_state(r.state, r.version, r.tick)
	if int(GS.state.get("veterans_policy", {}).get("parades", 0)) != parade_count:
		fails.append("بزرگداشت پیاپی باید مسدود شود (هر ۱۲ نوبت)")
	else:
		print("✓ ایثارگران: بزرگداشت محبوبیت آورد و دوره تاخیر ۱۲ نوبتی برقرار است")

	# رشد شمار در جنگ
	var war_turn: int = int(GS.tick)
	GS.state["world"]["wars"]["TUR"] = {"target": "TUR", "started_tick": war_turn, "progress": 0.2, "player_losses": 0, "enemy_losses": 0}
	var count_a := float(GS.state.get("veterans", {}).get("count", 500000.0))
	for i in range(3):
		r = GE.tick(GS.state, GS.version, GS.tick, [])
		GS.set_state(r.state, r.version, r.tick)
	var count_b := float(GS.state.get("veterans", {}).get("count", 500000.0))
	if count_b <= count_a:
		fails.append("جنگ شمار کهنه‌سربازان را افزایش نداد (%.0f → %.0f)" % [count_a, count_b])
	else:
		print("✓ ایثارگران: در جنگ، شمار کهنه‌سربازان از %.0f به %.0f رسید" % [count_a, count_b])
	GS.state["world"]["wars"].erase("TUR")

	# ── ۳) میراث فرهنگی ──
	var pres0 := float(GS.state.get("heritage", {}).get("preservation", 0.6))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_heritage_action("restore")])
	if not r.success:
		fails.append("مرمت ناموفق: " + str(r.get("reason", "")))
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("heritage", {}).get("preservation", 0.6)) <= pres0:
		fails.append("مرمت حفاظت را بالا نبرد")
	else:
		print("✓ میراث: مرمت، حفاظت محوطه‌ها را از %.2f به %.2f رساند" % [pres0, float(GS.state.get("heritage", {}).get("preservation", 0.6))])

	var unesco0 := 2
	GS.state["heritage"]["unesco_sites"] = unesco0
	var reg0: int = int(GS.state.get("heritage_policy", {}).get("registered", 0))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_heritage_action("register")])
	GS.set_state(r.state, r.version, r.tick)
	if int(GS.state.get("heritage", {}).get("unesco_sites", 0)) != unesco0 + 1:
		fails.append("ثبت جهانی شمار یونسکو را افزایش نداد")
	if int(GS.state.get("heritage_policy", {}).get("registered", 0)) != reg0 + 1:
		fails.append("ثبت جهانی ثبت نشد")
	else:
		print("✓ میراث: ثبت جهانی جدید (یونسکو %d → %d)؛ قدرت نرم و گردشگری در ماه‌های بعد رشد می‌کند" % [unesco0, unesco0 + 1])

	# جشنواره: دوره تاخیر ۱۲ نوبتی
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_heritage_action("festival")])
	GS.set_state(r.state, r.version, r.tick)
	var fest_count: int = int(GS.state.get("heritage_policy", {}).get("festivals", 0))
	if fest_count != 1:
		fails.append("جشنواره اول برگزار نشد")
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_heritage_action("festival")])
	GS.set_state(r.state, r.version, r.tick)
	if int(GS.state.get("heritage_policy", {}).get("festivals", 0)) != fest_count:
		fails.append("جشنواره پیاپی باید مسدود شود (هر ۱۲ نوبت)")
	else:
		print("✓ میراث: جشنواره بین‌المللی برگزار شد و دوره تاخیر ۱۲ نوبتی برقرار است")

	# ضد قاچاق
	var cor0 := float(GS.state.get("politics", {}).get("corruption", 0.3))
	var antiq_turn: int = int(GS.state.get("heritage_policy", {}).get("last_antiq", -99))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_heritage_action("antiquities")])
	GS.set_state(r.state, r.version, r.tick)
	if int(GS.state.get("heritage_policy", {}).get("last_antiq", -99)) == antiq_turn:
		fails.append("عملیات ضد قاچاق اجرا نشد")
	elif float(GS.state.get("politics", {}).get("corruption", 0.3)) >= cor0:
		fails.append("ضد قاچاق فساد را کاهش نداد")
	else:
		print("✓ میراث: عملیات ضد قاچاق، آثار را بازگرداند و فساد را کم کرد")

	# ── ۴) دترمینیسم ──
	var s_a = GS.state.duplicate(true)
	var ra = GE.tick(s_a, GS.version, GS.tick, [])
	var s_b = GS.state.duplicate(true)
	var rb = GE.tick(s_b, GS.version, GS.tick, [])
	if JSON.stringify(ra.state) != JSON.stringify(rb.state):
		fails.append("عدم دترمینیسم در سیستم‌های عمق بیشتر ۴")
	else:
		print("✓ دترمینیسم کامل")

	print("")
	if fails.is_empty():
		print("=== ✅ DEEPER 4 TEST PASSED ===")
	else:
		for f in fails:
			print("❌ " + f)
		print("=== ❌ FAILED: %d ===" % fails.size())
	quit(fails.size())
