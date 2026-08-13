extends SceneTree
# تست عمق بیشتر ۱۱: اصلاح قضایی، انتخابات، سوخت/گذار انرژی

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

	# ── ۱) اصلاح قضایی ──
	# دیجیتال بدون فناوری باید مسدود شود
	var jr = load("res://scripts/core/judicial_reform_manager.gd").new()
	var low = GS.state.duplicate(true); low["technology"]["branch_levels"]["دیجیتال"] = 0
	if jr.digitalize_courts(low, 1).get("success", false):
		fails.append("دادگاه دیجیتال بدون فناوری نباید فعال شود")
	else:
		print("✓ قضایی: دیجیتال‌سازی به فناوری دیجیتال نیاز دارد")
	GS.state["technology"]["branch_levels"]["دیجیتال"] = 6
	var jrc = CS.create_judicial_reform_action("digital")
	jrc.tick = 0; jrc.version = 0; jrc.player_id = "jr_digital"
	r = GE.tick(GS.state, GS.version, GS.tick, [jrc])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["judicial_reform_policy"]["digital_courts"]) <= 0.20:
		fails.append("دیجیتال‌سازی دادگاه اجرا نشد")
	else:
		print("✓ قضایی: دادگاه الکترونیک اطاله دادرسی را کم کرد")

	var spec0 = float(GS.state["judicial_reform_policy"]["specialized_courts"])
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_judicial_reform_action("specialized")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["judicial_reform_policy"]["specialized_courts"]) <= spec0:
		fails.append("دادگاه‌های تخصصی ایجاد نشد")
	else:
		print("✓ قضایی: دادگاه‌های تخصصی تجاری و خانواده راه‌اندازی شد")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_judicial_reform_action("mediation")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["judicial_reform_policy"]["mediation"]) <= 0.20:
		fails.append("میانجی‌گری توسعه نیافت")
	else:
		print("✓ قضایی: میانجی‌گری تراکم پرونده را کاهش داد")

	r = GE.tick(GS.state, GS.version, GS.tick, [])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state["judicial_reform_policy"].has("case_resolution"):
		fails.append("شبیه‌سازی ماهانه قضایی انجام نشد")
	else:
		print("✓ قضایی: سرعت رسیدگی و هزینه تأخیر ماهانه محاسبه شد")

	# ── ۲) انتخابات ──
	var mon0 = float(GS.state["election_policy"]["media_monitoring"])
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_election_action("monitoring")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["election_policy"]["media_monitoring"]) <= mon0:
		fails.append("نظارت انتخابات تقویت نشد")
	else:
		print("✓ انتخابات: نهاد ناظر مستقل انصاف را بالا برد")

	var acc0 = float(GS.state["election_policy"]["voter_access"])
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_election_action("access")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["election_policy"]["voter_access"]) <= acc0:
		fails.append("دسترسی رأی‌دهندگان بهبود نیافت")
	else:
		print("✓ انتخابات: دسترسی به صندوق رأی بهتر شد")

	var pl0 = float(GS.state["election_policy"]["party_pluralism"])
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_election_action("pluralism")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["election_policy"]["party_pluralism"]) <= pl0:
		fails.append("تکثر احزاب تقویت نشد")
	else:
		print("✓ انتخابات: فضای رقابت حزبی بازتر شد")

	# زمان‌بندی انتخابات (چرخه ماهانه شمارش می‌شود)
	if int(GS.state["election_policy"]["next_election_turn"]) > 0:
		print("✓ انتخابات: شمارش معکوس دوره انتخابات فعال است")
	else:
		fails.append("زمان‌بندی انتخابات محاسبه نشد")

	r = GE.tick(GS.state, GS.version, GS.tick, [])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state["election_policy"].has("legitimacy"):
		fails.append("شبیه‌سازی ماهانه انتخابات انجام نشد")
	else:
		print("✓ انتخابات: مشارکت، مشروعیت و فشار مخالفان محاسبه شد")

	# ── ۳) سوخت و گذار ──
	var ref_cmd = CS.create_fuel_action("reform")
	ref_cmd.tick = 0; ref_cmd.version = 0; ref_cmd.player_id = "fuel_reform"
	var sub0 = float(GS.state["fuel_policy"]["subsidy"])
	r = GE.tick(GS.state, GS.version, GS.tick, [ref_cmd])
	GS.set_state(r.state, r.version, r.tick)
	if not r.get("success", false) or float(GS.state["fuel_policy"]["subsidy"]) >= sub0:
		fails.append("اصلاح یارانه سوخت اجرا نشد")
	else:
		print("✓ سوخت: اصلاح یارانه درآمد هدفمند ساخت اما تورم آورد")

	# شارژ بدون انرژی پاک باید رد شود
	var fm = load("res://scripts/core/fuel_transition_manager.gd").new()
	var low_e = GS.state.duplicate(true); low_e["technology"]["branch_levels"]["انرژی_پاک"] = 0
	if fm.build_charging(low_e).get("success", false):
		fails.append("ایستگاه شارژ بدون انرژی پاک نباید ساخته شود")
	else:
		print("✓ سوخت: ایستگاه شارژ به فناوری انرژی پاک نیاز دارد")
	GS.state["technology"]["branch_levels"]["انرژی_پاک"] = 6
	var ch0 = float(GS.state["fuel_policy"]["ev_charging"])
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_fuel_action("charging")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["fuel_policy"]["ev_charging"]) <= ch0:
		fails.append("ایستگاه شارژ ساخته نشد")
	else:
		print("✓ سوخت: شبکه شارژ برقی گسترش یافت")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_fuel_action("emission")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["fuel_policy"]["emission_standard"]) <= 0.25:
		fails.append("استاندارد آلایندگی سختگیرانه نشد")
	else:
		print("✓ سوخت: استاندارد آلایندگی خودروها بالا رفت")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_fuel_action("fleet")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["fuel_policy"]["public_fleet"]) <= 0.20:
		fails.append("ناوگان عمومی برقی نشد")
	else:
		print("✓ سوخت: ناوگان اتوبوس برقی توسعه یافت")

	r = GE.tick(GS.state, GS.version, GS.tick, [])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state["fuel_policy"].has("ev_share"):
		fails.append("شبیه‌سازی ماهانه سوخت انجام نشد")
	else:
		print("✓ سوخت: تقاضا، قاچاق و سهم برقی ماهانه محاسبه شد")

	# ── دترمینیسم ──
	var s_a = GS.state.duplicate(true)
	var ra = GE.tick(s_a, GS.version, GS.tick, [])
	var s_b = GS.state.duplicate(true)
	var rb = GE.tick(s_b, GS.version, GS.tick, [])
	if JSON.stringify(ra.state) != JSON.stringify(rb.state):
		fails.append("عدم دترمینیسم در سیستم‌های عمق بیشتر ۱۱")
	else:
		print("✓ دترمینیسم کامل")

	print("")
	if fails.is_empty():
		print("=== ✅ DEEPER 11 TEST PASSED ===")
	else:
		for f in fails:
			print("❌ " + f)
		print("=== ❌ FAILED: %d ===" % fails.size())
	quit(fails.size())
