extends SceneTree
# تست عمق ۲۱: هوانوردی، پست و لجستیک ملی، استاندارد و کیفیت

func _init():
	await process_frame
	var fails: Array = []
	var GS = root.get_node("GameState")
	var CS = load("res://scripts/core/command.gd")

	# یک کشور پایه با اقتصاد قابل توجه
	var state: Dictionary = GS.state.duplicate(true)
	state["economy"] = state.get("economy", {})
	state["economy"]["gdp"] = 500_000_000_000.0
	state["economy"]["foreign_reserves"] = 50_000_000_000.0

	# ── هوانوردی ──
	root.get_node("AviationManager").reset()
	# هاب بدون توسعه فرودگاه باید رد شود (پیش‌نیاز)
	var r_hub_early = root.get_node("AviationManager").develop_hub(state)
	if r_hub_early.success:
		fails.append("هاب ترانزیت بدون پیش‌نیاز فرودگاه پذیرفته شد")
	else:
		print("✓ هوانوردی: هاب بدون فرودگاه توسعه‌یافته رد شد")
	var r1 = root.get_node("AviationManager").expand_airports(state)
	if not r1.success:
		fails.append("توسعه فرودگاه انجام نشد")
	root.get_node("AviationManager").expand_airports(state)
	root.get_node("AviationManager").expand_airports(state)
	root.get_node("AviationManager").expand_fleet(state)
	root.get_node("AviationManager").improve_safety(state)
	var r2 = root.get_node("AviationManager").develop_hub(state)
	if not r2.success:
		fails.append("هاب ترانزیت پس از توسعه فرودگاه پذیرفته نشد: " + str(r2.get("reason","")))
	root.get_node("AviationManager").develop_cargo(state)
	state = root.get_node("AviationManager").simulate(state, 1)
	var av_sum = root.get_node("AviationManager").get_summary(state)
	if int(av_sum.passengers_m) <= 25:
		fails.append("مسافران هوانوردی رشد نکرد")
	else:
		print("✓ هوانوردی: مسافر %s میلیون، ایمنی %s" % [str(av_sum.passengers_m), str(av_sum.safety)])

	# ── پست و لجستیک ملی ──
	root.get_node("PostalManager").reset()
	# تجارت الکترونیک بدون تحویل آخرین مایل باید رد شود (پیش‌نیاز)
	var r_ec_early = root.get_node("PostalManager").boost_ecommerce(state)
	if r_ec_early.success:
		fails.append("تجارت الکترونیک بدون پیش‌نیاز تحویل پذیرفته شد")
	else:
		print("✓ پست: تجارت الکترونیک بدون تحویل آخرین مایل رد شد")
	root.get_node("PostalManager").improve_lastmile(state)
	var r3 = root.get_node("PostalManager").boost_ecommerce(state)
	if not r3.success:
		fails.append("تجارت الکترونیک پس از تحویل آخرین مایل پذیرفته نشد: " + str(r3.get("reason","")))
	root.get_node("PostalManager").expand_network(state)
	root.get_node("PostalManager").mechanize_sorting(state)
	root.get_node("PostalManager").improve_tracking(state)
	state = root.get_node("PostalManager").simulate(state, 1)
	var po_sum = root.get_node("PostalManager").get_summary(state)
	if int(po_sum.parcels_m) <= 500:
		fails.append("حجم مرسولات رشد نکرد")
	else:
		print("✓ پست: مرسولات %s میلیون، تجارت الکترونیک %s" % [str(po_sum.parcels_m), str(po_sum.ecommerce)])

	# ── استاندارد و زیرساخت کیفیت ──
	root.get_node("StandardsManager").reset()
	# اعتباردهی بدون آزمایشگاه معتمد باید رد شود (پیش‌نیاز)
	var r_acr_early = root.get_node("StandardsManager").expand_accreditation(state)
	if r_acr_early.success:
		fails.append("اعتباردهی بدون آزمایشگاه پذیرفته شد")
	else:
		print("✓ استاندارد: اعتباردهی بدون آزمایشگاه رد شد")
	root.get_node("StandardsManager").accredit_labs(state)
	var r4 = root.get_node("StandardsManager").expand_accreditation(state)
	if not r4.success:
		fails.append("اعتباردهی پس از آزمایشگاه پذیرفته نشد: " + str(r4.get("reason","")))
	root.get_node("StandardsManager").invest_metrology(state)
	root.get_node("StandardsManager").improve_surveillance(state)
	root.get_node("StandardsManager").strengthen_export_gate(state)
	state = root.get_node("StandardsManager").simulate(state, 1)
	var st_sum = root.get_node("StandardsManager").get_summary(state)
	if int(st_sum.certified_firms) <= 1200:
		fails.append("بنگاه‌های گواهی‌شده رشد نکردند")
	else:
		print("✓ استاندارد: بنگاه‌های گواهی‌شده %s، مترولوژی %s" % [str(st_sum.certified_firms), str(st_sum.metrology)])

	# ── تست فرمان از طریق Command ──
	var av_cmd = CS.create_aviation_action("hub")
	if av_cmd.type != "aviation_action":
		fails.append("فرمان هوانوردی ساخته نشد")
	else:
		print("✓ فرمان هوانوردی ساخته شد")
	var po_cmd = CS.create_postal_action("ecommerce")
	if po_cmd.type != "postal_action":
		fails.append("فرمان پست ساخته نشد")
	else:
		print("✓ فرمان پست ساخته شد")
	var st_cmd = CS.create_standards_action("export_gate")
	if st_cmd.type != "standards_action":
		fails.append("فرمان استاندارد ساخته نشد")
	else:
		print("✓ فرمان استاندارد ساخته شد")

	# ── قرارداد موتور: simulate_month باید {state, events} برگرداند ──
	var av_m = root.get_node("AviationManager").simulate_month(state, 1)
	if not av_m.has("state") or not av_m.has("events"):
		fails.append("قرارداد simulate_month هوانوردی شکسته است")
	var po_m = root.get_node("PostalManager").simulate_month(state, 1)
	if not po_m.has("state") or not po_m.has("events"):
		fails.append("قرارداد simulate_month پست شکسته است")
	var st_m = root.get_node("StandardsManager").simulate_month(state, 1)
	if not st_m.has("state") or not st_m.has("events"):
		fails.append("قرارداد simulate_month استاندارد شکسته است")

	print("")
	if fails.is_empty():
		print("=== ✅ DEPTH 21 TEST PASSED ===")
	else:
		for f in fails: print("❌", f)
		print("=== ❌ FAILED: %d ===" % fails.size())
	quit(fails.size())
