extends SceneTree
# تست عمق بیشتر ۱۷: صنایع بنیادی، برند ملی، هوش مصنوعی

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

	# ── ۱) صنایع بنیادی ──
	var bm = load("res://scripts/core/basic_industry_manager.gd").new()
	var low = GS.state.duplicate(true); low["technology"]["branch_levels"]["صنعت"] = 0
	if bm.expand_steel(low, 1).get("success", false):
		fails.append("فولاد بدون فناوری نباید ساخته شود")
	else:
		print("✓ بنیادی: فولاد به فناوری صنعت نیاز دارد")
	GS.state["technology"]["branch_levels"]["صنعت"] = 7
	var steel_cmd = CS.create_basic_industry_action("steel")
	steel_cmd.tick = 0; steel_cmd.version = 0; steel_cmd.player_id = "bi_steel"
	r = GE.tick(GS.state, GS.version, GS.tick, [steel_cmd])
	GS.set_state(r.state, r.version, r.tick)
	if not r.get("success", false) or float(GS.state["basic_industry_policy"]["steel"]) <= 0.35:
		fails.append("فولاد توسعه نیافت")
	else:
		print("✓ بنیادی: ظرفیت فولاد افزایش یافت")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_basic_industry_action("cement")])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state["basic_industry_policy"].has("output"):
		fails.append("شبیه‌سازی بنیادی انجام نشد")
	else:
		print("✓ بنیادی: تولید و خودکفایی ماهانه محاسبه شد")

	# ── ۲) برند ملی ──
	var nb_cmd = CS.create_nation_brand_action("branding")
	nb_cmd.tick = 0; nb_cmd.version = 0; nb_cmd.player_id = "nb_brand"
	r = GE.tick(GS.state, GS.version, GS.tick, [nb_cmd])
	GS.set_state(r.state, r.version, r.tick)
	if not r.get("success", false) or float(GS.state["nation_brand_policy"]["branding"]) <= 0.25:
		fails.append("کمپین برند اجرا نشد")
	else:
		print("✓ برند ملی: کمپین برند آغاز شد")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_nation_brand_action("event")])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state["nation_brand_policy"].has("brand_index"):
		fails.append("شبیه‌سازی برند انجام نشد")
	else:
		print("✓ برند ملی: شاخص برند و قدرت نرم محاسبه شد")

	# ── ۳) هوش مصنوعی ──
	var am = load("res://scripts/core/ai_industry_manager.gd").new()
	var low_ai = GS.state.duplicate(true); low_ai["technology"]["branch_levels"]["دیجیتال"] = 0
	if am.adopt_ai(low_ai, 1).get("success", false):
		fails.append("پذیرش AI بدون دیجیتال نباید فعال شود")
	else:
		print("✓ AI: پذیرش به فناوری دیجیتال نیاز دارد")
	GS.state["technology"]["branch_levels"]["دیجیتال"] = 9
	var ai_cmd = CS.create_ai_action("adopt")
	ai_cmd.tick = 0; ai_cmd.version = 0; ai_cmd.player_id = "ai_adopt"
	r = GE.tick(GS.state, GS.version, GS.tick, [ai_cmd])
	GS.set_state(r.state, r.version, r.tick)
	if not r.get("success", false) or float(GS.state["ai_policy"]["adoption"]) <= 0.10:
		fails.append("پذیرش AI انجام نشد")
	else:
		print("✓ AI: پذیرش هوش مصنوعی آغاز شد")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_ai_action("reskill")])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state["ai_policy"].has("productivity"):
		fails.append("شبیه‌سازی AI انجام نشد")
	else:
		print("✓ AI: بهره‌وری و جابه‌جایی شغلی محاسبه شد")

	# ── دترمینیسم ──
	var s_a = GS.state.duplicate(true)
	var ra = GE.tick(s_a, GS.version, GS.tick, [])
	var s_b = GS.state.duplicate(true)
	var rb = GE.tick(s_b, GS.version, GS.tick, [])
	if JSON.stringify(ra.state) != JSON.stringify(rb.state):
		fails.append("عدم دترمینیسم در عمق بیشتر ۱۷")
	else:
		print("✓ دترمینیسم کامل")

	print("")
	if fails.is_empty():
		print("=== ✅ DEEPER 17 TEST PASSED ===")
	else:
		for f in fails:
			print("❌ " + f)
		print("=== ❌ FAILED: %d ===" % fails.size())
	quit(fails.size())
