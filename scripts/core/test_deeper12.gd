extends SceneTree
# تست عمق بیشتر ۱۲: مسکن، استارتاپ، SME

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

	# ── ۱) مسکن ──
	var soc_cmd = CS.create_housing_action("social")
	soc_cmd.tick = 0; soc_cmd.version = 0; soc_cmd.player_id = "house_soc"
	var s0 = float(GS.state["housing_policy"]["social_supply"])
	r = GE.tick(GS.state, GS.version, GS.tick, [soc_cmd])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["housing_policy"]["social_supply"]) <= s0:
		fails.append("مسکن اجتماعی ساخته نشد")
	else:
		print("✓ مسکن: مسکن اجتماعی بار اجاره را کم کرد")

	var m0 = float(GS.state["housing_policy"]["mortgage_access"])
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_housing_action("mortgage")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["housing_policy"]["mortgage_access"]) <= m0:
		fails.append("وام مسکن گسترش نیافت")
	else:
		print("✓ مسکن: دسترسی به وام مسکن افزایش یافت")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_housing_action("renewal")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["housing_policy"]["renewal"]) <= 0.15:
		fails.append("نوسازی بافت فرسوده انجام نشد")
	else:
		print("✓ مسکن: نوسازی بافت فرسوده اجرا شد")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_housing_action("regulate")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["housing_policy"]["bubble"]) >= 0.30:
		fails.append("تنظیم بازار حباب را کم نکرد")
	else:
		print("✓ مسکن: مالیات عایدی سوداگری و حباب را کاهش داد")

	r = GE.tick(GS.state, GS.version, GS.tick, [])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state["housing_policy"].has("price_index"):
		fails.append("شبیه‌سازی ماهانه مسکن انجام نشد")
	else:
		print("✓ مسکن: قیمت، اجاره و حباب ماهانه محاسبه شد")

	# ── ۲) استارتاپ ──
	var fund_cmd = CS.create_startup_action("fund")
	fund_cmd.tick = 0; fund_cmd.version = 0; fund_cmd.player_id = "startup_fund"
	var v0 = float(GS.state["startup_policy"]["vc_funding"])
	r = GE.tick(GS.state, GS.version, GS.tick, [fund_cmd])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["startup_policy"]["vc_funding"]) <= v0:
		fails.append("صندوق خطرپذیر تشکیل نشد")
	else:
		print("✓ استارتاپ: صندوق خطرپذیر تأمین مالی را بالا برد")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_startup_action("accelerator")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["startup_policy"]["accelerators"]) <= 0.20:
		fails.append("شتاب‌دهنده ایجاد نشد")
	else:
		print("✓ استارتاپ: مراکز شتاب‌دهی راه‌اندازی شد")

	# سندباکس بدون دیجیتال باید رد شود
	var sm = load("res://scripts/core/startup_manager.gd").new()
	var low = GS.state.duplicate(true); low["technology"]["branch_levels"]["دیجیتال"] = 0
	if sm.regulatory_sandbox(low).get("success", false):
		fails.append("سندباکس بدون دیجیتال نباید باز شود")
	else:
		print("✓ استارتاپ: سندباکس به فناوری دیجیتال نیاز دارد")
	GS.state["technology"]["branch_levels"]["دیجیتال"] = 6
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_startup_action("sandbox")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["startup_policy"]["regulatory_sandbox"]) <= 0.10:
		fails.append("سندباکس مقرراتی باز نشد")
	else:
		print("✓ استارتاپ: سندباکس مقرراتی نوآوری را تسهیل کرد")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_startup_action("braindrain")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["research_policy"]["brain_drain"]) >= 0.28:
		fails.append("بازگشت نخبگان فرار مغزها را کم نکرد")
	else:
		print("✓ استارتاپ: برنامه بازگشت نخبگان فرار مغزها را کاهش داد")

	r = GE.tick(GS.state, GS.version, GS.tick, [])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state["startup_policy"].has("innovation_rate"):
		fails.append("شبیه‌سازی ماهانه استارتاپ انجام نشد")
	else:
		print("✓ استارتاپ: نوآوری، شکست و صادرات فناوری محاسبه شد")

	# ── ۳) SME ──
	var r0 = float(GS.state["sme_policy"]["ease_business"])
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_sme_action("redtape")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["sme_policy"]["ease_business"]) <= r0:
		fails.append("مقررات‌زدایی انجام نشد")
	else:
		print("✓ SME: مقررات‌زدایی سهولت کسب‌وکار را بالا برد")

	var mc_cmd = CS.create_sme_action("microcredit")
	mc_cmd.tick = 0; mc_cmd.version = 0; mc_cmd.player_id = "sme_mc"
	var c0 = float(GS.state["sme_policy"]["micro_credit"])
	r = GE.tick(GS.state, GS.version, GS.tick, [mc_cmd])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["sme_policy"]["micro_credit"]) <= c0:
		fails.append("وام خرد پرداخت نشد")
	else:
		print("✓ SME: صندوق وام خرد شکاف اعتباری را کم کرد")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_sme_action("supplychain")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["sme_policy"]["supply_chain"]) <= 0.25:
		fails.append("تأمین مالی زنجیره انجام نشد")
	else:
		print("✓ SME: تأمین مالی زنجیره تأمین نقدینگی رساند")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_sme_action("formalize")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["sme_policy"]["formalization"]) <= 0.30:
		fails.append("رسمی‌سازی انجام نشد")
	else:
		print("✓ SME: رسمی‌سازی اقتصاد سایه را کوچک کرد")

	r = GE.tick(GS.state, GS.version, GS.tick, [])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state["sme_policy"].has("sme_share"):
		fails.append("شبیه‌سازی ماهانه SME انجام نشد")
	else:
		print("✓ SME: سهم اقتصاد، اشتغال و شکاف اعتباری محاسبه شد")

	# ── دترمینیسم ──
	var s_a = GS.state.duplicate(true)
	var ra = GE.tick(s_a, GS.version, GS.tick, [])
	var s_b = GS.state.duplicate(true)
	var rb = GE.tick(s_b, GS.version, GS.tick, [])
	if JSON.stringify(ra.state) != JSON.stringify(rb.state):
		fails.append("عدم دترمینیسم در سیستم‌های عمق بیشتر ۱۲")
	else:
		print("✓ دترمینیسم کامل")

	print("")
	if fails.is_empty():
		print("=== ✅ DEEPER 12 TEST PASSED ===")
	else:
		for f in fails:
			print("❌ " + f)
		print("=== ❌ FAILED: %d ===" % fails.size())
	quit(fails.size())
