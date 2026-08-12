extends SceneTree
# تست عمق بیشتر: پاندمی، تسلیحات، سایبر، مهاجرت، فرهنگ

func _init():
	await process_frame
	await process_frame
	var fails: Array = []
	var GS = root.get_node("GameState")
	var GE = root.get_node("GameEngine")
	var CS = load("res://scripts/core/command.gd")

	var r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_country_select("IRN", "balanced")])
	GS.set_state(r.state, r.version, r.tick)

	# ── ۱) پاندمی ──
	GS.state["epidemic"]["spread"] = 0.5
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_epidemic_action("lockdown2")])
	GS.set_state(r.state, r.version, r.tick)
	var spread0 := float(GS.state.get("epidemic", {}).get("spread", 0.0))
	GS.state["technology"]["branch_levels"]["پزشکی"] = 15
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_epidemic_action("vaccine")])
	if not r.success:
		fails.append("کمپین واکسن ناموفق: " + str(r.get("reason", "")))
	GS.set_state(r.state, r.version, r.tick)
	# کاهش شیوع
	for i in range(6):
		r = GE.tick(GS.state, GS.version, GS.tick, [])
		GS.set_state(r.state, r.version, r.tick)
	var spread1 := float(GS.state.get("epidemic", {}).get("spread", 0.0))
	if spread1 >= spread0:
		fails.append("قرنطینه/واکسن شیوع را کم نکرد (%.2f → %.2f)" % [spread0, spread1])
	else:
		print("✓ پاندمی: قرنطینه سنگین + واکسن شیوع را از %.2f به %.2f رساند" % [spread0, spread1])

	# ── ۲) صنایع دفاعی ──
	var stock0 := float(GS.state.get("arms_industry", {}).get("stock", 0.0))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_arms_action("invest")])
	GS.set_state(r.state, r.version, r.tick)
	var cap := float(GS.state.get("arms_industry", {}).get("capacity", 0.0))
	if cap < 30.0:
		fails.append("توسعه ظرفیت دفاعی کار نکرد: %.1f" % cap)
	# فروش
	GS.state["arms_industry"]["stock"] = 100.0
	GS.state["diplomacy"]["relations"]["AFG"] = 50.0
	var reserves0 := float(GS.state.get("economy", {}).get("foreign_reserves", 0.0))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_arms_action("sell", "AFG", 10.0)])
	if not r.success:
		fails.append("فروش تسلیحات ناموفق: " + str(r.get("reason", "")))
	GS.set_state(r.state, r.version, r.tick)
	var reserves1 := float(GS.state.get("economy", {}).get("foreign_reserves", 0.0))
	if reserves1 <= reserves0:
		fails.append("فروش تسلیحات ذخایر ارزی نیاورد")
	else:
		print("✓ تسلیحات: ظرفیت %.0f + فروش ۱۰ واحد به افغانستان (+%.0f ذخایر)" % [cap, reserves1 - reserves0])

	# ── ۳) جنگ سایبری ──
	GS.state["technology"]["branch_levels"]["دیجیتال"] = 15
	GS.state["diplomacy"]["relations"]["TUR"] = 20.0
	var tur_gdp0 := float(GS.state.get("world", {}).get("countries", {}).get("TUR", {}).get("gdp", 1.0))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_cyber_action("attack", "TUR", "economy")])
	if not r.success:
		fails.append("حمله سایبری ناموفق: " + str(r.get("reason", "")))
	GS.set_state(r.state, r.version, r.tick)
	var tur_gdp1 := float(GS.state.get("world", {}).get("countries", {}).get("TUR", {}).get("gdp", 1.0))
	var cyber_worked: bool = tur_gdp1 < tur_gdp0 or float(GS.state.get("diplomacy", {}).get("relations", {}).get("TUR", 20.0)) < 20.0
	if not cyber_worked:
		fails.append("حمله سایبری هیچ اثری نداشت")
	else:
		print("✓ سایبر: حمله به ترکیه اثر گذاشت (GDP یا روابط)")
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_cyber_action("firewall")])
	GS.set_state(r.state, r.version, r.tick)
	var fw := float(GS.state.get("cyber", {}).get("firewall", 0.0))
	if fw < 0.5:
		fails.append("فایروال ارتقا نیافت: %.2f" % fw)

	# ── ۴) مهاجرت ──
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_migration_action("skilled")])
	GS.set_state(r.state, r.version, r.tick)
	if str(GS.state.get("migration", {}).get("policy", "")) != "skilled":
		fails.append("سیاست مهاجرت تغییر نکرد")
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_migration_action("brain")])
	GS.set_state(r.state, r.version, r.tick)
	var brain := float(GS.state.get("migration", {}).get("brain_drain", 0.25))
	if brain >= 0.25:
		fails.append("فرار مغزها مهار نشد: %.2f" % brain)
	else:
		print("✓ مهاجرت: سیاست مهارت‌محور + مهار فرار مغزها (%.2f→%.2f)" % [0.25, brain])

	# ── ۵) فرهنگ ──
	GS.state["culture_policy"]["soft_power"] = 40.0
	var soft0 := float(GS.state.get("culture_policy", {}).get("soft_power", 40.0))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_culture_action("heritage")])
	GS.set_state(r.state, r.version, r.tick)
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_culture_action("festival")])
	if not r.success:
		fails.append("میزبانی رویداد ناموفق: " + str(r.get("reason", "")))
	GS.set_state(r.state, r.version, r.tick)
	var soft1 := float(GS.state.get("culture_policy", {}).get("soft_power", 40.0))
	if soft1 <= soft0:
		fails.append("قدرت نرم بالا نرفت (%.1f → %.1f)" % [soft0, soft1])
	else:
		print("✓ فرهنگ: میراث + جشنواره قدرت نرم را از %.0f به %.0f رساند" % [soft0, soft1])

	# ── ۶) دترمینیسم ──
	var s_a = GS.state.duplicate(true)
	var ra = GE.tick(s_a, GS.version, GS.tick, [])
	var s_b = GS.state.duplicate(true)
	var rb = GE.tick(s_b, GS.version, GS.tick, [])
	if JSON.stringify(ra.state) != JSON.stringify(rb.state):
		fails.append("عدم دترمینیسم در سیستم‌های عمق بیشتر")
	else:
		print("✓ دترمینیسم کامل")

	print("")
	if fails.is_empty():
		print("=== ✅ MORE DEPTH TEST PASSED ===")
	else:
		for f in fails:
			print("❌ " + f)
		print("=== ❌ FAILED: %d ===" % fails.size())
	quit(fails.size())
