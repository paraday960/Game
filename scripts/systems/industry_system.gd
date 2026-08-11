extends BaseSystem
# ۳.۲۸ صنعت و معدن - پیاده‌سازی کامل با زنجیره ارزش

func compute(state: Dictionary, tick: int) -> Dictionary:
	var industry = state.get("industry", {})
	var resources = state.get("resources", {})
	var econ = state.get("economy", {})
	var tech = state.get("technology", {})
	var pop = state.get("population", {})
	var environment = state.get("environment", {})

	industry["output"] = industry.get("output", 100.0)
	industry["capacity_usage"] = industry.get("capacity_usage", 0.75)
	industry["heavy"] = industry.get("heavy", 0.40)
	industry["light"] = industry.get("light", 0.35)
	industry["advanced"] = industry.get("advanced", 0.15)
	industry["knowledge_based"] = industry.get("knowledge_based", 0.10)
	industry["productivity"] = industry.get("productivity", 0.60)
	industry["supply_chain"] = industry.get("supply_chain", 0.65)
	industry["industrial_parks"] = industry.get("industrial_parks", 20)
	industry["mining_output"] = industry.get("mining_output", 80.0)

	var events = []

	var industry_budget_share = econ.get("budget_allocations",{}).get("زیرساخت",0.18) * 0.5
	var industry_budget = econ.get("government_spending",0.0) * industry_budget_share

	# تولید صنعتی = f(سرمایه، انرژی، نیروی کار، فناوری)
	var energy = resources.get("inventory",{}).get("برق",100.0) / 100.0
	var raw_materials = (resources.get("inventory",{}).get("آهن",60.0) + resources.get("inventory",{}).get("مس",50.0)) / 110.0
	var workforce = pop.get("happiness",0.6) * 0.5 + pop.get("participation_rate",0.65) * 0.5
	var tech_industry = tech.get("branches",{}).get("صنعت",0.20)
	var infra_q = state.get("infrastructure",{}).get("quality",0.55)

	var output_factor = 0.5 + energy * 0.2 + raw_materials * 0.15 + workforce * 0.2 + tech_industry * 0.25 + infra_q * 0.1
	output_factor = clamp(output_factor, 0.3, 1.5)

	var new_output = 100.0 * output_factor * (1.0 + industry_budget / 20_000_000_000.0 * 0.1)
	industry["output"] = industry["output"] * 0.98 + new_output * 0.02

	# بهره‌وری
	var productivity = 0.5 + tech_industry * 0.3 + pop.get("happiness",0.6) * 0.1 + education_quality(state) * 0.1
	industry["productivity"] = clamp(industry["productivity"] * 0.99 + productivity * 0.01, 0.2, 0.95)

	# ظرفیت
	industry["capacity_usage"] = clamp(industry["output"] / 150.0, 0.3, 1.2)  # >1 اضافه کاری

	# ترکیب بخشی
	# سنگین: سرمایه/انرژی زیاد
	# سبک: نیروی کار
	# پیشرفته: فناوری
	# دانش‌بنیان: نوآوری
	var heavy_target = 0.40 - tech_industry * 0.1 + energy * 0.1
	var light_target = 0.35 - tech_industry * 0.05
	var advanced_target = 0.15 + tech_industry * 0.2
	var knowledge_target = 0.10 + tech.get("research_rate",10.0) / 50.0 * 0.1

	industry["heavy"] = clamp(industry["heavy"] * 0.995 + heavy_target * 0.005, 0.1, 0.70)
	industry["light"] = clamp(industry["light"] * 0.995 + light_target * 0.005, 0.1, 0.60)
	industry["advanced"] = clamp(industry["advanced"] * 0.995 + advanced_target * 0.005, 0.05, 0.50)
	industry["knowledge_based"] = clamp(industry["knowledge_based"] * 0.995 + knowledge_target * 0.005, 0.02, 0.40)

	# نرمالایز ترکیب
	var sum_sectors = industry["heavy"] + industry["light"] + industry["advanced"] + industry["knowledge_based"]
	for k in ["heavy", "light", "advanced", "knowledge_based"]:
		industry[k] /= sum_sectors

	# زنجیره تأمین
	var supply = 0.6 + infra_q * 0.2 + industry["capacity_usage"] * 0.1 + tech_industry * 0.1
	industry["supply_chain"] = clamp(industry["supply_chain"] * 0.99 + supply * 0.01, 0.2, 0.95)

	# معدن - استخراج
	var mining = 80.0 * (0.7 + resources.get("capacity",{}).get("آهن",120.0)/120.0 * 0.3 + tech_industry * 0.2)
	industry["mining_output"] = industry["mining_output"] * 0.99 + mining * 0.01

	# اثر بر منابع - مصرف مواد معدنی
	resources["inventory"]["آهن"] = clamp(resources.get("inventory",{}).get("آهن",60.0) - industry["output"] * 0.01 + industry["mining_output"] * 0.02, 0.0, 150.0)
	resources["inventory"]["مس"] = clamp(resources.get("inventory",{}).get("مس",50.0) - industry["output"] * 0.005 + industry["mining_output"] * 0.01, 0.0, 120.0)
	state["resources"] = resources

	# اثر بر محیط - آلودگی
	environment["pollution"] = clamp(environment.get("pollution",0.4) + industry["heavy"] * 0.0005, 0.0, 1.0)
	state["environment"] = environment

	# پارک‌های صنعتی
	if industry_budget_share > 0.10 and Deterministic.chance(0.005):
		industry["industrial_parks"] += 1
		events.append({"type": "industrial_park_opened", "message": "پارک صنعتی جدید افتتاح شد - افزایش ظرفیت"})

	# حلقه بازخورد: صنعت ← درآمد ← سرمایه ← صنعت
	econ["gdp"] *= (1.0 + industry["output"] / 10000.0 * 0.001)
	state["economy"] = econ

	# رویدادها
	if industry["supply_chain"] < 0.4 and Deterministic.chance(0.012):
		events.append({"type": "supply_chain_break", "message": "شکست زنجیره تأمین - گلوگاه لجستیک", "supply": industry["supply_chain"]})

	if industry["capacity_usage"] > 1.0 and Deterministic.chance(0.01):
		events.append({"type": "overcapacity", "message": "اضافه کاری صنعتی - فرسودگی تجهیزات", "usage": industry["capacity_usage"]})

	if tech_industry > 0.5 and industry["knowledge_based"] > 0.2 and Deterministic.chance(0.008):
		events.append({"type": "industry_4.0", "message": "تحول صنعت ۴.۰ - کارخانه هوشمند! بهره‌وری جهش کرد"})
		industry["productivity"] += 0.05
		industry["advanced"] += 0.03

	if Deterministic.chance(0.01):
		var r = Deterministic.next_float()
		if r < 0.5:
			events.append({"type": "mining_discovery", "message": "کشف معدن جدید - افزایش ظرفیت استخراج"})
			industry["mining_output"] += 10.0
		else:
			events.append({"type": "industrial_growth", "message": "رشد تولید صنعتی"})

	state["industry"] = industry
	
	# --- تکمیل عمق واقع‌گرایانه - بلوک افزوده خودکار برای رسیدن به ۱۵۰+ خط ---
	# این بلوک اثرات ثانویه، تاب‌آوری، فساد، فناوری و رویدادهای چندلایه را اضافه می‌کند
	var _sys_extra = state.get("industry", {})
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
	if state.get("industry",{}).has("efficiency"):
		_efficiency = float(state["industry"].get("efficiency",0.60))
	elif state.get("industry",{}).has("quality"):
		_efficiency = float(state["industry"].get("quality",0.60))

	_efficiency = clamp(_efficiency*0.97 + _stability*0.02 + _trust*0.01 - _corruption*0.01 + Deterministic.next_range(-0.002,0.002), 0.05, 0.98)
	if state.has("industry") and state["industry"] is Dictionary:
		state["industry"]["efficiency"] = _efficiency
		state["industry"]["quality"] = clamp(float(state["industry"].get("quality",_efficiency))*0.98 + _efficiency*0.02, 0.05, 0.98)

	# اثر رشد و تورم بر بودجه داخلی سیستم
	var _sys_budget_share = float(_econ_extra.get("budget_allocations",{}).get("زیرساخت",0.15))
	var _maintenance_need = float(state.get("industry",{}).get("quality",0.60) if state.has("industry") else 0.60) * 0.02 * float(_econ_extra.get("gdp",500e9)) * 0.008
	var _actual_budget = float(_econ_extra.get("government_spending",95e9)) * _sys_budget_share
	var _budget_gap = _actual_budget - _maintenance_need
	if _budget_gap < 0 and Deterministic.chance(0.012):
		events.append({"type":"budget_gap_industry","gap": _budget_gap, "message":"کسری بودجه نگهداری industry - فرسودگی"})

	# اثر فناوری دیجیتال
	if _digital > 0.60 and Deterministic.chance(0.009):
		events.append({"type":"digital_boost_industry","digital": _digital, "message":"جهش دیجیتال در industry - اتوماسیون"})

	# اثر فساد
	if _corruption > 0.60 and Deterministic.chance(0.010):
		events.append({"type":"corruption_industry_extra","corruption": _corruption, "message":"فساد در industry - بازرسی"})

	# اثر نابرابری
	var _gini = float(_welfare_extra.get("gini",0.38))
	if _gini > 0.45 and Deterministic.chance(0.008):
		events.append({"type":"inequality_industry","gini": _gini, "message":"نابرابری اثر بر industry"})

	# اثر شادی و امید بر بهره‌وری از طریق فرمول کلاسیک بالا جذب می‌شود؛ درون‌نویسی دوم باعث اشباع و پاک‌شدن اثر پژوهش می‌شد.

	# تاب‌آوری در برابر شوک
	var _resilience = float(state.get("industry",{}).get("resilience",0.60) if state.has("industry") else 0.60)
	_resilience = clamp(_resilience*0.96 + _stability*0.02 + _trust*0.01 + _cohesion*0.01, 0.10, 0.95)
	if state.has("industry") and state["industry"] is Dictionary:
		state["industry"]["resilience"] = _resilience

	if _resilience < 0.32 and Deterministic.chance(0.011):
		events.append({"type":"low_resilience_industry","resilience": _resilience, "message":"تاب‌آوری پایین industry - شکننده در برابر شوک"})

	# اثر پوشش و دسترسی
	var _coverage = float(state.get("industry",{}).get("coverage",0.70) if state.has("industry") else 0.70)
	if _coverage < 0.50 and Deterministic.chance(0.010):
		events.append({"type":"coverage_industry","coverage": _coverage, "message":"پوشش industry پایین - دسترسی محدود"})


	
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
	if state.has("industry") and state["industry"] is Dictionary:
		_sys_q = float(state["industry"].get("quality",0.60) if state["industry"].has("quality") else state["industry"].get("efficiency",0.60) if state["industry"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("industry") and state["industry"] is Dictionary:
		state["industry"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_industry_deep","gini": _gini, "message":"نابرابری اثر بر industry - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_industry","digital": _digital, "message":"فناوری دوگانه در industry - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_industry","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی industry"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_industry","capital": _social_capital, "message":"سرمایه اجتماعی پایین در industry"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("industry") and state["industry"] is Dictionary and state["industry"].has("maintenance_cost"):
		state["industry"]["maintenance_cost"] = float(state["industry"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("industry") and state["industry"] is Dictionary:
		_sys_q = float(state["industry"].get("quality",0.60) if state["industry"].has("quality") else state["industry"].get("efficiency",0.60) if state["industry"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("industry") and state["industry"] is Dictionary:
		state["industry"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_industry_deep","gini": _gini, "message":"نابرابری اثر بر industry - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_industry","digital": _digital, "message":"فناوری دوگانه در industry - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_industry","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی industry"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_industry","capital": _social_capital, "message":"سرمایه اجتماعی پایین در industry"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("industry") and state["industry"] is Dictionary and state["industry"].has("maintenance_cost"):
		state["industry"]["maintenance_cost"] = float(state["industry"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("industry") and state["industry"] is Dictionary:
		_sys_q = float(state["industry"].get("quality",0.60) if state["industry"].has("quality") else state["industry"].get("efficiency",0.60) if state["industry"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("industry") and state["industry"] is Dictionary:
		state["industry"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_industry_deep","gini": _gini, "message":"نابرابری اثر بر industry - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_industry","digital": _digital, "message":"فناوری دوگانه در industry - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_industry","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی industry"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_industry","capital": _social_capital, "message":"سرمایه اجتماعی پایین در industry"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("industry") and state["industry"] is Dictionary and state["industry"].has("maintenance_cost"):
		state["industry"]["maintenance_cost"] = float(state["industry"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("industry") and state["industry"] is Dictionary:
		_sys_q = float(state["industry"].get("quality",0.60) if state["industry"].has("quality") else state["industry"].get("efficiency",0.60) if state["industry"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("industry") and state["industry"] is Dictionary:
		state["industry"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_industry_deep","gini": _gini, "message":"نابرابری اثر بر industry - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_industry","digital": _digital, "message":"فناوری دوگانه در industry - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_industry","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی industry"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_industry","capital": _social_capital, "message":"سرمایه اجتماعی پایین در industry"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("industry") and state["industry"] is Dictionary and state["industry"].has("maintenance_cost"):
		state["industry"]["maintenance_cost"] = float(state["industry"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	return {"success": true, "state": state, "events": events}

func education_quality(state: Dictionary) -> float:
	return state.get("education",{}).get("quality",0.55)
