extends BaseAI
# هوش تخصصی foreign_affairs - قدرت نرم - تحلیل دترمینستیک، بودجه‌محور، اقدام چندسطحی

func decide(state: Dictionary, tick: int) -> Array:
	var fa = state.get("foreign_affairs", {})
	var econ = state.get("economy", {})
	var cmds = []

	# تشخیص اولیه از BaseAI
	var diag = diagnose(state)
	var urgency = diag.get("urgency", 0.0)
	var metric_val = fa.get("soft_power", 0.5)

	# شرط اضطراری بر اساس شاخص اصلی
	if fa.get("soft_power", 0.5) < 0.5:
		var budget_cmd = build_budget_command(state, "اداره")
		if budget_cmd != null:
			cmds.append(budget_cmd)
		if fa.get("visa_policy",0.5) < 0.40:
			cmds.append(GameCommand.create_diplomacy_action("neighbors", "visa_liberalization"))

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
