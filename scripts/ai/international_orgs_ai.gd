extends BaseAI
# هوش تخصصی international_orgs - تعامل جهانی - تحلیل دترمینستیک، بودجه‌محور، اقدام چندسطحی

func decide(state: Dictionary, tick: int) -> Array:
	var intl = state.get("international_orgs", {})
	var econ = state.get("economy", {})
	var cmds = []

	# تشخیص اولیه از BaseAI
	var diag = diagnose(state)
	var urgency = diag.get("urgency", 0.0)
	var metric_val = intl.get("compliance", 0.6)

	# شرط اضطراری بر اساس شاخص اصلی
	if intl.get("compliance", 0.6) < 0.6:
		var budget_cmd = build_budget_command(state, "اداره")
		if budget_cmd != null:
			cmds.append(budget_cmd)
		if intl.get("influence_un",0.4) < 0.30:
			cmds.append(GameCommand.create_diplomacy_action("un", "boost_influence"))

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
