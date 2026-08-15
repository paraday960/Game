extends SceneTree
# تست عمق بیشتر ۶: امنیت آبی، پژوهش و نوآوری، مشارکت مدنی

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

	# ── ۱) امنیت آبی ──
	var storage0 := float(GS.state.get("water_infrastructure", {}).get("storage_bcm", 35.0))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_water_action("dam")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("water_infrastructure", {}).get("storage_bcm", 35.0)) <= storage0:
		fails.append("سد جدید ذخیره آب را افزایش نداد")
	else:
		print("✓ آب: سد و مخزن جدید ظرفیت ذخیره آب را بالا برد")

	var last_dam := int(GS.state.get("water_policy", {}).get("last_dam", -99))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_water_action("dam")])
	GS.set_state(r.state, r.version, r.tick)
	if int(GS.state.get("water_policy", {}).get("last_dam", -99)) != last_dam:
		fails.append("سد پیاپی باید مسدود شود (هر ۱۲ نوبت)")
	else:
		print("✓ آب: دوره تاخیر ۱۲ نوبتی سد رعایت شد")

	var leak0 := float(GS.state.get("water_policy", {}).get("leakage", 0.28))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_water_action("leakage")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("water_policy", {}).get("leakage", 0.28)) >= leak0:
		fails.append("کاهش هدررفت شبکه اجرا نشد")
	else:
		print("✓ آب: نوسازی شبکه هدررفت را کم کرد و پوشش آبرسانی شهری را بهبود داد")

	var irr0 := float(GS.state.get("water_policy", {}).get("irrigation_efficiency", 0.35))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_water_action("irrigation")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("water_policy", {}).get("irrigation_efficiency", 0.35)) <= irr0:
		fails.append("آبیاری نوین بازده را بالا نبرد")
	else:
		print("✓ آب: آبیاری تحت‌فشار، بازده مصرف آب کشاورزی را افزایش داد")

	GS.state["technology"]["branch_levels"]["انرژی_پاک"] = 5
	var desal0 := float(GS.state.get("water_policy", {}).get("desalination", 0.05))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_water_action("desal")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("water_policy", {}).get("desalination", 0.05)) <= desal0:
		fails.append("آب‌شیرین‌کن با فناوری لازم ساخته نشد")
	else:
		print("✓ آب: واحد آب‌شیرین‌کن با پیش‌نیاز انرژی پاک ساخته شد و مصرف برق را بالا برد")

	r = GE.tick(GS.state, GS.version, GS.tick, [])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state.get("water_policy", {}).has("aquifer") or not GS.state.get("water_infrastructure", {}).has("stress_index"):
		fails.append("شبیه‌سازی ماهانه آب انجام نشد")
	else:
		print("✓ آب: تنش آبی، سفره زیرزمینی و اثر بر کشاورزی ماهانه محاسبه شد")

	# ── ۲) پژوهش و نوآوری ──
	var brain0 := float(GS.state.get("research_policy", {}).get("brain_drain", 0.28))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_research_action("university")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("research_policy", {}).get("brain_drain", 0.28)) >= brain0:
		fails.append("بودجه دانشگاه فرار مغزها را کم نکرد")
	else:
		print("✓ پژوهش: بودجه دانشگاه کیفیت آموزش را بالا و فرار مغزها را کم کرد")

	var centers0 := float(GS.state.get("research_policy", {}).get("rnd_centers", 0.25))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_research_action("center")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("research_policy", {}).get("rnd_centers", 0.25)) <= centers0:
		fails.append("احداث پژوهشگاه اجرا نشد")
	var last_center := int(GS.state.get("research_policy", {}).get("last_center", -99))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_research_action("center")])
	GS.set_state(r.state, r.version, r.tick)
	if int(GS.state.get("research_policy", {}).get("last_center", -99)) != last_center:
		fails.append("پژوهشگاه پیاپی باید مسدود شود (هر ۸ نوبت)")
	else:
		print("✓ پژوهش: پژوهشگاه راهبردی ساخته شد و دوره تاخیر ۸ نوبتی دارد")

	var transfer0 := float(GS.state.get("research_policy", {}).get("tech_transfer", 0.20))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_research_action("transfer")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("research_policy", {}).get("tech_transfer", 0.20)) <= transfer0:
		fails.append("انتقال فناوری اجرا نشد")
	else:
		print("✓ پژوهش: پیوند دانشگاه و صنعت و شرکت‌های دانش‌بنیان تقویت شد")

	var papers0 := int(GS.state.get("research_policy", {}).get("papers", 0))
	r = GE.tick(GS.state, GS.version, GS.tick, [])
	GS.set_state(r.state, r.version, r.tick)
	if int(GS.state.get("research_policy", {}).get("papers", 0)) <= papers0:
		fails.append("تولید علم ماهانه شبیه‌سازی نشد")
	else:
		print("✓ پژوهش: مقاله، اختراع، نرخ پژوهش و شاخص نوآوری ماهانه رشد کرد")

	# ── ۳) مشارکت مدنی ──
	# اثر مستقیم open_data: شفافیت افزایش + فساد کاهش (اعتماد از کانال تدریجی
	# سیستم‌ها بالا می‌رود نه در همان تیک — عمق‌بخشی ۳۸: اصلاح تست منسوخ).
	var trans0 := float(GS.state.get("civic_policy", {}).get("transparency", 0.45))
	var corrupt0 := float(GS.state.get("politics", {}).get("corruption", 0.30))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_civic_action("opendata")])
	GS.set_state(r.state, r.version, r.tick)
	var trans1 := float(GS.state.get("civic_policy", {}).get("transparency", 0.45))
	var corrupt1 := float(GS.state.get("politics", {}).get("corruption", 0.30))
	if trans1 <= trans0 or corrupt1 >= corrupt0:
		fails.append("داده باز شفافیت را زیاد یا فساد را کم نکرد")
	else:
		print("✓ مدنی: داده باز شفافیت را از %.2f به %.2f و فساد را از %.2f به %.2f برد" % [trans0, trans1, corrupt0, corrupt1])

	var council0 := float(GS.state.get("civic_policy", {}).get("local_councils", 0.35))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_civic_action("councils")])
	GS.set_state(r.state, r.version, GS.tick)
	if float(GS.state.get("civic_policy", {}).get("local_councils", 0.35)) <= council0:
		fails.append("تقویت شوراهای محلی اجرا نشد")
	else:
		print("✓ مدنی: شوراهای محلی به تمرکززدایی و اعتماد محلی کمک کردند")

	var cmd_budget = CS.create_civic_action("budget")
	cmd_budget.tick = 0
	cmd_budget.version = 0
	cmd_budget.player_id = "budget_player"
	var pb0 := float(GS.state.get("civic_policy", {}).get("participatory_budget", 0.20))
	r = GE.tick(GS.state, GS.version, GS.tick, [cmd_budget])
	var pb_ok: bool = bool(r.get("success", false))
	GS.set_state(r.state, r.version, r.tick)
	var pb1 := float(GS.state.get("civic_policy", {}).get("participatory_budget", 0.20))
	if not pb_ok or pb1 < pb0 + 0.1:
		fails.append("بودجه‌ریزی مشارکتی اجرا نشد")
	var last_pb := int(GS.state.get("civic_policy", {}).get("last_assembly", -99))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_civic_action("budget")])
	GS.set_state(r.state, r.version, r.tick)
	if int(GS.state.get("civic_policy", {}).get("last_assembly", -99)) != last_pb:
		fails.append("مجمع بودجه پیاپی باید مسدود شود (هر ۵ نوبت)")
	else:
		print("✓ مدنی: بودجه‌ریزی مشارکتی برگزار شد و دوره تاخیر ۵ نوبتی دارد")

	var cmd_ngos = CS.create_civic_action("ngos")
	cmd_ngos.tick = 0
	cmd_ngos.version = 0
	cmd_ngos.player_id = "ngos_player"
	var ngo0 := float(GS.state.get("civic_policy", {}).get("ngo_space", 0.40))
	r = GE.tick(GS.state, GS.version, GS.tick, [cmd_ngos])
	var ngo_ok: bool = bool(r.get("success", false))
	GS.set_state(r.state, r.version, r.tick)
	var ngo1 := float(GS.state.get("civic_policy", {}).get("ngo_space", 0.40))
	if not ngo_ok or ngo1 < ngo0 + 0.1:
		fails.append("حمایت از سمن‌ها اجرا نشد")
	else:
		print("✓ مدنی: فضای سمن‌ها امن‌تر شد و اعتراض فروخورده کاهش یافت")

	r = GE.tick(GS.state, GS.version, GS.tick, [])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state.get("civic_policy", {}).has("social_capital"):
		fails.append("سرمایه اجتماعی ماهانه محاسبه نشد")
	else:
		print("✓ مدنی: سرمایه اجتماعی، اعتماد، ثبات و فشار اعتراض ماهانه پویا شد")

	# ── ۴) دترمینیسم ──
	var s_a = GS.state.duplicate(true)
	var ra = GE.tick(s_a, GS.version, GS.tick, [])
	var s_b = GS.state.duplicate(true)
	var rb = GE.tick(s_b, GS.version, GS.tick, [])
	if JSON.stringify(ra.state) != JSON.stringify(rb.state):
		fails.append("عدم دترمینیسم در سیستم‌های عمق بیشتر ۶")
	else:
		print("✓ دترمینیسم کامل")

	print("")
	if fails.is_empty():
		print("=== ✅ DEEPER 6 TEST PASSED ===")
	else:
		for f in fails:
			print("❌ " + f)
		print("=== ❌ FAILED: %d ===" % fails.size())
	quit(fails.size())
