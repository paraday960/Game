extends BaseSystem
# ۳.۳۰ گردشگری و خدمات - پیاده‌سازی کامل

func compute(state: Dictionary, tick: int) -> Dictionary:
	var tourism = state.get("tourism", {})
	var economy = state.get("economy", {})
	var culture = state.get("culture", {})
	var environment = state.get("environment", {})
	var security = state.get("security", {})
	var infra = state.get("infrastructure", {})
	var heritage = state.get("heritage", {})

	tourism["visitors"] = tourism.get("visitors", 5_000_000)
	tourism["revenue"] = tourism.get("revenue", 5_000_000_000.0)
	tourism["infrastructure"] = tourism.get("infrastructure", 0.55)
	tourism["service_quality"] = tourism.get("service_quality", 0.60)
	tourism["safety"] = tourism.get("safety", security.get("public_security",0.70))
	tourism["cultural_attraction"] = tourism.get("cultural_attraction", culture.get("cultural_output",0.5))
	tourism["natural_attraction"] = tourism.get("natural_attraction", environment.get("forest_coverage",0.30) + 0.3)
	tourism["visa_openness"] = tourism.get("visa_openness", 0.50)
	tourism["marketing"] = tourism.get("marketing", 0.50)
	tourism["seasonality"] = tourism.get("seasonality", 0.30)

	var events = []

	# گردشگری = f(زیرساخت، امنیت، فرهنگ، طبیعت، قیمت، روادید)
	var infra_factor = tourism["infrastructure"] * 0.25 + infra.get("quality",0.55) * 0.15
	var safety_factor = tourism["safety"] * 0.25 + security.get("feeling_security",0.70) * 0.1
	var attraction = (tourism["cultural_attraction"] + tourism["natural_attraction"] + heritage.get("sites",20)/50.0) / 3.0 * 0.25
	var price_factor = 1.0 / state.get("central_bank",{}).get("exchange_rate",1.0) * 0.1  # ارز ارزان‌تر برای گردشگر
	var visa_factor = tourism["visa_openness"] * 0.15

	var tourism_potential = 0.3 + infra_factor + safety_factor + attraction + price_factor + visa_factor
	tourism_potential = clamp(tourism_potential, 0.1, 1.5)

	var base_visitors = 5_000_000.0
	var visitors = base_visitors * tourism_potential * (1.0 + pop_total(state)/85_000_000.0 * 0.1) * (1.0 + economy.get("gdp",0)/500_000_000_000.0 * 0.1)
	# فصلی بودن
	var seasonal_factor = 1.0 + sin(float(tick) / 365.0 * 6.28 * 2.0) * tourism["seasonality"]
	visitors *= seasonal_factor

	tourism["visitors"] = tourism["visitors"] * 0.98 + visitors * 0.02

	# درآمد = بازدیدکنندگان × هزینه متوسط
	var avg_spending = 800.0 + tourism["service_quality"] * 400.0  # دلار per visitor
	var revenue = tourism["visitors"] * avg_spending
	tourism["revenue"] = tourism["revenue"] * 0.98 + revenue * 0.02

	# کیفیت خدمات
	tourism["service_quality"] = clamp(tourism["service_quality"] + (tourism["infrastructure"] - 0.5) * 0.001, 0.1, 0.95)

	# زیرساخت گردشگری با بودجه
	var tourism_budget_share = 0.02
	var tourism_budget = economy.get("government_spending",0.0) * tourism_budget_share
	tourism["infrastructure"] = clamp(tourism["infrastructure"] + (tourism_budget / 2_000_000_000.0 - 0.5) * 0.001, 0.1, 0.95)

	# ایمنی
	tourism["safety"] = security.get("public_security",0.70) * 0.7 + tourism["safety"] * 0.3

	# جذابیت فرهنگی و طبیعی
	tourism["cultural_attraction"] = culture.get("cultural_output",0.5) * 0.6 + heritage.get("preservation",0.65) * 0.4 if heritage else culture.get("cultural_output",0.5)
	tourism["natural_attraction"] = environment.get("forest_coverage",0.30) * 0.5 + environment.get("air_quality",0.6) * 0.3 + environment.get("protected_areas",0.12) * 2.0 * 0.2
	tourism["natural_attraction"] = clamp(tourism["natural_attraction"], 0.1, 0.95)

	# روادید با دیپلماسی
	var diplomacy = state.get("diplomacy",{})
	tourism["visa_openness"] = clamp(tourism["visa_openness"] + (diplomacy.get("soft_power",35.0)/100.0 - 0.5) * 0.001, 0.1, 0.90)

	# بازاریابی
	tourism["marketing"] = clamp(tourism["marketing"] + Deterministic.next_range(-0.002, 0.003), 0.1, 0.95)

	# اثر بر اقتصاد
	economy["gdp"] += tourism["revenue"] * 0.1 / 365.0
	state["economy"] = economy

	# اشتغال گردشگری
	var tourism_jobs = tourism["visitors"] / 100.0  # هر 100 گردشگر یک شغل
	state["welfare"]["tourism_jobs"] = tourism_jobs if state.has("welfare") else tourism_jobs

	# حلقه بازخورد: گردشگری → فرهنگ و درآمد؛ ناامنی → کاهش
	if tourism["safety"] < 0.4:
		tourism["visitors"] *= 0.95
		events.append({"type": "tourism_safety_crisis", "message": "ناامنی گردشگری - کاهش بازدیدکنندگان", "safety": tourism["safety"]})

	# رویدادها
	if tourism["visitors"] > 10_000_000 and Deterministic.chance(0.01):
		events.append({"type": "tourism_boom", "message": "رونق گردشگری - رکورد بازدیدکنندگان!", "visitors": tourism["visitors"]})

	if tourism["natural_attraction"] > 0.7 and Deterministic.chance(0.008):
		events.append({"type": "eco_tourism_growth", "message": "رشد گردشگری طبیعت - پارک‌های ملی پرطرفدار"})

	if tourism["service_quality"] < 0.4 and Deterministic.chance(0.01):
		events.append({"type": "tourism_service_crisis", "message": "بحران کیفیت خدمات گردشگری - نارضایتی"})

	if Deterministic.chance(0.006):
		events.append({"type": "cultural_festival_tourism", "message": "جشنواره فرهنگی - جذب گردشگر خارجی"})

	state["tourism"] = tourism
	return {"success": true, "state": state, "events": events}

func pop_total(state: Dictionary) -> float:
	return state.get("population",{}).get("total",85_000_000)
