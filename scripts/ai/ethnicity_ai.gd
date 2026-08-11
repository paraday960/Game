extends BaseAI
# هوش تخصصی ethnicity - تنش قومی - تحلیل دترمینستیک، بودجه‌محور، اقدام چندسطحی

func decide(state: Dictionary, tick: int) -> Array:
	var eth = state.get("ethnicity", {})
	var econ = state.get("economy", {})
	var cmds = []

	# تشخیص اولیه از BaseAI
	var diag = diagnose(state)
	var urgency = diag.get("urgency", 0.0)
	var metric_val = eth.get("tension", 0.35)

	# شرط اضطراری بر اساس شاخص اصلی
	if eth.get("tension", 0.35) > 0.35:
		var budget_cmd = build_budget_command(state, "رفاه")
		if budget_cmd != null:
			cmds.append(budget_cmd)
		if eth.get("tension",0.30) > 0.60:
			cmds.append(GameCommand.create_policy_change("ethnic_reconciliation", true))

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
