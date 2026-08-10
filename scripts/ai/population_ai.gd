extends BaseAI
# هوش جمعیت و دموگرافی - ۳.۱۱.۷ - دترمینستیک و اتمی

func decide(state: Dictionary, tick: int) -> Array:
	var pop = state.get("population", {})
	var econ = state.get("economy", {})
	var cmds = []

	# نرخ مرگ غیرطبیعی → بودجه بهداشت
	if pop.get("death_rate", 8.0) > 12.0:
		var allocs = econ.get("budget_allocations", {}).duplicate()
		if allocs.get("بهداشت", 0.10) < 0.20 and allocs.get("ذخیره", 0.22) > 0.10:
			allocs["بهداشت"] = allocs.get("بهداشت", 0.10) + 0.03
			allocs["ذخیره"] = allocs.get("ذخیره", 0.22) - 0.03
			var t = 0.0
			for v in allocs.values():
				t += v
			for k in allocs.keys():
				allocs[k] /= t
			cmds.append(GameCommand.create_budget_allocate(allocs))

	return cmds

func evaluate(state: Dictionary) -> float:
	var pop = state.get("population", {})
	return pop.get("happiness", 0.60) * 0.4 + pop.get("satisfaction", 0.62) * 0.3 + clamp(pop.get("growth_rate", 0.012) * 30.0, 0.0, 1.0) * 0.3
