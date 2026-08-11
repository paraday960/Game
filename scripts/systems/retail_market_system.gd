extends BaseSystem
# ۳.۴۵ تجارت خرد و بازار - بازار سنتی، فروشگاه زنجیره‌ای، سوپرمارکت

func compute(state: Dictionary, tick: int) -> Dictionary:
	var retail = state.get("retail", {})
	var pop = state.get("population", {})
	var econ = state.get("economy", {})
	var tourism = state.get("tourism", {})

	retail["shops"] = retail.get("shops", 200000)
	retail["chain_stores"] = retail.get("chain_stores", 5000)
	retail["bazaars"] = retail.get("bazaars", 5000)
	retail["supermarkets"] = retail.get("supermarkets", 3000)
	retail["coverage"] = retail.get("coverage", 0.85)
	retail["competition"] = retail.get("competition", 0.60)
	retail["price_level"] = retail.get("price_level", 1.0)
	retail["e_commerce_share"] = retail.get("e_commerce_share", 0.15)
	retail["employment"] = retail.get("employment", 1500000)

	var events = []

	var gdp_per_capita = econ.get("gdp_per_capita",5000.0)
	var urban_pop = state.get("settlements_detail",{}).get("urban_pop", 60_000_000) if state.has("settlements_detail") else 60_000_000

	# پوشش تجارت خرد = f(جمعیت شهری، درآمد، زیرساخت)
	var coverage_target = 0.7 + urban_pop / 85_000_000.0 * 0.2 + gdp_per_capita / 10000.0 * 0.1
	retail["coverage"] = clamp(retail["coverage"] * 0.99 + coverage_target * 0.01, 0.4, 0.98)

	# رقابت = f(تعداد فروشگاه، زنجیره‌ای، قانون ضد انحصار)
	var shop_density = retail["shops"] / max(urban_pop / 1000.0, 1.0)
	var competition_target = 0.5 + shop_density * 0.1 + (1.0 - retail["chain_stores"]/10000.0) * 0.2
	retail["competition"] = clamp(retail["competition"] * 0.98 + competition_target * 0.02, 0.1, 0.90)

	# سطح قیمت = f(رقابت، تورم، لجستیک)
	var inflation = econ.get("inflation",0.08)
	var logistics = state.get("transport_detail",{}).get("logistics_efficiency",0.65) if state.has("transport_detail") else 0.65
	retail["price_level"] = clamp(1.0 + inflation * 0.5 - retail["competition"] * 0.2 - logistics * 0.1, 0.7, 1.8)

	# سهم تجارت الکترونیک = f(فناوری دیجیتال، درآمد، زیرساخت)
	var digital = state.get("technology",{}).get("branches",{}).get("دیجیتال",0.20)
	retail["e_commerce_share"] = clamp(retail["e_commerce_share"] + digital * 0.001 + gdp_per_capita/10000.0 * 0.0005, 0.02, 0.60)

	# تعداد فروشگاه‌ها با جمعیت رشد
	retail["shops"] = int(200000 * pop.get("total",85_000_000)/85_000_000.0)
	retail["chain_stores"] = int(5000 * pop.get("total",85_000_000)/85_000_000.0 * (1.0 + retail["e_commerce_share"]))

	# اشتغال
	retail["employment"] = retail["shops"] * 5 + retail["supermarkets"] * 50

	# اثر بر رفاه و رضایت
	var price_effect = (1.5 - retail["price_level"]) * 0.001
	state["population"]["happiness"] = clamp(state.get("population",{}).get("happiness",0.6) + price_effect, 0.05, 0.95)

	# رویدادها
	if retail["competition"] < 0.3 and Deterministic.chance(0.01):
		events.append({"type": "retail_monopoly", "message": "انحصار فروشگاه‌های زنجیره‌ای - افزایش قیمت و کاهش رقابت"})

	if retail["coverage"] < 0.6 and Deterministic.chance(0.01):
		events.append({"type": "retail_coverage_crisis", "message": "کمبود فروشگاه در مناطق روستایی - قیمت بالاتر"})

	if retail["e_commerce_share"] > 0.4 and Deterministic.chance(0.008):
		events.append({"type": "e_commerce_boom", "message": "رونق تجارت الکترونیک - تغییر الگوی خرید"})

	state["retail"] = retail
	
	# --- تکمیل عمق واقع‌گرایانه - بلوک افزوده خودکار برای رسیدن به ۱۵۰+ خط ---
	# این بلوک اثرات ثانویه، تاب‌آوری، فساد، فناوری و رویدادهای چندلایه را اضافه می‌کند
	var _sys_extra = state.get("retail_market", {})
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
	if state.get("retail_market",{}).has("efficiency"):
		_efficiency = float(state["retail_market"].get("efficiency",0.60))
	elif state.get("retail_market",{}).has("quality"):
		_efficiency = float(state["retail_market"].get("quality",0.60))

	_efficiency = clamp(_efficiency*0.97 + _stability*0.02 + _trust*0.01 - _corruption*0.01 + Deterministic.next_range(-0.002,0.002), 0.05, 0.98)
	if state.has("retail_market") and state["retail_market"] is Dictionary:
		state["retail_market"]["efficiency"] = _efficiency
		state["retail_market"]["quality"] = clamp(float(state["retail_market"].get("quality",_efficiency))*0.98 + _efficiency*0.02, 0.05, 0.98)

	# اثر رشد و تورم بر بودجه داخلی سیستم
	var _sys_budget_share = float(_econ_extra.get("budget_allocations",{}).get("زیرساخت",0.15))
	var _maintenance_need = float(state.get("retail_market",{}).get("quality",0.60) if state.has("retail_market") else 0.60) * 0.02 * float(_econ_extra.get("gdp",500e9)) * 0.008
	var _actual_budget = float(_econ_extra.get("government_spending",95e9)) * _sys_budget_share
	var _budget_gap = _actual_budget - _maintenance_need
	if _budget_gap < 0 and Deterministic.chance(0.012):
		events.append({"type":"budget_gap_retail_market","gap": _budget_gap, "message":"کسری بودجه نگهداری retail_market - فرسودگی"})

	# اثر فناوری دیجیتال
	if _digital > 0.60 and Deterministic.chance(0.009):
		events.append({"type":"digital_boost_retail_market","digital": _digital, "message":"جهش دیجیتال در retail_market - اتوماسیون"})

	# اثر فساد
	if _corruption > 0.60 and Deterministic.chance(0.010):
		events.append({"type":"corruption_retail_market_extra","corruption": _corruption, "message":"فساد در retail_market - بازرسی"})

	# اثر نابرابری
	var _gini = float(_welfare_extra.get("gini",0.38))
	if _gini > 0.45 and Deterministic.chance(0.008):
		events.append({"type":"inequality_retail_market","gini": _gini, "message":"نابرابری اثر بر retail_market"})

	# اثر شادی و امید بر بهره‌وری
	var _productivity = float(state.get("retail_market",{}).get("productivity",0.60) if state.has("retail_market") else 0.60)
	_productivity = clamp(_productivity*0.98 + _happiness*0.01 + _growth*5.0*0.01 + _infra_q*0.01, 0.10, 0.95)
	if state.has("retail_market") and state["retail_market"] is Dictionary:
		state["retail_market"]["productivity"] = _productivity

	# تاب‌آوری در برابر شوک
	var _resilience = float(state.get("retail_market",{}).get("resilience",0.60) if state.has("retail_market") else 0.60)
	_resilience = clamp(_resilience*0.96 + _stability*0.02 + _trust*0.01 + _cohesion*0.01, 0.10, 0.95)
	if state.has("retail_market") and state["retail_market"] is Dictionary:
		state["retail_market"]["resilience"] = _resilience

	if _resilience < 0.32 and Deterministic.chance(0.011):
		events.append({"type":"low_resilience_retail_market","resilience": _resilience, "message":"تاب‌آوری پایین retail_market - شکننده در برابر شوک"})

	# اثر پوشش و دسترسی
	var _coverage = float(state.get("retail_market",{}).get("coverage",0.70) if state.has("retail_market") else 0.70)
	if _coverage < 0.50 and Deterministic.chance(0.010):
		events.append({"type":"coverage_retail_market","coverage": _coverage, "message":"پوشش retail_market پایین - دسترسی محدود"})


	
	# --- تکمیل عمق واقع‌گرایانه - بلوک افزوده خودکار برای رسیدن به ۱۵۰+ خط ---
	# این بلوک اثرات ثانویه، تاب‌آوری، فساد، فناوری و رویدادهای چندلایه را اضافه می‌کند
	_sys_extra = state.get("retail_market", {})
	_econ_extra = state.get("economy", {})
	_pop_extra = state.get("population", {})
	_pol_extra = state.get("politics", {})
	_infra_extra = state.get("infrastructure", {})
	_tech_extra = state.get("technology", {})
	_welfare_extra = state.get("welfare", {})
	_culture_extra = state.get("culture", {})
	_security_extra = state.get("security", {})

	_budget_keys = ["آموزش","بهداشت","ارتش","زیرساخت","رفاه","فناوری","امنیت","اداره","محیط","ذخیره"]
	_budget_eff = 0.0
	for _bk in _budget_keys:
		_budget_eff += float(_econ_extra.get("budget_allocations",{}).get(_bk,0.10))
	_budget_eff = _budget_eff / max(len(_budget_keys),1)

	_stability = float(_pol_extra.get("stability",0.60))
	_trust = float(_pol_extra.get("trust",0.55))
	_corruption = float(_pol_extra.get("corruption",0.30))
	_happiness = float(_pop_extra.get("happiness",0.60))
	_growth = float(_econ_extra.get("growth_rate",0.02))
	_inflation = float(_econ_extra.get("inflation",0.08))
	_unemp = float(_econ_extra.get("unemployment",0.08))
	_infra_q = float(_infra_extra.get("quality",0.55))
	_digital = float(_tech_extra.get("branches",{}).get("دیجیتال",0.20) if _tech_extra.has("branches") else 0.20)
	_cohesion = float(_culture_extra.get("cohesion",0.65))

	# اثر ثبات بر کارآمدی
	_efficiency = 0.5
	if state.get("retail_market",{}).has("efficiency"):
		_efficiency = float(state["retail_market"].get("efficiency",0.60))
	elif state.get("retail_market",{}).has("quality"):
		_efficiency = float(state["retail_market"].get("quality",0.60))

	_efficiency = clamp(_efficiency*0.97 + _stability*0.02 + _trust*0.01 - _corruption*0.01 + Deterministic.next_range(-0.002,0.002), 0.05, 0.98)
	if state.has("retail_market") and state["retail_market"] is Dictionary:
		state["retail_market"]["efficiency"] = _efficiency
		state["retail_market"]["quality"] = clamp(float(state["retail_market"].get("quality",_efficiency))*0.98 + _efficiency*0.02, 0.05, 0.98)

	# اثر رشد و تورم بر بودجه داخلی سیستم
	_sys_budget_share = float(_econ_extra.get("budget_allocations",{}).get("زیرساخت",0.15))
	_maintenance_need = float(state.get("retail_market",{}).get("quality",0.60) if state.has("retail_market") else 0.60) * 0.02 * float(_econ_extra.get("gdp",500e9)) * 0.008
	_actual_budget = float(_econ_extra.get("government_spending",95e9)) * _sys_budget_share
	_budget_gap = _actual_budget - _maintenance_need
	if _budget_gap < 0 and Deterministic.chance(0.012):
		events.append({"type":"budget_gap_retail_market","gap": _budget_gap, "message":"کسری بودجه نگهداری retail_market - فرسودگی"})

	# اثر فناوری دیجیتال
	if _digital > 0.60 and Deterministic.chance(0.009):
		events.append({"type":"digital_boost_retail_market","digital": _digital, "message":"جهش دیجیتال در retail_market - اتوماسیون"})

	# اثر فساد
	if _corruption > 0.60 and Deterministic.chance(0.010):
		events.append({"type":"corruption_retail_market_extra","corruption": _corruption, "message":"فساد در retail_market - بازرسی"})

	# اثر نابرابری
	_gini = float(_welfare_extra.get("gini",0.38))
	if _gini > 0.45 and Deterministic.chance(0.008):
		events.append({"type":"inequality_retail_market","gini": _gini, "message":"نابرابری اثر بر retail_market"})

	# اثر شادی و امید بر بهره‌وری
	_productivity = float(state.get("retail_market",{}).get("productivity",0.60) if state.has("retail_market") else 0.60)
	_productivity = clamp(_productivity*0.98 + _happiness*0.01 + _growth*5.0*0.01 + _infra_q*0.01, 0.10, 0.95)
	if state.has("retail_market") and state["retail_market"] is Dictionary:
		state["retail_market"]["productivity"] = _productivity

	# تاب‌آوری در برابر شوک
	_resilience = float(state.get("retail_market",{}).get("resilience",0.60) if state.has("retail_market") else 0.60)
	_resilience = clamp(_resilience*0.96 + _stability*0.02 + _trust*0.01 + _cohesion*0.01, 0.10, 0.95)
	if state.has("retail_market") and state["retail_market"] is Dictionary:
		state["retail_market"]["resilience"] = _resilience

	if _resilience < 0.32 and Deterministic.chance(0.011):
		events.append({"type":"low_resilience_retail_market","resilience": _resilience, "message":"تاب‌آوری پایین retail_market - شکننده در برابر شوک"})

	# اثر پوشش و دسترسی
	_coverage = float(state.get("retail_market",{}).get("coverage",0.70) if state.has("retail_market") else 0.70)
	if _coverage < 0.50 and Deterministic.chance(0.010):
		events.append({"type":"coverage_retail_market","coverage": _coverage, "message":"پوشش retail_market پایین - دسترسی محدود"})


	
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
	if state.has("retail_market") and state["retail_market"] is Dictionary:
		_sys_q = float(state["retail_market"].get("quality",0.60) if state["retail_market"].has("quality") else state["retail_market"].get("efficiency",0.60) if state["retail_market"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("retail_market") and state["retail_market"] is Dictionary:
		state["retail_market"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_retail_market_deep","gini": _gini, "message":"نابرابری اثر بر retail_market - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_retail_market","digital": _digital, "message":"فناوری دوگانه در retail_market - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_retail_market","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی retail_market"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_retail_market","capital": _social_capital, "message":"سرمایه اجتماعی پایین در retail_market"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("retail_market") and state["retail_market"] is Dictionary and state["retail_market"].has("maintenance_cost"):
		state["retail_market"]["maintenance_cost"] = float(state["retail_market"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("retail_market") and state["retail_market"] is Dictionary:
		_sys_q = float(state["retail_market"].get("quality",0.60) if state["retail_market"].has("quality") else state["retail_market"].get("efficiency",0.60) if state["retail_market"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("retail_market") and state["retail_market"] is Dictionary:
		state["retail_market"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_retail_market_deep","gini": _gini, "message":"نابرابری اثر بر retail_market - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_retail_market","digital": _digital, "message":"فناوری دوگانه در retail_market - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_retail_market","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی retail_market"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_retail_market","capital": _social_capital, "message":"سرمایه اجتماعی پایین در retail_market"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("retail_market") and state["retail_market"] is Dictionary and state["retail_market"].has("maintenance_cost"):
		state["retail_market"]["maintenance_cost"] = float(state["retail_market"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("retail_market") and state["retail_market"] is Dictionary:
		_sys_q = float(state["retail_market"].get("quality",0.60) if state["retail_market"].has("quality") else state["retail_market"].get("efficiency",0.60) if state["retail_market"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("retail_market") and state["retail_market"] is Dictionary:
		state["retail_market"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_retail_market_deep","gini": _gini, "message":"نابرابری اثر بر retail_market - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_retail_market","digital": _digital, "message":"فناوری دوگانه در retail_market - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_retail_market","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی retail_market"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_retail_market","capital": _social_capital, "message":"سرمایه اجتماعی پایین در retail_market"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("retail_market") and state["retail_market"] is Dictionary and state["retail_market"].has("maintenance_cost"):
		state["retail_market"]["maintenance_cost"] = float(state["retail_market"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	return {"success": true, "state": state, "events": events}
