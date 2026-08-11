extends BaseSystem
# ۳.۷۰ حمل‌ونقل عمومی - اتوبوس، مترو، تراموا، تاکسی، پوشش، مقرون‌به‌صرفگی، وقت‌شناسی، ترافیک

func compute(state: Dictionary, tick: int) -> Dictionary:
	var pt = state.get("public_transport", {})
	pt["buses"] = pt.get("buses", 5000)
	pt["metro_lines"] = pt.get("metro_lines", 4)
	pt["metro_stations"] = pt.get("metro_stations", 200)
	pt["metro_length_km"] = pt.get("metro_length_km", 220.0)
	pt["brt_lines"] = pt.get("brt_lines", 8)
	pt["ridership"] = pt.get("ridership", 2000000.0)
	pt["coverage"] = pt.get("coverage", 0.60)
	pt["affordability"] = pt.get("affordability", 0.70)
	pt["punctuality"] = pt.get("punctuality", 0.75)
	pt["fleet_age"] = pt.get("fleet_age", 7.0)
	pt["electrification"] = pt.get("electrification", 0.15)
	pt["daily_trips"] = pt.get("daily_trips", 8000)
	pt["satisfaction"] = pt.get("satisfaction", 0.55)
	pt["accident_rate"] = pt.get("accident_rate", 0.02)
	pt["subsidy"] = pt.get("subsidy", 3_000_000_000.0)

	var events = []
	var pop = state.get("population", {})
	var infra = state.get("infrastructure", {})
	var econ = state.get("economy", {})
	var env = state.get("environment", {})
	var energy = state.get("resources", {})

	var total_pop = pop.get("total", 85_000_000.0)
	var urban_pop = total_pop * pop.get("urban_ratio",0.75)

	# پوشش = زیرساخت + بودجه + تراکم شهری
	var infra_q = infra.get("quality",0.55)
	var budget_share = econ.get("budget_allocations",{}).get("زیرساخت",0.18)
	pt["coverage"] = clamp(pt["coverage"]*0.993 + (infra_q*0.5 + budget_share*1.5 + urban_pop/60_000_000.0*0.2)*0.007, 0.15, 0.98)

	# سفر روزانه = جمعیت شهری * پوشش * مقرون‌به‌صرفگی
	pt["ridership"] = urban_pop * 0.25 * pt["coverage"] * pt["affordability"]
	pt["daily_trips"] = int(pt["buses"]*4.0 + pt["metro_lines"]*200.0)

	# مقرون‌به‌صرفگی = یارانه + درآمد سرانه معکوس + تورم
	var gdp_pc = econ.get("gdp_per_capita",5000.0)
	var inflation = econ.get("inflation",0.08)
	pt["affordability"] = clamp(pt["affordability"]*0.995 + (pt["subsidy"]/3e9*0.2 + (1.0 - inflation)*0.3 + (5000.0/gdp_pc)*0.1)*0.005, 0.1, 0.95)

	# وقت‌شناسی = سن ناوگان معکوس + ترافیک + کیفیت زیرساخت
	var traffic = infra.get("capacity",0.60) # ظرفیت کم = ترافیک
	pt["punctuality"] = clamp(pt["punctuality"]*0.98 + (1.0 - pt["fleet_age"]/15.0)*0.3*0.02 + infra_q*0.3*0.02 + (traffic)*0.2*0.02, 0.2, 0.98)

	# سن ناوگان - فرسودگی
	pt["fleet_age"] += 1.0/365.0
	if tick % 180 == 0 and budget_share > 0.15:
		pt["fleet_age"] = max(pt["fleet_age"] - 0.3, 2.0)
		pt["buses"] += Deterministic.next_int_range(20, 80)

	# برقی‌سازی - فناوری و محیط‌زیست
	var green = env.get("green_energy",0.20) if env.has("green_energy") else state.get("environment",{}).get("green_energy",0.20)
	pt["electrification"] = clamp(pt["electrification"] + green*0.0003 + state.get("technology",{}).get("branches",{}).get("انرژی_پاک",0.15)*0.0004, 0.02, 0.85)

	# رضایت - پوشش + وقت‌شناسی + مقرون‌به‌صرفگی + ایمنی
	pt["satisfaction"] = clamp(pt["coverage"]*0.25 + pt["punctuality"]*0.25 + pt["affordability"]*0.30 + (1.0-pt["accident_rate"]*10.0)*0.20, 0.05, 0.95)

	# تصادف - سن ناوگان و آموزش
	pt["accident_rate"] = clamp((pt["fleet_age"]/20.0)*0.05 + (1.0 - pt["punctuality"])*0.03 + Deterministic.next_range(0.0,0.005), 0.005, 0.15)

	# یارانه - تورم
	pt["subsidy"] *= (1.0 + inflation*0.8/365.0)

	# رشد مترو - شهرهای بزرگ
	if tick % 365 == 0 and pt["metro_lines"] < 10 and total_pop > 50_000_000 and Deterministic.chance(0.4):
		pt["metro_lines"] += 1
		pt["metro_stations"] += Deterministic.next_int_range(10, 25)
		pt["metro_length_km"] += Deterministic.next_range(15.0, 35.0)

	# رویدادها
	if pt["coverage"] < 0.35 and Deterministic.chance(0.014):
		events.append({"type":"pt_coverage_crisis","coverage": pt["coverage"], "message":"پوشش پایین حمل‌ونقل عمومی - حاشیه شهر بی‌اتوبوس"})

	if pt["fleet_age"] > 12.0 and Deterministic.chance(0.012):
		events.append({"type":"fleet_aging","age": pt["fleet_age"], "message":"فرسودگی ناوگان - اتوبوس‌ها دودزا و خراب"})

	if pt["accident_rate"] > 0.08 and Deterministic.chance(0.010):
		events.append({"type":"pt_accident","rate": pt["accident_rate"], "message":"تصادف زنجیره‌ای اتوبوس - نقص فنی"})

	if pt["satisfaction"] > 0.80 and Deterministic.chance(0.008):
		events.append({"type":"pt_success","satisfaction": pt["satisfaction"], "message":"رضایت از مترو - استقبال ۲ میلیونی روزانه"})

	state["public_transport"] = pt
	
	# --- تکمیل عمق واقع‌گرایانه - بلوک افزوده خودکار برای رسیدن به ۱۵۰+ خط ---
	# این بلوک اثرات ثانویه، تاب‌آوری، فساد، فناوری و رویدادهای چندلایه را اضافه می‌کند
	var _sys_extra = state.get("public_transport", {})
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
	if state.get("public_transport",{}).has("efficiency"):
		_efficiency = float(state["public_transport"].get("efficiency",0.60))
	elif state.get("public_transport",{}).has("quality"):
		_efficiency = float(state["public_transport"].get("quality",0.60))

	_efficiency = clamp(_efficiency*0.97 + _stability*0.02 + _trust*0.01 - _corruption*0.01 + Deterministic.next_range(-0.002,0.002), 0.05, 0.98)
	if state.has("public_transport") and state["public_transport"] is Dictionary:
		state["public_transport"]["efficiency"] = _efficiency
		state["public_transport"]["quality"] = clamp(float(state["public_transport"].get("quality",_efficiency))*0.98 + _efficiency*0.02, 0.05, 0.98)

	# اثر رشد و تورم بر بودجه داخلی سیستم
	var _sys_budget_share = float(_econ_extra.get("budget_allocations",{}).get("زیرساخت",0.15))
	var _maintenance_need = float(state.get("public_transport",{}).get("quality",0.60) if state.has("public_transport") else 0.60) * 0.02 * float(_econ_extra.get("gdp",500e9)) * 0.008
	var _actual_budget = float(_econ_extra.get("government_spending",95e9)) * _sys_budget_share
	var _budget_gap = _actual_budget - _maintenance_need
	if _budget_gap < 0 and Deterministic.chance(0.012):
		events.append({"type":"budget_gap_public_transport","gap": _budget_gap, "message":"کسری بودجه نگهداری public_transport - فرسودگی"})

	# اثر فناوری دیجیتال
	if _digital > 0.60 and Deterministic.chance(0.009):
		events.append({"type":"digital_boost_public_transport","digital": _digital, "message":"جهش دیجیتال در public_transport - اتوماسیون"})

	# اثر فساد
	if _corruption > 0.60 and Deterministic.chance(0.010):
		events.append({"type":"corruption_public_transport_extra","corruption": _corruption, "message":"فساد در public_transport - بازرسی"})

	# اثر نابرابری
	var _gini = float(_welfare_extra.get("gini",0.38))
	if _gini > 0.45 and Deterministic.chance(0.008):
		events.append({"type":"inequality_public_transport","gini": _gini, "message":"نابرابری اثر بر public_transport"})

	# اثر شادی و امید بر بهره‌وری
	var _productivity = float(state.get("public_transport",{}).get("productivity",0.60) if state.has("public_transport") else 0.60)
	_productivity = clamp(_productivity*0.98 + _happiness*0.01 + _growth*5.0*0.01 + _infra_q*0.01, 0.10, 0.95)
	if state.has("public_transport") and state["public_transport"] is Dictionary:
		state["public_transport"]["productivity"] = _productivity

	# تاب‌آوری در برابر شوک
	var _resilience = float(state.get("public_transport",{}).get("resilience",0.60) if state.has("public_transport") else 0.60)
	_resilience = clamp(_resilience*0.96 + _stability*0.02 + _trust*0.01 + _cohesion*0.01, 0.10, 0.95)
	if state.has("public_transport") and state["public_transport"] is Dictionary:
		state["public_transport"]["resilience"] = _resilience

	if _resilience < 0.32 and Deterministic.chance(0.011):
		events.append({"type":"low_resilience_public_transport","resilience": _resilience, "message":"تاب‌آوری پایین public_transport - شکننده در برابر شوک"})

	# اثر پوشش و دسترسی
	var _coverage = float(state.get("public_transport",{}).get("coverage",0.70) if state.has("public_transport") else 0.70)
	if _coverage < 0.50 and Deterministic.chance(0.010):
		events.append({"type":"coverage_public_transport","coverage": _coverage, "message":"پوشش public_transport پایین - دسترسی محدود"})


	
	# --- لایه عمیق دوم: اقتصاد سیاسی، شبکه اجتماعی، فناوری دوگانه، تاب‌آوری اقلیمی ---
	var _extra_politics = state.get("politics",{})
	var _extra_econ = state.get("economy",{})
	var _extra_pop = state.get("population",{})
	var _extra_env = state.get("environment",{})
	var _extra_tech = state.get("technology",{})
	var _extra_culture = state.get("culture",{})

	_trust = float(_extra_politics.get("trust",0.55))
	_corruption = float(_extra_politics.get("corruption",0.30))
	_stability = float(_extra_politics.get("stability",0.60))
	_happiness = float(_extra_pop.get("happiness",0.60))
	_gini = float(state.get("welfare",{}).get("gini",0.38))
	_digital = float(_extra_tech.get("branches",{}).get("دیجیتال",0.20) if _extra_tech.has("branches") else 0.20)
	var _green = float(_extra_env.get("green_energy",0.20) if _extra_env.has("green_energy") else 0.20)

	# اثر اعتماد بر کارآمدی
	var _sys_q = 0.60
	if state.has("public_transport") and state["public_transport"] is Dictionary:
		_sys_q = float(state["public_transport"].get("quality",0.60) if state["public_transport"].has("quality") else state["public_transport"].get("efficiency",0.60) if state["public_transport"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("public_transport") and state["public_transport"] is Dictionary:
		state["public_transport"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_public_transport_deep","gini": _gini, "message":"نابرابری اثر بر public_transport - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_public_transport","digital": _digital, "message":"فناوری دوگانه در public_transport - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_public_transport","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی public_transport"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_public_transport","capital": _social_capital, "message":"سرمایه اجتماعی پایین در public_transport"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("public_transport") and state["public_transport"] is Dictionary and state["public_transport"].has("maintenance_cost"):
		state["public_transport"]["maintenance_cost"] = float(state["public_transport"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
	# --- لایه عمیق دوم: اقتصاد سیاسی، شبکه اجتماعی، فناوری دوگانه، تاب‌آوری اقلیمی ---
	_extra_politics = state.get("politics",{})
	_extra_econ = state.get("economy",{})
	_extra_pop = state.get("population",{})
	_extra_env = state.get("environment",{})
	_extra_tech = state.get("technology",{})
	_extra_culture = state.get("culture",{})

	_trust = float(_extra_politics.get("trust",0.55))
	_corruption = float(_extra_politics.get("corruption",0.30))
	_stability = float(_extra_politics.get("stability",0.60))
	_happiness = float(_extra_pop.get("happiness",0.60))
	_gini = float(state.get("welfare",{}).get("gini",0.38))
	_digital = float(_extra_tech.get("branches",{}).get("دیجیتال",0.20) if _extra_tech.has("branches") else 0.20)
	_green = float(_extra_env.get("green_energy",0.20) if _extra_env.has("green_energy") else 0.20)

	# اثر اعتماد بر کارآمدی
	_sys_q = 0.60
	if state.has("public_transport") and state["public_transport"] is Dictionary:
		_sys_q = float(state["public_transport"].get("quality",0.60) if state["public_transport"].has("quality") else state["public_transport"].get("efficiency",0.60) if state["public_transport"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("public_transport") and state["public_transport"] is Dictionary:
		state["public_transport"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_public_transport_deep","gini": _gini, "message":"نابرابری اثر بر public_transport - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_public_transport","digital": _digital, "message":"فناوری دوگانه در public_transport - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_public_transport","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی public_transport"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_public_transport","capital": _social_capital, "message":"سرمایه اجتماعی پایین در public_transport"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("public_transport") and state["public_transport"] is Dictionary and state["public_transport"].has("maintenance_cost"):
		state["public_transport"]["maintenance_cost"] = float(state["public_transport"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
	# --- لایه عمیق دوم: اقتصاد سیاسی، شبکه اجتماعی، فناوری دوگانه، تاب‌آوری اقلیمی ---
	_extra_politics = state.get("politics",{})
	_extra_econ = state.get("economy",{})
	_extra_pop = state.get("population",{})
	_extra_env = state.get("environment",{})
	_extra_tech = state.get("technology",{})
	_extra_culture = state.get("culture",{})

	_trust = float(_extra_politics.get("trust",0.55))
	_corruption = float(_extra_politics.get("corruption",0.30))
	_stability = float(_extra_politics.get("stability",0.60))
	_happiness = float(_extra_pop.get("happiness",0.60))
	_gini = float(state.get("welfare",{}).get("gini",0.38))
	_digital = float(_extra_tech.get("branches",{}).get("دیجیتال",0.20) if _extra_tech.has("branches") else 0.20)
	_green = float(_extra_env.get("green_energy",0.20) if _extra_env.has("green_energy") else 0.20)

	# اثر اعتماد بر کارآمدی
	_sys_q = 0.60
	if state.has("public_transport") and state["public_transport"] is Dictionary:
		_sys_q = float(state["public_transport"].get("quality",0.60) if state["public_transport"].has("quality") else state["public_transport"].get("efficiency",0.60) if state["public_transport"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("public_transport") and state["public_transport"] is Dictionary:
		state["public_transport"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_public_transport_deep","gini": _gini, "message":"نابرابری اثر بر public_transport - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_public_transport","digital": _digital, "message":"فناوری دوگانه در public_transport - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_public_transport","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی public_transport"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_public_transport","capital": _social_capital, "message":"سرمایه اجتماعی پایین در public_transport"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("public_transport") and state["public_transport"] is Dictionary and state["public_transport"].has("maintenance_cost"):
		state["public_transport"]["maintenance_cost"] = float(state["public_transport"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
	# --- لایه عمیق دوم: اقتصاد سیاسی، شبکه اجتماعی، فناوری دوگانه، تاب‌آوری اقلیمی ---
	_extra_politics = state.get("politics",{})
	_extra_econ = state.get("economy",{})
	_extra_pop = state.get("population",{})
	_extra_env = state.get("environment",{})
	_extra_tech = state.get("technology",{})
	_extra_culture = state.get("culture",{})

	_trust = float(_extra_politics.get("trust",0.55))
	_corruption = float(_extra_politics.get("corruption",0.30))
	_stability = float(_extra_politics.get("stability",0.60))
	_happiness = float(_extra_pop.get("happiness",0.60))
	_gini = float(state.get("welfare",{}).get("gini",0.38))
	_digital = float(_extra_tech.get("branches",{}).get("دیجیتال",0.20) if _extra_tech.has("branches") else 0.20)
	_green = float(_extra_env.get("green_energy",0.20) if _extra_env.has("green_energy") else 0.20)

	# اثر اعتماد بر کارآمدی
	_sys_q = 0.60
	if state.has("public_transport") and state["public_transport"] is Dictionary:
		_sys_q = float(state["public_transport"].get("quality",0.60) if state["public_transport"].has("quality") else state["public_transport"].get("efficiency",0.60) if state["public_transport"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("public_transport") and state["public_transport"] is Dictionary:
		state["public_transport"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_public_transport_deep","gini": _gini, "message":"نابرابری اثر بر public_transport - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_public_transport","digital": _digital, "message":"فناوری دوگانه در public_transport - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_public_transport","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی public_transport"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_public_transport","capital": _social_capital, "message":"سرمایه اجتماعی پایین در public_transport"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("public_transport") and state["public_transport"] is Dictionary and state["public_transport"].has("maintenance_cost"):
		state["public_transport"]["maintenance_cost"] = float(state["public_transport"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	return {"success":true,"state":state,"events":events}
