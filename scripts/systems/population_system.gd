extends BaseSystem
# سیستم جمعیت و دموگرافی - بخش ۳.۱۱

func compute(state: Dictionary, tick: int) -> Dictionary:
	var pop = state["population"]
	var econ = state["economy"]
	var health = state["health"]
	var edu = state["education"]
	var welfare = state["welfare"]
	var pol = state["politics"]
	var resources = state["resources"]

	var events = []

	# رشد طبیعی - ۳.۱۱.۳
	# تولد - مرگ
	var birth_rate = pop["birth_rate"]
	var death_rate = pop["death_rate"]

	# اثر رفاه بر تولد
	var welfare_effect = (econ["gdp_per_capita"] / 5000.0 - 1.0) * 0.5 + welfare["poverty"] * -2.0
	birth_rate += welfare_effect
	birth_rate += (pop["happiness"] - 0.5) * 2.0
	birth_rate = clamp(birth_rate, 5.0, 35.0)

	# اثر بهداشت بر مرگ
	var health_effect = (health["quality"] - 0.5) * -3.0
	death_rate += health_effect
	death_rate += (food_crisis_penalty(resources) + energy_crisis_penalty(resources))
	death_rate = clamp(death_rate, 4.0, 25.0)

	pop["birth_rate"] = birth_rate
	pop["death_rate"] = death_rate

	var natural_growth = (birth_rate - death_rate) / 1000.0  # سالانه به نسبت
	# مهاجرت
	var migration_rate = pop["migration_net"] / max(pop["total"], 1.0)
	# جذابیت کشور
	var attractiveness = 0.0
	attractiveness += pop["happiness"] * 0.5
	attractiveness += (1.0 - welfare["poverty"]) * 0.3
	attractiveness += pol["stability"] * 0.2
	attractiveness -= pol["tension"] * 0.3

	# مهاجرت تصادفی دترمینستیک
	if Deterministic.chance(0.05):
		var mig_change = Deterministic.next_range(-5000, 20000) * attractiveness
		pop["migration_net"] += mig_change
		pop["migration_net"] = clamp(pop["migration_net"], -100000, 200000)

	var total_growth_rate = natural_growth + migration_rate
	pop["growth_rate"] = total_growth_rate / 365.0  # روزانه
	pop["total"] *= (1.0 + pop["growth_rate"])
	pop["total"] = max(pop["total"], 1000.0)

	# نیروی کار
	pop["workforce"] = pop["total"] * pop["participation_rate"] * (1.0 - pop["age_structure"]["کودک"] - pop["age_structure"]["سالمند"] * 0.5)

	# نسبت وابستگی
	var children = pop["age_structure"]["کودک"]
	var elderly = pop["age_structure"]["سالمند"]
	var adults = pop["age_structure"]["بزرگسال"] + pop["age_structure"]["جوان"] * 0.7
	pop["dependency_ratio"] = (children + elderly) / max(adults, 0.01)

	# ترکیب سنی کند تغییر می‌کند
	if tick % 365 == 0:
		# هر سال
		pop["age_structure"]["سالمند"] += 0.002  # پیری جمعیت
		pop["age_structure"]["کودک"] -= 0.001
		# نرمالایز
		var sum_age = 0.0
		for v in pop["age_structure"].values():
			sum_age += v
		for k in pop["age_structure"].keys():
			pop["age_structure"][k] /= sum_age

	# رضایت - ۳.۱۱.۳
	# رضایت = f(رفاه، بیکاری، تورم، امنیت، آزادی، بهداشت)
	# مبنای ۰.۰۵ - تعادل در شرایط متوسط ≈ ۰.۶۷ (بدون مدیریت به سقف نمی‌رسد)
	var happiness = 0.05
	happiness += (1.0 - econ["unemployment"]) * 0.2
	happiness += (1.0 - econ["inflation"]) * 0.15
	happiness += health["quality"] * 0.15
	happiness += edu["quality"] * 0.1
	happiness += (1.0 - welfare["poverty"]) * 0.2
	happiness += pol["trust"] * 0.1
	happiness -= pol["tension"] * 0.2
	if resources["food_crisis"]:
		happiness -= 0.2
	if resources["energy_crisis"]:
		happiness -= 0.1
	happiness = clamp(happiness, 0.05, 0.95)
	pop["happiness"] = pop["happiness"] * 0.95 + happiness * 0.05  # نرم شدن تغییرات
	pop["satisfaction"] = pop["happiness"] * 0.9 + pol["trust"] * 0.1

	# آستانه شورش - ۳.۱۱.۴
	if pop["happiness"] < 0.30 and Deterministic.chance(0.05):
		events.append({"type": "unrest_risk", "happiness": pop["happiness"], "message": "نارضایتی شدید مردمی - خطر شورش"})

	# رویدادهای جمعیتی - ۳.۱۱.۵
	if Deterministic.chance(0.01):
		var r = Deterministic.next_float()
		if r < 0.2:
			events.append({"type": "baby_boom", "effect": 0.02})
			pop["birth_rate"] += 2.0
		elif r < 0.4:
			events.append({"type": "epidemic", "severity": Deterministic.next_range(0.1, 0.5)})
			pop["death_rate"] += 5.0
			health["quality"] -= 0.05
		elif r < 0.6:
			events.append({"type": "migration_wave", "size": Deterministic.next_int_range(10000, 100000)})
			pop["migration_net"] += Deterministic.next_int_range(10000, 100000)

	state["population"] = pop
	state["health"] = health

	return {"success": true, "state": state, "events": events}

func food_crisis_penalty(resources: Dictionary) -> float:
	if resources["food_crisis"]:
		return 5.0
	return 0.0

func energy_crisis_penalty(resources: Dictionary) -> float:
	if resources["energy_crisis"]:
		return 2.0
	return 0.0
