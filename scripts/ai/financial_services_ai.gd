extends BaseAI
# هوش تخصصی financial_services - فراگیری مالی - تحلیل دترمینستیک، بودجه‌محور، اقدام چندسطحی

func decide(state: Dictionary, tick: int) -> Array:
	var fin = state.get("financial_services", {})
	var econ = state.get("economy", {})
	var cmds = []

	# تشخیص اولیه از BaseAI
	var diag = diagnose(state)
	var urgency = diag.get("urgency", 0.0)
	var metric_val = fin.get("financial_inclusion", 0.7)

	# شرط اضطراری بر اساس شاخص اصلی
	if fin.get("financial_inclusion", 0.7) < 0.7:
		var budget_cmd = build_budget_command(state, "ذخیره")
		if budget_cmd != null:
			cmds.append(budget_cmd)
		if fin.get("non_performing_loans",0.08) > 0.15:
			cmds.append(GameCommand.create_policy_change("banking_reform", true))

	# اگر هیچ بحران فوری نیست اما سلامت پایین است، باز هم بودجه را تنظیم کن
	if cmds.is_empty() and urgency > 0.18:
		var fallback = build_budget_command(state, diag.get("budget_key", "ذخیره"))
		if fallback != null:
			cmds.append(fallback)

	# در صورت عدم نیاز به اقدام، تصمیم پایه را برگردان
	if cmds.is_empty():
		return super.decide(state, tick)
	return cmds

func evaluate(state: Dictionary) -> float:
	var d = diagnose(state)
	return float(d.get("health", 0.5))
