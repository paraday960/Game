extends BaseAI
# هوش تخصصی private_sector - فضای کسب‌وکار - تحلیل دترمینستیک، بودجه‌محور، اقدام چندسطحی

func decide(state: Dictionary, tick: int) -> Array:
	var priv = state.get("private_sector", {})
	var econ = state.get("economy", {})
	var cmds = []

	# تشخیص اولیه از BaseAI
	var diag = diagnose(state)
	var urgency = diag.get("urgency", 0.0)
	var metric_val = priv.get("business_climate", 0.55)

	# شرط اضطراری بر اساس شاخص اصلی
	if priv.get("business_climate", 0.55) < 0.55:
		var budget_cmd = build_budget_command(state, "فناوری")
		if budget_cmd != null:
			cmds.append(budget_cmd)
		if priv.get("informal_economy",0.25) > 0.40:
			cmds.append(GameCommand.create_policy_change("formalization_incentive", true))

	# اگر هیچ بحران فوری نیست اما سلامت پایین است، باز هم بودجه را تنظیم کن
	if cmds.is_empty() and urgency > 0.18:
		var fallback = build_budget_command(state, diag.get("budget_key", "فناوری"))
		if fallback != null:
			cmds.append(fallback)

	# در صورت عدم نیاز به اقدام، تصمیم پایه را برگردان
	if cmds.is_empty():
		return super.decide(state, tick)
	return cmds

func evaluate(state: Dictionary) -> float:
	var d = diagnose(state)
	return float(d.get("health", 0.5))
