extends SceneTree
# تست عمق جناح‌ها (عمق‌بخشی ۴۶):
# معامله با جناح (قول در ازای حمایت): محقق → پاداش، شکسته → وفاداری می‌سوزد.
# + واکنش جناح‌ها به قوانین (investment_code → نخبگان، emergency_powers → ارتش).

func _init():
	await process_frame
	var fails: Array = []
	var GS = root.get_node("GameState")
	var GE = root.get_node("GameEngine")
	var CS = load("res://scripts/core/command.gd")
	var FM = root.get_node("FactionManager")

	# ── سناریو ۱: معاملهٔ محقق‌شده با ارتش (آمادگی رزمی — معیار پایدار) ──
	var state: Dictionary = GS.state.duplicate(true)
	state = FM.ensure(state)
	state["military"] = state.get("military", {})
	state["military"]["readiness"] = 0.80  # از قبل محقق
	var r = GE.tick(state, GS.version, 0, [CS.create_faction_deal("ارتش", "war_ready")])
	if not r.success:
		fails.append("ثبت معامله ناموفق: %s" % r.reason)
	else:
		state = r.state
		var v: int = r.version; var t: int = r.tick
		var loyalty0 := float(state.get("factions", {}).get("ارتش", {}).get("loyalty", 62.0))
		var kept_seen := false
		for i in range(2):
			var r2 = GE.tick(state, v, t, [])
			state = r2.state; v = r2.version; t = r2.tick
			var loyalty1 := float(state.get("factions", {}).get("ارتش", {}).get("loyalty", 0.0))
			if loyalty1 > loyalty0:
				kept_seen = true
			loyalty0 = loyalty1
		if not kept_seen:
			fails.append("معاملهٔ محقق‌شده وفاداری ارتش را بالا نبرد")
		else:
			print("✓ معاملهٔ محقق‌شده: وفاداری ارتش افزایش یافت")

	# ── سناریو ۲: معاملهٔ شکسته با نخبگان (کاهش مالیات) ──
	var state2: Dictionary = GS.state.duplicate(true)
	state2 = FM.ensure(state2)
	var r2 = GE.tick(state2, GS.version, 0, [CS.create_faction_deal("نخبگان اقتصادی", "tax_relief")])
	if not r2.success:
		fails.append("ثبت معاملهٔ دوم ناموفق: %s" % r2.reason)
	else:
		state2 = r2.state
		var v2: int = r2.version; var t2: int = r2.tick
		var loyalty0b := float(state2.get("factions", {}).get("نخبگان اقتصادی", {}).get("loyalty", 55.0))
		# هیچ کاری نکن — مالیات همان ۰.۲ می‌ماند (تعهد ۰.۱۵)
		var broke := false
		for i in range(2):
			var r3 = GE.tick(state2, v2, t2, [])
			state2 = r3.state; v2 = r3.version; t2 = r3.tick
			var loyalty1b := float(state2.get("factions", {}).get("نخبگان اقتصادی", {}).get("loyalty", 0.0))
			if loyalty1b < loyalty0b - 5.0:
				broke = true
			loyalty0b = loyalty1b
		if not broke:
			fails.append("معاملهٔ شکسته وفاداری نخبگان را نسوزاند")
		else:
			print("✓ معاملهٔ شکسته: وفاداری نخبگان کاهش یافت (جریمه)")

	# ── سناریو ۳: واکنش به قانون ──
	var state3: Dictionary = GS.state.duplicate(true)
	state3 = FM.ensure(state3)
	state3["legislation"] = state3.get("legislation", {})
	state3["legislation"]["enacted"] = state3.get("legislation", {}).get("enacted", {})
	state3["legislation"]["enacted"]["investment_code"] = {"enacted_turn": 0}
	var v3: int = GS.version; var t3: int = 0
	var elites0 := float(state3.get("factions", {}).get("نخبگان اقتصادی", {}).get("loyalty", 55.0))
	var r4 = GE.tick(state3, v3, t3, [])
	state3 = r4.state
	var elites1 := float(state3.get("factions", {}).get("نخبگان اقتصادی", {}).get("loyalty", 0.0))
	if elites1 <= elites0:
		fails.append("قانون investment_code وفاداری نخبگان را بالا نبرد")
	else:
		print("✓ واکنش به قانون: investment_code وفاداری نخبگان را بالا برد")

	if fails.is_empty():
		print("\n=== ✅ FACTION DEPTH TEST PASSED ===")
		quit(0)
	else:
		print("\n=== ❌ FACTION DEPTH FAILED (%d) ===" % fails.size())
		for f in fails:
			print("  - " + f)
		quit(1)
