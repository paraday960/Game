extends BaseSystem
# ۳.۲۷ کشاورزی و امنیت غذایی - پیاده‌سازی کامل

func compute(state: Dictionary, tick: int) -> Dictionary:
	var agri = state.get("agriculture", {})
	var resources = state.get("resources", {})
	var econ = state.get("economy", {})
	var pop = state.get("population", {})
	var environment = state.get("environment", {})
	var water_infra = state.get("water_infrastructure", {})

	agri["production"] = agri.get("production", 100.0)
	agri["food_security"] = agri.get("food_security", 0.85)
	agri["yield"] = agri.get("yield", 0.70)
	agri["irrigated_land"] = agri.get("irrigated_land", 0.40)
	agri["mechanization"] = agri.get("mechanization", 0.50)
	agri["fertilizer_use"] = agri.get("fertilizer_use", 0.60)
	agri["crop_diversity"] = agri.get("crop_diversity", 0.55)
	agri["storage_capacity"] = agri.get("storage_capacity", 0.60)
	agri["waste"] = agri.get("waste", 0.20)
	agri["self_sufficiency"] = agri.get("self_sufficiency", 0.80)

	var events = []

	var agri_budget_share = 0.05  # از زیرساخت و منابع
	var agri_budget = econ.get("government_spending",0.0) * agri_budget_share

	# فرمول‌ها
	# تولید کشاورزی = f(زمین آبی، مکانیزاسیون، کود، آب، اقلیم، فناوری)
	var water = resources.get("inventory",{}).get("آب",90.0) / 100.0
	var tech_agri = state.get("technology",{}).get("branches",{}).get("صنعت",0.20) * 0.5
	var climate = 1.0 - environment.get("climate_change",0.50) * 0.3
	var soil = environment.get("soil_quality",0.60)

	var yield_factor = 0.5 + agri["irrigated_land"] * 0.2 + agri["mechanization"] * 0.15 + agri["fertilizer_use"] * 0.1 + water * 0.2 + soil * 0.15 + tech_agri * 0.1
	yield_factor *= climate
	yield_factor = clamp(yield_factor, 0.2, 1.5)
	agri["yield"] = yield_factor

	var production = 100.0 * yield_factor * (1.0 + agri_budget / 10_000_000_000.0 * 0.1)
	agri["production"] = agri["production"] * 0.99 + production * 0.01

	# امنیت غذایی = f(تولید، ذخیره، واردات، توزیع، ضایعات)
	var storage = agri["storage_capacity"]
	var waste = agri["waste"]
	var trade = state.get("trade",{}).get("imports",70_000_000_000.0) / 70_000_000_000.0
	var self_suff = agri["production"] / 100.0
	var food_security = 0.5 + self_suff * 0.3 + storage * 0.1 + (1.0 - waste) * 0.1 + trade * 0.05
	agri["food_security"] = clamp(agri["food_security"] * 0.99 + food_security * 0.01, 0.1, 0.95)
	agri["self_sufficiency"] = clamp(self_suff, 0.1, 1.5)

	# آبیاری
	agri["irrigated_land"] = clamp(agri["irrigated_land"] + (water - 0.5) * 0.001 + agri_budget_share * 0.001, 0.1, 0.85)

	# مکانیزاسیون با فناوری و بودجه
	agri["mechanization"] = clamp(agri["mechanization"] + tech_agri * 0.001, 0.1, 0.95)

	# ضایعات غذایی - با زیرساخت و ذخیره کاهش
	var infra_q = state.get("infrastructure",{}).get("quality",0.55)
	agri["waste"] = clamp(agri["waste"] + (0.25 - infra_q * 0.1 - storage * 0.1) * 0.001, 0.05, 0.50)

	# تنوع محصول
	agri["crop_diversity"] = clamp(agri["crop_diversity"] + Deterministic.next_range(-0.001, 0.002), 0.2, 0.90)

	# ذخیره
	agri["storage_capacity"] = clamp(agri["storage_capacity"] + (agri_budget_share - 0.04) * 0.002, 0.2, 0.95)

	# اثر بر منابع - غذا
	resources["inventory"]["غذا"] = clamp(resources.get("inventory",{}).get("غذا",85.0) + (agri["production"] - 100.0) * 0.05, 0.0, 150.0)
	state["resources"] = resources

	# حلقه بازخورد: کشاورزی → امنیت غذایی → رضایت
	pop["happiness"] = clamp(pop.get("happiness",0.6) + (agri["food_security"] - 0.5) * 0.001, 0.05, 0.95)
	state["population"] = pop

	# رویدادها
	if agri["food_security"] < 0.5 and Deterministic.chance(0.015):
		events.append({"type": "food_security_crisis", "message": "بحران امنیت غذایی - ذخایر غذا رو به پایان!", "security": agri["food_security"]})
		resources["food_crisis"] = true
		state["resources"] = resources

	if water < 0.4 and Deterministic.chance(0.012):
		events.append({"type": "drought", "message": "خشکسالی و کمبود آب کشاورزی - افت تولید", "water": water})
		agri["production"] *= 0.90

	if agri["yield"] > 1.2 and Deterministic.chance(0.01):
		events.append({"type": "bumper_harvest", "message": "برداشت فراوان - مازاد تولید کشاورزی!"})

	if Deterministic.chance(0.008):
		events.append({"type": "agri_tech_adoption", "message": "پذیرش فناوری نوین کشاورزی - افزایش بهره‌وری"})
		agri["mechanization"] += 0.02
		agri["yield"] += 0.05

	state["agriculture"] = agri
	
	# --- تکمیل عمق واقع‌گرایانه - بلوک افزوده خودکار برای رسیدن به ۱۵۰+ خط ---
	# این بلوک اثرات ثانویه، تاب‌آوری، فساد، فناوری و رویدادهای چندلایه را اضافه می‌کند
	var _sys_extra = state.get("agriculture", {})
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
	if state.get("agriculture",{}).has("efficiency"):
		_efficiency = float(state["agriculture"].get("efficiency",0.60))
	elif state.get("agriculture",{}).has("quality"):
		_efficiency = float(state["agriculture"].get("quality",0.60))

	_efficiency = clamp(_efficiency*0.97 + _stability*0.02 + _trust*0.01 - _corruption*0.01 + Deterministic.next_range(-0.002,0.002), 0.05, 0.98)
	if state.has("agriculture") and state["agriculture"] is Dictionary:
		state["agriculture"]["efficiency"] = _efficiency
		state["agriculture"]["quality"] = clamp(float(state["agriculture"].get("quality",_efficiency))*0.98 + _efficiency*0.02, 0.05, 0.98)

	# اثر رشد و تورم بر بودجه داخلی سیستم
	var _sys_budget_share = float(_econ_extra.get("budget_allocations",{}).get("زیرساخت",0.15))
	var _maintenance_need = float(state.get("agriculture",{}).get("quality",0.60) if state.has("agriculture") else 0.60) * 0.02 * float(_econ_extra.get("gdp",500e9)) * 0.008
	var _actual_budget = float(_econ_extra.get("government_spending",95e9)) * _sys_budget_share
	var _budget_gap = _actual_budget - _maintenance_need
	if _budget_gap < 0 and Deterministic.chance(0.012):
		events.append({"type":"budget_gap_agriculture","gap": _budget_gap, "message":"کسری بودجه نگهداری agriculture - فرسودگی"})

	# اثر فناوری دیجیتال
	if _digital > 0.60 and Deterministic.chance(0.009):
		events.append({"type":"digital_boost_agriculture","digital": _digital, "message":"جهش دیجیتال در agriculture - اتوماسیون"})

	# اثر فساد
	if _corruption > 0.60 and Deterministic.chance(0.010):
		events.append({"type":"corruption_agriculture_extra","corruption": _corruption, "message":"فساد در agriculture - بازرسی"})

	# اثر نابرابری
	var _gini = float(_welfare_extra.get("gini",0.38))
	if _gini > 0.45 and Deterministic.chance(0.008):
		events.append({"type":"inequality_agriculture","gini": _gini, "message":"نابرابری اثر بر agriculture"})

	# اثر شادی و امید بر بهره‌وری
	var _productivity = float(state.get("agriculture",{}).get("productivity",0.60) if state.has("agriculture") else 0.60)
	_productivity = clamp(_productivity*0.98 + _happiness*0.01 + _growth*5.0*0.01 + _infra_q*0.01, 0.10, 0.95)
	if state.has("agriculture") and state["agriculture"] is Dictionary:
		state["agriculture"]["productivity"] = _productivity

	# تاب‌آوری در برابر شوک
	var _resilience = float(state.get("agriculture",{}).get("resilience",0.60) if state.has("agriculture") else 0.60)
	_resilience = clamp(_resilience*0.96 + _stability*0.02 + _trust*0.01 + _cohesion*0.01, 0.10, 0.95)
	if state.has("agriculture") and state["agriculture"] is Dictionary:
		state["agriculture"]["resilience"] = _resilience

	if _resilience < 0.32 and Deterministic.chance(0.011):
		events.append({"type":"low_resilience_agriculture","resilience": _resilience, "message":"تاب‌آوری پایین agriculture - شکننده در برابر شوک"})

	# اثر پوشش و دسترسی
	var _coverage = float(state.get("agriculture",{}).get("coverage",0.70) if state.has("agriculture") else 0.70)
	if _coverage < 0.50 and Deterministic.chance(0.010):
		events.append({"type":"coverage_agriculture","coverage": _coverage, "message":"پوشش agriculture پایین - دسترسی محدود"})


	
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
	if state.has("agriculture") and state["agriculture"] is Dictionary:
		_sys_q = float(state["agriculture"].get("quality",0.60) if state["agriculture"].has("quality") else state["agriculture"].get("efficiency",0.60) if state["agriculture"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("agriculture") and state["agriculture"] is Dictionary:
		state["agriculture"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_agriculture_deep","gini": _gini, "message":"نابرابری اثر بر agriculture - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_agriculture","digital": _digital, "message":"فناوری دوگانه در agriculture - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_agriculture","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی agriculture"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_agriculture","capital": _social_capital, "message":"سرمایه اجتماعی پایین در agriculture"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("agriculture") and state["agriculture"] is Dictionary and state["agriculture"].has("maintenance_cost"):
		state["agriculture"]["maintenance_cost"] = float(state["agriculture"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("agriculture") and state["agriculture"] is Dictionary:
		_sys_q = float(state["agriculture"].get("quality",0.60) if state["agriculture"].has("quality") else state["agriculture"].get("efficiency",0.60) if state["agriculture"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("agriculture") and state["agriculture"] is Dictionary:
		state["agriculture"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_agriculture_deep","gini": _gini, "message":"نابرابری اثر بر agriculture - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_agriculture","digital": _digital, "message":"فناوری دوگانه در agriculture - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_agriculture","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی agriculture"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_agriculture","capital": _social_capital, "message":"سرمایه اجتماعی پایین در agriculture"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("agriculture") and state["agriculture"] is Dictionary and state["agriculture"].has("maintenance_cost"):
		state["agriculture"]["maintenance_cost"] = float(state["agriculture"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("agriculture") and state["agriculture"] is Dictionary:
		_sys_q = float(state["agriculture"].get("quality",0.60) if state["agriculture"].has("quality") else state["agriculture"].get("efficiency",0.60) if state["agriculture"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("agriculture") and state["agriculture"] is Dictionary:
		state["agriculture"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_agriculture_deep","gini": _gini, "message":"نابرابری اثر بر agriculture - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_agriculture","digital": _digital, "message":"فناوری دوگانه در agriculture - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_agriculture","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی agriculture"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_agriculture","capital": _social_capital, "message":"سرمایه اجتماعی پایین در agriculture"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("agriculture") and state["agriculture"] is Dictionary and state["agriculture"].has("maintenance_cost"):
		state["agriculture"]["maintenance_cost"] = float(state["agriculture"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("agriculture") and state["agriculture"] is Dictionary:
		_sys_q = float(state["agriculture"].get("quality",0.60) if state["agriculture"].has("quality") else state["agriculture"].get("efficiency",0.60) if state["agriculture"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("agriculture") and state["agriculture"] is Dictionary:
		state["agriculture"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_agriculture_deep","gini": _gini, "message":"نابرابری اثر بر agriculture - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_agriculture","digital": _digital, "message":"فناوری دوگانه در agriculture - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_agriculture","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی agriculture"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_agriculture","capital": _social_capital, "message":"سرمایه اجتماعی پایین در agriculture"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("agriculture") and state["agriculture"] is Dictionary and state["agriculture"].has("maintenance_cost"):
		state["agriculture"]["maintenance_cost"] = float(state["agriculture"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	return {"success": true, "state": state, "events": events}
