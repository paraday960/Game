extends BaseAI
# هوش تخصصی prison - تراکم زندان - تحلیل دترمینستیک، بودجه‌محور، اقدام چندسطحی

func decide(state: Dictionary, tick: int) -> Array:
	var pris = state.get("prison", {})
	var econ = state.get("economy", {})
	var cmds = []

	# تشخیص اولیه از BaseAI
	var diag = diagnose(state)
	var urgency = diag.get("urgency", 0.0)
	var metric_val = pris.get("overcrowding", 0.8)

	# شرط اضطراری بر اساس شاخص اصلی
	if pris.get("overcrowding", 0.8) > 0.8:
		var budget_cmd = build_budget_command(state, "امنیت")
		if budget_cmd != null:
			cmds.append(budget_cmd)
		if pris.get("rehabilitation",0.40) < 0.35:
			cmds.append(GameCommand.create_policy_change("rehabilitation_program", true))

	# اگر هیچ بحران فوری نیست اما سلامت پایین است، باز هم بودجه را تنظیم کن
	if cmds.is_empty() and urgency > 0.18:
		var fallback = build_budget_command(state, diag.get("budget_key", "امنیت"))
		if fallback != null:
			cmds.append(fallback)

	# در صورت عدم نیاز به اقدام، تصمیم پایه را برگردان
	if cmds.is_empty():
		return super.decide(state, tick)
	return cmds

func evaluate(state: Dictionary) -> float:
	var d = diagnose(state)
	return float(d.get("health", 0.5))
