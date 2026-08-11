extends BaseAI
# هوش تخصصی interdependency - تاب‌آوری جریان‌ها - تحلیل دترمینستیک، بودجه‌محور، اقدام چندسطحی

func decide(state: Dictionary, tick: int) -> Array:
	var inter = state.get("indicators", {})
	var econ = state.get("economy", {})
	var cmds = []

	# تشخیص اولیه از BaseAI
	var diag = diagnose(state)
	var urgency = diag.get("urgency", 0.0)
	var metric_val = inter.get("stability", 0.6)

	# شرط اضطراری بر اساس شاخص اصلی
	if inter.get("stability", 0.6) < 0.6:
		var budget_cmd = build_budget_command(state, "ذخیره")
		if budget_cmd != null:
			cmds.append(budget_cmd)
		if inter.get("bottlenecks",[]).size() > 2:
			cmds.append(GameCommand.create_policy_change("bottleneck_relief", true))

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
