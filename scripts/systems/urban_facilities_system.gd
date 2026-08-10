extends BaseSystem
# ۳.۴۷ تأسیسات شهری - آب، برق، مخابرات، زباله - بخش ۳.۴۷

func compute(state: Dictionary, tick: int) -> Dictionary:
	var urban = state.get("urban_facilities", {})
	var infra = state.get("infrastructure", {})
	var pop = state.get("population", {})
	var econ = state.get("economy", {})
	var env = state.get("environment", {})

	urban["water_network"] = urban.get("water_network", 0.75)
	urban["electricity_grid"] = urban.get("electricity_grid", 0.70)
	urban["telecom_coverage"] = urban.get("telecom_coverage", 0.80)
	urban["waste_collection"] = urban.get("waste_collection", 0.70)
	urban["waste_recycling"] = urban.get("waste_recycling", 0.15)
	urban["sewage_coverage"] = urban.get("sewage_coverage", 0.65)
	urban["street_lighting"] = urban.get("street_lighting", 0.60)
	urban["maintenance_cost"] = urban.get("maintenance_cost", 2_000_000_000.0)

	var events = []

	var urban_budget_share = econ.get("budget_allocations",{}).get("زیرساخت",0.18) * 0.3
	var urban_budget = econ.get("government_spending",0.0) * urban_budget_share

	# آب
	var water_target = 0.7 + urban_budget_share * 2.0 + infra.get("quality",0.55) * 0.2
	urban["water_network"] = clamp(urban["water_network"] * 0.995 + water_target * 0.005, 0.3, 0.98)

	# برق
	var elec_target = 0.65 + state.get("resources",{}).get("inventory",{}).get("برق",100.0)/100.0 * 0.2 + urban_budget_share * 1.5
	urban["electricity_grid"] = clamp(urban["electricity_grid"] * 0.995 + elec_target * 0.005, 0.3, 0.98)

	# مخابرات
	var telecom_target = 0.75 + state.get("technology",{}).get("branches",{}).get("دیجیتال",0.20) * 0.3 + urban_budget_share * 1.0
	urban["telecom_coverage"] = clamp(urban["telecom_coverage"] * 0.995 + telecom_target * 0.005, 0.3, 0.99)

	# زباله - جمع‌آوری و بازیافت
	var waste_per_capita = 0.8  # کیلوگرم روزانه
	var total_waste = pop.get("total",85_000_000) * waste_per_capita / 1000.0  # تن روزانه
	urban["waste_collection"] = clamp(urban["waste_collection"] + (urban_budget_share - 0.05) * 0.002, 0.3, 0.98)
	urban["waste_recycling"] = clamp(urban["waste_recycling"] + (env.get("recycling_rate",0.15) - 0.15) * 0.001 + 0.0002, 0.05, 0.70)

	# فاضلاب
	urban["sewage_coverage"] = clamp(urban["sewage_coverage"] + (urban_budget_share - 0.05) * 0.001, 0.2, 0.95)

	# روشنایی معابر
	urban["street_lighting"] = clamp(urban["street_lighting"] + (urban["electricity_grid"] - 0.5) * 0.001, 0.2, 0.95)

	# هزینه نگهداری
	urban["maintenance_cost"] = total_waste * 100000.0 + urban["water_network"] * 1_000_000_000.0

	# اثر بر بهداشت و محیط
	var waste_effect = (1.0 - urban["waste_collection"]) * 0.3 + (1.0 - urban["sewage_coverage"]) * 0.2
	state["health"]["quality"] = clamp(state.get("health",{}).get("quality",0.60) - waste_effect * 0.001, 0.1, 0.95)
	state["environment"]["pollution"] = clamp(state.get("environment",{}).get("pollution",0.4) + waste_effect * 0.001, 0.0, 1.0)
	state["environment"]["water_quality"] = clamp(state.get("environment",{}).get("water_quality",0.65) + (urban["water_network"] - 0.5) * 0.001, 0.1, 0.95)

	# رویدادها
	if urban["waste_collection"] < 0.5 and Deterministic.chance(0.012):
		events.append({"type": "waste_crisis", "message": "بحران زباله شهری - انباشت زباله در خیابان‌ها!", "collection": urban["waste_collection"]})

	if urban["water_network"] < 0.5 and Deterministic.chance(0.01):
		events.append({"type": "water_shortage_urban", "message": "قطع آب در برخی محلات - فرسودگی شبکه آبرسانی"})

	if urban["electricity_grid"] < 0.5 and Deterministic.chance(0.01):
		events.append({"type": "blackout", "message": "خاموشی گسترده برق - فشار بر شبکه"})

	if urban["waste_recycling"] > 0.4 and Deterministic.chance(0.006):
		events.append({"type": "recycling_success", "message": "موفقیت بازیافت - اقتصاد چرخشی و کاهش آلودگی"})

	state["urban_facilities"] = urban
	return {"success": true, "state": state, "events": events}
