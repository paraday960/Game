extends BaseAI
# هوش تخصصی welfare - کاهش فقر - تحلیل دترمینستیک، بودجه‌محور، اقدام چندسطحی

func decide(state: Dictionary, tick: int) -> Array:
	var wel = state.get("welfare", {})
	var econ = state.get("economy", {})
	var cmds = []

	# تشخیص اولیه از BaseAI
	var diag = diagnose(state)
	var urgency = diag.get("urgency", 0.0)
	var metric_val = wel.get("poverty", 0.15)

	# شرط اضطراری بر اساس شاخص اصلی
	if wel.get("poverty", 0.15) > 0.15:
		var budget_cmd = build_budget_command(state, "رفاه")
		if budget_cmd != null:
			cmds.append(budget_cmd)
		if wel.get("gini",0.38) > 0.45:
			cmds.append(GameCommand.create_policy_change("progressive_tax", true))

	# اگر هیچ بحران فوری نیست اما سلامت پایین است، باز هم بودجه را تنظیم کن
	if cmds.is_empty() and urgency > 0.18:
		var fallback = build_budget_command(state, diag.get("budget_key", "رفاه"))
		if fallback != null:
			cmds.append(fallback)

	# در صورت عدم نیاز به اقدام، تصمیم پایه را برگردان
	if cmds.is_empty():
		return super.decide(state, tick)
	return cmds

func evaluate(state: Dictionary) -> float:
	var d = diagnose(state)
	return float(d.get("health", 0.5))
