extends BaseAI
# هوش تخصصی citizens - رضایت شهروندان - تحلیل دترمینستیک، بودجه‌محور، اقدام چندسطحی

func decide(state: Dictionary, tick: int) -> Array:
	var citizens = state.get("citizens_detail", {})
	var econ = state.get("economy", {})
	var cmds = []

	# تشخیص اولیه از BaseAI
	var diag = diagnose(state)
	var urgency = diag.get("urgency", 0.0)
	var metric_val = citizens.get("avg_happiness", 0.62)

	# شرط اضطراری بر اساس شاخص اصلی
	if citizens.get("avg_happiness", 0.62) < 0.62:
		var budget_cmd = build_budget_command(state, "رفاه")
		if budget_cmd != null:
			cmds.append(budget_cmd)
		if citizens.get("social_mobility",0.5) < 0.35:
			cmds.append(GameCommand.create_policy_change("education_equity", true))

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
