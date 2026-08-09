extends BaseSystem
# ۳.۲۴ محیط‌زیست و اقلیم - پیاده‌سازی کامل

func compute(state: Dictionary, tick: int) -> Dictionary:
	var env = state.get("environment", {})
	var resources = state.get("resources", {})
	var industry = state.get("industry", {})
	var pop = state.get("population", {})
	var econ = state.get("economy", {})
	var health = state.get("health", {})
	var agriculture = state.get("agriculture", {})

	env["air_quality"] = env.get("air_quality", 0.60)
	env["water_quality"] = env.get("water_quality", 0.65)
	env["soil_quality"] = env.get("soil_quality", 0.60)
	env["carbon_emission"] = env.get("carbon_emission", 0.6)
	env["pollution"] = env.get("pollution", 0.40)
	env["climate_change"] = env.get("climate_change", 0.50)
	env["green_energy_share"] = env.get("green_energy_share", 0.20)
	env["forest_coverage"] = env.get("forest_coverage", 0.30)
	env["protected_areas"] = env.get("protected_areas", 0.12)
	env["disaster_resilience"] = env.get("disaster_resilience", 0.50)
	env["recycling_rate"] = env.get("recycling_rate", 0.15)

	var events = []

	var env_budget_share = econ.get("budget_allocations",{}).get("محیط", 0.03)
	var env_budget = econ.get("government_spending",0.0) * env_budget_share

	# فرمول‌ها - ۳.۲۴.۳
	# کیفیت محیط = f(آلودگی، انتشار، حفاظت)
	var pollution = env["pollution"]
	# آلودگی از صنعت و انرژی فسیلی
	var industrial_pollution = industry.get("output",100.0) / 200.0 * 0.3
	var energy_pollution = (1.0 - env["green_energy_share"]) * 0.4
	var emission = env["carbon_emission"]
	pollution = 0.3 + industrial_pollution + energy_pollution * 0.3 + emission * 0.2 - env["forest_coverage"] * 0.2 - env["recycling_rate"] * 0.1
	env["pollution"] = clamp(env["pollution"] * 0.99 + pollution * 0.01, 0.0, 1.0)

	# کیفیت هوا، آب، خاک
	var air = 0.8 - env["pollution"] * 0.5 - env["carbon_emission"] * 0.2 + env["forest_coverage"] * 0.3 + env["green_energy_share"] * 0.2
	env["air_quality"] = clamp(env["air_quality"] * 0.99 + air * 0.01, 0.1, 0.95)

	var water = 0.7 - env["pollution"] * 0.3 + env_budget_share * 0.5
	env["water_quality"] = clamp(env["water_quality"] * 0.99 + water * 0.01, 0.1, 0.95)

	var soil = 0.65 - env["pollution"] * 0.2 - (1.0 - agriculture.get("production",100.0)/100.0) * 0.1
	env["soil_quality"] = clamp(env["soil_quality"] * 0.99 + soil * 0.01, 0.1, 0.95)

	# انتشار کربن = f(سوخت فسیلی، صنعت)
	var carbon = 0.5 + (1.0 - env["green_energy_share"]) * 0.3 + industry.get("output",100.0)/200.0 * 0.2 - env["forest_coverage"] * 0.2
	env["carbon_emission"] = clamp(env["carbon_emission"] * 0.998 + carbon * 0.002, 0.0, 1.0)

	# اثر تغییر اقلیم = f(انتشار، بلایا، تاب‌آوری)
	var climate = 0.4 + env["carbon_emission"] * 0.4 + (1.0 - env["disaster_resilience"]) * 0.2
	env["climate_change"] = clamp(env["climate_change"] * 0.999 + climate * 0.001, 0.0, 1.0)

	# تاب‌آوری = f(زیرساخت، آمادگی، بودجه)
	var infra_q = state.get("infrastructure",{}).get("quality",0.55)
	var emergency_prep = state.get("emergency",{}).get("preparedness",0.5) if state.has("emergency") else 0.5
	var resilience = 0.4 + infra_q * 0.3 + emergency_prep * 0.3 + env_budget_share * 2.0
	env["disaster_resilience"] = clamp(env["disaster_resilience"] * 0.995 + resilience * 0.005, 0.1, 0.95)

	# پوشش جنگلی پویا
	if env_budget_share > 0.04 and Deterministic.chance(0.01):
		env["forest_coverage"] += 0.001
	elif env["carbon_emission"] > 0.7 and Deterministic.chance(0.01):
		env["forest_coverage"] -= 0.001
	env["forest_coverage"] = clamp(env["forest_coverage"], 0.05, 0.70)

	# سهم انرژی پاک
	var tech_green = state.get("technology",{}).get("branches",{}).get("انرژی_پاک",0.15)
	env["green_energy_share"] = clamp(env["green_energy_share"] * 0.998 + (tech_green * 0.5 + env_budget_share * 2.0) * 0.002, 0.05, 0.85)

	# بازیافت
	env["recycling_rate"] = clamp(env["recycling_rate"] + (env_budget_share - 0.03) * 0.002, 0.05, 0.80)

	# هزینه زیست‌محیطی = f(آلودگی، سلامت، کشاورزی)
	var env_cost = env["pollution"] * 5_000_000_000.0 + (1.0 - env["air_quality"]) * 3_000_000_000.0
	health["quality"] = health.get("quality",0.6) - env["pollution"] * 0.0005
	state["health"] = health

	agriculture["production"] = agriculture.get("production",100.0) * (0.999 + env["soil_quality"] * 0.001 - env["pollution"] * 0.0005)
	state["agriculture"] = agriculture

	# حلقه بازخورد: آلودگی ← سلامت ← رضایت؛ اقلیم ← بلایا ← اقتصاد
	pop["happiness"] = clamp(pop.get("happiness",0.6) + (env["air_quality"] - 0.5) * 0.0005, 0.05, 0.95)
	state["population"] = pop

	if env["pollution"] > 0.7:
		econ["gdp"] *= (1.0 - 0.0001)
		state["economy"] = econ

	# رویدادها - ۳.۲۴.۵
	if env["air_quality"] < 0.3 and Deterministic.chance(0.015):
		events.append({"type": "air_pollution_crisis", "message": "بحران آلودگی هوا - شهرها در دود!", "quality": env["air_quality"]})
		health["quality"] -= 0.01
		state["health"] = health

	if env["climate_change"] > 0.7 and Deterministic.chance(0.01):
		var disasters = ["خشکسالی شدید", "سیل ویرانگر", "طوفان سهمگین", "موج گرما"]
		var chosen = Deterministic.shuffle_array(disasters)[0]
		events.append({"type": "climate_disaster", "message": "بحران اقلیمی: %s" % chosen, "severity": env["climate_change"]})
		env["disaster_resilience"] -= 0.02
		state["infrastructure"]["quality"] = state.get("infrastructure",{}).get("quality",0.55) - 0.01

	if env["forest_coverage"] < 0.15 and Deterministic.chance(0.008):
		events.append({"type": "deforestation_crisis", "message": "بحران جنگل‌زدایی - تنوع زیستی در خطر"})

	if Deterministic.chance(0.006):
		events.append({"type": "green_energy_breakthrough", "message": "پیشرفت انرژی پاک - افزایش سهم تجدیدپذیر", "boost": 0.02})
		env["green_energy_share"] += 0.02

	state["environment"] = env
	return {"success": true, "state": state, "events": events}
