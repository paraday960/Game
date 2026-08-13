extends SceneTree
# تست عمق بیشتر ۱۵: دارو، مالکیت فکری، ترانزیت

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

	# ── ۱) دارو ──
	var pm = load("res://scripts/core/pharma_manager.gd").new()
	var low = GS.state.duplicate(true); low["technology"]["branch_levels"]["دیجیتال"] = 0; low["technology"]["branch_levels"]["پزشکی"] = 0; low["technology"]["branch_levels"]["صنعت"] = 0
	if pm.build_plant(low, 1).get("success", false):
		fails.append("کارخانه دارو بدون فناوری نباید ساخته شود")
	else:
		print("✓ دارو: کارخانه دارو به فناوری نیاز دارد")
	GS.state["technology"]["branch_levels"]["دیجیتال"] = 6
	var plant_cmd = CS.create_pharma_action("plant")
	plant_cmd.tick = 0; plant_cmd.version = 0; plant_cmd.player_id = "pharma_plant"
	r = GE.tick(GS.state, GS.version, GS.tick, [plant_cmd])
	GS.set_state(r.state, r.version, r.tick)
	if not r.get("success", false) or float(GS.state["pharma_policy"]["domestic"]) <= 0.30:
		fails.append("کارخانه دارو ساخته نشد")
	else:
		print("✓ دارو: تولید داخلی دارو افزایش یافت")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_pharma_action("generic")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["pharma_policy"]["generic"]) <= 0.40:
		fails.append("داروی ژنریک توسعه نیافت")
	else:
		print("✓ دارو: داروی ژنریک قیمت دارو را کم کرد")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_pharma_action("stockpile")])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state["pharma_policy"].has("drug_security"):
		fails.append("شبیه‌سازی دارو انجام نشد")
	else:
		print("✓ دارو: امنیت دارو و وابستگی واردات محاسبه شد")

	# ── ۲) مالکیت فکری ──
	var ip_cmd = CS.create_ip_action("patent")
	ip_cmd.tick = 0; ip_cmd.version = 0; ip_cmd.player_id = "ip_patent"
	r = GE.tick(GS.state, GS.version, GS.tick, [ip_cmd])
	GS.set_state(r.state, r.version, r.tick)
	if not r.get("success", false) or float(GS.state["ip_policy"]["patents"]) <= 0.25:
		fails.append("اصلاح ثبت اختراع انجام نشد")
	else:
		print("✓ مالکیت فکری: نظام ثبت اختراع اصلاح شد")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_ip_action("copyright")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["ip_policy"]["copyright"]) <= 0.30:
		fails.append("حمایت کپی‌رایت تقویت نشد")
	else:
		print("✓ مالکیت فکری: کپی‌رایت تقویت شد")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_ip_action("transfer")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["ip_policy"]["tech_transfer"]) <= 0.20:
		fails.append("دفتر انتقال فناوری ایجاد نشد")
	else:
		print("✓ مالکیت فکری: انتقال فناوری از دانشگاه به صنعت")

	r = GE.tick(GS.state, GS.version, GS.tick, [])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state["ip_policy"].has("innovation_index"):
		fails.append("شبیه‌سازی IP انجام نشد")
	else:
		print("✓ مالکیت فکری: نوآوری و رویالتی ماهانه محاسبه شد")

	# ── ۳) ترانزیت ──
	# گمرک بدون دیجیتال باید رد شود
	var tm = load("res://scripts/core/transit_manager.gd").new()
	var low_t = GS.state.duplicate(true); low_t["technology"]["branch_levels"]["دیجیتال"] = 0
	if tm.customs_reform(low_t).get("success", false):
		fails.append("گمرک هوشمند بدون دیجیتال نباید باز شود")
	else:
		print("✓ ترانزیت: گمرک هوشمند به فناوری دیجیتال نیاز دارد")
	GS.state["technology"]["branch_levels"]["دیجیتال"] = 8

	var cor_cmd = CS.create_transit_action("corridor")
	cor_cmd.tick = 0; cor_cmd.version = 0; cor_cmd.player_id = "tr_corridor"
	r = GE.tick(GS.state, GS.version, GS.tick, [cor_cmd])
	GS.set_state(r.state, r.version, r.tick)
	if not r.get("success", false) or float(GS.state["transit_policy"]["corridors"]) <= 0.25:
		fails.append("کریدور ترانزیتی توسعه نیافت")
	else:
		print("✓ ترانزیت: کریدور ترانزیتی توسعه یافت")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_transit_action("customs")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["transit_policy"]["customs"]) <= 0.30:
		fails.append("گمرک هوشمند راه‌اندازی نشد")
	else:
		print("✓ ترانزیت: گمرک هوشمند تأخیر مرزی را کم کرد")

	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_transit_action("rail")])
	GS.set_state(r.state, r.version, r.tick)
	if float(GS.state["transit_policy"]["rail"]) <= 0.25:
		fails.append("ریلی باری توسعه نیافت")
	else:
		print("✓ ترانزیت: شبکه ریلی باری توسعه یافت")

	r = GE.tick(GS.state, GS.version, GS.tick, [])
	GS.set_state(r.state, r.version, r.tick)
	if not GS.state["transit_policy"].has("transit_share"):
		fails.append("شبیه‌سازی ترانزیت انجام نشد")
	else:
		print("✓ ترانزیت: سهم ترانزیت و درآمد ارزی محاسبه شد")

	# ── دترمینیسم ──
	var s_a = GS.state.duplicate(true)
	var ra = GE.tick(s_a, GS.version, GS.tick, [])
	var s_b = GS.state.duplicate(true)
	var rb = GE.tick(s_b, GS.version, GS.tick, [])
	if JSON.stringify(ra.state) != JSON.stringify(rb.state):
		fails.append("عدم دترمینیسم در عمق بیشتر ۱۵")
	else:
		print("✓ دترمینیسم کامل")

	print("")
	if fails.is_empty():
		print("=== ✅ DEEPER 15 TEST PASSED ===")
	else:
		for f in fails:
			print("❌ " + f)
		print("=== ❌ FAILED: %d ===" % fails.size())
	quit(fails.size())
