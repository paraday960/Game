extends BaseSystem
# ۳.۱۹ بهداشت و سلامت عمومی - پیاده‌سازی کامل

func compute(state: Dictionary, tick: int) -> Dictionary:
	var health = state.get("health", {})
	var pop = state.get("population", {})
	var econ = state.get("economy", {})
	var education = state.get("education", {})
	var environment = state.get("environment", {})
	var resources = state.get("resources", {})
	var welfare = state.get("welfare", {})

	health["coverage"] = health.get("coverage", 0.75)
	health["quality"] = health.get("quality", 0.60)
	health["hospital_beds"] = health.get("hospital_beds", 150000)
	health["insurance"] = health.get("insurance", 0.75)
	health["vaccination"] = health.get("vaccination", 0.85)
	health["epidemic_readiness"] = health.get("epidemic_readiness", 0.50)
	health["mental_health"] = health.get("mental_health", 0.60)
	health["doctors"] = health.get("doctors", 50000)
	health["nurses"] = health.get("nurses", 120000)
	health["life_expectancy"] = health.get("life_expectancy", 74.0)

	var events = []

	# بودجه بهداشت
	var health_budget_share = econ.get("budget_allocations", {}).get("بهداشت", 0.10)
	var health_budget = econ.get("government_spending", 0.0) * health_budget_share

	# فرمول‌ها - ۳.۱۹.۳
	# سلامت جمعیت = f(دسترسی، کیفیت، پیشگیری، تغذیه، محیط)
	var access = health["coverage"] * 0.5 + health["insurance"] * 0.3 + resources.get("inventory", {}).get("غذا", 85) / 100.0 * 0.2
	var prevention = health["vaccination"] * 0.5 + health["epidemic_readiness"] * 0.3 + education.get("quality",0.55) * 0.2
	var nutrition = resources.get("inventory", {}).get("غذا", 85) / 100.0
	var env_health = environment.get("air_quality",0.6) if environment else 0.6
	
	var population_health = 0.5
	population_health += access * 0.3
	population_health += health["quality"] * 0.3
	population_health += prevention * 0.2
	population_health += nutrition * 0.1
	population_health += env_health * 0.1
	health["population_health"] = clamp(population_health, 0.1, 0.95)

	# کیفیت با بودجه
	var quality_change = (health_budget_share - 0.08) * 0.01 + (health_budget / 10_000_000_000.0 - 0.5) * 0.001
	health["quality"] = clamp(health["quality"] + quality_change, 0.1, 0.95)

	# پوشش بیمه = f(بودجه، نظام بیمه، سیاست)
	var insurance_target = 0.75 + (health_budget_share - 0.08) * 2.0
	health["insurance"] = clamp(health["insurance"] * 0.995 + insurance_target * 0.005, 0.1, 0.99)

	# واکسیناسیون
	health["vaccination"] = clamp(health["vaccination"] + Deterministic.next_range(-0.001, 0.002), 0.5, 0.99)

	# آمادگی اپیدمی
	health["epidemic_readiness"] = clamp(health["epidemic_readiness"] + (health_budget_share - 0.08) * 0.003, 0.1, 0.95)

	# عمر امید = f(سلامت، بهداشت، تغذیه، امنیت)
	var life_exp = 70.0
	life_exp += health["quality"] * 10.0
	life_exp += health["population_health"] * 5.0
	life_exp += nutrition * 3.0
	life_exp += (1.0 - welfare.get("poverty",0.15)) * 2.0
	health["life_expectancy"] = clamp(health["life_expectancy"] * 0.999 + life_exp * 0.001, 50.0, 90.0)

	# هزینه سلامت = f(بیمارستان، دارو، نیروی متخصص)
	var bed_need = pop.get("total", 85_000_000) / 1000.0 * 2.5  # 2.5 تخت per 1000
	var bed_ratio = health["hospital_beds"] / max(bed_need, 1.0)
	if bed_ratio < 0.8:
		events.append({"type": "hospital_bed_shortage", "message": "کمبود تخت بیمارستانی - ظرفیت پر", "ratio": bed_ratio})
		health["quality"] -= 0.002

	# نیروی پزشکی
	var doctor_need = pop.get("total",0) / 1000.0 * 1.5
	var doctor_ratio = health["doctors"] / max(doctor_need,1.0)
	if doctor_ratio < 0.7 and Deterministic.chance(0.01):
		events.append({"type": "doctor_shortage", "message": "کمبود پزشک و پرستار"})

	# سلامت روان
	health["mental_health"] = clamp(health["mental_health"] + (pop.get("happiness",0.6) - 0.5) * 0.002, 0.1, 0.95)

	# حلقه بازخورد: سلامت → بهره‌وری/رشد؛ اپیدمی → بحران
	pop["happiness"] = clamp(pop.get("happiness",0.6) + (health["population_health"] - 0.5) * 0.001, 0.05, 0.95)
	# اثر بر رشد جمعیت - بهداشت خوب مرگ کمتر
	# در سیستم جمعیت اعمال می‌شود اما اینجا سیگنال می‌دهیم

	state["population"] = pop

	# رویدادها - ۳.۱۹.۵
	if health["epidemic_readiness"] < 0.4 and Deterministic.chance(0.01):
		events.append({"type": "epidemic_outbreak", "message": "شیوع بیماری واگیردار! آمادگی پایین", "severity": 1.0 - health["epidemic_readiness"]})
		health["quality"] -= 0.02
		pop["happiness"] -= 0.03

	if health["coverage"] < 0.6 and Deterministic.chance(0.01):
		events.append({"type": "health_inequality_exposed", "message": "افشای نابرابری در دسترسی به سلامت", "coverage": health["coverage"]})

	if Deterministic.chance(0.008):
		events.append({"type": "medical_breakthrough", "message": "پیشرفت پزشکی - کشف درمان جدید", "benefit": 0.03})
		health["quality"] += 0.01
		health["life_expectancy"] += 0.1

	state["health"] = health
	return {"success": true, "state": state, "events": events}
