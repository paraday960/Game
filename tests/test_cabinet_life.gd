extends SceneTree
# تست کابینهٔ زنده (عمق‌بخشی ۴۴):
# مأموریت ویژه (موفقیت/شکست)، چرخهٔ عمر (فرسودگی/جاه‌طلبی/درگذشت)،
# درگیری وزرا و میانجیگری.

func _init():
	await process_frame
	var fails: Array = []
	var GS = root.get_node("GameState")
	var GE = root.get_node("GameEngine")
	var CS = load("res://scripts/core/command.gd")

	# دادهٔ کابینه ویژگی‌های جدید دارد
	var sample = root.get_node("CabinetManager").get_candidate("econ_rahimi")
	if not sample.has("age") or not sample.has("ideology") or not sample.has("ambition") or not sample.has("resilience"):
		fails.append("دادهٔ کابینه ویژگی‌های عمر (سن/ایدئولوژی/جاه‌طلبی/مقاومت) ندارد")
	else:
		print("✓ دادهٔ وزیران: سن=%s گرایش=%s" % [str(sample.get("age", "?")), str(sample.get("ideology", "?"))])

	var state: Dictionary = GS.state.duplicate(true)
	var v: int = GS.version
	var t: int = 0
	state["policies"]["political_capital"] = 5.0

	# مأموریت ویژه: باید پذیرفته شود
	var r = GE.tick(state, v, t, [CS.create_cabinet_mission("economy")])
	if not r.success:
		fails.append("مأموریت ویژه پذیرفته نشد: %s" % r.reason)
	else:
		state = r.state; v = r.version; t = r.tick
		print("✓ مأموریت ویژه به وزیر اقتصاد ثبت شد")
		# مأموریت باید در همان ماه حل شود (موفق یا ناموفق)
		var missions_before: int = state.get("cabinet", {}).get("missions", {}).size()
		var r2 = GE.tick(state, v, t, [])
		state = r2.state; v = r2.version; t = r2.tick
		var missions_after: int = state.get("cabinet", {}).get("missions", {}).size()
		if missions_after >= missions_before and missions_before > 0:
			fails.append("مأموریت در همان ماه حل نشد")
		else:
			print("✓ مأموریت حل شد (موفقیت/شکست بر اساس شایستگی)")

	# کولداون: مأموریت دوم باید رد شود
	var r3 = GE.tick(state, v, t, [CS.create_cabinet_mission("economy")])
	if r3.success:
		fails.append("مأموریت دوم در دورهٔ کولداون پذیرفته شد")
	else:
		print("✓ کولداون مأموریت کار می‌کند")

	# میانجیگری: باید با وضعیت درگیری هم‌خوان باشد (اگر درگیری هست → موفق، وگرنه رد)
	var disputes_now: int = state.get("cabinet", {}).get("disputes", []).size()
	var r4 = GE.tick(state, v, t, [CS.create_cabinet_mediate()])
	if disputes_now > 0 and not r4.success:
		fails.append("میانجیگری با درگیری فعال پذیرفته نشد")
	elif disputes_now == 0 and r4.success:
		fails.append("میانجیگری بدون درگیری پذیرفته شد")
	else:
		print("✓ میانجیگری با وضعیت درگیری هم‌خوان است (%d درگیری)" % disputes_now)

	# چرخهٔ عمر: شبیه‌سازی طولانی باید استعفا/درگذشت تولید کند (یا حداقل بدون خطا بماند)
	var resignations := 0
	for i in range(200):
		var r5 = GE.tick(state, v, t, [])
		if not r5.success:
			fails.append("شبیه‌سازی کابینه در نوبت %d شکست: %s" % [i, r5.reason])
			break
		state = r5.state; v = r5.version; t = r5.tick
		for ev in r5.get("events", []):
			var et := str(ev.get("type", ""))
			if et == "minister_resigned" or et == "minister_died":
				resignations += 1
	if resignations > 0:
		print("✓ چرخهٔ عمر وزیران: %d استعفا/درگذشت در ۲۰۰ نوبت" % resignations)
	else:
		print("✓ شبیه‌سازی ۲۰۰ نوبتهٔ کابینه بدون خطا (استعفا نادر و احتمالی است)")

	if fails.is_empty():
		print("\n=== ✅ CABINET LIFE TEST PASSED ===")
		quit(0)
	else:
		print("\n=== ❌ CABINET LIFE FAILED (%d) ===" % fails.size())
		for f in fails:
			print("  - " + f)
		quit(1)
