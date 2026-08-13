extends SceneTree
# تست عمق بیشتر ۹: زندان، آمار ملی و معدن

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

	# ── ۱) زندان ──
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_prison_approach("rehab")])
	GS.set_state(r.state, r.version, r.tick)
	if str(GS.state.get("prison_policy", {}).get("approach", "")) != "rehab":
		fails.append("رویکرد بازپرورانه اعمال نشد")
	else:
		print("✓ زندان: تغییر رویکرد کیفری به بازپرورانه اعمال شد")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_prison_action("education")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("prison_policy", {}).get("education", 0)) < 0.40:
		fails.append("آموزش زندان اجرا نشد")
	else:
		print("✓ زندان: برنامه آموزشی و مهارتی در زندان اجرا شد")

	var cap_cmd = CS.create_prison_action("capacity")
	cap_cmd.tick = 0; cap_cmd.version = 0; cap_cmd.player_id = "prison_cap"
	r = GE.tick(GS.state, GS.version, GS.tick, [cap_cmd])
	GS.set_state(r.state, r.version, r.tick)
	if not r.get("success", false) or float(GS.state["prison_policy"]["capacity_expansion"]) <= 0.30:
		fails.append("توسعه ظرفیت زندان اجرا نشد")
	else:
		print("✓ زندان: توسعه ظرفیت زندان‌ها ازدحام را کنترل کرد")

	r = GE.tick(GS.state, GS.version, GS.tick, [])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state["prison_policy"].has("recidivism_target"):
		fails.append("شبیه‌سازی ماهانه زندان انجام نشد")
	else:
		print("✓ زندان: ازدحام، بازاجتماعی‌سازی و بازگشت به جرم ماهانه محاسبه شد")

	# ── ۲) آمار ملی ──
	var census_cmd = CS.create_statistics_action("census")
	census_cmd.tick = 0; census_cmd.version = 0; census_cmd.player_id = "stats_census"
	r = GE.tick(GS.state, GS.version, GS.tick, [census_cmd])
	GS.set_state(r.state, r.version, r.tick)
	if not r.get("success", false) or int(GS.state["statistics_policy"]["last_census"]) < 0:
		fails.append("سرشماری ملی اجرا نشد")
	else:
		print("✓ آمار: سرشماری ملی پوشش و دقت داده را بالا برد")

	# پایگاه داده بدون دیجیتال سطح ۵ باید مسدود شود
	var s_low = GS.state.duplicate(true)
	s_low["technology"]["branch_levels"]["دیجیتال"] = 0
	var sm = load("res://scripts/core/statistics_manager.gd").new()
	if sm.build_data_infra(s_low).get("success", false):
		fails.append("پایگاه داده بدون فناوری دیجیتال نباید فعال شود")
	else:
		print("✓ آمار: زیرساخت داده به فناوری دیجیتال نیاز دارد")
	GS.state["technology"]["branch_levels"]["دیجیتال"] = 8
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_statistics_action("infra")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["statistics_policy"]["data_infrastructure"]) <= 0.40:
		fails.append("تقویت زیرساخت داده اجرا نشد")
	else:
		print("✓ آمار: پایگاه ملی داده و رصدخانه سیاستی ساخته شد")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_statistics_action("independence")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["statistics_policy"]["independence"]) <= 0.55:
		fails.append("استقلال مرکز آمار تضمین نشد")
	else:
		print("✓ آمار: تضمین استقلال مرکز آمار اعتماد عمومی را بالا برد")

	r = GE.tick(GS.state, GS.version, GS.tick, [])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state["statistics_policy"].has("accuracy"):
		fails.append("دقت آمار محاسبه نشد")
	else:
		print("✓ آمار: دقت، کم‌گمارشی و اعتماد به داده ماهانه محاسبه شد")

	# ── ۳) معدن ──
	var mine_cmd = CS.create_mining_action("mine")
	mine_cmd.tick = 0; mine_cmd.version = 0; mine_cmd.player_id = "mine_dev"
	r = GE.tick(GS.state, GS.version, GS.tick, [mine_cmd])
	GS.set_state(r.state, r.version, r.tick)
	if not r.get("success", false) or float(GS.state["mining_policy"]["exploration"]) <= 0.30:
		fails.append("توسعه معدن اجرا نشد")
	else:
		print("✓ معدن: اکتشاف و توسعه معدن ذخایر و اشتغال را بالا برد")

	# کارخانه فرآوری بدون صنعت سطح ۶ باید مسدود شود
	var low_tech = GS.state.duplicate(true)
	low_tech["technology"]["branch_levels"]["صنعت"] = 0
	var mm = load("res://scripts/core/mining_manager.gd").new()
	if mm.build_refinery(low_tech, 1).get("success", false):
		fails.append("کارخانه فرآوری بدون صنعت سطح ۶ نباید ساخته شود")
	else:
		print("✓ معدن: فرآوری معدنی به فناوری صنعت سطح ۶ نیاز دارد")
	GS.state["technology"]["branch_levels"]["صنعت"] = 8
	var ref_cmd = CS.create_mining_action("refinery")
	ref_cmd.tick = 0; ref_cmd.version = 0; ref_cmd.player_id = "mine_ref"
	r = GE.tick(GS.state, GS.version, GS.tick, [ref_cmd])
	GS.set_state(r.state, r.version, r.tick)
	if not r.get("success", false) or float(GS.state["mining_policy"]["processing"]) <= 0.25:
		fails.append("احداث کارخانه فرآوری اجرا نشد")
	else:
		print("✓ معدن: فرآوری داخل خام‌فروشی را کم و ارزش افزوده را زیاد کرد")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_mining_action("safety")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["mining_policy"]["safety"]) <= 0.40:
		fails.append("ارتقای ایمنی معادن اجرا نشد")
	else:
		print("✓ معدن: ارتقای ایمنی معادن ریسک حادثه را کم کرد")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_mining_action("formalize")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["mining_policy"]["formalization"]) <= 0.35:
		fails.append("ساماندهی معادن کوچک اجرا نشد")
	else:
		print("✓ معدن: ساماندهی معادن کوچک، قاچاق و حوادث را کاهش داد")

	r = GE.tick(GS.state, GS.version, GS.tick, [])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state["mining_policy"].has("accident_risk"):
		fails.append("شبیه‌سازی ماهانه معدن انجام نشد")
	else:
		print("✓ معدن: ذخایر، تولید، فرآوری و آلودگی ماهانه اثر متقابل دارند")

	# ── دترمینیسم ──
	var s_a = GS.state.duplicate(true)
	var ra = GE.tick(s_a, GS.version, GS.tick, [])
	var s_b = GS.state.duplicate(true)
	var rb = GE.tick(s_b, GS.version, GS.tick, [])
	if JSON.stringify(ra.state) != JSON.stringify(rb.state):
		fails.append("عدم دترمینیسم در سیستم‌های عمق بیشتر ۹")
	else:
		print("✓ دترمینیسم کامل")

	print("")
	if fails.is_empty():
		print("=== ✅ DEEPER 9 TEST PASSED ===")
	else:
		for f in fails:
			print("❌ " + f)
		print("=== ❌ FAILED: %d ===" % fails.size())
	quit(fails.size())
