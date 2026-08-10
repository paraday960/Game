extends BaseAI
# هوش دیپلماسی و روابط بین‌الملل - ۳.۱۴.۷ - دترمینستیک و اتمی

func decide(state: Dictionary, tick: int) -> Array:
	var dip = state.get("diplomacy", {})
	var cmds = []

	# بدترین رابطه → تلاش برای بهبود
	var relations = dip.get("relations", {})
	var worst_key = ""
	var worst_val = 1000
	for k in relations.keys():
		if relations[k] < worst_val:
			worst_val = relations[k]
			worst_key = k

	if worst_key != "" and worst_val < 25:
		cmds.append(GameCommand.create_diplomacy_action(worst_key, "improve_relations"))

	# تحریم‌های ورودی زیاد → مذاکره با یکی از تحریم‌کنندگان معتبر
	if dip.get("sanctions", []).size() > 2:
		var sanction_target = worst_key
		for sanction in dip.get("sanctions", []):
			if sanction is Dictionary and sanction.get("by", "foreign") != "player" and relations.has(sanction.get("target", "")):
				sanction_target = sanction["target"]
				break
		if sanction_target != "":
			cmds.append(GameCommand.create_diplomacy_action(sanction_target, "negotiate_sanctions"))

	return cmds

func evaluate(state: Dictionary) -> float:
	var dip = state.get("diplomacy", {})
	var avg = 0.0
	var relations = dip.get("relations", {})
	if relations.size() > 0:
		for v in relations.values():
			avg += v
		avg /= relations.size()
	return clamp(avg / 100.0, 0.0, 1.0) * 0.6 + clamp(dip.get("influence", 40.0) / 100.0, 0.0, 1.0) * 0.4
