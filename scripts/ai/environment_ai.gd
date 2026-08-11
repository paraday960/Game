extends BaseAI
# هوش تخصصی environment - کیفیت محیط‌زیست - تحلیل دترمینستیک، بودجه‌محور، اقدام چندسطحی

func decide(state: Dictionary, tick: int) -> Array:
	var env = state.get("environment", {})
	var econ = state.get("economy", {})
	var cmds = []

	# تشخیص اولیه از BaseAI
	var diag = diagnose(state)
	var urgency = diag.get("urgency", 0.0)
	var metric_val = env.get("air_quality", 0.65)

	# شرط اضطراری بر اساس شاخص اصلی
	if env.get("air_quality", 0.65) < 0.65:
		var budget_cmd = build_budget_command(state, "محیط")
		if budget_cmd != null:
			cmds.append(budget_cmd)
		if env.get("carbon",0.6) > 0.65:
			cmds.append(GameCommand.create_policy_change("carbon_tax", true))

	# اگر هیچ بحران فوری نیست اما سلامت پایین است، باز هم بودجه را تنظیم کن
	if cmds.is_empty() and urgency > 0.18:
		var fallback = build_budget_command(state, diag.get("budget_key", "محیط"))
		if fallback != null:
			cmds.append(fallback)

	# در صورت عدم نیاز به اقدام، تصمیم پایه را برگردان
	if cmds.is_empty():
		return super.decide(state, tick)
	return cmds

func evaluate(state: Dictionary) -> float:
	var d = diagnose(state)
	return float(d.get("health", 0.5))
