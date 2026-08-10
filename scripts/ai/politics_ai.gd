extends BaseAI
# هوش سیاست و ثبات - ۳.۱۲.۷ - دترمینستیک و اتمی

func decide(state: Dictionary, tick: int) -> Array:
	var politics = state.get("politics", {})
	var pop = state.get("population", {})
	var econ = state.get("economy", {})
	var cmds = []

	# تنش بالا + اعتماد پایین → وضعیت خطرناک - کاهش مالیات برای آرامش
	var tension = politics.get("tension", 0.35)
	var trust = politics.get("trust", 0.55)
	if tension > 0.65 and trust < 0.40:
		var rate = econ.get("tax_rate", 0.20)
		if rate > 0.12:
			cmds.append(GameCommand.create_tax_set(clamp(rate - 0.01, 0.10, 0.40)))

	# فساد بالا → بودجه امنیت برای مبارزه
	if politics.get("corruption", 0.30) > 0.50:
		var allocs = econ.get("budget_allocations", {}).duplicate()
		if allocs.get("ذخیره", 0.22) > 0.12:
			allocs["امنیت"] = allocs.get("امنیت", 0.05) + 0.02
			allocs["ذخیره"] = allocs.get("ذخیره", 0.22) - 0.02
			var total = 0.0
			for v in allocs.values():
				total += v
			for k in allocs.keys():
				allocs[k] /= total
			cmds.append(GameCommand.create_budget_allocate(allocs))

	# شادی بحرانی → تقویت رفاه
	if pop.get("happiness", 0.60) < 0.40:
		var allocs2 = econ.get("budget_allocations", {}).duplicate()
		if allocs2.get("رفاه", 0.15) < 0.25 and allocs2.get("ذخیره", 0.22) > 0.10:
			allocs2["رفاه"] = allocs2.get("رفاه", 0.15) + 0.03
			allocs2["ذخیره"] = allocs2.get("ذخیره", 0.22) - 0.03
			var t2 = 0.0
			for v in allocs2.values():
				t2 += v
			for k in allocs2.keys():
				allocs2[k] /= t2
			cmds.append(GameCommand.create_budget_allocate(allocs2))

	return cmds

func evaluate(state: Dictionary) -> float:
	var politics = state.get("politics", {})
	return politics.get("stability", 0.60) * 0.5 + politics.get("legitimacy", 0.58) * 0.3 + (1.0 - politics.get("corruption", 0.30)) * 0.2
