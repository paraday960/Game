extends BaseAI
# هوش سوخت و انرژی - ۳.۴۶ - دترمینستیک و اتمی

func decide(state: Dictionary, tick: int) -> Array:
	var f = state.get("fuel_stations", {})
	var res = state.get("resources", {})
	var econ = state.get("economy", {})
	var cmds = []

	# ذخیره سوخت بحرانی → بودجه زیرساخت انرژی
	if f.get("storage_days", 15.0) < 7.0:
		var allocs = econ.get("budget_allocations", {}).duplicate()
		if allocs.get("ذخیره", 0.22) > 0.12:
			allocs["زیرساخت"] = allocs.get("زیرساخت", 0.18) + 0.03
			allocs["ذخیره"] = allocs.get("ذخیره", 0.22) - 0.03
			var t = 0.0
			for v in allocs.values():
				t += v
			for k in allocs.keys():
				allocs[k] /= t
			cmds.append(GameCommand.create_budget_allocate(allocs))

	# قاچاق سوخت بالا → پایش (با بودجه امنیت در آینده)
	if f.get("smuggling", 0.15) > 0.40:
		pass

	# بحران برق قریبالوقوع - اگر هنوز فرمانی ندادیم
	var electricity = res.get("inventory", {}).get("برق", 100.0)
	if electricity < 25.0 and cmds.is_empty():
		pass  # آینده: فرمان سهمیه‌بندی برق

	return cmds

func evaluate(state: Dictionary) -> float:
	var f = state.get("fuel_stations", {})
	return f.get("coverage", 0.75) * 0.5 + clamp(f.get("storage_days", 15.0) / 30.0, 0.0, 1.0) * 0.5
