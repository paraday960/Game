extends SceneTree
# تست عمق بیشتر ۱۰: پسماند، بیمه و توسعه روستایی

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

	# ── ۱) پسماند ──
	var col0 := float(GS.state.get("waste_policy", {}).get("collection", 0.65))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_waste_action("collection")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["waste_policy"]["collection"]) <= col0:
		fails.append("توسعه جمع‌آوری پسماند اجرا نشد")
	else:
		print("✓ پسماند: جمع‌آوری مکانیزه توسعه یافت")

	var rec_cmd = CS.create_waste_action("recycling")
	rec_cmd.tick = 0; rec_cmd.version = 0; rec_cmd.player_id = "waste_rec"
	var rec0 := float(GS.state["waste_policy"]["recycling"])
	r = GE.tick(GS.state, GS.version, GS.tick, [rec_cmd])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["waste_policy"]["recycling"]) <= rec0:
		fails.append("کارخانه بازیافت ساخته نشد")
	else:
		print("✓ پسماند: کارخانه بازیافت افتتاح شد")

	var land0 := float(GS.state["waste_policy"]["sanitary_landfill"])
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_waste_action("landfill")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["waste_policy"]["sanitary_landfill"]) <= land0:
		fails.append("دفن بهداشتی اجرا نشد")
	else:
		print("✓ پسماند: دفن بهداشتی و شیرآبه کنترل شد")

	r = GE.tick(GS.state, GS.version, GS.tick, [])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state["waste_policy"].has("recycling_rate"):
		fails.append("شبیه‌سازی ماهانه پسماند انجام نشد")
	else:
		print("✓ پسماند: بازیافت، رهاسازی و اقتصاد چرخه‌ای ماهانه محاسبه شد")

	# ── ۲) بیمه ──
	var uni_cmd = CS.create_insurance_action("universal")
	uni_cmd.tick = 0; uni_cmd.version = 0; uni_cmd.player_id = "ins_uni"
	var pen0 := float(GS.state["insurance_policy"]["penetration"])
	r = GE.tick(GS.state, GS.version, GS.tick, [uni_cmd])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["insurance_policy"]["penetration"]) <= pen0:
		fails.append("طرح بیمه فراگیر اجرا نشد")
	else:
		print("✓ بیمه: طرح بیمه فراگیر ضریب نفوذ را بالا برد")

	var hi0 := float(GS.state["insurance_policy"]["health_insurance"])
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_insurance_action("health")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["insurance_policy"]["health_insurance"]) <= hi0:
		fails.append("بیمه درمان گسترش نیافت")
	else:
		print("✓ بیمه: بیمه درمان تکمیلی هزینه‌های کمرشکن را کم کرد")

	var ag0 := float(GS.state["insurance_policy"]["agri_insurance"])
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_insurance_action("agri")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["insurance_policy"]["agri_insurance"]) <= ag0:
		fails.append("بیمه کشاورزی گسترش نیافت")
	else:
		print("✓ بیمه: صندوق بیمه کشاورزی خشکسالی و سیل را پوشش داد")

	r = GE.tick(GS.state, GS.version, GS.tick, [])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state["insurance_policy"].has("solvency"):
		fails.append("توانگری بیمه محاسبه نشد")
	else:
		print("✓ بیمه: توانگری، خسارت و ریسک ورشکستگی ماهانه محاسبه شد")

	# ── ۳) روستایی ──
	var road_cmd = CS.create_rural_action("roads")
	road_cmd.tick = 0; road_cmd.version = 0; road_cmd.player_id = "rural_road"
	var road0 := float(GS.state["rural_policy"]["rural_roads"])
	r = GE.tick(GS.state, GS.version, GS.tick, [road_cmd])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["rural_policy"]["rural_roads"]) <= road0:
		fails.append("راه روستایی ساخته نشد")
	else:
		print("✓ روستایی: راه روستایی دسترسی به بازار را بهتر کرد")

	# اینترنت بدون دیجیتال سطح ۴ باید مسدود شود
	var rm = load("res://scripts/core/rural_manager.gd").new()
	var low = GS.state.duplicate(true); low["technology"]["branch_levels"]["دیجیتال"] = 0
	if rm.expand_rural_internet(low).get("success", false):
		fails.append("اینترنت روستایی بدون دیجیتال سطح ۴ نباید فعال شود")
	else:
		print("✓ روستایی: اینترنت روستایی به فناوری دیجیتال نیاز دارد")
	GS.state["technology"]["branch_levels"]["دیجیتال"] = 6
	var int0 := float(GS.state["rural_policy"]["rural_internet"])
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_rural_action("internet")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["rural_policy"]["rural_internet"]) <= int0:
		fails.append("اینترنت روستایی گسترش نیافت")
	else:
		print("✓ روستایی: اینترنت پرسرعت روستاها را به بازار آنلاین وصل کرد")

	var proc0 := float(GS.state["rural_policy"]["agro_processing"])
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_rural_action("processing")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["rural_policy"]["agro_processing"]) <= proc0:
		fails.append("صنایع تبدیلی ساخته نشد")
	else:
		print("✓ روستایی: صنایع تبدیلی ضایعات را کم و ارزش افزوده را زیاد کرد")

	r = GE.tick(GS.state, GS.version, GS.tick, [])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state["rural_policy"].has("rural_income"):
		fails.append("شبیه‌سازی ماهانه روستایی انجام نشد")
	else:
		print("✓ روستایی: مهاجرت، درآمد و حاشیه‌نشینی ماهانه پویا شد")

	# ── دترمینیسم ──
	var s_a = GS.state.duplicate(true)
	var ra = GE.tick(s_a, GS.version, GS.tick, [])
	var s_b = GS.state.duplicate(true)
	var rb = GE.tick(s_b, GS.version, GS.tick, [])
	if JSON.stringify(ra.state) != JSON.stringify(rb.state):
		fails.append("عدم دترمینیسم در سیستم‌های عمق بیشتر ۱۰")
	else:
		print("✓ دترمینیسم کامل")

	print("")
	if fails.is_empty():
		print("=== ✅ DEEPER 10 TEST PASSED ===")
	else:
		for f in fails:
			print("❌ " + f)
		print("=== ❌ FAILED: %d ===" % fails.size())
	quit(fails.size())
