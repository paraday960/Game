extends BaseAI
# هوش تخصصی urban_facilities - پوشش تأسیسات شهری - تحلیل دترمینستیک، بودجه‌محور، اقدام چندسطحی

func decide(state: Dictionary, tick: int) -> Array:
	var uf = state.get("urban_facilities", {})
	var econ = state.get("economy", {})
	var cmds = []

	# تشخیص اولیه از BaseAI
	var diag = diagnose(state)
	var urgency = diag.get("urgency", 0.0)
	var metric_val = uf.get("water_network", 0.7)

	# شرط اضطراری بر اساس شاخص اصلی
	if uf.get("water_network", 0.7) < 0.7:
		var budget_cmd = build_budget_command(state, "زیرساخت")
		if budget_cmd != null:
			cmds.append(budget_cmd)
		if uf.get("waste_recycling",0.15) < 0.20:
			cmds.append(GameCommand.create_policy_change("recycling_program", true))

	# اگر هیچ بحران فوری نیست اما سلامت پایین است، باز هم بودجه را تنظیم کن
	if cmds.is_empty() and urgency > 0.18:
		var fallback = build_budget_command(state, diag.get("budget_key", "زیرساخت"))
		if fallback != null:
			cmds.append(fallback)

	# در صورت عدم نیاز به اقدام، تصمیم پایه را برگردان
	if cmds.is_empty():
		return super.decide(state, tick)
	return cmds

func evaluate(state: Dictionary) -> float:
	var d = diagnose(state)
	return float(d.get("health", 0.5))
