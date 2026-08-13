extends SceneTree
# تست سه سیستم جدید: مالیات، خودرو برقی، گردشگری سلامت

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

	# ── مالیات ──
	root.get_node("TaxManager").reset()
	var r1 = root.get_node("TaxManager").set_rate(state, "vat", 0.10)
	if not r1.success:
		fails.append("تنظیم نرخ مالیات بر ارزش افزوده انجام نشد")
	root.get_node("TaxManager").deploy_digital_invoicing(state)
	root.get_node("TaxManager").improve_compliance(state)
	state = root.get_node("TaxManager").simulate(state, 1)
	var tax_sum = root.get_node("TaxManager").get_summary(state)
	if float(tax_sum.revenue) <= 0:
		fails.append("درآمد مالیاتی صفر است")
	else:
		print("✓ مالیات: درآمد %s (نسبت به GDP: %s)" % [str(tax_sum.revenue), str(tax_sum.revenue_to_gdp)])

	# ── خودرو برقی ──
	root.get_node("EvIndustryManager").reset()
	state["mining_policy"] = {"output": 0.6}
	state["energy_policy"] = state.get("energy_policy", {})
	state["energy_policy"]["energy_security"] = 0.7
	var r2 = root.get_node("EvIndustryManager").build_battery_factory(state)
	if not r2.success: fails.append("ساخت کارخانه باطری: " + str(r2.reason))
	root.get_node("EvIndustryManager").invest_battery_research(state)
	var r3 = root.get_node("EvIndustryManager").expand_ev_production(state)
	if not r3.success: fails.append("تولید خودرو برقی: " + str(r3.reason))
	root.get_node("EvIndustryManager").build_charging_network(state)
	state = root.get_node("EvIndustryManager").simulate(state, 1)
	var ev_sum = root.get_node("EvIndustryManager").get_summary(state)
	if float(ev_sum.ev_share) < 0:
		fails.append("سهم خودرو برقی منفی است")
	else:
		print("✓ خودرو برقی: سهم %s، ظرفیت باطری %s" % [str(ev_sum.ev_share), str(ev_sum.battery_capacity)])

	# ── گردشگری سلامت ──
	root.get_node("HealthTourismManager").reset()
	state["health"] = {"quality": 0.5}
	state["politics"] = {"stability": 0.7}
	root.get_node("HealthTourismManager").improve_quality(state)
	root.get_node("HealthTourismManager").build_international_hospital(state)
	root.get_node("HealthTourismManager").develop_wellness(state)
	root.get_node("HealthTourismManager").facilitate_visa(state)
	state = root.get_node("HealthTourismManager").simulate(state, 1)
	var ht_sum = root.get_node("HealthTourismManager").get_summary(state)
	print("✓ گردشگری سلامت: گردشگر %s، درآمد %s" % [str(ht_sum.tourists), str(ht_sum.revenue)])

	# ── تست فرمان از طریق Command ──
	var tax_cmd = CS.create_tax_action("vat", 0.12)
	if tax_cmd.type != "tax_action":
		fails.append("فرمان مالیاتی ساخته نشد")
	else:
		print("✓ فرمان مالیاتی ساخته شد")
	var ev_cmd = CS.create_ev_action("battery")
	if ev_cmd.type != "ev_action":
		fails.append("فرمان خودرو برقی ساخته نشد")
	else:
		print("✓ فرمان خودرو برقی ساخته شد")
	var ht_cmd = CS.create_health_tourism_action("hospital")
	if ht_cmd.type != "health_tourism_action":
		fails.append("فرمان گردشگری سلامت ساخته نشد")
	else:
		print("✓ فرمان گردشگری سلامت ساخته شد")

	print("")
	if fails.is_empty():
		print("=== ✅ DEPTH 18 TEST PASSED ===")
	else:
		for f in fails: print("❌", f)
		print("=== ❌ FAILED: %d ===" % fails.size())
	quit(fails.size())
