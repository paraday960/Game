extends BaseAI
# هوش تخصصی central_bank - پایداری بانکی - تحلیل دترمینستیک، بودجه‌محور، اقدام چندسطحی

func decide(state: Dictionary, tick: int) -> Array:
	var cb = state.get("central_bank", {})
	var econ = state.get("economy", {})
	var cmds = []

	# تشخیص اولیه از BaseAI
	var diag = diagnose(state)
	var urgency = diag.get("urgency", 0.0)
	var metric_val = cb.get("bank_stability", 0.65)

	# شرط اضطراری بر اساس شاخص اصلی
	if cb.get("bank_stability", 0.65) < 0.65:
		var budget_cmd = build_budget_command(state, "ذخیره")
		if budget_cmd != null:
			cmds.append(budget_cmd)
		if cb.get("inflation",0.08) > 0.15:
			var new_rate = clamp(cb.get("interest_rate",0.15)+0.01, 0.05, 0.40)
			cmds.append(GameCommand.create_central_bank_set(new_rate))

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
