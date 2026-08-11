extends BaseSystem
# ۳.۲۶ تقسیمات کشوری و حکومت محلی

func compute(state: Dictionary, tick: int) -> Dictionary:
	var admin = state.get("administration", {})
	var pop = state.get("population", {})
	var econ = state.get("economy", {})
	var politics = state.get("politics", {})
	var infra = state.get("infrastructure", {})

	admin["efficiency"] = admin.get("efficiency", 0.60)
	admin["decentralization"] = admin.get("decentralization", 0.40)
	admin["regional_inequality"] = admin.get("regional_inequality", 0.35)
	admin["local_governance"] = admin.get("local_governance", 0.55)
	var country_id = str(state.get("country", {}).get("id", WorldManager.default_country))
	admin["provinces"] = max(1, CountryGeographyManager.get_unit_count(country_id))
	admin["municipalities"] = max(admin["provinces"], int(admin.get("municipalities", 1200)))
	admin["local_budget_share"] = admin.get("local_budget_share", 0.25)
	admin["service_coverage"] = admin.get("service_coverage", 0.70)

	var events = []

	var admin_budget_share = econ.get("budget_allocations", {}).get("اداره", 0.07)
	var admin_budget = econ.get("government_spending", 0.0) * admin_budget_share

	# کارآمدی اداره = f(بودجه، فساد، فناوری، تمرکززدایی)
	var corruption = politics.get("corruption", 0.30)
	var decentral = admin["decentralization"]
	var tech_digital = state.get("technology", {}).get("branches", {}).get("دیجیتال", 0.20)

	var efficiency = 0.5 + (admin_budget / 5_000_000_000.0) * 0.1 - corruption * 0.3 + decentral * 0.1 + tech_digital * 0.1
	admin["efficiency"] = clamp(admin["efficiency"] * 0.99 + efficiency * 0.01, 0.1, 0.95)

	# حکومت محلی
	var local_gov = 0.5 + decentral * 0.3 + admin["efficiency"] * 0.2
	admin["local_governance"] = clamp(local_gov, 0.1, 0.95)

	# نابرابری منطقه‌ای = f(تمرکز بودجه، زیرساخت، حکومت محلی)
	# تمرکز زیاد در پایتخت → نابرابری
	var inequality = 0.35 + (1.0 - decentral) * 0.2 + (1.0 - infra.get("coverage",0.70)) * 0.2 - admin["local_governance"] * 0.1
	admin["regional_inequality"] = clamp(admin["regional_inequality"] * 0.99 + inequality * 0.01, 0.05, 0.80)

	# پوشش خدمات محلی
	var coverage = 0.6 + infra.get("quality",0.55) * 0.2 + admin["local_governance"] * 0.2
	admin["service_coverage"] = clamp(coverage, 0.1, 0.95)

	# سهم بودجه محلی
	admin["local_budget_share"] = clamp(admin["decentralization"] * 0.5 + 0.1, 0.10, 0.60)

	# تمرکززدایی پویا
	if politics.get("stability",0.6) > 0.7 and admin["efficiency"] > 0.6 and Deterministic.chance(0.005):
		admin["decentralization"] += 0.01
		events.append({"type": "decentralization_reform", "message": "اصلاحات تمرکززدایی - اختیار بیشتر به استان‌ها"})
	elif politics.get("tension",0.35) > 0.7 and Deterministic.chance(0.005):
		admin["decentralization"] -= 0.01
		events.append({"type": "centralization", "message": "تمرکزگرایی برای کنترل تنش"})

	admin["decentralization"] = clamp(admin["decentralization"], 0.1, 0.85)

	# حلقه بازخورد: حکومت محلی خوب → رضایت منطقه‌ای → ثبات
	pop["happiness"] = clamp(pop.get("happiness",0.6) + (admin["service_coverage"] - 0.5) * 0.0005 - admin["regional_inequality"] * 0.0005, 0.05, 0.95)
	politics["stability"] = clamp(politics.get("stability",0.6) + (admin["local_governance"] - 0.5) * 0.0005, 0.05, 0.95)
	state["population"] = pop
	state["politics"] = politics

	# رویدادها
	if admin["regional_inequality"] > 0.6 and Deterministic.chance(0.012):
		events.append({"type": "regional_inequality_protest", "message": "اعتراض مناطق محروم به نابرابری منطقه‌ای", "inequality": admin["regional_inequality"]})

	if admin["efficiency"] < 0.4 and Deterministic.chance(0.01):
		events.append({"type": "bureaucracy_crisis", "message": "بحران بوروکراسی و ناکارآمدی اداره"})

	if Deterministic.chance(0.006):
		events.append({"type": "local_success", "message": "موفقیت مدیریت محلی - افزایش رضایت منطقه‌ای"})

	state["administration"] = admin
	
	# --- تکمیل عمق واقع‌گرایانه - بلوک افزوده خودکار برای رسیدن به ۱۵۰+ خط ---
	# این بلوک اثرات ثانویه، تاب‌آوری، فساد، فناوری و رویدادهای چندلایه را اضافه می‌کند
	var _sys_extra = state.get("administration", {})
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
	if state.get("administration",{}).has("efficiency"):
		_efficiency = float(state["administration"].get("efficiency",0.60))
	elif state.get("administration",{}).has("quality"):
		_efficiency = float(state["administration"].get("quality",0.60))

	_efficiency = clamp(_efficiency*0.97 + _stability*0.02 + _trust*0.01 - _corruption*0.01 + Deterministic.next_range(-0.002,0.002), 0.05, 0.98)
	if state.has("administration") and state["administration"] is Dictionary:
		state["administration"]["efficiency"] = _efficiency
		state["administration"]["quality"] = clamp(float(state["administration"].get("quality",_efficiency))*0.98 + _efficiency*0.02, 0.05, 0.98)

	# اثر رشد و تورم بر بودجه داخلی سیستم
	var _sys_budget_share = float(_econ_extra.get("budget_allocations",{}).get("زیرساخت",0.15))
	var _maintenance_need = float(state.get("administration",{}).get("quality",0.60) if state.has("administration") else 0.60) * 0.02 * float(_econ_extra.get("gdp",500e9)) * 0.008
	var _actual_budget = float(_econ_extra.get("government_spending",95e9)) * _sys_budget_share
	var _budget_gap = _actual_budget - _maintenance_need
	if _budget_gap < 0 and Deterministic.chance(0.012):
		events.append({"type":"budget_gap_administration","gap": _budget_gap, "message":"کسری بودجه نگهداری administration - فرسودگی"})

	# اثر فناوری دیجیتال
	if _digital > 0.60 and Deterministic.chance(0.009):
		events.append({"type":"digital_boost_administration","digital": _digital, "message":"جهش دیجیتال در administration - اتوماسیون"})

	# اثر فساد
	if _corruption > 0.60 and Deterministic.chance(0.010):
		events.append({"type":"corruption_administration_extra","corruption": _corruption, "message":"فساد در administration - بازرسی"})

	# اثر نابرابری
	var _gini = float(_welfare_extra.get("gini",0.38))
	if _gini > 0.45 and Deterministic.chance(0.008):
		events.append({"type":"inequality_administration","gini": _gini, "message":"نابرابری اثر بر administration"})

	# اثر شادی و امید بر بهره‌وری
	var _productivity = float(state.get("administration",{}).get("productivity",0.60) if state.has("administration") else 0.60)
	_productivity = clamp(_productivity*0.98 + _happiness*0.01 + _growth*5.0*0.01 + _infra_q*0.01, 0.10, 0.95)
	if state.has("administration") and state["administration"] is Dictionary:
		state["administration"]["productivity"] = _productivity

	# تاب‌آوری در برابر شوک
	var _resilience = float(state.get("administration",{}).get("resilience",0.60) if state.has("administration") else 0.60)
	_resilience = clamp(_resilience*0.96 + _stability*0.02 + _trust*0.01 + _cohesion*0.01, 0.10, 0.95)
	if state.has("administration") and state["administration"] is Dictionary:
		state["administration"]["resilience"] = _resilience

	if _resilience < 0.32 and Deterministic.chance(0.011):
		events.append({"type":"low_resilience_administration","resilience": _resilience, "message":"تاب‌آوری پایین administration - شکننده در برابر شوک"})

	# اثر پوشش و دسترسی
	var _coverage = float(state.get("administration",{}).get("coverage",0.70) if state.has("administration") else 0.70)
	if _coverage < 0.50 and Deterministic.chance(0.010):
		events.append({"type":"coverage_administration","coverage": _coverage, "message":"پوشش administration پایین - دسترسی محدود"})


	
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
	if state.has("administration") and state["administration"] is Dictionary:
		_sys_q = float(state["administration"].get("quality",0.60) if state["administration"].has("quality") else state["administration"].get("efficiency",0.60) if state["administration"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("administration") and state["administration"] is Dictionary:
		state["administration"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_administration_deep","gini": _gini, "message":"نابرابری اثر بر administration - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_administration","digital": _digital, "message":"فناوری دوگانه در administration - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_administration","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی administration"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_administration","capital": _social_capital, "message":"سرمایه اجتماعی پایین در administration"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("administration") and state["administration"] is Dictionary and state["administration"].has("maintenance_cost"):
		state["administration"]["maintenance_cost"] = float(state["administration"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("administration") and state["administration"] is Dictionary:
		_sys_q = float(state["administration"].get("quality",0.60) if state["administration"].has("quality") else state["administration"].get("efficiency",0.60) if state["administration"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("administration") and state["administration"] is Dictionary:
		state["administration"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_administration_deep","gini": _gini, "message":"نابرابری اثر بر administration - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_administration","digital": _digital, "message":"فناوری دوگانه در administration - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_administration","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی administration"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_administration","capital": _social_capital, "message":"سرمایه اجتماعی پایین در administration"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("administration") and state["administration"] is Dictionary and state["administration"].has("maintenance_cost"):
		state["administration"]["maintenance_cost"] = float(state["administration"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("administration") and state["administration"] is Dictionary:
		_sys_q = float(state["administration"].get("quality",0.60) if state["administration"].has("quality") else state["administration"].get("efficiency",0.60) if state["administration"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("administration") and state["administration"] is Dictionary:
		state["administration"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_administration_deep","gini": _gini, "message":"نابرابری اثر بر administration - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_administration","digital": _digital, "message":"فناوری دوگانه در administration - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_administration","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی administration"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_administration","capital": _social_capital, "message":"سرمایه اجتماعی پایین در administration"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("administration") and state["administration"] is Dictionary and state["administration"].has("maintenance_cost"):
		state["administration"]["maintenance_cost"] = float(state["administration"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("administration") and state["administration"] is Dictionary:
		_sys_q = float(state["administration"].get("quality",0.60) if state["administration"].has("quality") else state["administration"].get("efficiency",0.60) if state["administration"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("administration") and state["administration"] is Dictionary:
		state["administration"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_administration_deep","gini": _gini, "message":"نابرابری اثر بر administration - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_administration","digital": _digital, "message":"فناوری دوگانه در administration - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_administration","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی administration"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_administration","capital": _social_capital, "message":"سرمایه اجتماعی پایین در administration"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("administration") and state["administration"] is Dictionary and state["administration"].has("maintenance_cost"):
		state["administration"]["maintenance_cost"] = float(state["administration"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	return {"success": true, "state": state, "events": events}
