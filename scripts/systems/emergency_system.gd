extends BaseSystem
# ۳.۳۵ خدمات اضطراری و مدیریت بحران - پیاده‌سازی کامل

func compute(state: Dictionary, tick: int) -> Dictionary:
	var emergency = state.get("emergency", {})
	var infra = state.get("infrastructure", {})
	var health = state.get("health", {})
	var security = state.get("security", {})

	emergency["preparedness"] = emergency.get("preparedness", 0.50)
	emergency["response_time"] = emergency.get("response_time", 10.0)
	emergency["fire_stations"] = emergency.get("fire_stations", 500)
	emergency["ambulances"] = emergency.get("ambulances", 2000)
	emergency["rescue_teams"] = emergency.get("rescue_teams", 300)
	emergency["stockpile"] = emergency.get("stockpile", 30.0)  # روز ذخیره
	emergency["early_warning"] = emergency.get("early_warning", 0.45)
	emergency["evacuation_capacity"] = emergency.get("evacuation_capacity", 0.50)
	emergency["volunteers"] = emergency.get("volunteers", 100000)
	emergency["budget_share"] = emergency.get("budget_share", 0.02)

	var events = []

	var econ = state.get("economy", {})
	var env = state.get("environment", {})

	var emergency_budget_share = econ.get("budget_allocations",{}).get("امنیت",0.05) * 0.3
	var emergency_budget = econ.get("government_spending",0.0) * emergency_budget_share
	emergency["budget_share"] = emergency_budget_share

	# آمادگی = f(بودجه، آموزش، تجهیزات، تجربه، فناوری)
	var training = state.get("education",{}).get("quality",0.55) * 0.2
	var tech = state.get("technology",{}).get("branches",{}).get("دیجیتال",0.2) * 0.1
	var experience = min(float(tick) / 3650.0 * 0.1, 0.3)  # تجربه با زمان

	var preparedness_target = 0.4 + emergency_budget_share * 5.0 + training + tech + experience + health.get("epidemic_readiness",0.5) * 0.1
	emergency["preparedness"] = clamp(emergency["preparedness"] * 0.995 + preparedness_target * 0.005, 0.1, 0.95)

	# زمان واکنش = f(تعداد آمبولانس، توزیع، ترافیک، فاصله)
	var ambulance_per_pop = emergency["ambulances"] / (state.get("population",{}).get("total",85_000_000) / 100000.0)  # per 100k
	var ideal_response = 15.0 - ambulance_per_pop * 0.5 - infra.get("quality",0.55) * 3.0
	emergency["response_time"] = clamp(emergency["response_time"] * 0.99 + ideal_response * 0.01, 3.0, 60.0)

	# ایستگاه‌ها و تجهیزات
	if emergency_budget_share > 0.015 and Deterministic.chance(0.005):
		emergency["fire_stations"] += 1
		emergency["ambulances"] += 5
		emergency["rescue_teams"] += 1

	# ذخیره تجهیزات (۳۰ روز هدف - ۳.۲۲۴)
	var stockpile_target = 30.0 + emergency_budget_share * 200.0
	emergency["stockpile"] = clamp(emergency["stockpile"] * 0.995 + stockpile_target * 0.005, 5.0, 90.0)

	# هشدار زودهنگام
	var early_warning_target = 0.4 + tech * 2.0 + emergency["preparedness"] * 0.3
	emergency["early_warning"] = clamp(emergency["early_warning"] * 0.99 + early_warning_target * 0.01, 0.1, 0.90)

	# ظرفیت تخلیه
	emergency["evacuation_capacity"] = clamp(emergency["evacuation_capacity"] + (emergency["preparedness"] - 0.5) * 0.001, 0.2, 0.95)

	# داوطلبان
	var happiness = state.get("population",{}).get("happiness",0.6)
	emergency["volunteers"] = int(emergency["volunteers"] * 0.999 + happiness * 100000.0 * 0.001 + emergency["preparedness"] * 50000.0 * 0.001)

	# اثر هشدار زودهنگام: ضریب کاهش ۲۰ تا ۵۰ درصدی تلفات بلایا (۳.۱۸۸)
	emergency["casualty_reduction"] = clamp(
		0.20 + max(0.0, emergency["early_warning"] - 0.4) * 0.5,
		0.20, 0.50)

	# تاب‌آوری = f(آمادگی، زیرساخت، بودجه)
	var resilience = emergency["preparedness"] * 0.5 + infra.get("quality",0.55) * 0.3 + emergency_budget_share * 5.0 * 0.2
	env["disaster_resilience"] = clamp(env.get("disaster_resilience",0.50) * 0.99 + resilience * 0.01, 0.1, 0.95)
	state["environment"] = env

	# حلقه بازخورد: واکنش ← نجات ← اعتماد ← آمادگی
	if emergency["response_time"] < 8.0:
		state["population"]["happiness"] = clamp(state.get("population",{}).get("happiness",0.6) + 0.0003, 0.05, 0.95)
		state["politics"]["trust"] = clamp(state.get("politics",{}).get("trust",0.55) + 0.0002, 0.05, 0.95)

	# رویدادها
	if emergency["preparedness"] < 0.3 and Deterministic.chance(0.015):
		events.append({"type": "emergency_unprepared", "message": "آمادگی پایین مدیریت بحران - آسیب‌پذیری در برابر بلایا", "preparedness": emergency["preparedness"]})

	if emergency["response_time"] > 20.0 and Deterministic.chance(0.012):
		events.append({"type": "slow_response", "message": "زمان واکنش اضطراری بسیار بالا - کمبود آمبولانس", "response_time": emergency["response_time"]})

	if emergency["stockpile"] < 15.0 and Deterministic.chance(0.01):
		events.append({"type": "stockpile_shortage", "message": "ذخیره تجهیزات اضطراری رو به پایان - نیاز به تامین فوری"})

	if Deterministic.chance(0.008):
		events.append({"type": "emergency_drill_success", "message": "مانور موفق مدیریت بحران - افزایش آمادگی"})
		emergency["preparedness"] += 0.02

	# بلایای طبیعی تصادفی - ۳.۱۸۸ زنجیره بلایا
	if Deterministic.chance(0.003):
		var disasters = ["زلزله", "سیل", "طوفان", "خشک‌سالی", "آتش‌سوزی جنگل"]
		var disaster = Deterministic.shuffle_array(disasters)[0]
		var severity = Deterministic.next_range(0.1, 0.9)
		var damage_reduction = emergency["preparedness"] * 0.4 + emergency["early_warning"] * 0.3
		var actual_damage = severity * (1.0 - damage_reduction)
		events.append({"type": "natural_disaster", "disaster": disaster, "severity": severity, "actual_damage": actual_damage, "message": "بلای طبیعی: %s - خسارت %.0f٪" % [disaster, actual_damage*100]})
		# خسارت به زیرساخت و اقتصاد
		state["infrastructure"]["quality"] = clamp(state.get("infrastructure",{}).get("quality",0.55) - actual_damage * 0.05, 0.1, 0.95)
		state["economy"]["gdp"] *= (1.0 - actual_damage * 0.001)
		# اگر آمادگی خوب باشد تلفات کمتر
		if emergency["early_warning"] > 0.6:
			events.append({"type": "early_warning_saved_lives", "message": "هشدار زودهنگام جان بسیاری را نجات داد - کاهش ۵۰٪ تلفات"})

	state["emergency"] = emergency
	return {"success": true, "state": state, "events": events}
