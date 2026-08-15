extends SceneTree
# تست میزبانی رویداد بزرگ جهانی (عمق‌بخشی ۴۳):
# نامزدی → میزبانی/میراث، اثر روی گردشگری/قدرت نرم/بدهی، و پایان دوره.

func _init():
	await process_frame
	var fails: Array = []
	var GS = root.get_node("GameState")
	var GE = root.get_node("GameEngine")
	var CS = load("res://scripts/core/command.gd")

	# داده‌ی رویدادها لود شده است
	var ids: Array = root.get_node("MegaEventManager").get_event_ids()
	if ids.size() < 3:
		fails.append("رویدادهای جهانی کم‌اند: %d" % ids.size())
	else:
		print("✓ رویدادها: %s" % ", ".join(ids))

	var state: Dictionary = GS.state.duplicate(true)
	var v: int = GS.version
	var t: int = 0
	# زیرساخت بالا تا شانس موفقیت نامزدی خوب باشد
	state["infrastructure"] = state.get("infrastructure", {})
	state["infrastructure"]["quality"] = 0.9
	state["pro_sports_policy"] = state.get("pro_sports_policy", {})
	state["pro_sports_policy"]["infrastructure"] = 0.8
	state["culture_policy"] = state.get("culture_policy", {})
	state["culture_policy"]["soft_power"] = 80.0

	# نامزدی برای جام جهانی
	var r = GE.tick(state, v, t, [CS.create_mega_event_action("world_cup")])
	if not r.success:
		fails.append("نامزدی ناموفق: %s" % r.reason)
	else:
		state = r.state; v = r.version; t = r.tick
		print("✓ نامزدی ثبت شد — وضعیت: %s" % str(state.get("mega_event", {}).get("status", "?")))

	# باید یا hosting باشد (شانس بالا با زیرساخت ۰.۹) یا حداقل legacy (باخته)
	var me: Dictionary = state.get("mega_event", {})
	var status := str(me.get("status", "none"))
	if status == "none":
		fails.append("نامزدی هیچ اثری نداشت")
	elif status == "hosting":
		print("✓ میزبانی آغاز شد: %s (تا نوبت %s)" % [str(me.get("event_id", "")), str(me.get("ends_turn", 0))])
		# چند نوبت میزبانی: گردشگری/قدرت نرم باید رشد کند و بدهی سنگین شود
		var soft0 := float(state.get("culture_policy", {}).get("soft_power", 40.0))
		var debt0 := float(state.get("economy", {}).get("national_debt", 0.0))
		for i in range(4):
			r = GE.tick(state, v, t, [])
			state = r.state; v = r.version; t = r.tick
		var soft1 := float(state.get("culture_policy", {}).get("soft_power", 40.0))
		var debt1 := float(state.get("economy", {}).get("national_debt", 0.0))
		if soft1 <= soft0:
			fails.append("قدرت نرم در میزبانی رشد نکرد (%.1f → %.1f)" % [soft0, soft1])
		else:
			print("✓ قدرت نرم در میزبانی: %.1f → %.1f" % [soft0, soft1])
		if debt1 <= debt0:
			fails.append("هزینه‌ی میزبانی در بدهی دیده نشد")
		# پایان میزبانی → میراث (مدت میزبانی ۳ ماه؛ صبر می‌کنیم تا وضعیت عوض شود)
		var after := ""
		for i in range(8):
			r = GE.tick(state, v, t, [])
			state = r.state; v = r.version; t = r.tick
			after = str(state.get("mega_event", {}).get("status", "?"))
			if after == "legacy":
				break
		if after != "legacy":
			fails.append("پس از پایان میزبانی وضعیت میراث نشد: %s" % after)
		else:
			print("✓ پس از میزبانی: میراث فعال است")
			# میراث در نهایت به حالت عادی برمی‌گردد
			var back_to_none := false
			for i in range(30):
				r = GE.tick(state, v, t, [])
				state = r.state; v = r.version; t = r.tick
				if str(state.get("mega_event", {}).get("status", "?")) == "none":
					back_to_none = true
					break
			if not back_to_none:
				fails.append("میراث هرگز به حالت عادی برنگشت")
			else:
				print("✓ میراث پایان یافت و کشور به حالت عادی بازگشت")
	elif status == "legacy":
		print("✓ نامزدی ناموفق بود اما هزینه و دورهٔ میراث ثبت شد (شانس دترمینستیک)")

	# فرمان نامعتبر باید رد شود
	var bad = GE.tick(state, v, t, [CS.create_mega_event_action("nonexistent")])
	if bad.success:
		fails.append("فرمان رویداد ناموجود پذیرفته شد")

	if fails.is_empty():
		print("\n=== ✅ MEGA EVENT TEST PASSED ===")
		quit(0)
	else:
		print("\n=== ❌ MEGA EVENT FAILED (%d) ===" % fails.size())
		for f in fails:
			print("  - " + f)
		quit(1)
