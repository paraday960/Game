extends SceneTree
# تست عمق بیشتر ۱۴: پتروشیمی/پالایش، آموزش عالی، زنجیره غذا

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

	# ── ۱) پتروشیمی/پالایش ──
	# پالایش بدون صنعت کافی باید رد شود
	var dm = load("res://scripts/core/downstream_energy_manager.gd").new()
	var low = GS.state.duplicate(true); low["technology"]["branch_levels"]["صنعت"] = 0
	if dm.expand_refining(low, 1).get("success", false):
		fails.append("پالایشگاه بدون صنعت نباید ساخته شود")
	else:
		print("✓ پتروشیمی: پالایشگاه به فناوری صنعت نیاز دارد")
	GS.state["technology"]["branch_levels"]["صنعت"] = 6
	var ref_cmd = CS.create_downstream_action("refining")
	ref_cmd.tick = 0; ref_cmd.version = 0; ref_cmd.player_id = "ds_ref"
	var r0 = float(GS.state["downstream_policy"]["refining"])
	r = GE.tick(GS.state, GS.version, GS.tick, [ref_cmd])
	GS.set_state(r.state, r.version, r.tick)
	if not r.get("success", false) or float(GS.state["downstream_policy"]["refining"]) <= r0:
		fails.append("توسعه پالایش انجام نشد")
	else:
		print("✓ پتروشیمی: ظرفیت پالایش افزایش یافت")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_downstream_action("petrochem")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["downstream_policy"]["petrochemical"]) <= 0.30:
		fails.append("پتروشیمی توسعه نیافت")
	else:
		print("✓ پتروشیمی: مجتمع پتروشیمی ارزش‌افزوده ساخت")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_downstream_action("selfsuff")])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state["downstream_policy"].has("fuel_security"):
		fails.append("شبیه‌سازی ماهانه پتروشیمی انجام نشد")
	else:
		print("✓ پتروشیمی: خام‌فروشی و امنیت سوخت محاسبه شد")

	# ── ۲) آموزش عالی ──
	var he_cmd = CS.create_higher_ed_action("funding")
	he_cmd.tick = 0; he_cmd.version = 0; he_cmd.player_id = "he_fund"
	r = GE.tick(GS.state, GS.version, GS.tick, [he_cmd])
	GS.set_state(r.state, r.version, r.tick)
	if not r.get("success", false) or float(GS.state["higher_ed_policy"]["funding"]) <= 0.30:
		fails.append("بودجه دانشگاه افزایش نیافت")
	else:
		print("✓ آموزش عالی: بودجه دانشگاه افزایش یافت")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_higher_ed_action("research")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["higher_ed_policy"]["research"]) <= 0.25:
		fails.append("گرنت پژوهشی اجرا نشد")
	else:
		print("✓ آموزش عالی: تحقیقات دانشگاهی تقویت شد")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_higher_ed_action("faculty")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["higher_ed_policy"]["faculty"]) <= 0.30:
		fails.append("جذب هیئت علمی نشد")
	else:
		print("✓ آموزش عالی: هیئت علمی تقویت شد")

	r = GE.tick(GS.state, GS.version, GS.tick, [])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state["higher_ed_policy"].has("quality"):
		fails.append("شبیه‌سازی آموزش عالی انجام نشد")
	else:
		print("✓ آموزش عالی: کیفیت و رتبه ماهانه محاسبه شد")

	# ── ۳) زنجیره غذا ──
	var stor_cmd = CS.create_food_chain_action("storage")
	stor_cmd.tick = 0; stor_cmd.version = 0; stor_cmd.player_id = "fc_stor"
	var s0 = float(GS.state["food_chain_policy"]["storage"])
	r = GE.tick(GS.state, GS.version, GS.tick, [stor_cmd])
	GS.set_state(r.state, r.version, r.tick)
	if not r.get("success", false) or float(GS.state["food_chain_policy"]["storage"]) <= s0:
		fails.append("سردخانه ساخته نشد")
	else:
		print("✓ غذا: سردخانه ضایعات را کم کرد")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_food_chain_action("processing")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["food_chain_policy"]["processing"]) <= 0.20:
		fails.append("صنایع تبدیلی غذا توسعه نیافت")
	else:
		print("✓ غذا: صنایع تبدیلی غذا رشد کرد")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_food_chain_action("logistics")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["food_chain_policy"]["logistics"]) <= 0.30:
		fails.append("لجستیک غذا بهبود نیافت")
	else:
		print("✓ غذا: لجستیک سردخانه‌ای بهینه شد")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_food_chain_action("safety")])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state["food_chain_policy"].has("food_security"):
		fails.append("شبیه‌سازی زنجیره غذا انجام نشد")
	else:
		print("✓ غذا: امنیت و ضایعات غذا محاسبه شد")

	# ── دترمینیسم ──
	var s_a = GS.state.duplicate(true)
	var ra = GE.tick(s_a, GS.version, GS.tick, [])
	var s_b = GS.state.duplicate(true)
	var rb = GE.tick(s_b, GS.version, GS.tick, [])
	if JSON.stringify(ra.state) != JSON.stringify(rb.state):
		fails.append("عدم دترمینیسم در عمق بیشتر ۱۴")
	else:
		print("✓ دترمینیسم کامل")

	print("")
	if fails.is_empty():
		print("=== ✅ DEEPER 14 TEST PASSED ===")
	else:
		for f in fails:
			print("❌ " + f)
		print("=== ❌ FAILED: %d ===" % fails.size())
	quit(fails.size())
