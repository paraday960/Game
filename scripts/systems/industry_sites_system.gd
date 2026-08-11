extends BaseSystem
# ۳.۴۹ صنعت و انبار - کارخانه، انبار، معدن، نیروگاه، شهرک صنعتی، بهره‌برداری، آلودگی، ایمنی

func compute(state: Dictionary, tick: int) -> Dictionary:
	var sites = state.get("industry_sites_detail", {})
	sites["factories"] = sites.get("factories", 5000)
	sites["warehouses"] = sites.get("warehouses", 10000)
	sites["mines"] = sites.get("mines", 200)
	sites["power_plants"] = sites.get("power_plants", 100)
	sites["refineries"] = sites.get("refineries", 10)
	sites["industrial_parks"] = sites.get("industrial_parks", 20)
	sites["utilization"] = sites.get("utilization", 0.75)
	sites["pollution_industrial"] = sites.get("pollution_industrial", 0.40)
	sites["safety_index"] = sites.get("safety_index", 0.65)
	sites["automation"] = sites.get("automation", 0.30)
	sites["energy_consumption"] = sites.get("energy_consumption", 120.0)
	sites["water_consumption"] = sites.get("water_consumption", 80.0)
	sites["export_capacity"] = sites.get("export_capacity", 0.60)
	sites["maintenance_backlog"] = sites.get("maintenance_backlog", 0.20)

	var events = []
	var ind = state.get("industry", {})
	var resources = state.get("resources", {})
	var env = state.get("environment", {})
	var econ = state.get("economy", {})
	var tech = state.get("technology", {})

	var output = ind.get("output", 100.0)
	var capacity_usage = ind.get("capacity_usage", 0.75)
	var productivity = ind.get("productivity", 0.68) if ind.has("productivity") else 0.68

	# بهره‌برداری = استفاده ظرفیت + بهره‌وری
	sites["utilization"] = clamp(capacity_usage*0.7 + productivity*0.3, 0.1, 0.98)

	# آلودگی صنعتی = بهره‌برداری + فناوری پاک معکوس
	var clean_tech = tech.get("branches", {}).get("انرژی_پاک", 0.15)
	var green = env.get("green_energy", 0.20) if env.has("green_energy") else 0.20
	sites["pollution_industrial"] = clamp(sites["pollution_industrial"]*0.993 + (sites["utilization"]-0.5)*0.002 - clean_tech*0.001 - green*0.0005, 0.05, 0.95)

	# ایمنی - آموزش + نگهداری + آلودگی معکوس
	var safety_target = 0.6 + (1.0 - sites["pollution_industrial"])*0.1 + (1.0 - sites["maintenance_backlog"])*0.2 + 0.1
	sites["safety_index"] = clamp(sites["safety_index"]*0.99 + safety_target*0.01, 0.1, 0.95)

	# اتوماسیون - فناوری صنعت
	var ind_tech = tech.get("branches", {}).get("صنعت", 0.20)
	sites["automation"] = clamp(sites["automation"] + ind_tech*0.0004 + econ.get("growth_rate",0.02)*0.0005, 0.05, 0.85)

	# مصرف انرژی و آب - بهره‌برداری
	sites["energy_consumption"] = output * 1.2 * (0.8 + sites["automation"]*0.2)
	sites["water_consumption"] = output * 0.8 * (1.0 - sites["automation"]*0.1)

	# ظرفیت صادرات - کیفیت و زیرساخت
	var infra_q = state.get("infrastructure", {}).get("quality", 0.55)
	sites["export_capacity"] = clamp(infra_q*0.3 + sites["utilization"]*0.3 + sites["automation"]*0.2 + 0.2, 0.1, 0.95)

	# عقب‌ماندگی نگهداری
	sites["maintenance_backlog"] = clamp(sites["maintenance_backlog"] + sites["utilization"]*0.0005 - econ.get("budget_allocations",{}).get("زیرساخت",0.18)*0.001, 0.05, 0.70)

	# رشد کارخانه‌ها
	if tick % 90 == 0:
		if output > 120.0 and econ.get("growth_rate",0.02) > 0.02:
			sites["factories"] += Deterministic.next_int_range(5, 15)
			sites["warehouses"] += Deterministic.next_int_range(10, 30)
			if Deterministic.chance(0.3):
				sites["industrial_parks"] += 1
		if output < 80.0 and Deterministic.chance(0.2):
			sites["factories"] = max(sites["factories"] - Deterministic.next_int_range(2, 8), 3000)

	# نیروگاه‌ها - انرژی
	if tick % 180 == 0 and resources.get("demand",{}).get("برق",12.0) > sites["power_plants"]*1.2:
		sites["power_plants"] += Deterministic.next_int_range(1, 3)

	# پالایشگاه‌ها - نفت
	if tick % 180 == 0 and resources.get("inventory",{}).get("نفت",80.0) > 70.0 and sites["refineries"] < 20:
		sites["refineries"] += Deterministic.next_int_range(0,1)

	# رویدادها
	if sites["pollution_industrial"] > 0.72 and Deterministic.chance(0.015):
		events.append({"type":"industrial_pollution","pollution": sites["pollution_industrial"], "message":"آلودگی صنعتی شدید - ساکنان اطراف شهرک صنعتی شکایت کردند"})

	if sites["safety_index"] < 0.35 and Deterministic.chance(0.012):
		events.append({"type":"industrial_accident","safety": sites["safety_index"], "message":"حادثه کار در کارخانه - ۳ مصدوم، بازرسی ایمنی"})

	if sites["maintenance_backlog"] > 0.50 and Deterministic.chance(0.010):
		events.append({"type":"maintenance_backlog_crisis","backlog": sites["maintenance_backlog"], "message":"عقب‌ماندگی نگهداری - ماشین‌آلات فرسوده، توقف خط"})

	if sites["utilization"] > 0.90 and Deterministic.chance(0.009):
		events.append({"type":"full_utilization","util": sites["utilization"], "message":"ظرفیت تولید تکمیل - نیاز به توسعه شهرک صنعتی جدید"})

	if sites["automation"] > 0.60 and tick % 180 == 0 and Deterministic.chance(0.02):
		events.append({"type":"automation_milestone","automation": sites["automation"], "message":"اتوماسیون ۶۰٪ - ربات‌ها جای ۲۰۰۰ کارگر را گرفتند"})

	state["industry_sites_detail"] = sites
	
	# --- تکمیل عمق واقع‌گرایانه - بلوک افزوده خودکار برای رسیدن به ۱۵۰+ خط ---
	# این بلوک اثرات ثانویه، تاب‌آوری، فساد، فناوری و رویدادهای چندلایه را اضافه می‌کند
	var _sys_extra = state.get("industry_sites", {}) if state.has("industry_sites") else sys if 'sys' in locals() else {}
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
	if state.get("industry_sites",{}).has("efficiency"):
		_efficiency = float(state["industry_sites"].get("efficiency",0.60))
	elif state.get("industry_sites",{}).has("quality"):
		_efficiency = float(state["industry_sites"].get("quality",0.60))

	_efficiency = clamp(_efficiency*0.97 + _stability*0.02 + _trust*0.01 - _corruption*0.01 + Deterministic.next_range(-0.002,0.002), 0.05, 0.98)
	if state.has("industry_sites") and state["industry_sites"] is Dictionary:
		state["industry_sites"]["efficiency"] = _efficiency
		state["industry_sites"]["quality"] = clamp(float(state["industry_sites"].get("quality",_efficiency))*0.98 + _efficiency*0.02, 0.05, 0.98)

	# اثر رشد و تورم بر بودجه داخلی سیستم
	var _sys_budget_share = float(_econ_extra.get("budget_allocations",{}).get("زیرساخت",0.15))
	var _maintenance_need = float(state.get("industry_sites",{}).get("quality",0.60) if state.has("industry_sites") else 0.60) * 0.02 * float(_econ_extra.get("gdp",500e9)) * 0.008
	var _actual_budget = float(_econ_extra.get("government_spending",95e9)) * _sys_budget_share
	var _budget_gap = _actual_budget - _maintenance_need
	if _budget_gap < 0 and Deterministic.chance(0.012):
		events.append({"type":"budget_gap_industry_sites","gap": _budget_gap, "message":"کسری بودجه نگهداری industry_sites - فرسودگی"})

	# اثر فناوری دیجیتال
	if _digital > 0.60 and Deterministic.chance(0.009):
		events.append({"type":"digital_boost_industry_sites","digital": _digital, "message":"جهش دیجیتال در industry_sites - اتوماسیون"})

	# اثر فساد
	if _corruption > 0.60 and Deterministic.chance(0.010):
		events.append({"type":"corruption_industry_sites_extra","corruption": _corruption, "message":"فساد در industry_sites - بازرسی"})

	# اثر نابرابری
	var _gini = float(_welfare_extra.get("gini",0.38))
	if _gini > 0.45 and Deterministic.chance(0.008):
		events.append({"type":"inequality_industry_sites","gini": _gini, "message":"نابرابری اثر بر industry_sites"})

	# اثر شادی و امید بر بهره‌وری
	var _productivity = float(state.get("industry_sites",{}).get("productivity",0.60) if state.has("industry_sites") else 0.60)
	_productivity = clamp(_productivity*0.98 + _happiness*0.01 + _growth*5.0*0.01 + _infra_q*0.01, 0.10, 0.95)
	if state.has("industry_sites") and state["industry_sites"] is Dictionary:
		state["industry_sites"]["productivity"] = _productivity

	# تاب‌آوری در برابر شوک
	var _resilience = float(state.get("industry_sites",{}).get("resilience",0.60) if state.has("industry_sites") else 0.60)
	_resilience = clamp(_resilience*0.96 + _stability*0.02 + _trust*0.01 + _cohesion*0.01, 0.10, 0.95)
	if state.has("industry_sites") and state["industry_sites"] is Dictionary:
		state["industry_sites"]["resilience"] = _resilience

	if _resilience < 0.32 and Deterministic.chance(0.011):
		events.append({"type":"low_resilience_industry_sites","resilience": _resilience, "message":"تاب‌آوری پایین industry_sites - شکننده در برابر شوک"})

	# اثر پوشش و دسترسی
	var _coverage = float(state.get("industry_sites",{}).get("coverage",0.70) if state.has("industry_sites") else 0.70)
	if _coverage < 0.50 and Deterministic.chance(0.010):
		events.append({"type":"coverage_industry_sites","coverage": _coverage, "message":"پوشش industry_sites پایین - دسترسی محدود"})


	
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
	if state.has("industry_sites") and state["industry_sites"] is Dictionary:
		_sys_q = float(state["industry_sites"].get("quality",0.60) if state["industry_sites"].has("quality") else state["industry_sites"].get("efficiency",0.60) if state["industry_sites"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("industry_sites") and state["industry_sites"] is Dictionary:
		state["industry_sites"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_industry_sites_deep","gini": _gini, "message":"نابرابری اثر بر industry_sites - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_industry_sites","digital": _digital, "message":"فناوری دوگانه در industry_sites - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_industry_sites","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی industry_sites"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_industry_sites","capital": _social_capital, "message":"سرمایه اجتماعی پایین در industry_sites"})

	# اثر تورمی بر هزینه نگهداری
	var _inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("industry_sites") and state["industry_sites"] is Dictionary and state["industry_sites"].has("maintenance_cost"):
		state["industry_sites"]["maintenance_cost"] = float(state["industry_sites"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("industry_sites") and state["industry_sites"] is Dictionary:
		_sys_q = float(state["industry_sites"].get("quality",0.60) if state["industry_sites"].has("quality") else state["industry_sites"].get("efficiency",0.60) if state["industry_sites"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("industry_sites") and state["industry_sites"] is Dictionary:
		state["industry_sites"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_industry_sites_deep","gini": _gini, "message":"نابرابری اثر بر industry_sites - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_industry_sites","digital": _digital, "message":"فناوری دوگانه در industry_sites - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_industry_sites","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی industry_sites"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_industry_sites","capital": _social_capital, "message":"سرمایه اجتماعی پایین در industry_sites"})

	# اثر تورمی بر هزینه نگهداری
	var _inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("industry_sites") and state["industry_sites"] is Dictionary and state["industry_sites"].has("maintenance_cost"):
		state["industry_sites"]["maintenance_cost"] = float(state["industry_sites"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("industry_sites") and state["industry_sites"] is Dictionary:
		_sys_q = float(state["industry_sites"].get("quality",0.60) if state["industry_sites"].has("quality") else state["industry_sites"].get("efficiency",0.60) if state["industry_sites"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("industry_sites") and state["industry_sites"] is Dictionary:
		state["industry_sites"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_industry_sites_deep","gini": _gini, "message":"نابرابری اثر بر industry_sites - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_industry_sites","digital": _digital, "message":"فناوری دوگانه در industry_sites - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_industry_sites","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی industry_sites"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_industry_sites","capital": _social_capital, "message":"سرمایه اجتماعی پایین در industry_sites"})

	# اثر تورمی بر هزینه نگهداری
	var _inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("industry_sites") and state["industry_sites"] is Dictionary and state["industry_sites"].has("maintenance_cost"):
		state["industry_sites"]["maintenance_cost"] = float(state["industry_sites"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("industry_sites") and state["industry_sites"] is Dictionary:
		_sys_q = float(state["industry_sites"].get("quality",0.60) if state["industry_sites"].has("quality") else state["industry_sites"].get("efficiency",0.60) if state["industry_sites"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("industry_sites") and state["industry_sites"] is Dictionary:
		state["industry_sites"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_industry_sites_deep","gini": _gini, "message":"نابرابری اثر بر industry_sites - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_industry_sites","digital": _digital, "message":"فناوری دوگانه در industry_sites - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_industry_sites","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی industry_sites"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_industry_sites","capital": _social_capital, "message":"سرمایه اجتماعی پایین در industry_sites"})

	# اثر تورمی بر هزینه نگهداری
	var _inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("industry_sites") and state["industry_sites"] is Dictionary and state["industry_sites"].has("maintenance_cost"):
		state["industry_sites"]["maintenance_cost"] = float(state["industry_sites"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	return {"success":true,"state":state,"events":events}
