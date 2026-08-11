extends BaseAI
# هوش تخصصی public_services - پوشش خدمات عمومی - تحلیل دترمینستیک، بودجه‌محور، اقدام چندسطحی

func decide(state: Dictionary, tick: int) -> Array:
	var ps = state.get("public_services_detail", {})
	var econ = state.get("economy", {})
	var cmds = []

	# تشخیص اولیه از BaseAI
	var diag = diagnose(state)
	var urgency = diag.get("urgency", 0.0)
	var metric_val = ps.get("coverage_health", 0.7)

	# شرط اضطراری بر اساس شاخص اصلی
	if ps.get("coverage_health", 0.7) < 0.7:
		var budget_cmd = build_budget_command(state, "بهداشت")
		if budget_cmd != null:
			cmds.append(budget_cmd)
		if ps.get("staff_shortage",0.15) > 0.35:
			cmds.append(GameCommand.create_policy_change("hire_public_staff", true))

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
