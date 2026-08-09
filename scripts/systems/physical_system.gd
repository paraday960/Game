extends BaseSystem
# لایه اماکن و نهادهای فیزیکی - بخش ۳.۴۲ تا ۳.۵۲ - 11 دسته مکانی

func compute(state: Dictionary, tick: int) -> Dictionary:
	var physical = state.get("physical", {})
	var pop = state.get("population", {})
	var econ = state.get("economy", {})

	physical["settlements"] = physical.get("settlements", 1200)
	physical["settlement_details"] = physical.get("settlement_details", {
		"شهر_بزرگ": 50,
		"شهر_متوسط": 200,
		"شهر_کوچک": 350,
		"شهرک": 400,
		"روستا": 10000
	})
	physical["transport"] = physical.get("transport", 5000)
	physical["transport_details"] = physical.get("transport_details", {
		"جاده": 3000,
		"راه_آهن": 500,
		"بندر": 20,
		"فرودگاه": 60,
		"ایستگاه_مترو": 200
	})
	physical["facilities"] = physical.get("facilities", 3000)
	physical["housing_units"] = physical.get("housing_units", 25000000)
	physical["housing_shortage"] = physical.get("housing_shortage", 0.10)
	physical["commercial"] = physical.get("commercial", {
		"رستوران": 50000,
		"فروشگاه": 200000,
		"بازار": 5000,
		"هتل": 3000
	})
	physical["public_services"] = physical.get("public_services", {
		"بیمارستان": 500,
		"مدرسه": 10000,
		"دانشگاه": 150,
		"ایستگاه_پلیس": 2000,
		"آتش_نشانی": 500
	})
	physical["industry_sites"] = physical.get("industry_sites", {
		"کارخانه": 5000,
		"انبار": 10000,
		"معدن": 200,
		"نیروگاه": 100
	})
	physical["energy_fuel"] = physical.get("energy_fuel", {
		"پمپ_بنزین": 4000,
		"ایستگاه_شارژ": 500,
		"شبکه_برق": 0.70
	})

	var events = []

	# رشد سکونتگاه‌ها با جمعیت
	var pop_growth = pop.get("growth_rate",0.012)
	physical["settlements"] += pop_growth * 100.0
	physical["housing_units"] += pop_growth * physical["housing_units"] * 0.5

	# کمبود مسکن = تقاضا - عرضه
	var housing_demand = pop.get("total",85_000_000) / 3.0  # هر خانوار 3 نفر
	var housing_shortage = (housing_demand - physical["housing_units"]) / housing_demand
	physical["housing_shortage"] = clamp(housing_shortage, -0.2, 0.60)

	if physical["housing_shortage"] > 0.2 and Deterministic.chance(0.01):
		events.append({"type": "housing_crisis", "message": "بحران مسکن - کمبود %s٪" % str(int(physical["housing_shortage"]*100)), "shortage": physical["housing_shortage"]})

	# حمل‌ونقل با زیرساخت رشد می‌کند
	var infra_q = state.get("infrastructure",{}).get("quality",0.55)
	physical["transport"] += infra_q * 0.5

	# تأسیسات شهری با بودجه
	var facilities_budget = econ.get("budget_allocations",{}).get("زیرساخت",0.18) * econ.get("government_spending",0.0) * 0.2
	physical["facilities"] += facilities_budget / 1_000_000_000.0 * 0.1

	# خدمات عمومی
	if tick % 30 == 0:  # ماهانه
		physical["public_services"]["بیمارستان"] += 0.01
		physical["public_services"]["مدرسه"] += 0.1

	# تجاری
	if economy_growth(state) > 0.02 and Deterministic.chance(0.01):
		physical["commercial"]["فروشگاه"] += 10
		physical["commercial"]["رستوران"] += 5

	# اثرات زیست‌محیطی ساخت‌وساز
	if physical["settlements"] > 1500 and Deterministic.chance(0.005):
		events.append({"type": "urban_sprawl", "message": "گسترش شهری بی‌رویه - تخریب منابع طبیعی"})
		state["environment"]["forest_coverage"] = clamp(state.get("environment",{}).get("forest_coverage",0.30) - 0.001, 0.05, 0.70)

	# رویدادهای فیزیکی
	if infra_q < 0.4 and Deterministic.chance(0.012):
		events.append({"type": "infrastructure_decay", "message": "فرسودگی زیرساخت‌های فیزیکی - نیاز به بازسازی"})

	state["physical"] = physical
	return {"success": true, "state": state, "events": events}

func economy_growth(state: Dictionary) -> float:
	return state.get("economy",{}).get("growth_rate",0.02)
