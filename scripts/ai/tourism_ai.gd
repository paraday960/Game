extends BaseAI
# هوش تخصصی tourism - کیفیت گردشگری - تحلیل دترمینستیک، بودجه‌محور، اقدام چندسطحی

func decide(state: Dictionary, tick: int) -> Array:
	var tour = state.get("tourism", {})
	var econ = state.get("economy", {})
	var cmds = []

	# تشخیص اولیه از BaseAI
	var diag = diagnose(state)
	var urgency = diag.get("urgency", 0.0)
	var metric_val = tour.get("service_quality", 0.6)

	# شرط اضطراری بر اساس شاخص اصلی
	if tour.get("service_quality", 0.6) < 0.6:
		var budget_cmd = build_budget_command(state, "زیرساخت")
		if budget_cmd != null:
			cmds.append(budget_cmd)
		if tour.get("visitors",5000000) < 3000000:
			cmds.append(GameCommand.create_policy_change("visa_liberalization_tourism", true))

	# اگر هیچ بحران فوری نیست اما سلامت پایین است، باز هم بودجه را تنظیم کن
	if cmds.is_empty() and urgency > 0.18:
		var fallback = build_budget_command(state, diag.get("budget_key", "زیرساخت"))
		if fallback != null:
			cmds.append(fallback)

	# در صورت عدم نیاز به اقدام، تصمیم پایه را برگردان
	if cmds.is_empty():
		return super.decide(state, tick)
	return cmds

func evaluate(state: Dictionary) -> float:
	var d = diagnose(state)
	return float(d.get("health", 0.5))
