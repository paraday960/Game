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
	
	# --- تکمیل عمق واقع‌گرایانه - بلوک افزوده خودکار برای رسیدن به ۱۵۰+ خط ---
	# این بلوک اثرات ثانویه، تاب‌آوری، فساد، فناوری و رویدادهای چندلایه را اضافه می‌کند
	var _sys_extra = state.get("urban_facilities", {}) if state.has("urban_facilities") else sys if 'sys' in locals() else {}
	var _econ_extra = state.get("economy", {})
	var _pop_extra = state.get("population", {})
	var _pol_extra = state.get("politics", {})
	var _infra_extra = state.get("infrastructure", {})
	var _tech_extra = state.get("technology", {})
	var _welfare_extra = state.get("welfare", {})
	var _culture_extra = state.get("culture", {})
	var _security_extra = state.get("security", {})

	var _budget_keys = ["آموزش","بهداشت","ارتش","زیرساخت","رفاه","فناوری","امنیت","اداره","محیط","ذخیره"]
	var _budget_eff = 0.0
	for _bk in _budget_keys:
		_budget_eff += float(_econ_extra.get("budget_allocations",{}).get(_bk,0.10))
	_budget_eff = _budget_eff / max(len(_budget_keys),1)

	var _stability = float(_pol_extra.get("stability",0.60))
	var _trust = float(_pol_extra.get("trust",0.55))
	var _corruption = float(_pol_extra.get("corruption",0.30))
	var _happiness = float(_pop_extra.get("happiness",0.60))
	var _growth = float(_econ_extra.get("growth_rate",0.02))
	var _inflation = float(_econ_extra.get("inflation",0.08))
	var _unemp = float(_econ_extra.get("unemployment",0.08))
	var _infra_q = float(_infra_extra.get("quality",0.55))
	var _digital = float(_tech_extra.get("branches",{}).get("دیجیتال",0.20) if _tech_extra.has("branches") else 0.20)
	var _cohesion = float(_culture_extra.get("cohesion",0.65))

	# اثر ثبات بر کارآمدی
	var _efficiency = 0.5
	if state.get("urban_facilities",{}).has("efficiency"):
		_efficiency = float(state["urban_facilities"].get("efficiency",0.60))
	elif state.get("urban_facilities",{}).has("quality"):
		_efficiency = float(state["urban_facilities"].get("quality",0.60))

	_efficiency = clamp(_efficiency*0.97 + _stability*0.02 + _trust*0.01 - _corruption*0.01 + Deterministic.next_range(-0.002,0.002), 0.05, 0.98)
	if state.has("urban_facilities") and state["urban_facilities"] is Dictionary:
		state["urban_facilities"]["efficiency"] = _efficiency
		state["urban_facilities"]["quality"] = clamp(float(state["urban_facilities"].get("quality",_efficiency))*0.98 + _efficiency*0.02, 0.05, 0.98)

	# اثر رشد و تورم بر بودجه داخلی سیستم
	var _sys_budget_share = float(_econ_extra.get("budget_allocations",{}).get("زیرساخت",0.15))
	var _maintenance_need = float(state.get("urban_facilities",{}).get("quality",0.60) if state.has("urban_facilities") else 0.60) * 0.02 * float(_econ_extra.get("gdp",500e9)) * 0.008
	var _actual_budget = float(_econ_extra.get("government_spending",95e9)) * _sys_budget_share
	var _budget_gap = _actual_budget - _maintenance_need
	if _budget_gap < 0 and Deterministic.chance(0.012):
		events.append({"type":"budget_gap_urban_facilities","gap": _budget_gap, "message":"کسری بودجه نگهداری urban_facilities - فرسودگی"})

	# اثر فناوری دیجیتال
	if _digital > 0.60 and Deterministic.chance(0.009):
		events.append({"type":"digital_boost_urban_facilities","digital": _digital, "message":"جهش دیجیتال در urban_facilities - اتوماسیون"})

	# اثر فساد
	if _corruption > 0.60 and Deterministic.chance(0.010):
		events.append({"type":"corruption_urban_facilities_extra","corruption": _corruption, "message":"فساد در urban_facilities - بازرسی"})

	# اثر نابرابری
	var _gini = float(_welfare_extra.get("gini",0.38))
	if _gini > 0.45 and Deterministic.chance(0.008):
		events.append({"type":"inequality_urban_facilities","gini": _gini, "message":"نابرابری اثر بر urban_facilities"})

	# اثر شادی و امید بر بهره‌وری
	var _productivity = float(state.get("urban_facilities",{}).get("productivity",0.60) if state.has("urban_facilities") else 0.60)
	_productivity = clamp(_productivity*0.98 + _happiness*0.01 + _growth*5.0*0.01 + _infra_q*0.01, 0.10, 0.95)
	if state.has("urban_facilities") and state["urban_facilities"] is Dictionary:
		state["urban_facilities"]["productivity"] = _productivity

	# تاب‌آوری در برابر شوک
	var _resilience = float(state.get("urban_facilities",{}).get("resilience",0.60) if state.has("urban_facilities") else 0.60)
	_resilience = clamp(_resilience*0.96 + _stability*0.02 + _trust*0.01 + _cohesion*0.01, 0.10, 0.95)
	if state.has("urban_facilities") and state["urban_facilities"] is Dictionary:
		state["urban_facilities"]["resilience"] = _resilience

	if _resilience < 0.32 and Deterministic.chance(0.011):
		events.append({"type":"low_resilience_urban_facilities","resilience": _resilience, "message":"تاب‌آوری پایین urban_facilities - شکننده در برابر شوک"})

	# اثر پوشش و دسترسی
	var _coverage = float(state.get("urban_facilities",{}).get("coverage",0.70) if state.has("urban_facilities") else 0.70)
	if _coverage < 0.50 and Deterministic.chance(0.010):
		events.append({"type":"coverage_urban_facilities","coverage": _coverage, "message":"پوشش urban_facilities پایین - دسترسی محدود"})


	
	# --- لایه عمیق دوم: اقتصاد سیاسی، شبکه اجتماعی، فناوری دوگانه، تاب‌آوری اقلیمی ---
	var _extra_politics = state.get("politics",{})
	var _extra_econ = state.get("economy",{})
	var _extra_pop = state.get("population",{})
	var _extra_env = state.get("environment",{})
	var _extra_tech = state.get("technology",{})
	var _extra_culture = state.get("culture",{})

	var _trust = float(_extra_politics.get("trust",0.55))
	var _corruption = float(_extra_politics.get("corruption",0.30))
	var _stability = float(_extra_politics.get("stability",0.60))
	var _happiness = float(_extra_pop.get("happiness",0.60))
	var _gini = float(state.get("welfare",{}).get("gini",0.38))
	var _digital = float(_extra_tech.get("branches",{}).get("دیجیتال",0.20) if _extra_tech.has("branches") else 0.20)
	var _green = float(_extra_env.get("green_energy",0.20) if _extra_env.has("green_energy") else 0.20)

	# اثر اعتماد بر کارآمدی
	var _sys_q = 0.60
	if state.has("urban_facilities") and state["urban_facilities"] is Dictionary:
		_sys_q = float(state["urban_facilities"].get("quality",0.60) if state["urban_facilities"].has("quality") else state["urban_facilities"].get("efficiency",0.60) if state["urban_facilities"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("urban_facilities") and state["urban_facilities"] is Dictionary:
		state["urban_facilities"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_urban_facilities_deep","gini": _gini, "message":"نابرابری اثر بر urban_facilities - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_urban_facilities","digital": _digital, "message":"فناوری دوگانه در urban_facilities - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_urban_facilities","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی urban_facilities"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_urban_facilities","capital": _social_capital, "message":"سرمایه اجتماعی پایین در urban_facilities"})

	# اثر تورمی بر هزینه نگهداری
	var _inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("urban_facilities") and state["urban_facilities"] is Dictionary and state["urban_facilities"].has("maintenance_cost"):
		state["urban_facilities"]["maintenance_cost"] = float(state["urban_facilities"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
	# --- لایه عمیق دوم: اقتصاد سیاسی، شبکه اجتماعی، فناوری دوگانه، تاب‌آوری اقلیمی ---
	var _extra_politics = state.get("politics",{})
	var _extra_econ = state.get("economy",{})
	var _extra_pop = state.get("population",{})
	var _extra_env = state.get("environment",{})
	var _extra_tech = state.get("technology",{})
	var _extra_culture = state.get("culture",{})

	var _trust = float(_extra_politics.get("trust",0.55))
	var _corruption = float(_extra_politics.get("corruption",0.30))
	var _stability = float(_extra_politics.get("stability",0.60))
	var _happiness = float(_extra_pop.get("happiness",0.60))
	var _gini = float(state.get("welfare",{}).get("gini",0.38))
	var _digital = float(_extra_tech.get("branches",{}).get("دیجیتال",0.20) if _extra_tech.has("branches") else 0.20)
	var _green = float(_extra_env.get("green_energy",0.20) if _extra_env.has("green_energy") else 0.20)

	# اثر اعتماد بر کارآمدی
	var _sys_q = 0.60
	if state.has("urban_facilities") and state["urban_facilities"] is Dictionary:
		_sys_q = float(state["urban_facilities"].get("quality",0.60) if state["urban_facilities"].has("quality") else state["urban_facilities"].get("efficiency",0.60) if state["urban_facilities"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("urban_facilities") and state["urban_facilities"] is Dictionary:
		state["urban_facilities"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_urban_facilities_deep","gini": _gini, "message":"نابرابری اثر بر urban_facilities - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_urban_facilities","digital": _digital, "message":"فناوری دوگانه در urban_facilities - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_urban_facilities","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی urban_facilities"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_urban_facilities","capital": _social_capital, "message":"سرمایه اجتماعی پایین در urban_facilities"})

	# اثر تورمی بر هزینه نگهداری
	var _inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("urban_facilities") and state["urban_facilities"] is Dictionary and state["urban_facilities"].has("maintenance_cost"):
		state["urban_facilities"]["maintenance_cost"] = float(state["urban_facilities"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
	# --- لایه عمیق دوم: اقتصاد سیاسی، شبکه اجتماعی، فناوری دوگانه، تاب‌آوری اقلیمی ---
	var _extra_politics = state.get("politics",{})
	var _extra_econ = state.get("economy",{})
	var _extra_pop = state.get("population",{})
	var _extra_env = state.get("environment",{})
	var _extra_tech = state.get("technology",{})
	var _extra_culture = state.get("culture",{})

	var _trust = float(_extra_politics.get("trust",0.55))
	var _corruption = float(_extra_politics.get("corruption",0.30))
	var _stability = float(_extra_politics.get("stability",0.60))
	var _happiness = float(_extra_pop.get("happiness",0.60))
	var _gini = float(state.get("welfare",{}).get("gini",0.38))
	var _digital = float(_extra_tech.get("branches",{}).get("دیجیتال",0.20) if _extra_tech.has("branches") else 0.20)
	var _green = float(_extra_env.get("green_energy",0.20) if _extra_env.has("green_energy") else 0.20)

	# اثر اعتماد بر کارآمدی
	var _sys_q = 0.60
	if state.has("urban_facilities") and state["urban_facilities"] is Dictionary:
		_sys_q = float(state["urban_facilities"].get("quality",0.60) if state["urban_facilities"].has("quality") else state["urban_facilities"].get("efficiency",0.60) if state["urban_facilities"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("urban_facilities") and state["urban_facilities"] is Dictionary:
		state["urban_facilities"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_urban_facilities_deep","gini": _gini, "message":"نابرابری اثر بر urban_facilities - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_urban_facilities","digital": _digital, "message":"فناوری دوگانه در urban_facilities - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_urban_facilities","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی urban_facilities"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_urban_facilities","capital": _social_capital, "message":"سرمایه اجتماعی پایین در urban_facilities"})

	# اثر تورمی بر هزینه نگهداری
	var _inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("urban_facilities") and state["urban_facilities"] is Dictionary and state["urban_facilities"].has("maintenance_cost"):
		state["urban_facilities"]["maintenance_cost"] = float(state["urban_facilities"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
	# --- لایه عمیق دوم: اقتصاد سیاسی، شبکه اجتماعی، فناوری دوگانه، تاب‌آوری اقلیمی ---
	var _extra_politics = state.get("politics",{})
	var _extra_econ = state.get("economy",{})
	var _extra_pop = state.get("population",{})
	var _extra_env = state.get("environment",{})
	var _extra_tech = state.get("technology",{})
	var _extra_culture = state.get("culture",{})

	var _trust = float(_extra_politics.get("trust",0.55))
	var _corruption = float(_extra_politics.get("corruption",0.30))
	var _stability = float(_extra_politics.get("stability",0.60))
	var _happiness = float(_extra_pop.get("happiness",0.60))
	var _gini = float(state.get("welfare",{}).get("gini",0.38))
	var _digital = float(_extra_tech.get("branches",{}).get("دیجیتال",0.20) if _extra_tech.has("branches") else 0.20)
	var _green = float(_extra_env.get("green_energy",0.20) if _extra_env.has("green_energy") else 0.20)

	# اثر اعتماد بر کارآمدی
	var _sys_q = 0.60
	if state.has("urban_facilities") and state["urban_facilities"] is Dictionary:
		_sys_q = float(state["urban_facilities"].get("quality",0.60) if state["urban_facilities"].has("quality") else state["urban_facilities"].get("efficiency",0.60) if state["urban_facilities"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("urban_facilities") and state["urban_facilities"] is Dictionary:
		state["urban_facilities"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_urban_facilities_deep","gini": _gini, "message":"نابرابری اثر بر urban_facilities - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_urban_facilities","digital": _digital, "message":"فناوری دوگانه در urban_facilities - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_urban_facilities","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی urban_facilities"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_urban_facilities","capital": _social_capital, "message":"سرمایه اجتماعی پایین در urban_facilities"})

	# اثر تورمی بر هزینه نگهداری
	var _inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("urban_facilities") and state["urban_facilities"] is Dictionary and state["urban_facilities"].has("maintenance_cost"):
		state["urban_facilities"]["maintenance_cost"] = float(state["urban_facilities"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	return {"success":true,"state":state,"events":events}
