extends BaseAI
# هوش تخصصی human_states - فشار روانی - تحلیل دترمینستیک، بودجه‌محور، اقدام چندسطحی

func decide(state: Dictionary, tick: int) -> Array:
	var hs = state.get("human_states", {})
	var econ = state.get("economy", {})
	var cmds = []

	# تشخیص اولیه از BaseAI
	var diag = diagnose(state)
	var urgency = diag.get("urgency", 0.0)
	var metric_val = hs.get("stress", 0.4)

	# شرط اضطراری بر اساس شاخص اصلی
	if hs.get("stress", 0.4) > 0.4:
		var budget_cmd = build_budget_command(state, "بهداشت")
		if budget_cmd != null:
			cmds.append(budget_cmd)
		if hs.get("hope",0.60) < 0.35:
			cmds.append(GameCommand.create_policy_change("mental_health_program", true))

	# اگر هیچ بحران فوری نیست اما سلامت پایین است، باز هم بودجه را تنظیم کن
	if cmds.is_empty() and urgency > 0.18:
		var fallback = build_budget_command(state, diag.get("budget_key", "بهداشت"))
		if fallback != null:
			cmds.append(fallback)

	# در صورت عدم نیاز به اقدام، تصمیم پایه را برگردان
	if cmds.is_empty():
		return super.decide(state, tick)
	return cmds

func evaluate(state: Dictionary) -> float:
	var d = diagnose(state)
	return float(d.get("health", 0.5))
