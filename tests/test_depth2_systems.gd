extends SceneTree
# تست عمق‌بخشی مرحله ۲: فرماندهان ارتش، رسانه و افکار عمومی، بازار جهانی کالا، سازمان‌های بین‌المللی

func _init():
	await process_frame
	await process_frame
	var fails: Array = []
	var GS = root.get_node("GameState")
	var GE = root.get_node("GameEngine")
	var CS = load("res://scripts/core/command.gd")
	var GM = root.get_node("GeneralsManager")
	var MM = root.get_node("MediaManager")
	var CM = root.get_node("CommodityManager")
	var OM = root.get_node("OrgManager")

	var r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_country_select("IRN", "balanced")])
	GS.set_state(r.state, r.version, r.tick)

	# ── ۱) فرماندهان ──
	GS.state["policies"]["political_capital"] = 5.0
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_general_recruit()])
	if not r.success:
		fails.append("استخدام فرمانده ناموفق: " + str(r.get("reason", "")))
	GS.set_state(r.state, r.version, r.tick)
	var commanders: Dictionary = GS.state.get("generals", {}).get("commanders", {})
	if commanders.is_empty():
		fails.append("فرمانده استخدام نشد")
	else:
		var cid := str(commanders.keys()[0])
		var commander: Dictionary = commanders[cid]
		if str(commander.get("trait", "")) == "" or str(commander.get("name_fa", "")) == "":
			fails.append("ویژگی/نام فرمانده خالی است")
		# گماردن به جنگ
		GS.state["diplomacy"]["relations"]["AFG"] = 20.0
		r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_diplomacy_action("AFG", "declare_war", "reparations")])
		GS.set_state(r.state, r.version, r.tick)
		r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_general_assign(cid, "AFG")])
		if not r.success:
			fails.append("گماردن فرمانده ناموفق: " + str(r.get("reason", "")))
		GS.set_state(r.state, r.version, r.tick)
		if str(GS.state.get("generals", {}).get("commanders", {}).get(cid, {}).get("assigned_war", "")) != "AFG":
			fails.append("فرمانده به جنگ گمارده نشد")
		# بونوس جبهه باید عددی و از فرمانده گمارده‌شده بیاید (ویژگی‌ها عمداً بده‌بستان دارند:
		# مثلاً فرمانده دفاعی حمله ضعیف‌تری دارد؛ عدد منفی ویژگی، باگ نیست)
		var bonus: Dictionary = GM.front_bonus(GS.state, "AFG")
		for k in ["offense", "defense", "logistics", "air"]:
			if not is_finite(float(bonus.get(k, 0.0))):
				fails.append("بونوس جبهه «%s» عددی نیست" % k)
		var contributed := absf(float(bonus.get("offense", 0.0))) + absf(float(bonus.get("defense", 0.0))) + absf(float(bonus.get("logistics", 0.0))) + absf(float(bonus.get("air", 0.0)))
		if contributed <= 0.0:
			fails.append("بونوس جبهه از فرمانده گمارده‌شده صفر است")
		# چند تیک برای تجربه/ارتقا
		for i in range(8):
			r = GE.tick(GS.state, GS.version, GS.tick, [])
			GS.set_state(r.state, r.version, r.tick)
		var exp := float(GS.state.get("generals", {}).get("commanders", {}).get(cid, {}).get("experience", 0.0))
		if exp <= 0.0:
			fails.append("فرمانده در جنگ تجربه نگرفت")
		else:
			print("✓ فرماندهان: استخدام، گماردن و تجربه از نبرد (تجربه: %.1f)" % exp)

	# ── ۲) رسانه و افکار عمومی ──
	var approval0: float = MM.overall_approval(GS.state)
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_media_policy("populist")])
	GS.set_state(r.state, r.version, r.tick)
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_media_campaign("جوانان", "emotional")])
	if not r.success:
		fails.append("کمپین رسانه‌ای ناموفق: " + str(r.get("reason", "")))
	GS.set_state(r.state, r.version, r.tick)
	var camp: Dictionary = GS.state.get("media", {}).get("campaign", {})
	if int(camp.get("turns_left", 0)) <= 0:
		fails.append("کمپین فعال نشد")
	# اجرای کمپین در چند نوبت
	for i in range(3):
		r = GE.tick(GS.state, GS.version, GS.tick, [])
		GS.set_state(r.state, r.version, r.tick)
	var young := float(GS.state.get("media", {}).get("groups", {}).get("جوانان", {}).get("approval", 0.0))
	if young <= 45.0:
		fails.append("رضایت جوانان با کمپین بالا نرفت: %.1f" % young)
	else:
		print("✓ رسانه: سیاست پوپولیستی + کمپین احساسی رضایت جوانان را به %.0f رساند" % young)

	# ── ۳) بازار جهانی کالا ──
	var price0: float = CM.get_price(GS.state, "نفت")
	GS.state["economy"]["foreign_reserves"] = 100e9
	var reserves0 := float(GS.state.get("commodities", {}).get("reserves", {}).get("نفت", 0.0))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_commodity_trade("نفت", 10.0)])
	if not r.success:
		fails.append("فروش کالا ناموفق: " + str(r.get("reason", "")))
	GS.set_state(r.state, r.version, r.tick)
	var reserves1 := float(GS.state.get("commodities", {}).get("reserves", {}).get("نفت", 0.0))
	var foreign1 := float(GS.state.get("economy", {}).get("foreign_reserves", 0.0))
	if reserves1 >= reserves0:
		fails.append("ذخیره نفت کم نشد")
	if foreign1 <= 100e9:
		fails.append("ذخیره ارزی از فروش زیاد نشد")
	# نوسان قیمت در ۶ نوبت
	var prices_seen := {}
	for i in range(6):
		r = GE.tick(GS.state, GS.version, GS.tick, [])
		GS.set_state(r.state, r.version, r.tick)
		var p: float = CM.get_price(GS.state, "نفت")
		prices_seen[p] = true
	if prices_seen.size() < 3:
		fails.append("قیمت نفت نوسان کافی نداشت: %d مقدار یکتا" % prices_seen.size())
	else:
		print("✓ بازار کالا: فروش ۱۰ واحد نفت ذخیره ارزی ساخت (+%.0f) و قیمت‌ها نوسان دارند" % (foreign1 - 100e9))

	# ── ۴) سازمان‌های بین‌المللی ──
	var memberships0: Dictionary = GS.state.get("intl_orgs", {}).get("memberships", {})
	var was_opec := bool(memberships0.get("اوپک", false))
	r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_org_toggle("اوپک")])
	if not r.success:
		fails.append("تغییر عضویت اوپک ناموفق: " + str(r.get("reason", "")))
	GS.set_state(r.state, r.version, r.tick)
	var memberships1: Dictionary = GS.state.get("intl_orgs", {}).get("memberships", {})
	if bool(memberships1.get("اوپک", false)) == was_opec:
		fails.append("عضویت اوپک تغییر نکرد")
	# انتظار قطعنامه (تا ۱۰ نوبت)
	var vote_seen := false
	var vote_ok := false
	for i in range(10):
		r = GE.tick(GS.state, GS.version, GS.tick, [])
		GS.set_state(r.state, r.version, r.tick)
		var pending: Dictionary = GS.state.get("intl_orgs", {}).get("pending_vote", {})
		if not pending.is_empty() and not vote_seen:
			vote_seen = true
			r = GE.tick(GS.state, GS.version, GS.tick, [CS.create_org_vote("yes")])
			if not r.success:
				fails.append("رأی به قطعنامه ناموفق: " + str(r.get("reason", "")))
			else:
				vote_ok = true
			GS.set_state(r.state, r.version, r.tick)
		if vote_ok:
			break
	if not vote_ok:
		fails.append("قطعنامه‌ای در ۱۰ نوبت رأی‌گیری نشد")
	else:
		print("✓ سازمان‌ها: تغییر عضویت اوپک + رأی به قطعنامه (پیمان اقلیمی)")

	# ── ۵) دترمینیسم ──
	var s_a = GS.state.duplicate(true)
	var ra = GE.tick(s_a, GS.version, GS.tick, [])
	var s_b = GS.state.duplicate(true)
	var rb = GE.tick(s_b, GS.version, GS.tick, [])
	if JSON.stringify(ra.state) != JSON.stringify(rb.state):
		fails.append("عدم دترمینیسم در سیستم‌های عمق ۲")
	else:
		print("✓ دترمینیسم کامل")

	print("")
	if fails.is_empty():
		print("=== ✅ DEPTH2 SYSTEMS TEST PASSED ===")
	else:
		for f in fails:
			print("❌ " + f)
		print("=== ❌ FAILED: %d ===" % fails.size())
	quit(fails.size())
