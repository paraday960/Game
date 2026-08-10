extends BaseSystem
# ۳.۴۲ سکونتگاه‌ها - شهر، شهرک، روستا - لایه اماکن فیزیکی تفصیلی

func compute(state: Dictionary, tick: int) -> Dictionary:
	var settlements = state.get("settlements_detail", {})
	var pop = state.get("population", {})
	var infra = state.get("infrastructure", {})
	var econ = state.get("economy", {})

	settlements["total"] = settlements.get("total", 1200)
	settlements["cities_large"] = settlements.get("cities_large", 50)
	settlements["cities_medium"] = settlements.get("cities_medium", 200)
	settlements["cities_small"] = settlements.get("cities_small", 350)
	settlements["towns"] = settlements.get("towns", 400)
	settlements["villages"] = settlements.get("villages", 10000)
	settlements["urban_pop"] = settlements.get("urban_pop", pop.get("total",85_000_000) * 0.75)
	settlements["rural_pop"] = settlements.get("rural_pop", pop.get("total",85_000_000) * 0.25)
	settlements["density"] = settlements.get("density", 50.0)
	settlements["sprawl"] = settlements.get("sprawl", 0.30)
	settlements["housing_quality"] = settlements.get("housing_quality", 0.60)

	var events = []

	# رشد شهری با جمعیت و اقتصاد
	var pop_growth = pop.get("growth_rate",0.012)
	var urbanization_rate = 0.01  # ۱٪ سالانه شهرنشینی افزایش
	settlements["urban_pop"] = settlements["urban_pop"] * (1.0 + pop_growth + urbanization_rate/365.0)
	settlements["rural_pop"] = pop.get("total",85_000_000) - settlements["urban_pop"]

	# تراکم = جمعیت شهری / تعداد شهرها
	settlements["density"] = settlements["urban_pop"] / max(settlements["cities_large"]*1000000 + settlements["cities_medium"]*200000 + settlements["cities_small"]*50000, 1.0) * 1000.0

	# گسترش بی‌رویه شهری
	var infra_coverage = infra.get("coverage",0.70)
	settlements["sprawl"] = clamp(settlements["sprawl"] + (settlements["urban_pop"]/85_000_000.0 - infra_coverage) * 0.0001, 0.0, 0.85)

	# کیفیت مسکن
	var housing_shortage = state.get("physical",{}).get("housing_shortage",0.10)
	settlements["housing_quality"] = clamp(settlements["housing_quality"] + (0.15 - housing_shortage) * 0.001, 0.2, 0.95)

	# تعداد سکونتگاه‌ها با جمعیت رشد می‌کند
	if tick % 365 == 0:
		if settlements["urban_pop"] > settlements["cities_large"]*1500000:
			settlements["cities_large"] += 1
			settlements["cities_medium"] += 2
			events.append({"type": "new_city", "message": "شهر بزرگ جدید تاسیس شد - مهاجرت و رشد جمعیت"})

	# اثر بر زیرساخت
	infra["coverage"] = clamp(infra_coverage + settlements["sprawl"] * -0.0001 + 0.0002, 0.2, 0.95)
	state["infrastructure"] = infra

	# حلقه: شهرنشینی → زیرساخت → رشد → شهرنشینی
	if settlements["sprawl"] > 0.6 and Deterministic.chance(0.01):
		events.append({"type": "urban_sprawl_crisis", "message": "گسترش بی‌رویه شهری - تخریب کشاورزی و ترافیک", "sprawl": settlements["sprawl"]})
		state["environment"]["forest_coverage"] = clamp(state.get("environment",{}).get("forest_coverage",0.30) - 0.002, 0.05, 0.70)

	if housing_shortage > 0.3 and Deterministic.chance(0.012):
		events.append({"type": "housing_shortage_protest", "message": "بحران مسکن - جوانان قادر به خانه‌دار شدن نیستند", "shortage": housing_shortage})

	state["settlements_detail"] = settlements
	return {"success": true, "state": state, "events": events}
