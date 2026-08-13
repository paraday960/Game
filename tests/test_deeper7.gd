extends SceneTree
# تست عمق بیشتر ۷: دیاسپورا، پدافند غیرعامل، اقتصاد دریایی

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

	# ── ۱) دیاسپورا ──
	var trust0 := float(GS.state.get("diaspora_policy", {}).get("trust", 0.45))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_diaspora_action("diplomacy")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("diaspora_policy", {}).get("trust", 0.45)) <= trust0:
		fails.append("دیپلماسی عمومی اعتماد دیاسپورا را بالا نبرد")
	else:
		print("✓ دیاسپورا: دیپلماسی عمومی اعتماد و قدرت نرم را بالا برد")

	var sum0 := int(GS.state.get("diaspora_policy", {}).get("last_summit", -99))
	var summit_cmd = CS.create_diaspora_action("summit")
	summit_cmd.tick = 0; summit_cmd.version = 0; summit_cmd.player_id = "diaspora_summit"
	r = GE.tick(GS.state, GS.version, GS.tick, [summit_cmd])
	GS.set_state(r.state, r.version, r.tick)
	if int(GS.state.get("diaspora_policy", {}).get("last_summit", -99)) <= sum0:
		fails.append("اجلاس دیاسپورا برگزار نشد")
	else:
		print("✓ دیاسپورا: اجلاس جهانی تعامل رسمی را افزایش داد")

	var net0 := float(GS.state.get("diaspora_policy", {}).get("networks", 0.25))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_diaspora_action("networks")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("diaspora_policy", {}).get("networks", 0.25)) <= net0:
		fails.append("شبکه تخصصی دیاسپورا ساخته نشد")
	else:
		print("✓ دیاسپورا: شبکه‌های تخصصی علمی و سرمایه‌گذاری تقویت شد")

	var drain0 := float(GS.state.get("research_policy", {}).get("brain_drain", 0.28))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_diaspora_action("return")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("research_policy", {}).get("brain_drain", 0.28)) >= drain0:
		fails.append("بسته بازگشت نخبگان فرار مغزها را کم نکرد")
	else:
		print("✓ دیاسپورا: بسته بازگشت نخبگان فرار مغزها را کاهش داد")

	r = GE.tick(GS.state, GS.version, GS.tick, [])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("diaspora_policy", {}).get("remittance_b", 0.0)) <= 0.0:
		fails.append("حواله ارزی دیاسپورا شبیه‌سازی نشد")
	else:
		print("✓ دیاسپورا: حواله ارزی، لابی و قدرت نرم ماهانه محاسبه شد")

	# ── ۲) پدافند غیرعامل ──
	var hard0 := int(GS.state.get("civil_defense_policy", {}).get("last_hardening", -99))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_civil_defense_action("hardening")])
	GS.set_state(r.state, r.version, r.tick)
	if int(GS.state.get("civil_defense_policy", {}).get("last_hardening", -99)) <= hard0:
		fails.append("سخت‌سازی هدف‌ها اجرا نشد")
	else:
		print("✓ پدافند: سخت‌سازی زیرساخت‌های حیاتی انجام شد")

	var red0 := float(GS.state.get("civil_defense_policy", {}).get("redundancy", 0.20))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_civil_defense_action("redundancy")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("civil_defense_policy", {}).get("redundancy", 0.20)) <= red0:
		fails.append("افزونگی زیرساخت اجرا نشد")
	else:
		print("✓ پدافند: افزونگی و پراکندگی آسیب اختلال نقطه‌ای را کم می‌کند")

	var shel0 := float(GS.state.get("civil_defense_policy", {}).get("shelters", 0.20))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_civil_defense_action("shelters")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("civil_defense_policy", {}).get("shelters", 0.20)) <= shel0:
		fails.append("پناهگاه غیرنظامی ساخته نشد")
	else:
		print("✓ پدافند: پناهگاه و حفاظت غیرنظامی توسعه یافت")

	var stock0 := float(GS.state.get("civil_defense_policy", {}).get("strategic_stock", 0.30))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_civil_defense_action("stockpile")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("civil_defense_policy", {}).get("strategic_stock", 0.30)) <= stock0:
		fails.append("ذخیره راهبردی افزایش نیافت")
	else:
		print("✓ پدافند: ذخیره راهبردی غذا/دارو/سوخت افزایش یافت")

	r = GE.tick(GS.state, GS.version, GS.tick, [])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("civil_defense_policy", {}).get("resilience_index", 0.0)) <= 0.0:
		fails.append("شاخص تاب‌آوری پدافند محاسبه نشد")
	else:
		print("✓ پدافند: تاب‌آوری، بازدارندگی و آمادگی امداد ماهانه به‌روز شد")

	# ── ۳) اقتصاد دریایی ──
	var port0 := int(GS.state.get("blue_economy_policy", {}).get("last_port", -99))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_blue_economy_action("port")])
	GS.set_state(r.state, r.version, r.tick)
	if int(GS.state.get("blue_economy_policy", {}).get("last_port", -99)) <= port0:
		fails.append("توسعه بندر اجرا نشد")
	else:
		print("✓ دریا: توسعه ظرفیت بندر و اسکله کانتینری به تجارت کمک کرد")

	var fleet0 := int(GS.state.get("blue_economy_policy", {}).get("last_fleet", -99))
	var fleet_cmd = CS.create_blue_economy_action("fleet")
	fleet_cmd.tick = 0; fleet_cmd.version = 0; fleet_cmd.player_id = "blue_fleet"
	r = GE.tick(GS.state, GS.version, GS.tick, [fleet_cmd])
	GS.set_state(r.state, r.version, r.tick)
	if int(GS.state.get("blue_economy_policy", {}).get("last_fleet", -99)) <= fleet0:
		fails.append("توسعه ناوگان تجاری اجرا نشد")
	else:
		print("✓ دریا: ناوگان تجاری و کشتی‌سازی رشد کرد")

	var fish0 := float(GS.state.get("blue_economy_policy", {}).get("sustainable_fisheries", 0.35))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_blue_economy_action("fishery")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state.get("blue_economy_policy", {}).get("sustainable_fisheries", 0.35)) <= fish0:
		fails.append("مدیریت پایدار شیلات اجرا نشد")
	else:
		print("✓ دریا: شیلات پایدار ذخایر ماهی و معیشت ساحلی را حفظ می‌کند")

	var patrol0 := int(GS.state.get("blue_economy_policy", {}).get("last_patrol", -99))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_blue_economy_action("patrol")])
	GS.set_state(r.state, r.version, r.tick)
	if int(GS.state.get("blue_economy_policy", {}).get("last_patrol", -99)) <= patrol0:
		fails.append("گشت دریایی اجرا نشد")
	else:
		print("✓ دریا: گشت ساحلی قاچاق سوخت و صید غیرمجاز را مهار کرد")

	r = GE.tick(GS.state, GS.version, GS.tick, [])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state.get("blue_economy_policy", {}).has("blue_gdp"):
		fails.append("سهم اقتصاد دریا محاسبه نشد")
	else:
		print("✓ دریا: بندر، ناوگان، شیلات و گشت ماهانه در اقتصاد و تجارت اثر می‌گذارند")

	# ── ۴) دترمینیسم ──
	var s_a = GS.state.duplicate(true)
	var ra = GE.tick(s_a, GS.version, GS.tick, [])
	var s_b = GS.state.duplicate(true)
	var rb = GE.tick(s_b, GS.version, GS.tick, [])
	if JSON.stringify(ra.state) != JSON.stringify(rb.state):
		fails.append("عدم دترمینیسم در سیستم‌های عمق بیشتر ۷")
	else:
		print("✓ دترمینیسم کامل")

	print("")
	if fails.is_empty():
		print("=== ✅ DEEPER 7 TEST PASSED ===")
	else:
		for f in fails:
			print("❌ " + f)
		print("=== ❌ FAILED: %d ===" % fails.size())
	quit(fails.size())
