extends SceneTree
# تست عمق بیشتر ۱۳: زنجیره تأمین، اقتصاد مراقبت، دیپلماسی علمی

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

	# ── ۱) زنجیره تأمین ──
	var res_cmd = CS.create_supply_action("reserve")
	res_cmd.tick = 0; res_cmd.version = 0; res_cmd.player_id = "sup_res"
	var r0 = float(GS.state["supply_policy"]["strategic_reserve"])
	r = GE.tick(GS.state, GS.version, GS.tick, [res_cmd])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["supply_policy"]["strategic_reserve"]) <= r0:
		fails.append("ذخایر راهبردی تقویت نشد")
	else:
		print("✓ زنجیره: ذخایر راهبردی تقویت شد")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_supply_action("diversify")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["supply_policy"]["diversification"]) <= 0.40:
		fails.append("تنوع تأمین‌کننده افزایش نیافت")
	else:
		print("✓ زنجیره: تنوع تأمین‌کننده ریسک را کم کرد")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_supply_action("domestic")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["supply_policy"]["domestic_capacity"]) <= 0.40:
		fails.append("ظرفیت داخلی افزایش نیافت")
	else:
		print("✓ زنجیره: تولید داخلی کلیدی تقویت شد")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_supply_action("rotation")])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state["supply_policy"].has("disruption"):
		fails.append("شبیه‌سازی ماهانه زنجیره انجام نشد")
	else:
		print("✓ زنجیره: اختلال و لجستیک ماهانه محاسبه شد")

	# ── ۲) اقتصاد مراقبت ──
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_care_action("eldercare")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["care_policy"]["eldercare"]) <= 0.25:
		fails.append("مراقبت سالمندان افزایش نیافت")
	else:
		print("✓ مراقبت: خدمات سالمندان توسعه یافت")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_care_action("childcare")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["care_policy"]["childcare"]) <= 0.25:
		fails.append("مهدکودک افزایش نیافت")
	else:
		print("✓ مراقبت: مهدکودک مشارکت زنان را بالا برد")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_care_action("homecare")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["care_policy"]["home_care"]) <= 0.20:
		fails.append("مراقبت در منزل افزایش نیافت")
	else:
		print("✓ مراقبت: خدمات در منزل توسعه یافت")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_care_action("leave")])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state["care_policy"].has("female_lfp"):
		fails.append("شبیه‌سازی ماهانه مراقبت انجام نشد")
	else:
		print("✓ مراقبت: مشارکت زنان و بار مراقبت محاسبه شد")

	# ── ۳) دیپلماسی علمی ──
	# آزمایشگاه بدون دیجیتال باید رد شود
	var sdm = load("res://scripts/core/science_diplomacy_manager.gd").new()
	var low = GS.state.duplicate(true); low["technology"]["branch_levels"]["دیجیتال"] = 0
	if sdm.joint_lab(low).get("success", false):
		fails.append("آزمایشگاه مشترک بدون دیجیتال نباید باز شود")
	else:
		print("✓ علم: آزمایشگاه مشترک به فناوری دیجیتال نیاز دارد")
	GS.state["technology"]["branch_levels"]["دیجیتال"] = 6

	var agr_cmd = CS.create_science_action("agreement")
	agr_cmd.tick = 0; agr_cmd.version = 0; agr_cmd.player_id = "sci_agr"
	r = GE.tick(GS.state, GS.version, GS.tick, [agr_cmd])
	GS.set_state(r.state, r.version, r.tick)
	if not r.get("success", false) or float(GS.state["science_policy"]["bilateral"]) <= 0.20:
		fails.append("توافق علمی منعقد نشد")
	else:
		print("✓ علم: توافق علمی دوجانبه امضا شد")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_science_action("lab")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["science_policy"]["joint_labs"]) <= 0.15:
		fails.append("آزمایشگاه مشترک تأسیس نشد")
	else:
		print("✓ علم: آزمایشگاه مشترک تحقیقاتی افتتاح شد")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_science_action("scholarship")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["science_policy"]["scholarships"]) <= 0.25:
		fails.append("برنامه بورس گسترش نیافت")
	else:
		print("✓ علم: بورس بین‌المللی دانشجویان توسعه یافت")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_science_action("consortium")])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state["science_policy"].has("knowledge_flow"):
		fails.append("شبیه‌سازی ماهانه علم انجام نشد")
	else:
		print("✓ علم: جریان دانش و جذب نخبگان محاسبه شد")

	# ── دترمینیسم ──
	var s_a = GS.state.duplicate(true)
	var ra = GE.tick(s_a, GS.version, GS.tick, [])
	var s_b = GS.state.duplicate(true)
	var rb = GE.tick(s_b, GS.version, GS.tick, [])
	if JSON.stringify(ra.state) != JSON.stringify(rb.state):
		fails.append("عدم دترمینیسم در سیستم‌های عمق بیشتر ۱۳")
	else:
		print("✓ دترمینیسم کامل")

	print("")
	if fails.is_empty():
		print("=== ✅ DEEPER 13 TEST PASSED ===")
	else:
		for f in fails:
			print("❌ " + f)
		print("=== ❌ FAILED: %d ===" % fails.size())
	quit(fails.size())
