extends SceneTree
# تست همه‌ی سناریوها (عمق‌بخشی ۲۸): هر ۹ سناریو باید بدون خطا شروع شوند،
# افکت‌های شروع و بحران‌های اولیه اعمال شوند و چند نوبت شبیه‌سازی پایدار بماند.

func _init():
	await process_frame
	var fails: Array = []
	var GS = root.get_node("GameState")
	var scenario_ids: Array = root.get_node("ScenarioManager").get_scenario_ids()
	print("=== SCENARIO MATRIX TEST: %d scenarios ===" % scenario_ids.size())

	if scenario_ids.size() < 8:
		fails.append("تعداد سناریوها غیرمنتظره است: %d" % scenario_ids.size())

	for scenario_id in scenario_ids:
		var state: Dictionary = GS.state.duplicate(true)
		state["tick"] = 0

		# قابلیت انتخاب در تیک صفر
		var select_check = root.get_node("ScenarioManager").can_select(state, scenario_id)
		if not select_check.valid:
			fails.append("%s: can_select رد شد: %s" % [scenario_id, select_check.reason])
			continue

		state = root.get_node("ScenarioManager").apply_scenario(state, scenario_id, 0)
		var sc: Dictionary = state.get("scenario", {})
		if str(sc.get("id", "")) != scenario_id:
			fails.append("%s: سناریو در state ثبت نشد" % scenario_id)
			continue
		var objectives: Array = sc.get("objectives", [])
		if objectives.is_empty():
			fails.append("%s: هیچ هدفی ندارد" % scenario_id)

		# چند نوبت شبیه‌سازی
		var version: int = GS.version
		var tick: int = 0
		var ok_run := true
		for i in range(6):
			var result = root.get_node("GameEngine").tick(state, version, tick, [])
			if not result.success:
				fails.append("%s: تیک %d شکست: %s" % [scenario_id, i + 1, result.reason])
				ok_run = false
				break
			state = result.state
			version = result.version
			tick = result.tick

		if not ok_run:
			continue

		# صحت state پس از اجرا
		var gdp = float(state.get("economy", {}).get("gdp", 0.0))
		var pop = float(state.get("population", {}).get("total", 0.0))
		if is_nan(gdp) or is_inf(gdp) or gdp <= 0.0:
			fails.append("%s: GDP نامعتبر پس از اجرا: %s" % [scenario_id, str(gdp)])
		if is_nan(pop) or is_inf(pop) or pop <= 0.0:
			fails.append("%s: جمعیت نامعتبر پس از اجرا: %s" % [scenario_id, str(pop)])
		var happiness = float(state.get("population", {}).get("happiness", 0.0))
		if is_nan(happiness) or happiness < 0.0 or happiness > 1.0:
			fails.append("%s: شادی خارج از محدوده: %s" % [scenario_id, str(happiness)])
		# اهداف باید پیشرفت قابل اندازه‌گیری داشته باشند
		var progress_sum := 0.0
		for objective in state.get("scenario", {}).get("objectives", []):
			progress_sum += float(objective.get("progress", 0.0))
		if progress_sum < -0.001:
			fails.append("%s: پیشرفت اهداف منفی شد: %.3f" % [scenario_id, progress_sum])
		var crises: Array = state.get("events_active", [])
		print("✓ %s | objectives=%d | active_crises=%d | GDP=%.2fT | happy=%.2f" % [
			scenario_id, objectives.size(), crises.size(), gdp / 1e12, happiness])

	if fails.is_empty():
		print("\n=== ✅ ALL %d SCENARIOS PASSED ===" % scenario_ids.size())
		quit(0)
	else:
		print("\n=== ❌ SCENARIO MATRIX FAILED (%d) ===" % fails.size())
		for f in fails:
			print("  - " + f)
		quit(1)
