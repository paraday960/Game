extends SceneTree
# تست عمق بیشتر ۱۶: مدیریت بحران، دامپروری، نساجی

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

	# ── ۱) مدیریت بحران ──
	var dm = load("res://scripts/core/disaster_manager.gd").new()
	var low = GS.state.duplicate(true); low["technology"]["branch_levels"]["دیجیتال"] = 0
	if dm.build_early_warning(low, 1).get("success", false):
		fails.append("هشدار زودهنگام بدون فناوری نباید فعال شود")
	else:
		print("✓ بحران: هشدار زودهنگام به فناوری نیاز دارد")
	GS.state["technology"]["branch_levels"]["دیجیتال"] = 6
	var warn_cmd = CS.create_disaster_action("warning")
	warn_cmd.tick = 0; warn_cmd.version = 0; warn_cmd.player_id = "dis_warn"
	var w0 = float(GS.state["disaster_policy"]["early_warning"])
	r = GE.tick(GS.state, GS.version, GS.tick, [warn_cmd])
	GS.set_state(r.state, r.version, r.tick)
	if not r.get("success", false) or float(GS.state["disaster_policy"]["early_warning"]) <= w0:
		fails.append("سامانه هشدار ساخته نشد")
	else:
		print("✓ بحران: هشدار زودهنگام نصب شد")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_disaster_action("shelter")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["disaster_policy"]["shelter"]) <= 0.25:
		fails.append("پناهگاه اضطراری توسعه نیافت")
	else:
		print("✓ بحران: پناهگاه توسعه یافت")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_disaster_action("response")])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state["disaster_policy"].has("preparedness"):
		fails.append("شبیه‌سازی بحران انجام نشد")
	else:
		print("✓ بحران: آمادگی و ریسک ماهانه محاسبه شد")

	# ── ۲) دامپروری ──
	var ind_cmd = CS.create_livestock_action("industrial")
	ind_cmd.tick = 0; ind_cmd.version = 0; ind_cmd.player_id = "live_ind"
	r = GE.tick(GS.state, GS.version, GS.tick, [ind_cmd])
	GS.set_state(r.state, r.version, r.tick)
	if not r.get("success", false) or float(GS.state["livestock_policy"]["industrial"]) <= 0.30:
		fails.append("دامداری صنعتی توسعه نیافت")
	else:
		print("✓ دام: دامداری صنعتی گسترش یافت")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_livestock_action("vaccine")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["livestock_policy"]["vaccination"]) <= 0.45:
		fails.append("واکسیناسیون دام انجام نشد")
	else:
		print("✓ دام: واکسیناسیون بیماری را کم کرد")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_livestock_action("feed")])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state["livestock_policy"].has("protein_security"):
		fails.append("شبیه‌سازی دام انجام نشد")
	else:
		print("✓ دام: امنیت پروتئین و تولید ماهانه محاسبه شد")

	# ── ۳) نساجی ──
	var mill_cmd = CS.create_textile_action("mills")
	mill_cmd.tick = 0; mill_cmd.version = 0; mill_cmd.player_id = "tex_mill"
	r = GE.tick(GS.state, GS.version, GS.tick, [mill_cmd])
	GS.set_state(r.state, r.version, r.tick)
	if not r.get("success", false) or float(GS.state["textile_policy"]["spinning"]) <= 0.30:
		fails.append("کارخانه نساجی ساخته نشد")
	else:
		print("✓ نساجی: کارخانه ریسندگی توسعه یافت")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_textile_action("cotton")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["textile_policy"]["raw_material"]) <= 0.35:
		fails.append("تامین پنبه افزایش نیافت")
	else:
		print("✓ نساجی: الیاف داخلی تامین شد")

	# برندسازی بدون دیجیتال باید رد شود
	var low_t = GS.state.duplicate(true); low_t["technology"]["branch_levels"]["دیجیتال"] = 0
	var tm = load("res://scripts/core/textile_manager.gd").new()
	if tm.branding(low_t).get("success", false):
		fails.append("برندسازی بدون دیجیتال نباید فعال شود")
	else:
		print("✓ نساجی: برندسازی به فناوری دیجیتال نیاز دارد")
	GS.state["technology"]["branch_levels"]["دیجیتال"] = 8
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_textile_action("branding")])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state["textile_policy"].has("output"):
		fails.append("شبیه‌سازی نساجی انجام نشد")
	else:
		print("✓ نساجی: تولید، اشتغال و صادرات محاسبه شد")

	# ── دترمینیسم ──
	var s_a = GS.state.duplicate(true)
	var ra = GE.tick(s_a, GS.version, GS.tick, [])
	var s_b = GS.state.duplicate(true)
	var rb = GE.tick(s_b, GS.version, GS.tick, [])
	if JSON.stringify(ra.state) != JSON.stringify(rb.state):
		fails.append("عدم دترمینیسم در عمق بیشتر ۱۶")
	else:
		print("✓ دترمینیسم کامل")

	print("")
	if fails.is_empty():
		print("=== ✅ DEEPER 16 TEST PASSED ===")
	else:
		for f in fails:
			print("❌ " + f)
		print("=== ❌ FAILED: %d ===" % fails.size())
	quit(fails.size())
