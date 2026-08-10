extends BaseAI
# هوش زیرساخت - ۳.۱۵.۷ - دترمینستیک و اتمی

func decide(state: Dictionary, tick: int) -> Array:
	var infra = state.get("infrastructure", {})
	var econ = state.get("economy", {})
	var cmds = []

	# کیفیت یا پوشش پایین → بودجه بیشتر
	var quality = infra.get("quality", 0.55)
	var coverage = infra.get("coverage", 0.70)
	if quality < 0.45 or coverage < 0.55:
		var allocs = econ.get("budget_allocations", {}).duplicate()
		if allocs.get("زیرساخت", 0.18) < 0.30 and allocs.get("ذخیره", 0.22) > 0.12:
			allocs["زیرساخت"] = allocs.get("زیرساخت", 0.18) + 0.03
			allocs["ذخیره"] = allocs.get("ذخیره", 0.22) - 0.03
			var t = 0.0
			for v in allocs.values():
				t += v
			for k in allocs.keys():
				allocs[k] /= t
			cmds.append(GameCommand.create_budget_allocate(allocs))

	return cmds

func evaluate(state: Dictionary) -> float:
	var infra = state.get("infrastructure", {})
	return infra.get("quality", 0.55) * 0.4 + infra.get("coverage", 0.70) * 0.4 + infra.get("capacity", 0.60) * 0.2
