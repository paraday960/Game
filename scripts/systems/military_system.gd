extends BaseSystem
# ارتش و دفاع - ۳.۱۳

func compute(state: Dictionary, tick: int) -> Dictionary:
	var mil = state["military"]
	var econ = state["economy"]
	var pop = state["population"]
	var pol = state["politics"]
	var tech = state["technology"]
	var infra = state["infrastructure"]
	var development_modifiers = MilitaryManager.get_effective_modifiers(state)

	var events = []

	# بودجه نظامی از تخصیص بودجه می‌آید
	var budget_share = econ["budget_allocations"].get("ارتش", 0.08)
	mil["budget_share"] = budget_share
	var mil_budget = econ["government_spending"] * budget_share

	# هزینه نگهداری ماهانه از نسبت سالانه داده‌محور - ۳.۱۳.۴
	var maintenance_ratio = float(BalanceConfig.get_value("military.maintenance", 0.15))
	var maintenance = mil["power"] * 10_000_000.0 * maintenance_ratio / 12.0
	if mil_budget < maintenance:
		mil["readiness"] -= 0.005
		events.append({"type": "low_military_budget", "readiness": mil["readiness"]})
	else:
		mil["readiness"] += 0.002

	mil["readiness"] = clamp(mil["readiness"], 0.1, 1.0)

	# قدرت نظامی = f(نیروی انسانی، تجهیزات، آموزش، فناوری، لجستیک، بودجه)
	var personnel_factor = mil["personnel"] / 500_000.0
	var tech_factor = tech["branches"]["نظامی"] * 1.5
	var readiness_factor = clamp(float(mil["readiness"]) + float(development_modifiers.get("readiness_bonus", 0.0)), 0.1, 1.0)
	mil["effective_readiness"] = readiness_factor
	var logistics_factor = clamp(infra["quality"] * 0.5 + 0.5 + float(development_modifiers.get("logistics_bonus", 0.0)), 0.4, 1.4)
	var budget_factor = (mil_budget / max(econ["government_spending"] * 0.08, 1.0))

	var power = 50.0
	power *= (0.5 + personnel_factor * 0.5)
	power *= (0.7 + tech_factor * 0.3)
	power *= (0.5 + readiness_factor * 0.5)
	power *= logistics_factor
	power *= (0.8 + budget_factor * 0.2)
	power *= float(development_modifiers.get("power_multiplier", 1.0))
	mil["power"] = clamp(power, 5.0, 200.0)

	# روحیه
	var morale = pop["happiness"] * 0.3 + pol["trust"] * 0.3 + mil["readiness"] * 0.4
	# ضریب روحیه در آمادگی ۲۰٪ - ۳.۱۳.۴
	mil["readiness"] = mil["readiness"] * 0.8 + morale * 0.2

	# بازدارندگی = f(قدرت، آمادگی، توان هسته‌ای)
	var deterrence = mil["power"] * 0.6 + readiness_factor * 30.0 + float(development_modifiers.get("deterrence_bonus", 0.0))
	if state["space"]["level"] > 0.5: # توان موشکی
		deterrence += 10.0
	mil["deterrence"] = clamp(deterrence, 0.0, 100.0)

	# خستگی جنگ (رودمپ ۵): در جنگ توسط WorldManager رشد می‌کند و در صلح به‌تدریج فروکش
	# می‌کند؛ تا وقتی بالاست، فشار روانی آن بر شادی و ثبات جامعه اعمال می‌شود (مقیاس ماهانه).
	var wars_now: Dictionary = state.get("world", {}).get("wars", {})
	var exhaustion = clamp(float(mil.get("war_exhaustion", 0.0)), 0.0, 1.0)
	if wars_now.is_empty():
		exhaustion = clamp(exhaustion - 0.008, 0.0, 1.0)
	mil["war_exhaustion"] = exhaustion
	if exhaustion > 0.05:
		pop["happiness"] = clamp(float(pop["happiness"]) - exhaustion * 0.0004, 0.05, 0.95)
		pol["stability"] = clamp(float(pol["stability"]) - exhaustion * 0.0002, 0.05, 0.95)

	# رویدادها - ۳.۱۳.۵
	if Deterministic.chance(0.008):
		events.append({"type": "border_tension", "message": "تحرکات مرزی گزارش شد"})
		pol["tension"] += 0.02 if state["politics"].has("tension") else 0

	if mil["readiness"] < 0.4 and Deterministic.chance(0.02):
		events.append({"type": "military_crisis", "readiness": mil["readiness"]})

	state["military"] = mil
	return {"success": true, "state": state, "events": events}
