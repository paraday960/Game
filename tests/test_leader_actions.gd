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

	# ── سناریو ۶: بازدید سرزده → فساد کم می‌شود ──
	var state6: Dictionary = GS.state.duplicate(true)
	state6 = LM.ensure(state6)
	state6["politics"]["corruption"] = 0.60
	var corrupt0 := float(state6["politics"]["corruption"])
	var r8 = GE.tick(state6, GS.version, 0, [CS.create_leader_action("inspection")])
	if not r8.success:
		fails.append("بازدید سرزده ناموفق: %s" % r8.reason)
	else:
		state6 = r8.state
		var corrupt1 := float(state6["politics"]["corruption"])
		if corrupt1 >= corrupt0:
			fails.append("بازدید سرزده فساد را کم نکرد (%.2f → %.2f)" % [corrupt0, corrupt1])
		else:
			print("✓ بازدید سرزده: فساد %.2f → %.2f" % [corrupt0, corrupt1])

	# ── سناریو ۷: عفو عمومی رهبر → جمعیت زندان کم می‌شود (کانال واقعی) ──
	var state7: Dictionary = GS.state.duplicate(true)
	state7 = LM.ensure(state7)
	var prison0 := float(state7.get("prison", {}).get("population", 80000.0))
	var r9 = GE.tick(state7, GS.version, 0, [CS.create_leader_action("amnesty")])
	if not r9.success:
		fails.append("عفو عمومی ناموفق: %s" % r9.reason)
	else:
		state7 = r9.state
		var prison1 := float(state7.get("prison", {}).get("population", 80000.0))
		if prison1 >= prison0:
			fails.append("عفو عمومی جمعیت زندان را کم نکرد (%.0f → %.0f)" % [prison0, prison1])
		else:
			print("✓ عفو عمومی رهبر: زندانیان %.0f → %.0f" % [prison0, prison1])

	# ── سناریو ۸: نشان ملی → تکریم کهنه‌سربازان از کانال recognition ──
	var state8: Dictionary = GS.state.duplicate(true)
	state8 = LM.ensure(state8)
	var rec0 := float(state8.get("veterans", {}).get("recognition", 0.7))
	var r10 = GE.tick(state8, GS.version, 0, [CS.create_leader_action("honors")])
	if not r10.success:
		fails.append("نشان ملی ناموفق: %s" % r10.reason)
	else:
		state8 = r10.state
		var rec1 := float(state8.get("veterans", {}).get("recognition", 0.7))
		if rec1 <= rec0:
			fails.append("نشان ملی تکریم کهنه‌سربازان را بالا نبرد (%.2f → %.2f)" % [rec0, rec1])
		else:
			print("✓ نشان ملی: تکریم %.2f → %.2f" % [rec0, rec1])

	# ── سناریو ۹: سخنرانی سازمان ملل — بدون عضویت رد می‌شود؛ با عضویت اثر می‌گذارد ──
	var state9: Dictionary = GS.state.duplicate(true)
	state9 = LM.ensure(state9)
	if not state9.has("intl_orgs"):
		state9["intl_orgs"] = {"memberships": {"سازمان ملل": true, "اوپک": false, "اتحادیه منطقه‌ای": true},
			"next_vote_turn": 4, "pending_vote": {}, "votes_history": []}
	state9["intl_orgs"]["memberships"]["سازمان ملل"] = false
	var r11 = GE.tick(state9, GS.version, 0, [CS.create_leader_action("un_address")])
	if r11.success:
		fails.append("سخنرانی سازمان ملل بدون عضویت پذیرفته شد")
	else:
		print("✓ سخنرانی سازمان ملل بدون عضویت رد می‌شود")
	var state9b: Dictionary = GS.state.duplicate(true)
	state9b = LM.ensure(state9b)
	if not state9b.has("intl_orgs"):
		state9b["intl_orgs"] = {"memberships": {"سازمان ملل": true, "اوپک": false, "اتحادیه منطقه‌ای": true},
			"next_vote_turn": 4, "pending_vote": {}, "votes_history": []}
	state9b["intl_orgs"]["memberships"]["سازمان ملل"] = true
	var rel0 := 0.0
	for cid in state9b.get("diplomacy", {}).get("relations", {}).keys():
		rel0 += float(state9b["diplomacy"]["relations"][cid])
	var r12 = GE.tick(state9b, GS.version, 0, [CS.create_leader_action("un_address")])
	if not r12.success:
		fails.append("سخنرانی سازمان ملل با عضویت ناموفق: %s" % r12.reason)
	else:
		state9b = r12.state
		var rel1 := 0.0
		for cid in state9b.get("diplomacy", {}).get("relations", {}).keys():
			rel1 += float(state9b["diplomacy"]["relations"][cid])
		if rel1 <= rel0:
			fails.append("سخنرانی سازمان ملل روابط را گرم نکرد (%.0f → %.0f)" % [rel0, rel1])
		else:
			print("✓ سخنرانی سازمان ملل: مجموع روابط %.0f → %.0f" % [rel0, rel1])

	# ── سناریو ۱۰: گفتگوی تلویزیونی — رسانهٔ آزاد اعتماد می‌سازد، مهارشده پروپاگاندا ──
	var state10: Dictionary = GS.state.duplicate(true)
	state10 = LM.ensure(state10)
	state10["culture"]["media_freedom"] = 0.60
	var trust0 := float(state10.get("media", {}).get("trust", 0.55))
	var r13 = GE.tick(state10, GS.version, 0, [CS.create_leader_action("interview")])
	if not r13.success:
		fails.append("گفتگوی تلویزیونی ناموفق: %s" % r13.reason)
	else:
		state10 = r13.state
		var trust1 := float(state10.get("media", {}).get("trust", 0.55))
		if trust1 <= trust0:
			fails.append("گفتگو در رسانهٔ آزاد اعتماد را بالا نبرد")
		else:
			print("✓ گفتگو در رسانهٔ آزاد: اعتماد %.2f → %.2f" % [trust0, trust1])
	var state10b: Dictionary = GS.state.duplicate(true)
	state10b = LM.ensure(state10b)
	state10b["culture"]["media_freedom"] = 0.20
	var trust0b := float(state10b.get("media", {}).get("trust", 0.55))
	var r14 = GE.tick(state10b, GS.version, 0, [CS.create_leader_action("interview")])
	if not r14.success:
		fails.append("گفتگو در رسانهٔ مهارشده ناموفق: %s" % r14.reason)
	else:
		state10b = r14.state
		var trust1b := float(state10b.get("media", {}).get("trust", 0.55))
		if trust1b >= trust0b:
			fails.append("گفتگو زیر رسانهٔ مهارشده اعتماد را نسوزاند (پروپاگاندا)")
		else:
			print("✓ گفتگو زیر رسانهٔ مهارشده: اعتماد %.2f → %.2f (پروپاگاندا)" % [trust0b, trust1b])

	# ── سناریو ۱۱: دیدار سرمایه‌داران → اعتماد سرمایه‌گذاران بالا ──
	var state11: Dictionary = GS.state.duplicate(true)
	state11 = LM.ensure(state11)
	var conf0 := float(state11.get("economy", {}).get("cycle", {}).get("confidence", 55.0))
	var r15 = GE.tick(state11, GS.version, 0, [CS.create_leader_action("summit")])
	if not r15.success:
		fails.append("دیدار سرمایه‌داران ناموفق: %s" % r15.reason)
	else:
		state11 = r15.state
		var conf1 := float(state11.get("economy", {}).get("cycle", {}).get("confidence", 55.0))
		if conf1 <= conf0:
			fails.append("دیدار سرمایه‌داران اعتماد را بالا نبرد (%.1f → %.1f)" % [conf0, conf1])
		else:
			print("✓ دیدار سرمایه‌داران: اعتماد %.1f → %.1f" % [conf0, conf1])

	# ── سناریو ۱۲: گفتگوی ملی اقوام → تنش هویتی کم می‌شود ──
	var state12: Dictionary = GS.state.duplicate(true)
	state12 = LM.ensure(state12)
	state12["ethnicity"]["tension"] = 0.50
	var ten0 := float(state12["ethnicity"]["tension"])
	var r16 = GE.tick(state12, GS.version, 0, [CS.create_leader_action("dialogue")])
	if not r16.success:
		fails.append("گفتگوی ملی ناموفق: %s" % r16.reason)
	else:
		state12 = r16.state
		var ten1 := float(state12["ethnicity"]["tension"])
		if ten1 >= ten0:
			fails.append("گفتگوی ملی تنش قومی را کم نکرد (%.2f → %.2f)" % [ten0, ten1])
		else:
			print("✓ گفتگوی ملی اقوام: تنش %.2f → %.2f" % [ten0, ten1])

	# ── سناریو ۱۳: کولداون بازدید سرزده ──
	var state13: Dictionary = GS.state.duplicate(true)
	state13 = LM.ensure(state13)
	state13["politics"]["corruption"] = 0.60
	var r17 = GE.tick(state13, GS.version, 0, [CS.create_leader_action("inspection")])
	var r18 = GE.tick(r17.state, r17.version, r17.tick, [CS.create_leader_action("inspection")])
	if r18.success:
		fails.append("بازدید سرزده دوم در دورهٔ کولداون پذیرفته شد")
	else:
		print("✓ کولداون بازدید سرزده کار می‌کند")

	if fails.is_empty():
		print("\n=== ✅ LEADER ACTIONS TEST PASSED ===")
		quit(0)
	else:
		print("\n=== ❌ LEADER ACTIONS FAILED (%d) ===" % fails.size())
		for f in fails:
			print("  - " + f)
		quit(1)
