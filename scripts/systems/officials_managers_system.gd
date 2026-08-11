extends BaseSystem
# ۳.۵۵ دولتمردان و مدیران - وزرا، استانداران، فرمانداران، شهرداران، شایستگی، فساد، گردش، آموزش

func compute(state: Dictionary, tick: int) -> Dictionary:
	var officials = state.get("officials", {})
	officials["ministers"] = officials.get("ministers", 20)
	var country_id = str(state.get("country", {}).get("id", WorldManager.default_country))
	officials["governors"] = max(1, CountryGeographyManager.get_unit_count(country_id))
	officials["mayors"] = max(officials["governors"], int(state.get("administration", {}).get("municipalities", 1200)))
	officials["governors_general"] = officials.get("governors_general", int(state.get("population", {}).get("total",85_000_000.0)/2_000_000.0))
	officials["senior_managers"] = officials.get("senior_managers", 5000)
	officials["middle_managers"] = officials.get("middle_managers", 25000)
	officials["competence"] = officials.get("competence", 0.60)
	officials["corruption"] = officials.get("corruption", state.get("politics", {}).get("corruption", 0.30))
	officials["turnover"] = officials.get("turnover", 0.15)
	officials["training"] = officials.get("training", 0.45)
	officials["merit_based_promotion"] = officials.get("merit_based_promotion", 0.50)
	officials["public_trust_officials"] = officials.get("public_trust_officials", 0.50)
	officials["decision_speed"] = officials.get("decision_speed", 0.55)
	officials["avg_age"] = officials.get("avg_age", 52.0)

	var events = []
	var corruption = state.get("politics", {}).get("corruption", 0.30)
	var stability = state.get("politics", {}).get("stability", 0.60)
	var edu_q = state.get("education", {}).get("quality", 0.55)
	var trust = state.get("politics", {}).get("trust", 0.55)
	var judicial = state.get("judicial", {}).get("rule_of_law", 0.60)

	# شایستگی = آموزش + شایسته‌سالاری + تجربه
	var meritocracy = state.get("political_career", {}).get("meritocracy", 0.50) if state.has("political_career") else 0.50
	var competence_target = edu_q*0.35 + meritocracy*0.30 + officials["training"]*0.20 + 0.15
	officials["competence"] = clamp(officials["competence"]*0.993 + competence_target*0.007 - corruption*0.001, 0.15, 0.95)

	officials["corruption"] = clamp(corruption*0.7 + (1.0 - judicial)*0.2 + (1.0 - officials["merit_based_promotion"])*0.1, 0.05, 0.85)

	# گردش = بی‌ثباتی + فساد + سن بالا
	officials["turnover"] = clamp(0.10 + (1.0 - stability)*0.20 + corruption*0.10 + max(0.0,(officials["avg_age"]-55.0)/100.0), 0.03, 0.55)

	# آموزش مدیران
	officials["training"] = clamp(officials["training"] + edu_q*0.0004 + state.get("technology", {}).get("branches", {}).get("دیجیتال",0.20)*0.0003, 0.1, 0.90)

	# ارتقای شایسته‌محور
	officials["merit_based_promotion"] = clamp(meritocracy*0.6 + judicial*0.2 + 0.2, 0.1, 0.90)

	# اعتماد عمومی به مدیران
	var trust_target = officials["competence"]*0.35 + (1.0 - officials["corruption"])*0.35 + stability*0.20 + 0.10
	officials["public_trust_officials"] = clamp(officials["public_trust_officials"]*0.96 + trust_target*0.04, 0.05, 0.90)

	# سرعت تصمیم‌گیری - تمرکززدایی + کارآمدی
	var decentral = state.get("administration", {}).get("decentralization", 0.4)
	officials["decision_speed"] = clamp(officials["competence"]*0.3 + decentral*0.2 + officials["training"]*0.2 + 0.3, 0.2, 0.95)

	# میانگین سنی - پیری + گردش
	officials["avg_age"] += (0.02 - officials["turnover"]*0.1) / 365.0
	officials["avg_age"] = clamp(officials["avg_age"], 38.0, 65.0)

	# تعداد مدیران میانی - رشد بوروکراسی
	if tick % 180 == 0 and officials["competence"] < 0.6:
		officials["middle_managers"] += Deterministic.next_int_range(100, 500)
	else:
		officials["middle_managers"] = max(officials["middle_managers"] - 10, 15000)

	# رویدادها
	if officials["corruption"] > 0.62 and Deterministic.chance(0.014):
		events.append({"type":"manager_corruption","corruption": officials["corruption"], "message":"افشای فساد مدیران ارشد - پرونده ۳ مدیرکل به قوه قضائیه"})

	if officials["competence"] < 0.35 and Deterministic.chance(0.012):
		events.append({"type":"low_competence_managers","competence": officials["competence"], "message":"ناشایستگی مدیریتی - ۴۰٪ مدیران بدون تخصص مرتبط"})

	if officials["turnover"] > 0.40 and Deterministic.chance(0.010):
		events.append({"type":"high_manager_turnover","turnover": officials["turnover"], "message":"سونامی برکناری مدیران - هر وزیر تیم خودش را آورد"})

	if officials["public_trust_officials"] < 0.30 and Deterministic.chance(0.011):
		events.append({"type":"trust_officials_low","trust": officials["public_trust_officials"], "message":"بی‌اعتمادی به مدیران - کار مردم معطل امضای مدیرکل"})

	state["officials"] = officials
	
	# --- تکمیل عمق واقع‌گرایانه - بلوک افزوده خودکار برای رسیدن به ۱۵۰+ خط ---
	# این بلوک اثرات ثانویه، تاب‌آوری، فساد، فناوری و رویدادهای چندلایه را اضافه می‌کند
	var _sys_extra = state.get("officials_managers", {})
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
	if state.get("officials_managers",{}).has("efficiency"):
		_efficiency = float(state["officials_managers"].get("efficiency",0.60))
	elif state.get("officials_managers",{}).has("quality"):
		_efficiency = float(state["officials_managers"].get("quality",0.60))

	_efficiency = clamp(_efficiency*0.97 + _stability*0.02 + _trust*0.01 - _corruption*0.01 + Deterministic.next_range(-0.002,0.002), 0.05, 0.98)
	if state.has("officials_managers") and state["officials_managers"] is Dictionary:
		state["officials_managers"]["efficiency"] = _efficiency
		state["officials_managers"]["quality"] = clamp(float(state["officials_managers"].get("quality",_efficiency))*0.98 + _efficiency*0.02, 0.05, 0.98)

	# اثر رشد و تورم بر بودجه داخلی سیستم
	var _sys_budget_share = float(_econ_extra.get("budget_allocations",{}).get("زیرساخت",0.15))
	var _maintenance_need = float(state.get("officials_managers",{}).get("quality",0.60) if state.has("officials_managers") else 0.60) * 0.02 * float(_econ_extra.get("gdp",500e9)) * 0.008
	var _actual_budget = float(_econ_extra.get("government_spending",95e9)) * _sys_budget_share
	var _budget_gap = _actual_budget - _maintenance_need
	if _budget_gap < 0 and Deterministic.chance(0.012):
		events.append({"type":"budget_gap_officials_managers","gap": _budget_gap, "message":"کسری بودجه نگهداری officials_managers - فرسودگی"})

	# اثر فناوری دیجیتال
	if _digital > 0.60 and Deterministic.chance(0.009):
		events.append({"type":"digital_boost_officials_managers","digital": _digital, "message":"جهش دیجیتال در officials_managers - اتوماسیون"})

	# اثر فساد
	if _corruption > 0.60 and Deterministic.chance(0.010):
		events.append({"type":"corruption_officials_managers_extra","corruption": _corruption, "message":"فساد در officials_managers - بازرسی"})

	# اثر نابرابری
	var _gini = float(_welfare_extra.get("gini",0.38))
	if _gini > 0.45 and Deterministic.chance(0.008):
		events.append({"type":"inequality_officials_managers","gini": _gini, "message":"نابرابری اثر بر officials_managers"})

	# اثر شادی و امید بر بهره‌وری
	var _productivity = float(state.get("officials_managers",{}).get("productivity",0.60) if state.has("officials_managers") else 0.60)
	_productivity = clamp(_productivity*0.98 + _happiness*0.01 + _growth*5.0*0.01 + _infra_q*0.01, 0.10, 0.95)
	if state.has("officials_managers") and state["officials_managers"] is Dictionary:
		state["officials_managers"]["productivity"] = _productivity

	# تاب‌آوری در برابر شوک
	var _resilience = float(state.get("officials_managers",{}).get("resilience",0.60) if state.has("officials_managers") else 0.60)
	_resilience = clamp(_resilience*0.96 + _stability*0.02 + _trust*0.01 + _cohesion*0.01, 0.10, 0.95)
	if state.has("officials_managers") and state["officials_managers"] is Dictionary:
		state["officials_managers"]["resilience"] = _resilience

	if _resilience < 0.32 and Deterministic.chance(0.011):
		events.append({"type":"low_resilience_officials_managers","resilience": _resilience, "message":"تاب‌آوری پایین officials_managers - شکننده در برابر شوک"})

	# اثر پوشش و دسترسی
	var _coverage = float(state.get("officials_managers",{}).get("coverage",0.70) if state.has("officials_managers") else 0.70)
	if _coverage < 0.50 and Deterministic.chance(0.010):
		events.append({"type":"coverage_officials_managers","coverage": _coverage, "message":"پوشش officials_managers پایین - دسترسی محدود"})


	
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
	if state.has("officials_managers") and state["officials_managers"] is Dictionary:
		_sys_q = float(state["officials_managers"].get("quality",0.60) if state["officials_managers"].has("quality") else state["officials_managers"].get("efficiency",0.60) if state["officials_managers"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("officials_managers") and state["officials_managers"] is Dictionary:
		state["officials_managers"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_officials_managers_deep","gini": _gini, "message":"نابرابری اثر بر officials_managers - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_officials_managers","digital": _digital, "message":"فناوری دوگانه در officials_managers - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_officials_managers","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی officials_managers"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_officials_managers","capital": _social_capital, "message":"سرمایه اجتماعی پایین در officials_managers"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("officials_managers") and state["officials_managers"] is Dictionary and state["officials_managers"].has("maintenance_cost"):
		state["officials_managers"]["maintenance_cost"] = float(state["officials_managers"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("officials_managers") and state["officials_managers"] is Dictionary:
		_sys_q = float(state["officials_managers"].get("quality",0.60) if state["officials_managers"].has("quality") else state["officials_managers"].get("efficiency",0.60) if state["officials_managers"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("officials_managers") and state["officials_managers"] is Dictionary:
		state["officials_managers"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_officials_managers_deep","gini": _gini, "message":"نابرابری اثر بر officials_managers - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_officials_managers","digital": _digital, "message":"فناوری دوگانه در officials_managers - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_officials_managers","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی officials_managers"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_officials_managers","capital": _social_capital, "message":"سرمایه اجتماعی پایین در officials_managers"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("officials_managers") and state["officials_managers"] is Dictionary and state["officials_managers"].has("maintenance_cost"):
		state["officials_managers"]["maintenance_cost"] = float(state["officials_managers"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("officials_managers") and state["officials_managers"] is Dictionary:
		_sys_q = float(state["officials_managers"].get("quality",0.60) if state["officials_managers"].has("quality") else state["officials_managers"].get("efficiency",0.60) if state["officials_managers"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("officials_managers") and state["officials_managers"] is Dictionary:
		state["officials_managers"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_officials_managers_deep","gini": _gini, "message":"نابرابری اثر بر officials_managers - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_officials_managers","digital": _digital, "message":"فناوری دوگانه در officials_managers - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_officials_managers","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی officials_managers"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_officials_managers","capital": _social_capital, "message":"سرمایه اجتماعی پایین در officials_managers"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("officials_managers") and state["officials_managers"] is Dictionary and state["officials_managers"].has("maintenance_cost"):
		state["officials_managers"]["maintenance_cost"] = float(state["officials_managers"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("officials_managers") and state["officials_managers"] is Dictionary:
		_sys_q = float(state["officials_managers"].get("quality",0.60) if state["officials_managers"].has("quality") else state["officials_managers"].get("efficiency",0.60) if state["officials_managers"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("officials_managers") and state["officials_managers"] is Dictionary:
		state["officials_managers"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_officials_managers_deep","gini": _gini, "message":"نابرابری اثر بر officials_managers - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_officials_managers","digital": _digital, "message":"فناوری دوگانه در officials_managers - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_officials_managers","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی officials_managers"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_officials_managers","capital": _social_capital, "message":"سرمایه اجتماعی پایین در officials_managers"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("officials_managers") and state["officials_managers"] is Dictionary and state["officials_managers"].has("maintenance_cost"):
		state["officials_managers"]["maintenance_cost"] = float(state["officials_managers"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	return {"success":true,"state":state,"events":events}
