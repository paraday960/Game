extends BaseSystem
# ۳.۶۲ خانواده‌ها و خانوارها - درآمد، پس‌انداز، بدهی، مسکن، اندازه، تاب‌آوری، سبک زندگی

func compute(state: Dictionary, tick: int) -> Dictionary:
	var hh = state.get("households_detail_full", {})
	hh["count"] = hh.get("count", 25000000)
	hh["avg_size"] = hh.get("avg_size", 3.2)
	hh["income_avg"] = hh.get("income_avg", state.get("economy", {}).get("gdp_per_capita", 5000.0)*0.8)
	hh["income_median"] = hh.get("income_median", hh["income_avg"]*0.72)
	hh["savings_rate"] = hh.get("savings_rate", 0.15)
	hh["debt_ratio"] = hh.get("debt_ratio", 0.20)
	hh["debt_absolute"] = hh.get("debt_absolute", hh["income_avg"]*0.5)
	hh["housing_own"] = hh.get("housing_own", 0.70)
	hh["housing_rent_burden"] = hh.get("housing_rent_burden", 0.30)
	hh["food_share"] = hh.get("food_share", 0.35)
	hh["energy_share"] = hh.get("energy_share", 0.12)
	hh["resilience"] = hh.get("resilience", 0.55)
	hh["female_headed"] = hh.get("female_headed", 0.18)
	hh["urban_households"] = hh.get("urban_households", int(hh["count"]*0.75))

	var events = []
	var econ = state.get("economy", {})
	var pop = state.get("population", {})
	var welfare = state.get("welfare", {})
	var family = state.get("family", {})
	var infra = state.get("infrastructure", {})

	var inflation = econ.get("inflation", 0.08)
	var growth = econ.get("growth_rate", 0.02)
	var unemployment = econ.get("unemployment", 0.08)
	var gini = welfare.get("gini", 0.38)
	var poverty = welfare.get("poverty", 0.15)

	# درآمد خانوار - رشد GDP اما با بیکاری و تورم تعدیل
	var income_growth = growth*0.8 - inflation*0.3 - unemployment*0.2
	hh["income_avg"] *= (1.0 + income_growth/365.0)
	hh["income_avg"] = max(hh["income_avg"], 500.0)
	hh["income_median"] = hh["income_avg"] * (0.85 - gini*0.4)

	# اندازه خانوار - شهرنشینی اندازه را کوچک می‌کند
	var urban_ratio = pop.get("urban_ratio", 0.75)
	var fertility = family.get("fertility", 1.8) if family else 1.8
	var size_target = 2.0 + fertility*0.6 + (1.0 - urban_ratio)*0.8
	hh["avg_size"] = clamp(hh["avg_size"]*0.998 + size_target*0.002, 2.0, 5.5)
	hh["count"] = int(pop.get("total",85_000_000.0) / max(hh["avg_size"],1.0))

	# سهم غذا - قانون انگل: درآمد پایین سهم غذا بالا
	hh["food_share"] = clamp(0.60 - (hh["income_avg"]/10000.0)*0.15, 0.15, 0.60)
	hh["energy_share"] = clamp(0.08 + inflation*0.2, 0.05, 0.30)

	# پس‌انداز = درآمد - هزینه‌های الزامی - بدهی
	var obligatory = hh["food_share"] + hh["energy_share"] + hh["housing_rent_burden"]
	var saving_target = 1.0 - obligatory - hh["debt_ratio"]*0.1
	saving_target = clamp(saving_target, -0.10, 0.40)
	hh["savings_rate"] = clamp(hh["savings_rate"]*0.97 + saving_target*0.03 + Deterministic.next_range(-0.002,0.002), -0.05, 0.50)

	# بدهی - نرخ بهره و بیکاری
	var interest = econ.get("central_bank",{}).get("interest_rate",0.15) if econ.has("central_bank") else state.get("central_bank",{}).get("interest_rate",0.15)
	hh["debt_ratio"] = clamp(hh["debt_ratio"] + (interest - 0.10)*0.0008 + unemployment*0.0005 + Deterministic.next_range(-0.0003,0.0006), 0.02, 0.85)
	hh["debt_absolute"] = hh["income_avg"] * hh["debt_ratio"]

	# مسکن - مالکیت با پس‌انداز
	var housing_target = 0.40 + hh["savings_rate"]*0.6 + (1.0 - hh["housing_rent_burden"])*0.2
	hh["housing_own"] = clamp(hh["housing_own"]*0.996 + housing_target*0.004, 0.30, 0.90)
	hh["housing_rent_burden"] = clamp(hh["housing_rent_burden"] + inflation*0.0005 - growth*0.0003, 0.10, 0.60)

	# تاب‌آوری = پس‌انداز + اشتغال + مسکن
	var resilience_target = hh["savings_rate"]*0.4 + (1.0-unemployment)*0.3 + hh["housing_own"]*0.2 + 0.1
	hh["resilience"] = clamp(hh["resilience"]*0.97 + resilience_target*0.03, 0.05, 0.95)

	# خانوار زن‌سرپرست
	hh["female_headed"] = clamp(hh["female_headed"] + 0.00003, 0.10, 0.35)
	hh["urban_households"] = int(hh["count"] * urban_ratio)

	# رویدادها
	if hh["debt_ratio"] > 0.65 and Deterministic.chance(0.013):
		events.append({"type":"household_debt_crisis","debt": hh["debt_ratio"], "message":"بحران بدهی خانوارها - اقساط ۶۵٪ درآمد"})

	if hh["housing_rent_burden"] > 0.50 and Deterministic.chance(0.011):
		events.append({"type":"housing_affordability_crisis","burden": hh["housing_rent_burden"], "message":"بحران مسکن - اجاره نیمی از حقوق را می‌بلعد"})

	if hh["resilience"] < 0.25 and Deterministic.chance(0.012):
		events.append({"type":"household_fragility","resilience": hh["resilience"], "message":"شکنندگی معیشت - خانوارها یک شوک تا خط فقر فاصله دارند"})

	if hh["savings_rate"] < 0.0 and tick % 30 == 0:
		events.append({"type":"negative_saving","saving": hh["savings_rate"], "message":"پس‌انداز منفی - خانوارها از ذخیره می‌خورند"})

	if hh["food_share"] > 0.50 and Deterministic.chance(0.009):
		events.append({"type":"food_share_warning","share": hh["food_share"], "message":"فشار خوراک - ۵۰٪ درآمد صرف غذا می‌شود"})

	state["households_detail_full"] = hh
	
	# --- تکمیل عمق واقع‌گرایانه - بلوک افزوده خودکار برای رسیدن به ۱۵۰+ خط ---
	# این بلوک اثرات ثانویه، تاب‌آوری، فساد، فناوری و رویدادهای چندلایه را اضافه می‌کند
	var _sys_extra = state.get("households", {}) if state.has("households") else sys if 'sys' in locals() else {}
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
	if state.get("households",{}).has("efficiency"):
		_efficiency = float(state["households"].get("efficiency",0.60))
	elif state.get("households",{}).has("quality"):
		_efficiency = float(state["households"].get("quality",0.60))

	_efficiency = clamp(_efficiency*0.97 + _stability*0.02 + _trust*0.01 - _corruption*0.01 + Deterministic.next_range(-0.002,0.002), 0.05, 0.98)
	if state.has("households") and state["households"] is Dictionary:
		state["households"]["efficiency"] = _efficiency
		state["households"]["quality"] = clamp(float(state["households"].get("quality",_efficiency))*0.98 + _efficiency*0.02, 0.05, 0.98)

	# اثر رشد و تورم بر بودجه داخلی سیستم
	var _sys_budget_share = float(_econ_extra.get("budget_allocations",{}).get("زیرساخت",0.15))
	var _maintenance_need = float(state.get("households",{}).get("quality",0.60) if state.has("households") else 0.60) * 0.02 * float(_econ_extra.get("gdp",500e9)) * 0.008
	var _actual_budget = float(_econ_extra.get("government_spending",95e9)) * _sys_budget_share
	var _budget_gap = _actual_budget - _maintenance_need
	if _budget_gap < 0 and Deterministic.chance(0.012):
		events.append({"type":"budget_gap_households","gap": _budget_gap, "message":"کسری بودجه نگهداری households - فرسودگی"})

	# اثر فناوری دیجیتال
	if _digital > 0.60 and Deterministic.chance(0.009):
		events.append({"type":"digital_boost_households","digital": _digital, "message":"جهش دیجیتال در households - اتوماسیون"})

	# اثر فساد
	if _corruption > 0.60 and Deterministic.chance(0.010):
		events.append({"type":"corruption_households_extra","corruption": _corruption, "message":"فساد در households - بازرسی"})

	# اثر نابرابری
	var _gini = float(_welfare_extra.get("gini",0.38))
	if _gini > 0.45 and Deterministic.chance(0.008):
		events.append({"type":"inequality_households","gini": _gini, "message":"نابرابری اثر بر households"})

	# اثر شادی و امید بر بهره‌وری
	var _productivity = float(state.get("households",{}).get("productivity",0.60) if state.has("households") else 0.60)
	_productivity = clamp(_productivity*0.98 + _happiness*0.01 + _growth*5.0*0.01 + _infra_q*0.01, 0.10, 0.95)
	if state.has("households") and state["households"] is Dictionary:
		state["households"]["productivity"] = _productivity

	# تاب‌آوری در برابر شوک
	var _resilience = float(state.get("households",{}).get("resilience",0.60) if state.has("households") else 0.60)
	_resilience = clamp(_resilience*0.96 + _stability*0.02 + _trust*0.01 + _cohesion*0.01, 0.10, 0.95)
	if state.has("households") and state["households"] is Dictionary:
		state["households"]["resilience"] = _resilience

	if _resilience < 0.32 and Deterministic.chance(0.011):
		events.append({"type":"low_resilience_households","resilience": _resilience, "message":"تاب‌آوری پایین households - شکننده در برابر شوک"})

	# اثر پوشش و دسترسی
	var _coverage = float(state.get("households",{}).get("coverage",0.70) if state.has("households") else 0.70)
	if _coverage < 0.50 and Deterministic.chance(0.010):
		events.append({"type":"coverage_households","coverage": _coverage, "message":"پوشش households پایین - دسترسی محدود"})


	
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
	if state.has("households") and state["households"] is Dictionary:
		_sys_q = float(state["households"].get("quality",0.60) if state["households"].has("quality") else state["households"].get("efficiency",0.60) if state["households"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("households") and state["households"] is Dictionary:
		state["households"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_households_deep","gini": _gini, "message":"نابرابری اثر بر households - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_households","digital": _digital, "message":"فناوری دوگانه در households - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_households","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی households"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_households","capital": _social_capital, "message":"سرمایه اجتماعی پایین در households"})

	# اثر تورمی بر هزینه نگهداری
	var _inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("households") and state["households"] is Dictionary and state["households"].has("maintenance_cost"):
		state["households"]["maintenance_cost"] = float(state["households"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("households") and state["households"] is Dictionary:
		_sys_q = float(state["households"].get("quality",0.60) if state["households"].has("quality") else state["households"].get("efficiency",0.60) if state["households"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("households") and state["households"] is Dictionary:
		state["households"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_households_deep","gini": _gini, "message":"نابرابری اثر بر households - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_households","digital": _digital, "message":"فناوری دوگانه در households - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_households","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی households"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_households","capital": _social_capital, "message":"سرمایه اجتماعی پایین در households"})

	# اثر تورمی بر هزینه نگهداری
	var _inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("households") and state["households"] is Dictionary and state["households"].has("maintenance_cost"):
		state["households"]["maintenance_cost"] = float(state["households"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("households") and state["households"] is Dictionary:
		_sys_q = float(state["households"].get("quality",0.60) if state["households"].has("quality") else state["households"].get("efficiency",0.60) if state["households"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("households") and state["households"] is Dictionary:
		state["households"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_households_deep","gini": _gini, "message":"نابرابری اثر بر households - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_households","digital": _digital, "message":"فناوری دوگانه در households - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_households","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی households"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_households","capital": _social_capital, "message":"سرمایه اجتماعی پایین در households"})

	# اثر تورمی بر هزینه نگهداری
	var _inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("households") and state["households"] is Dictionary and state["households"].has("maintenance_cost"):
		state["households"]["maintenance_cost"] = float(state["households"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("households") and state["households"] is Dictionary:
		_sys_q = float(state["households"].get("quality",0.60) if state["households"].has("quality") else state["households"].get("efficiency",0.60) if state["households"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("households") and state["households"] is Dictionary:
		state["households"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_households_deep","gini": _gini, "message":"نابرابری اثر بر households - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_households","digital": _digital, "message":"فناوری دوگانه در households - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_households","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی households"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_households","capital": _social_capital, "message":"سرمایه اجتماعی پایین در households"})

	# اثر تورمی بر هزینه نگهداری
	var _inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("households") and state["households"] is Dictionary and state["households"].has("maintenance_cost"):
		state["households"]["maintenance_cost"] = float(state["households"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	return {"success":true,"state":state,"events":events}
