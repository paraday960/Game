extends BaseAI
# هوش تخصصی political_career - شایسته‌سالاری - تحلیل دترمینستیک، بودجه‌محور، اقدام چندسطحی

func decide(state: Dictionary, tick: int) -> Array:
	var pc = state.get("political_career", {})
	var econ = state.get("economy", {})
	var cmds = []

	# تشخیص اولیه از BaseAI
	var diag = diagnose(state)
	var urgency = diag.get("urgency", 0.0)
	var metric_val = pc.get("meritocracy", 0.55)

	# شرط اضطراری بر اساس شاخص اصلی
	if pc.get("meritocracy", 0.55) < 0.55:
		var budget_cmd = build_budget_command(state, "اداره")
		if budget_cmd != null:
			cmds.append(budget_cmd)
		if pc.get("nepotism_index",0.35) > 0.50:
			cmds.append(GameCommand.create_policy_change("meritocracy_law", true))

	# اگر هیچ بحران فوری نیست اما سلامت پایین است، باز هم بودجه را تنظیم کن
	if cmds.is_empty() and urgency > 0.18:
		var fallback = build_budget_command(state, diag.get("budget_key", "اداره"))
		if fallback != null:
			cmds.append(fallback)

	# در صورت عدم نیاز به اقدام، تصمیم پایه را برگردان
	if cmds.is_empty():
		return super.decide(state, tick)
	return cmds

func evaluate(state: Dictionary) -> float:
	var d = diagnose(state)
	return float(d.get("health", 0.5))
