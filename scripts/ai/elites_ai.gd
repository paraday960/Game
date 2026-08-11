extends BaseAI
# هوش تخصصی elites - فرار نخبگان - تحلیل دترمینستیک، بودجه‌محور، اقدام چندسطحی

func decide(state: Dictionary, tick: int) -> Array:
	var elites = state.get("elites_detail", {})
	var econ = state.get("economy", {})
	var cmds = []

	# تشخیص اولیه از BaseAI
	var diag = diagnose(state)
	var urgency = diag.get("urgency", 0.0)
	var metric_val = elites.get("brain_drain", 0.25)

	# شرط اضطراری بر اساس شاخص اصلی
	if elites.get("brain_drain", 0.25) > 0.25:
		var budget_cmd = build_budget_command(state, "فناوری")
		if budget_cmd != null:
			cmds.append(budget_cmd)
		if elites.get("satisfaction",0.55) < 0.40:
			cmds.append(GameCommand.create_policy_change("research_funding_boost", true))

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
