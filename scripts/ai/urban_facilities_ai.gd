extends BaseAI
# هوش تأسیسات شهری - ۳.۴۷ - دترمینستیک و اتمی

func decide(state: Dictionary, tick: int) -> Array:
	var u = state.get("urban_facilities", {})
	var econ = state.get("economy", {})
	var cmds = []

	# پوشش آب یا جمع‌آوری زباله بحرانی → بودجه زیرساخت فوری
	if u.get("water_network", 0.75) < 0.65 or u.get("waste_collection", 0.70) < 0.50:
		var allocs = econ.get("budget_allocations", {}).duplicate()
		if allocs.get("ذخیره", 0.22) > 0.10:
			allocs["زیرساخت"] = allocs.get("زیرساخت", 0.18) + 0.04
			allocs["ذخیره"] = allocs.get("ذخیره", 0.22) - 0.04
			var t = 0.0
			for v in allocs.values():
				t += v
			for k in allocs.keys():
				allocs[k] /= t
			cmds.append(GameCommand.create_budget_allocate(allocs))

	return cmds

func evaluate(state: Dictionary) -> float:
	var u = state.get("urban_facilities", {})
	return (u.get("water_network", 0.75) + u.get("electricity_grid", 0.70) + u.get("waste_collection", 0.70)) / 3.0
