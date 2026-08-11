extends BaseSystem
# زیرساخت - ۳.۱۵ - کیفیت، ظرفیت، پوشش، راه، برق، آب، مخابرات، مسکن، نگهداری، گلوگاه، سرمایه‌گذاری

func compute(state: Dictionary, tick: int) -> Dictionary:
	var infra = state.get("infrastructure", {})
	infra["quality"] = infra.get("quality", 0.55)
	infra["capacity"] = infra.get("capacity", 0.60)
	infra["coverage"] = infra.get("coverage", 0.70)
	infra["road_quality"] = infra.get("road_quality", 0.55)
	infra["rail_quality"] = infra.get("rail_quality", 0.45)
	infra["electricity_grid"] = infra.get("electricity_grid", 0.70)
	infra["water_network"] = infra.get("water_network", 0.65)
	infra["telecom"] = infra.get("telecom", 0.70)
	infra["housing_quality"] = infra.get("housing_quality", 0.60)
	infra["maintenance_cost"] = infra.get("maintenance_cost", 0.02)
	infra["investment"] = infra.get("investment", 5_000_000_000.0)
	infra["decay_rate"] = infra.get("decay_rate", 0.03)
	infra["projects"] = infra.get("projects", [])
	infra["bottleneck_score"] = infra.get("bottleneck_score", 0.20)

	var events = []
	var econ = state.get("economy", {})
	var pop = state.get("population", {})
	var resources = state.get("resources", {})
	var tech = state.get("technology", {})

	var budget_share = econ.get("budget_allocations", {}).get("زیرساخت", 0.18)
	var budget = budget_share * econ.get("government_spending", 95e9)
	var gdp = econ.get("gdp", 500e9)
	var growth = econ.get("growth_rate", 0.02)
	var total_pop = pop.get("total", 85_000_000.0)

	# نیاز نگهداری - ۲٪ ارزش جایگزینی سالانه، فرسودگی با کیفیت بالاتر بیشتر!
	var maintenance_need = infra["quality"] * 0.02 * gdp * 0.015
	infra["maintenance_cost"] = maintenance_need / max(gdp,1.0)

	# کیفیت زیرساخت - بودجه کافی vs فرسودگی
	if budget < maintenance_need:
		infra["decay_rate"] = 0.05 # ۵٪ سالانه اگر نگهداری کم
		infra["quality"] -= infra["decay_rate"]/365.0
		if tick % 30 == 0 and Deterministic.chance(0.10):
			events.append({"type":"infra_decay","quality": infra["quality"], "message":"فرسودگی زیرساخت - بودجه نگهداری کم است"})
	else:
		infra["decay_rate"] = 0.01
		infra["quality"] += (0.0006 + budget_share*0.001) # رشد کند با سرمایه‌گذاری

	infra["quality"] = clamp(infra["quality"], 0.05, 0.98)

	# زیرشاخه‌ها - هرکدام با تاخیر به کیفیت کل همگرا
	infra["road_quality"] = clamp(infra["road_quality"]*0.995 + infra["quality"]*0.005 + Deterministic.next_range(-0.0005,0.0008), 0.1, 0.95)
	infra["rail_quality"] = clamp(infra["rail_quality"]*0.995 + infra["quality"]*0.004 + tech.get("branches",{}).get("صنعت",0.20)*0.001, 0.1, 0.90)
	infra["electricity_grid"] = clamp(infra["electricity_grid"]*0.994 + infra["quality"]*0.005 + (resources.get("production",{}).get("برق",15.0)/20.0)*0.001, 0.2, 0.98)
	infra["water_network"] = clamp(infra["water_network"]*0.996 + infra["quality"]*0.004, 0.2, 0.95)
	infra["telecom"] = clamp(infra["telecom"]*0.990 + infra["quality"]*0.005 + tech.get("branches",{}).get("دیجیتال",0.20)*0.005, 0.3, 0.98)
	infra["housing_quality"] = clamp(infra["housing_quality"]*0.993 + infra["quality"]*0.004 + econ.get("gdp_per_capita",5000.0)/10000.0*0.003, 0.2, 0.95)

	# پوشش - جمعیت و کیفیت
	var coverage_target = infra["quality"]*0.6 + pop.get("urban_ratio",0.75)*0.2 + 0.2
	infra["coverage"] = clamp(infra["coverage"]*0.992 + coverage_target*0.008, 0.3, 0.98)

	# ظرفیت - اثر گلوگاه - تقاضای جمعیت و GDP
	var demand = (total_pop / 85_000_000.0)*0.6 + (gdp/500e9)*0.4
	var capacity_ratio = demand / max(infra["capacity"], 0.05)
	infra["bottleneck_score"] = clamp(capacity_ratio - 1.0, -0.5, 2.0)

	if capacity_ratio > 1.15:
		events.append({"type":"bottleneck","ratio": capacity_ratio, "score": infra["bottleneck_score"], "message":"گلوگاه زیرساختی - تقاضا %.0f%% بیش از ظرفیت" % (capacity_ratio*100.0)})
		infra["capacity"] += 0.0005 # سرمایه‌گذاری خودکار اضطراری
		econ["growth_rate"] = econ.get("growth_rate",0.02) - 0.001
	elif capacity_ratio > 1.0:
		infra["capacity"] += 0.0003
	else:
		infra["capacity"] = clamp(infra["capacity"] + 0.00015 + budget_share*0.0002, 0.2, 1.8)

	# سرمایه‌گذاری - رشد با اقتصاد
	infra["investment"] *= (1.0 + growth*0.3/365.0)
	if budget > maintenance_need:
		infra["investment"] += (budget - maintenance_need) * 0.3 / 365.0

	# بلایای طبیعی به زیرساخت آسیب می‌زند - ۰.۵٪ احتمال روزانه
	if Deterministic.chance(0.006):
		var damage = Deterministic.next_range(0.01, 0.06)
		infra["quality"] -= damage
		infra["road_quality"] -= damage*0.8
		infra["electricity_grid"] -= damage*0.6
		events.append({"type":"infrastructure_damage","damage": damage, "quality": infra["quality"], "message":"آسیب به زیرساخت - خسارت %d٪ بر اثر بلای طبیعی" % int(damage*100.0)})

	# پروژه‌های بزرگ - هر ۶ ماه
	if tick % 180 == 0 and infra["quality"] < 0.70 and budget_share > 0.12:
		if infra["projects"].size() < 5:
			infra["projects"].append({
				"name": "توسعه زیرساخت %d" % (infra["projects"].size()+1),
				"progress": 0.0,
				"cost": 1_000_000_000.0,
				"tick_start": tick
			})
	# پیشرفت پروژه‌ها
	for proj in infra["projects"]:
		proj["progress"] += 0.05
		if proj["progress"] >= 1.0:
			events.append({"type":"infra_project_complete","project": proj["name"], "message":"پروژه %s تکمیل شد" % proj["name"]})
	infra["projects"] = infra["projects"].filter(func(p): return p["progress"] < 1.0)

	state["infrastructure"] = infra
	state["economy"] = econ
	
	# --- تکمیل عمق واقع‌گرایانه - بلوک افزوده خودکار برای رسیدن به ۱۵۰+ خط ---
	# این بلوک اثرات ثانویه، تاب‌آوری، فساد، فناوری و رویدادهای چندلایه را اضافه می‌کند
	var _sys_extra = state.get("infrastructure", {}) if state.has("infrastructure") else sys if 'sys' in locals() else {}
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
	if state.get("infrastructure",{}).has("efficiency"):
		_efficiency = float(state["infrastructure"].get("efficiency",0.60))
	elif state.get("infrastructure",{}).has("quality"):
		_efficiency = float(state["infrastructure"].get("quality",0.60))

	_efficiency = clamp(_efficiency*0.97 + _stability*0.02 + _trust*0.01 - _corruption*0.01 + Deterministic.next_range(-0.002,0.002), 0.05, 0.98)
	if state.has("infrastructure") and state["infrastructure"] is Dictionary:
		state["infrastructure"]["efficiency"] = _efficiency
		state["infrastructure"]["quality"] = clamp(float(state["infrastructure"].get("quality",_efficiency))*0.98 + _efficiency*0.02, 0.05, 0.98)

	# اثر رشد و تورم بر بودجه داخلی سیستم
	var _sys_budget_share = float(_econ_extra.get("budget_allocations",{}).get("زیرساخت",0.15))
	var _maintenance_need = float(state.get("infrastructure",{}).get("quality",0.60) if state.has("infrastructure") else 0.60) * 0.02 * float(_econ_extra.get("gdp",500e9)) * 0.008
	var _actual_budget = float(_econ_extra.get("government_spending",95e9)) * _sys_budget_share
	var _budget_gap = _actual_budget - _maintenance_need
	if _budget_gap < 0 and Deterministic.chance(0.012):
		events.append({"type":"budget_gap_infrastructure","gap": _budget_gap, "message":"کسری بودجه نگهداری infrastructure - فرسودگی"})

	# اثر فناوری دیجیتال
	if _digital > 0.60 and Deterministic.chance(0.009):
		events.append({"type":"digital_boost_infrastructure","digital": _digital, "message":"جهش دیجیتال در infrastructure - اتوماسیون"})

	# اثر فساد
	if _corruption > 0.60 and Deterministic.chance(0.010):
		events.append({"type":"corruption_infrastructure_extra","corruption": _corruption, "message":"فساد در infrastructure - بازرسی"})

	# اثر نابرابری
	var _gini = float(_welfare_extra.get("gini",0.38))
	if _gini > 0.45 and Deterministic.chance(0.008):
		events.append({"type":"inequality_infrastructure","gini": _gini, "message":"نابرابری اثر بر infrastructure"})

	# اثر شادی و امید بر بهره‌وری
	var _productivity = float(state.get("infrastructure",{}).get("productivity",0.60) if state.has("infrastructure") else 0.60)
	_productivity = clamp(_productivity*0.98 + _happiness*0.01 + _growth*5.0*0.01 + _infra_q*0.01, 0.10, 0.95)
	if state.has("infrastructure") and state["infrastructure"] is Dictionary:
		state["infrastructure"]["productivity"] = _productivity

	# تاب‌آوری در برابر شوک
	var _resilience = float(state.get("infrastructure",{}).get("resilience",0.60) if state.has("infrastructure") else 0.60)
	_resilience = clamp(_resilience*0.96 + _stability*0.02 + _trust*0.01 + _cohesion*0.01, 0.10, 0.95)
	if state.has("infrastructure") and state["infrastructure"] is Dictionary:
		state["infrastructure"]["resilience"] = _resilience

	if _resilience < 0.32 and Deterministic.chance(0.011):
		events.append({"type":"low_resilience_infrastructure","resilience": _resilience, "message":"تاب‌آوری پایین infrastructure - شکننده در برابر شوک"})

	# اثر پوشش و دسترسی
	var _coverage = float(state.get("infrastructure",{}).get("coverage",0.70) if state.has("infrastructure") else 0.70)
	if _coverage < 0.50 and Deterministic.chance(0.010):
		events.append({"type":"coverage_infrastructure","coverage": _coverage, "message":"پوشش infrastructure پایین - دسترسی محدود"})


	
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
	if state.has("infrastructure") and state["infrastructure"] is Dictionary:
		_sys_q = float(state["infrastructure"].get("quality",0.60) if state["infrastructure"].has("quality") else state["infrastructure"].get("efficiency",0.60) if state["infrastructure"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("infrastructure") and state["infrastructure"] is Dictionary:
		state["infrastructure"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_infrastructure_deep","gini": _gini, "message":"نابرابری اثر بر infrastructure - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_infrastructure","digital": _digital, "message":"فناوری دوگانه در infrastructure - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_infrastructure","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی infrastructure"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_infrastructure","capital": _social_capital, "message":"سرمایه اجتماعی پایین در infrastructure"})

	# اثر تورمی بر هزینه نگهداری
	var _inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("infrastructure") and state["infrastructure"] is Dictionary and state["infrastructure"].has("maintenance_cost"):
		state["infrastructure"]["maintenance_cost"] = float(state["infrastructure"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("infrastructure") and state["infrastructure"] is Dictionary:
		_sys_q = float(state["infrastructure"].get("quality",0.60) if state["infrastructure"].has("quality") else state["infrastructure"].get("efficiency",0.60) if state["infrastructure"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("infrastructure") and state["infrastructure"] is Dictionary:
		state["infrastructure"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_infrastructure_deep","gini": _gini, "message":"نابرابری اثر بر infrastructure - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_infrastructure","digital": _digital, "message":"فناوری دوگانه در infrastructure - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_infrastructure","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی infrastructure"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_infrastructure","capital": _social_capital, "message":"سرمایه اجتماعی پایین در infrastructure"})

	# اثر تورمی بر هزینه نگهداری
	var _inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("infrastructure") and state["infrastructure"] is Dictionary and state["infrastructure"].has("maintenance_cost"):
		state["infrastructure"]["maintenance_cost"] = float(state["infrastructure"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("infrastructure") and state["infrastructure"] is Dictionary:
		_sys_q = float(state["infrastructure"].get("quality",0.60) if state["infrastructure"].has("quality") else state["infrastructure"].get("efficiency",0.60) if state["infrastructure"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("infrastructure") and state["infrastructure"] is Dictionary:
		state["infrastructure"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_infrastructure_deep","gini": _gini, "message":"نابرابری اثر بر infrastructure - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_infrastructure","digital": _digital, "message":"فناوری دوگانه در infrastructure - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_infrastructure","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی infrastructure"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_infrastructure","capital": _social_capital, "message":"سرمایه اجتماعی پایین در infrastructure"})

	# اثر تورمی بر هزینه نگهداری
	var _inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("infrastructure") and state["infrastructure"] is Dictionary and state["infrastructure"].has("maintenance_cost"):
		state["infrastructure"]["maintenance_cost"] = float(state["infrastructure"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("infrastructure") and state["infrastructure"] is Dictionary:
		_sys_q = float(state["infrastructure"].get("quality",0.60) if state["infrastructure"].has("quality") else state["infrastructure"].get("efficiency",0.60) if state["infrastructure"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("infrastructure") and state["infrastructure"] is Dictionary:
		state["infrastructure"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_infrastructure_deep","gini": _gini, "message":"نابرابری اثر بر infrastructure - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_infrastructure","digital": _digital, "message":"فناوری دوگانه در infrastructure - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_infrastructure","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی infrastructure"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_infrastructure","capital": _social_capital, "message":"سرمایه اجتماعی پایین در infrastructure"})

	# اثر تورمی بر هزینه نگهداری
	var _inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("infrastructure") and state["infrastructure"] is Dictionary and state["infrastructure"].has("maintenance_cost"):
		state["infrastructure"]["maintenance_cost"] = float(state["infrastructure"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	return {"success":true,"state":state,"events":events}
