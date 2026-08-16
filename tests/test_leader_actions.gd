extends SceneTree
# تست اقدامات فعال رهبر (عمق‌بخشی ۴۷):
# سخنرانی (امیدبخش در بحران → اثر مثبت؛ در رفاه → حرف بی‌عمل)،
# سبک رهبری (اثر ماهانه سراسری)، حضور میدانی (تقویت ۳ ماهه).

func _init():
	await process_frame
	var fails: Array = []
	var GS = root.get_node("GameState")
	var GE = root.get_node("GameEngine")
	var CS = load("res://scripts/core/command.gd")
	var LM = root.get_node("LeaderManager")

	# ── سناریو ۱: سخنرانی امیدبخش در بحران → اثر مثبت (مستقیم، ایزوله) ──
	var state: Dictionary = GS.state.duplicate(true)
	state = LM.ensure(state)
	state["population"]["happiness"] = 0.40  # بحران
	state["politics"]["stability"] = 0.40
	var happy0 := float(state["population"]["happiness"])
	var r = LM.speech(state, "hope", 1)
	if not r.success:
		fails.append("سخنرانی امیدبخش ناموفق: %s" % r.reason)
	else:
		state = r.state
		var happy1 := float(state["population"]["happiness"])
		if happy1 <= happy0:
			fails.append("سخنرانی امیدبخش در بحران اثر نکرد (%.2f → %.2f)" % [happy0, happy1])
		else:
			print("✓ سخنرانی امیدبخش در بحران: شادی %.2f → %.2f" % [happy0, happy1])

	# ── سناریو ۲: سخنرانی امیدبخش در رفاه → حرف بی‌عمل (اعتماد کم می‌شود) ──
	var state2: Dictionary = GS.state.duplicate(true)
	state2 = LM.ensure(state2)
	state2["population"]["happiness"] = 0.75  # رفاه
	state2["politics"]["stability"] = 0.70
	var trust0 := float(state2["politics"]["trust"])
	var r2 = LM.speech(state2, "hope", 2)
	if r2.success:
		state2 = r2.state
		var trust1 := float(state2["politics"]["trust"])
		if trust1 >= trust0:
			fails.append("حرف بی‌عمل در رفاه اعتماد را نسوزاند")
		else:
			print("✓ سخنرانی بی‌محتوا در رفاه: اعتماد کاهش یافت (حرف بی‌عمل)")
	else:
		fails.append("سخنرانی دوم ناموفق")

	# ── سناریو ۳: سبک رهبری تکنوکرات → ظرفیت پژوهش ↑ (کانال درست) ──
	var state3: Dictionary = GS.state.duplicate(true)
	state3 = LM.ensure(state3)
	var r3 = GE.tick(state3, GS.version, 0, [CS.create_leader_action("style", "technocrat")])
	if not r3.success:
		fails.append("انتخاب سبک ناموفق: %s" % r3.reason)
	else:
		state3 = r3.state
		var v3: int = r3.version; var t3: int = r3.tick
		var sci0 := float(state3.get("elites_detail", {}).get("scientific", 10000.0))
		var r4 = GE.tick(state3, v3, t3, [])
		state3 = r4.state
		var sci1 := float(state3.get("elites_detail", {}).get("scientific", 10000.0))
		if sci1 <= sci0:
			fails.append("سبک تکنوکرات دانشمندان را تقویت نکرد (%.0f → %.0f)" % [sci0, sci1])
		else:
			print("✓ سبک تکنوکرات: دانشمندان %.0f → %.0f" % [sci0, sci1])

	# ── سناریو ۴: حضور میدانی → تقویت ۳ ماهه ──
	var state4: Dictionary = GS.state.duplicate(true)
	state4 = LM.ensure(state4)
	var r5 = GE.tick(state4, GS.version, 0, [CS.create_leader_action("presence")])
	if not r5.success:
		fails.append("حضور میدانی ناموفق: %s" % r5.reason)
	else:
		state4 = r5.state
		if int(state4["leader"].get("presence_boost_until", 0)) <= int(state4.get("tick", 0)):
			fails.append("حضور میدانی اثر ۳ ماهه ثبت نکرد")
		else:
			print("✓ حضور میدانی: تقویت ۳ ماهه فعال شد (تا نوبت %s)" % str(state4["leader"]["presence_boost_until"]))

	# ── سناریو ۵: کولداون سخنرانی ──
	var state5: Dictionary = GS.state.duplicate(true)
	state5 = LM.ensure(state5)
	var r6 = GE.tick(state5, GS.version, 0, [CS.create_leader_action("speech", "unite")])
	var r7 = GE.tick(r6.state, r6.version, r6.tick, [CS.create_leader_action("speech", "unite")])
	if r7.success:
		fails.append("سخنرانی دوم در دورهٔ کولداون پذیرفته شد")
	else:
		print("✓ کولداون سخنرانی کار می‌کند")

	if fails.is_empty():
		print("\n=== ✅ LEADER ACTIONS TEST PASSED ===")
		quit(0)
	else:
		print("\n=== ❌ LEADER ACTIONS FAILED (%d) ===" % fails.size())
		for f in fails:
			print("  - " + f)
		quit(1)
