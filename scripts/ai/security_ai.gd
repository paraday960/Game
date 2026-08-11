extends BaseAI
# هوش تخصصی security - امنیت عمومی - تحلیل دترمینستیک، بودجه‌محور، اقدام چندسطحی

func decide(state: Dictionary, tick: int) -> Array:
	var sec = state.get("security", {})
	var econ = state.get("economy", {})
	var cmds = []

	# تشخیص اولیه از BaseAI
	var diag = diagnose(state)
	var urgency = diag.get("urgency", 0.0)
	var metric_val = sec.get("public_security", 0.65)

	# شرط اضطراری بر اساس شاخص اصلی
	if sec.get("public_security", 0.65) < 0.65:
		var budget_cmd = build_budget_command(state, "امنیت")
		if budget_cmd != null:
			cmds.append(budget_cmd)
		if sec.get("police_presence",0.5) < 0.40:
			cmds.append(GameCommand.create_policy_change("police_hiring", true))

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
