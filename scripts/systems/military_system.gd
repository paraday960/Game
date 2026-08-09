extends BaseSystem
# ارتش و دفاع - ۳.۱۳

func compute(state: Dictionary, tick: int) -> Dictionary:
	var mil = state["military"]
	var econ = state["economy"]
	var pop = state["population"]
	var pol = state["politics"]
	var tech = state["technology"]
	var infra = state["infrastructure"]

	var events = []

	# بودجه نظامی از تخصیص بودجه می‌آید
	var budget_share = econ["budget_allocations"].get("ارتش", 0.08)
	mil["budget_share"] = budget_share
	var mil_budget = econ["government_spending"] * budget_share

	# هزینه نگهداری - ۱۵٪ ارزش تجهیزات سالانه - ۳.۱۳.۴
	var maintenance = mil["power"] * 10_000_000.0  # ساده‌سازی
	if mil_budget < maintenance:
		mil["readiness"] -= 0.005
		events.append({"type": "low_military_budget", "readiness": mil["readiness"]})
	else:
		mil["readiness"] += 0.002

	mil["readiness"] = clamp(mil["readiness"], 0.1, 1.0)

	# قدرت نظامی = f(نیروی انسانی، تجهیزات، آموزش، فناوری، لجستیک، بودجه)
	var personnel_factor = mil["personnel"] / 500_000.0
	var tech_factor = tech["branches"]["نظامی"] * 1.5
	var readiness_factor = mil["readiness"]
	var logistics_factor = infra["quality"] * 0.5 + 0.5
	var budget_factor = (mil_budget / max(econ["government_spending"] * 0.08, 1.0))

	var power = 50.0
	power *= (0.5 + personnel_factor * 0.5)
	power *= (0.7 + tech_factor * 0.3)
	power *= (0.5 + readiness_factor * 0.5)
	power *= logistics_factor
	power *= (0.8 + budget_factor * 0.2)
	mil["power"] = clamp(power, 5.0, 200.0)

	# روحیه
	var morale = pop["happiness"] * 0.3 + pol["trust"] * 0.3 + mil["readiness"] * 0.4
	# ضریب روحیه در آمادگی ۲۰٪ - ۳.۱۳.۴
	mil["readiness"] = mil["readiness"] * 0.8 + morale * 0.2

	# بازدارندگی = f(قدرت، آمادگی، توان هسته‌ای)
	var deterrence = mil["power"] * 0.6 + mil["readiness"] * 30.0
	if state["space"]["level"] > 0.5: # توان موشکی
		deterrence += 10.0
	mil["deterrence"] = clamp(deterrence, 0.0, 100.0)

	# رویدادها - ۳.۱۳.۵
	if Deterministic.chance(0.008):
		events.append({"type": "border_tension", "message": "تحرکات مرزی گزارش شد"})
		pol["tension"] += 0.02 if state["politics"].has("tension") else 0

	if mil["readiness"] < 0.4 and Deterministic.chance(0.02):
		events.append({"type": "military_crisis", "readiness": mil["readiness"]})

	state["military"] = mil
	return {"success": true, "state": state, "events": events}
