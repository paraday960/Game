extends BaseAI
# هوش جنگ مسیرهای تجاری - ۳.۸۰ - حفاظت از کریدورها، مقابله با دزدی دریایی، اسکورت

func decide(state: Dictionary, tick: int) -> Array:
	var warfare = state.get("trade_route_warfare", {})
	var econ = state.get("economy", {})
	var mil = state.get("military", {})
	var cmds = []

	var piracy = warfare.get("piracy_level", 0.10)
	var disrupted = warfare.get("disrupted_volume", 0.0)
	var blockade_eff = warfare.get("blockade_effectiveness", 0.0)
	var econ_damage = warfare.get("economic_damage", 0.0)

	# دزدی دریایی بالا → اسکورت و گشت دریایی
	if piracy > 0.35:
		var cmd = build_budget_command(state, "امنیت")
		if cmd != null:
			cmds.append(cmd)
		if piracy > 0.50 and not state.get("policies",{}).get("active",{}).has("naval_patrol"):
			cmds.append(GameCommand.create_policy_change("naval_patrol", true))

	# حجم مختل بالا → حفاظت از مسیرها
	if disrupted > 3.0:
		var protect_cmd = build_budget_command(state, "زیرساخت")
		if protect_cmd != null:
			cmds.append(protect_cmd)

	# محاصره دشمن موثر → ضد محاصره، دیپلماسی و اسکورت
	if blockade_eff > 0.40:
		if state.get("diplomacy",{}).get("influence",40.0) > 50.0:
			# تلاش دیپلماتیک برای شکست محاصره
			var allies = state.get("world",{}).get("alliances",[])
			if allies.size() > 0:
				cmds.append(GameCommand.create_diplomacy_action(str(allies[0]), "improve_relations"))

	# خسارت اقتصادی بالا → سرمایه‌گذاری در مسیرهای جایگزین
	if econ_damage > 5e9 and econ.get("budget_allocations",{}).get("زیرساخت",0.18) < 0.22:
		var allocs = econ.get("budget_allocations",{}).duplicate()
		if allocs.get("ذخیره",0.22) > 0.12:
			allocs["زیرساخت"] = allocs.get("زیرساخت",0.18) + 0.03
			allocs["ذخیره"] = allocs.get("ذخیره",0.22) - 0.03
			var total = 0.0
			for v in allocs.values(): total += v
			for k in allocs.keys(): allocs[k] /= total
			cmds.append(GameCommand.create_budget_allocate(allocs))

	if cmds.is_empty():
		return super.decide(state, tick)
	return cmds

func evaluate(state: Dictionary) -> float:
	var warfare = state.get("trade_route_warfare", {})
	var piracy = warfare.get("piracy_level", 0.10)
	var disrupted = warfare.get("disrupted_volume", 0.0)
	# سلامت = 1 - (دزدی + اختلال)
	var health = clamp(1.0 - piracy*0.6 - disrupted*0.05, 0.0, 1.0)
	return health
