extends BaseSystem
# ۳.۴۷ تأسیسات شهری - آب، برق، مخابرات، زباله، فاضلاب، روشنایی، پیاده‌رو، نگهداری

func compute(state: Dictionary, tick: int) -> Dictionary:
	var urban = state.get("urban_facilities", {})
	var infra = state.get("infrastructure", {})
	var pop = state.get("population", {})
	var econ = state.get("economy", {})
	var env = state.get("environment", {})

	urban["water_network"] = urban.get("water_network", 0.75)
	urban["electricity_grid"] = urban.get("electricity_grid", 0.70)
	urban["telecom_coverage"] = urban.get("telecom_coverage", 0.80)
	urban["5g_coverage"] = urban.get("5g_coverage", 0.25)
	urban["waste_collection"] = urban.get("waste_collection", 0.70)
	urban["waste_recycling"] = urban.get("waste_recycling", 0.15)
	urban["sewage_coverage"] = urban.get("sewage_coverage", 0.65)
	urban["street_lighting"] = urban.get("street_lighting", 0.60)
	urban["sidewalks"] = urban.get("sidewalks", 0.55)
	urban["parks_maintenance"] = urban.get("parks_maintenance", 0.60)
	urban["maintenance_cost"] = urban.get("maintenance_cost", 2_000_000_000.0)
	urban["leakage_water"] = urban.get("leakage_water", 0.25)
	urban["outage_hours"] = urban.get("outage_hours", 5.0)

	var events = []

	var budget_share = econ.get("budget_allocations",{}).get("زیرساخت",0.18) * 0.35
	var urban_budget = econ.get("government_spending",0.0) * budget_share
	var total_pop = pop.get("total",85_000_000.0)
	var infra_q = infra.get("quality",0.55)
	var digital = state.get("technology",{}).get("branches",{}).get("دیجیتال",0.20)

	# آب
	var water_target = 0.65 + budget_share*2.2 + infra_q*0.25 + 0.10
	urban["water_network"] = clamp(urban["water_network"]*0.993 + water_target*0.007, 0.25, 0.99)
	urban["leakage_water"] = clamp((1.0 - urban["water_network"])*0.4 + 0.05, 0.05, 0.50)

	# برق
	var electricity_target = 0.60 + state.get("resources",{}).get("inventory",{}).get("برق",100.0)/100.0*0.20 + budget_share*1.6 + infra_q*0.15
	urban["electricity_grid"] = clamp(urban["electricity_grid"]*0.993 + electricity_target*0.007, 0.25, 0.99)
	urban["outage_hours"] = clamp((1.0 - urban["electricity_grid"])*20.0 + Deterministic.next_range(0.0,2.0), 0.2, 40.0)

	# مخابرات و 5G
	var telecom_target = 0.70 + digital*0.35 + budget_share*0.8 + infra_q*0.15
	urban["telecom_coverage"] = clamp(urban["telecom_coverage"]*0.992 + telecom_target*0.008, 0.30, 0.995)
	urban["5g_coverage"] = clamp(urban["5g_coverage"] + digital*0.001 + urban["telecom_coverage"]*0.0005, 0.05, 0.85)

	# زباله
	var waste_per_capita = 0.8
	var total_waste = total_pop * waste_per_capita / 1000.0
	urban["waste_collection"] = clamp(urban["waste_collection"]*0.994 + (budget_share*1.5 + infra_q*0.3 + 0.3)*0.006, 0.25, 0.99)
	urban["waste_recycling"] = clamp(urban["waste_recycling"]*0.997 + (env.get("recycling_rate",0.15) if env.has("recycling_rate") else 0.15 -0.15)*0.002 + 0.0003, 0.03, 0.75)

	# فاضلاب
	urban["sewage_coverage"] = clamp(urban["sewage_coverage"]*0.995 + (budget_share*1.2 + infra_q*0.2 + 0.4)*0.005, 0.20, 0.96)

	# روشنایی و پیاده‌رو
	urban["street_lighting"] = clamp(urban["street_lighting"]*0.996 + (urban["electricity_grid"]*0.6 + budget_share*1.0 + 0.2)*0.004, 0.15, 0.96)
	urban["sidewalks"] = clamp(urban["sidewalks"]*0.995 + (infra_q*0.4 + budget_share*0.8 + 0.2)*0.005, 0.15, 0.90)
	urban["parks_maintenance"] = clamp(urban["parks_maintenance"]*0.994 + (budget_share*1.0 + env.get("green_energy",0.20)*0.3 + 0.3)*0.006, 0.20, 0.95)

	# هزینه
	urban["maintenance_cost"] = total_waste * 120000.0 + urban["water_network"]*1_100_000_000.0 + urban["electricity_grid"]*800_000_000.0
	urban["maintenance_cost"] *= (1.0 + econ.get("inflation",0.08)/365.0)

	# اثر بر بهداشت و محیط و رضایت
	var waste_effect = (1.0 - urban["waste_collection"])*0.30 + (1.0 - urban["sewage_coverage"])*0.20 + urban["leakage_water"]*0.1
	state["health"]["quality"] = clamp(state.get("health",{}).get("quality",0.60) - waste_effect*0.0008, 0.1, 0.95)
	var pollution_base = state.get("environment",{}).get("air_quality",0.60)
	state["environment"]["air_quality"] = clamp(pollution_base + waste_effect*0.0002, 0.1, 0.95) if state["environment"].has("air_quality") else state["environment"]
	state["population"]["happiness"] = clamp(state.get("population",{}).get("happiness",0.60) + (urban["waste_collection"]-0.5)*0.0004 + (urban["street_lighting"]-0.5)*0.0002, 0.05, 0.95)

	# رویدادها
	if urban["waste_collection"] < 0.48 and Deterministic.chance(0.014):
		events.append({"type":"waste_crisis","collection": urban["waste_collection"], "message":"بحران زباله - انباشت در خیابان‌ها، بوی تعفن"})

	if urban["water_network"] < 0.50 and Deterministic.chance(0.012):
		events.append({"type":"water_shortage_urban","water": urban["water_network"], "leakage": urban["leakage_water"], "message":"قطع آب محلات - فرسودگی شبکه، هدررفت %d٪" % int(urban["leakage_water"]*100.0)})

	if urban["electricity_grid"] < 0.48 and Deterministic.chance(0.011):
		events.append({"type":"blackout","grid": urban["electricity_grid"], "outage": urban["outage_hours"], "message":"خاموشی گسترده - %d ساعت قطعی هفتگی" % int(urban["outage_hours"])})

	if urban["waste_recycling"] > 0.40 and Deterministic.chance(0.007):
		events.append({"type":"recycling_success","recycling": urban["waste_recycling"], "message":"جهش بازیافت - %d٪ زباله بازیافت می‌شود" % int(urban["waste_recycling"]*100.0)})

	if urban["5g_coverage"] > 0.60 and tick % 180 == 0 and Deterministic.chance(0.02):
		events.append({"type":"5g_milestone","coverage": urban["5g_coverage"], "message":"پوشش 5G ۶۰٪ - شهر هوشمند"})

	state["urban_facilities"] = urban
	
	# ── لایه واقع‌گرایانه اختصاصی تأسیسات شهری (جایگزین قالب خودکار) — بخش ۳.۴۷ ──
	# هزینه نگهداری واقعی: تابع جمعیت و تورم — بودجه ناکافی یعنی فرسودگی شبکه‌ها
	urban["maintenance_cost"] = float(total_pop) * 28.0 * (1.0 + float(econ.get("inflation", 0.08)))
	# قطعی برق: شبکه ضعیف یعنی ساعت‌های خاموشی بیشتر — تابستان اوج می‌گیرد
	var outage_target = maxf((0.90 - float(urban.get("electricity_grid", 0.70))) * 15.0, 0.2)
	urban["outage_hours"] = clampf(float(urban.get("outage_hours", 5.0)) * 0.995 + outage_target * 0.005, 0.2, 20.0)
	# قابلیت اتکای برق برای اقتصاد (سیستم اقتصاد می‌تواند بخواند)
	econ["power_reliability"] = clampf(1.0 - float(urban.get("outage_hours", 5.0)) / 20.0, 0.05, 1.0)
	state["economy"] = econ
	# فاضلاب ضعیف → مخاطره بهداشتی شهری (شیوع بیماری‌های آب‌بخوری)
	if float(urban.get("sewage_coverage", 0.65)) < 0.50 and Deterministic.chance(0.004):
		events.append({"type": "sewage_health_risk", "message": "نشت فاضلاب به چاه‌های آب شرب - هشدار بیماری‌های گوارشی شهری"})
	# هدررفت آب بالا → بحران آبی تشدید می‌شود
	if float(urban.get("leakage_water", 0.25)) > 0.30 and Deterministic.chance(0.004):
		events.append({"type": "water_loss_warning", "message": "یک‌سوم آب شرب شهرها در شبکه فرسوده هدر می‌رود - ضرورت بازسازی", "leakage": urban["leakage_water"]})
	# زباله جمع‌نشده → بحران بهداشت محیط
	if float(urban.get("waste_collection", 0.70)) < 0.60 and Deterministic.chance(0.004):
		events.append({"type": "waste_pileup", "message": "انباشت زباله در معابر شهرها - نارضایتی و مخاطره بهداشتی"})
	# توسعه 5G: تابع تلفن‌همراه و سرمایه‌گذاری دیجیتال، نه شبح
	urban["5g_coverage"] = clampf(float(urban.get("5g_coverage", 0.25)) + float(digital) * 0.0008 - 0.0001, 0.02, 0.92)
	state["urban_facilities"] = urban

	return {"success":true,"state":state,"events":events}
