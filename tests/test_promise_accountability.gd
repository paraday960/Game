extends SceneTree
# تست پاسخگویی وعده‌های انتخاباتی (عمق‌بخشی ۴۵):
# وعده = تعهد سنجش‌پذیر. محقق‌شده → ماندات/اعتماد؛ شکسته → رأی و اعتماد می‌سوزد.
# نتیجه در parliament.last_result (promises_kept/promises_broken) ثبت می‌شود.

func _init():
	await process_frame
	var fails: Array = []
	var GS = root.get_node("GameState")
	var GE = root.get_node("GameEngine")
	var CS = load("res://scripts/core/command.gd")

	# ── سناریو ۱: وعدهٔ محقق‌شده ──
	var state: Dictionary = GS.state.duplicate(true)
	state = root.get_node("ParliamentManager").ensure(state)
	# انتخابات ۲ نوبت بعد (snapshot_tick = tick+1، پس انتخابات در تیک بعد از آن)
	state["parliament"]["next_election_turn"] = 2
	var r = GE.tick(state, GS.version, 0, [CS.create_campaign_promise("tax_cut")])
	if not r.success:
		fails.append("ثبت وعده ناموفق: %s" % r.reason)
	else:
		state = r.state
		state["economy"]["tax_rate"] = max(0.05, float(state.get("economy", {}).get("tax_rate", 0.2)) - 0.05)  # محقق کردن
		var v: int = r.version; var t: int = r.tick
		var kept := 0
		var broken := 0
		for i in range(3):
			var r2 = GE.tick(state, v, t, [])
			state = r2.state; v = r2.version; t = r2.tick
			var last: Dictionary = state.get("parliament", {}).get("last_result", {})
			if not last.is_empty():
				kept = int(last.get("promises_kept", 0)); broken = int(last.get("promises_broken", 0))
		if kept != 1 or broken != 0:
			fails.append("وعدهٔ محقق‌شده درست سنجیده نشد (kept=%d broken=%d)" % [kept, broken])
		else:
			print("✓ وعدهٔ محقق‌شده: kept=1 broken=0 — پاداش ماندات و اعتماد")

	# ── سناریو ۲: وعدهٔ شکسته ──
	var state2: Dictionary = GS.state.duplicate(true)
	state2 = root.get_node("ParliamentManager").ensure(state2)
	state2["parliament"]["next_election_turn"] = 2
	var r2 = GE.tick(state2, GS.version, 0, [CS.create_campaign_promise("fight_corruption")])
	if not r2.success:
		fails.append("ثبت وعدهٔ دوم ناموفق: %s" % r2.reason)
	else:
		state2 = r2.state
		# هیچ کاری برای مبارزه با فساد نکن — وعده شکسته می‌شود
		var v2: int = r2.version; var t2: int = r2.tick
		var kept2 := 0
		var broken2 := 0
		for i in range(3):
			var r3 = GE.tick(state2, v2, t2, [])
			state2 = r3.state; v2 = r3.version; t2 = r3.tick
			var last2: Dictionary = state2.get("parliament", {}).get("last_result", {})
			if not last2.is_empty():
				kept2 = int(last2.get("promises_kept", 0)); broken2 = int(last2.get("promises_broken", 0))
		if broken2 != 1:
			fails.append("وعدهٔ محقق‌نشده شکسته شمرده نشد (kept=%d broken=%d)" % [kept2, broken2])
		else:
			print("✓ وعدهٔ شکسته: broken=1 — جریمهٔ اعتماد و رأی")

	# ── سناریو ۳: baseline ثبت می‌شود + has_promise ──
	var state3: Dictionary = GS.state.duplicate(true)
	state3 = root.get_node("ParliamentManager").ensure(state3)
	state3["parliament"]["next_election_turn"] = 5  # در ۶ نوبت آخر (قابل ثبت) ولی انتخابات فوری نه
	var r4 = GE.tick(state3, GS.version, 0, [CS.create_campaign_promise("green_turn")])
	if r4.success:
		var promises: Array = r4.state.get("parliament", {}).get("promises", [])
		if promises.is_empty() or not (promises[0] is Dictionary) or not promises[0].has("baseline"):
			fails.append("وعده baseline شاخص را ثبت نمی‌کند")
		else:
			print("✓ وعده baseline ثبت می‌کند: %s" % str(promises[0].get("baseline", "?")))
		if not root.get_node("ParliamentManager").has_promise(promises, "green_turn"):
			fails.append("has_promise وعدهٔ موجود را نمی‌یابد")
		else:
			print("✓ has_promise با آرایهٔ دیکشنری کار می‌کند")
	else:
		fails.append("ثبت وعدهٔ green_turn ناموفق")

	if fails.is_empty():
		print("\n=== ✅ PROMISE ACCOUNTABILITY TEST PASSED ===")
		quit(0)
	else:
		print("\n=== ❌ PROMISE ACCOUNTABILITY FAILED (%d) ===" % fails.size())
		for f in fails:
			print("  - " + f)
		quit(1)
