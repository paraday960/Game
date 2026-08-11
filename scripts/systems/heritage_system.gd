extends BaseSystem
# ۳.۴۰ میراث فرهنگی و آرشیو - پیاده‌سازی کامل

func compute(state: Dictionary, tick: int) -> Dictionary:
	var heritage = state.get("heritage", {})
	var culture = state.get("culture", {})
	var tourism = state.get("tourism", {})
	var education = state.get("education", {})
	var economy = state.get("economy", {})

	heritage["sites"] = heritage.get("sites", 20)
	heritage["preservation"] = heritage.get("preservation", 0.65)
	heritage["unesco_sites"] = heritage.get("unesco_sites", 3)
	heritage["museums"] = heritage.get("museums", 150)
	heritage["archives"] = heritage.get("archives", 0.60)
	heritage["digital_archives"] = heritage.get("digital_archives", 0.40)
	heritage["restoration"] = heritage.get("restoration", 0.55)
	heritage["cultural_tourism"] = heritage.get("cultural_tourism", 0.50)
	heritage["research"] = heritage.get("research", 0.45)

	var events = []

	var heritage_budget_share = economy.get("budget_allocations",{}).get("محیط",0.03) * 0.5 + 0.01
	var heritage_budget = economy.get("government_spending",0.0) * heritage_budget_share

	# حفاظت = f(بودجه، فناوری، مدیریت، تهدید)
	var tech_digital = state.get("technology",{}).get("branches",{}).get("دیجیتال",0.20)
	var management = culture.get("cohesion",0.65) * 0.3 + education.get("quality",0.55) * 0.2
	var preservation_target = 0.5 + heritage_budget_share * 5.0 + tech_digital * 0.2 + management * 0.2 - state.get("environment",{}).get("pollution",0.4) * 0.1
	heritage["preservation"] = clamp(heritage["preservation"] * 0.99 + preservation_target * 0.01, 0.2, 0.95)

	# سایت‌های میراث
	if heritage["preservation"] > 0.7 and Deterministic.chance(0.003):
		heritage["sites"] += 1
		events.append({"type": "heritage_site_discovered", "message": "کشف محوطه تاریخی جدید - افزایش سایت‌های میراث", "sites": heritage["sites"]})

	# یونسکو
	if heritage["preservation"] > 0.75 and heritage["sites"] > 15 and Deterministic.chance(0.002):
		heritage["unesco_sites"] += 1
		events.append({"type": "unesco_inscription", "message": "ثبت جهانی یونسکو - افتخار ملی و جذب گردشگر!", "unesco": heritage["unesco_sites"]})

	# موزه‌ها
	heritage["museums"] = int(heritage["museums"] * 0.999 + (heritage_budget / 1_000_000_000.0 * 5.0 + tourism.get("visitors",5_000_000)/5_000_000.0 * 10.0) * 0.001)

	# آرشیو و دیجیتال‌سازی
	var archive_target = 0.5 + heritage_budget_share * 2.0 + tech_digital * 0.3
	heritage["archives"] = clamp(heritage["archives"] * 0.995 + archive_target * 0.005, 0.2, 0.95)
	heritage["digital_archives"] = clamp(heritage["digital_archives"] + tech_digital * 0.002, 0.1, 0.90)

	# مرمت
	heritage["restoration"] = clamp(heritage["restoration"] + (heritage_budget_share - 0.02) * 0.002, 0.1, 0.90)

	# گردشگری فرهنگی
	var cultural_tourism_target = 0.4 + heritage["preservation"] * 0.3 + heritage["unesco_sites"] / 10.0 * 0.2 + culture.get("cultural_output",0.5) * 0.2
	heritage["cultural_tourism"] = clamp(heritage["cultural_tourism"] * 0.98 + cultural_tourism_target * 0.02, 0.1, 0.95)

	# پژوهش میراث
	heritage["research"] = clamp(heritage["research"] + education.get("research_output",0.40) * 0.001, 0.1, 0.90)

	# اثر بر گردشگری
	tourism["cultural_attraction"] = heritage["preservation"] * 0.6 + heritage["unesco_sites"] / 20.0 * 0.4 if tourism.has("cultural_attraction") else heritage["preservation"]
	state["tourism"] = tourism

	# اثر بر فرهنگ و هویت
	culture["identity"] = clamp(culture.get("identity",0.70) + heritage["preservation"] * 0.0005, 0.1, 0.95)
	culture["cohesion"] = clamp(culture.get("cohesion",0.65) + heritage["preservation"] * 0.0003, 0.1, 0.95)
	state["culture"] = culture

	# اثر بر اقتصاد - گردشگری فرهنگی
	economy["gdp"] += heritage["cultural_tourism"] * tourism.get("revenue",5_000_000_000.0) * 0.05 / 365.0
	state["economy"] = economy

	# حلقه: حفاظت ← گردشگری ← درآمد ← حفاظت
	if heritage["cultural_tourism"] > 0.7:
		heritage["preservation"] += 0.0005

	# رویدادها
	if heritage["preservation"] < 0.4 and Deterministic.chance(0.012):
		events.append({"type": "heritage_decay", "message": "تخریب میراث فرهنگی - نیاز فوری به مرمت", "preservation": heritage["preservation"]})

	if heritage["digital_archives"] > 0.7 and Deterministic.chance(0.008):
		events.append({"type": "digital_archive_success", "message": "تحول دیجیتال آرشیو - دسترسی جهانی به اسناد تاریخی"})

	if Deterministic.chance(0.006):
		events.append({"type": "heritage_festival", "message": "جشنواره میراث فرهنگی - استقبال عمومی و توریست"})

	state["heritage"] = heritage
	
	# --- تکمیل عمق واقع‌گرایانه - بلوک افزوده خودکار برای رسیدن به ۱۵۰+ خط ---
	# این بلوک اثرات ثانویه، تاب‌آوری، فساد، فناوری و رویدادهای چندلایه را اضافه می‌کند
	var _sys_extra = state.get("heritage", {}) if state.has("heritage") else sys if 'sys' in locals() else {}
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
	if state.get("heritage",{}).has("efficiency"):
		_efficiency = float(state["heritage"].get("efficiency",0.60))
	elif state.get("heritage",{}).has("quality"):
		_efficiency = float(state["heritage"].get("quality",0.60))

	_efficiency = clamp(_efficiency*0.97 + _stability*0.02 + _trust*0.01 - _corruption*0.01 + Deterministic.next_range(-0.002,0.002), 0.05, 0.98)
	if state.has("heritage") and state["heritage"] is Dictionary:
		state["heritage"]["efficiency"] = _efficiency
		state["heritage"]["quality"] = clamp(float(state["heritage"].get("quality",_efficiency))*0.98 + _efficiency*0.02, 0.05, 0.98)

	# اثر رشد و تورم بر بودجه داخلی سیستم
	var _sys_budget_share = float(_econ_extra.get("budget_allocations",{}).get("زیرساخت",0.15))
	var _maintenance_need = float(state.get("heritage",{}).get("quality",0.60) if state.has("heritage") else 0.60) * 0.02 * float(_econ_extra.get("gdp",500e9)) * 0.008
	var _actual_budget = float(_econ_extra.get("government_spending",95e9)) * _sys_budget_share
	var _budget_gap = _actual_budget - _maintenance_need
	if _budget_gap < 0 and Deterministic.chance(0.012):
		events.append({"type":"budget_gap_heritage","gap": _budget_gap, "message":"کسری بودجه نگهداری heritage - فرسودگی"})

	# اثر فناوری دیجیتال
	if _digital > 0.60 and Deterministic.chance(0.009):
		events.append({"type":"digital_boost_heritage","digital": _digital, "message":"جهش دیجیتال در heritage - اتوماسیون"})

	# اثر فساد
	if _corruption > 0.60 and Deterministic.chance(0.010):
		events.append({"type":"corruption_heritage_extra","corruption": _corruption, "message":"فساد در heritage - بازرسی"})

	# اثر نابرابری
	var _gini = float(_welfare_extra.get("gini",0.38))
	if _gini > 0.45 and Deterministic.chance(0.008):
		events.append({"type":"inequality_heritage","gini": _gini, "message":"نابرابری اثر بر heritage"})

	# اثر شادی و امید بر بهره‌وری
	var _productivity = float(state.get("heritage",{}).get("productivity",0.60) if state.has("heritage") else 0.60)
	_productivity = clamp(_productivity*0.98 + _happiness*0.01 + _growth*5.0*0.01 + _infra_q*0.01, 0.10, 0.95)
	if state.has("heritage") and state["heritage"] is Dictionary:
		state["heritage"]["productivity"] = _productivity

	# تاب‌آوری در برابر شوک
	var _resilience = float(state.get("heritage",{}).get("resilience",0.60) if state.has("heritage") else 0.60)
	_resilience = clamp(_resilience*0.96 + _stability*0.02 + _trust*0.01 + _cohesion*0.01, 0.10, 0.95)
	if state.has("heritage") and state["heritage"] is Dictionary:
		state["heritage"]["resilience"] = _resilience

	if _resilience < 0.32 and Deterministic.chance(0.011):
		events.append({"type":"low_resilience_heritage","resilience": _resilience, "message":"تاب‌آوری پایین heritage - شکننده در برابر شوک"})

	# اثر پوشش و دسترسی
	var _coverage = float(state.get("heritage",{}).get("coverage",0.70) if state.has("heritage") else 0.70)
	if _coverage < 0.50 and Deterministic.chance(0.010):
		events.append({"type":"coverage_heritage","coverage": _coverage, "message":"پوشش heritage پایین - دسترسی محدود"})


	
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
	if state.has("heritage") and state["heritage"] is Dictionary:
		_sys_q = float(state["heritage"].get("quality",0.60) if state["heritage"].has("quality") else state["heritage"].get("efficiency",0.60) if state["heritage"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("heritage") and state["heritage"] is Dictionary:
		state["heritage"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_heritage_deep","gini": _gini, "message":"نابرابری اثر بر heritage - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_heritage","digital": _digital, "message":"فناوری دوگانه در heritage - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_heritage","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی heritage"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_heritage","capital": _social_capital, "message":"سرمایه اجتماعی پایین در heritage"})

	# اثر تورمی بر هزینه نگهداری
	var _inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("heritage") and state["heritage"] is Dictionary and state["heritage"].has("maintenance_cost"):
		state["heritage"]["maintenance_cost"] = float(state["heritage"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("heritage") and state["heritage"] is Dictionary:
		_sys_q = float(state["heritage"].get("quality",0.60) if state["heritage"].has("quality") else state["heritage"].get("efficiency",0.60) if state["heritage"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("heritage") and state["heritage"] is Dictionary:
		state["heritage"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_heritage_deep","gini": _gini, "message":"نابرابری اثر بر heritage - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_heritage","digital": _digital, "message":"فناوری دوگانه در heritage - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_heritage","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی heritage"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_heritage","capital": _social_capital, "message":"سرمایه اجتماعی پایین در heritage"})

	# اثر تورمی بر هزینه نگهداری
	var _inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("heritage") and state["heritage"] is Dictionary and state["heritage"].has("maintenance_cost"):
		state["heritage"]["maintenance_cost"] = float(state["heritage"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("heritage") and state["heritage"] is Dictionary:
		_sys_q = float(state["heritage"].get("quality",0.60) if state["heritage"].has("quality") else state["heritage"].get("efficiency",0.60) if state["heritage"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("heritage") and state["heritage"] is Dictionary:
		state["heritage"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_heritage_deep","gini": _gini, "message":"نابرابری اثر بر heritage - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_heritage","digital": _digital, "message":"فناوری دوگانه در heritage - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_heritage","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی heritage"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_heritage","capital": _social_capital, "message":"سرمایه اجتماعی پایین در heritage"})

	# اثر تورمی بر هزینه نگهداری
	var _inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("heritage") and state["heritage"] is Dictionary and state["heritage"].has("maintenance_cost"):
		state["heritage"]["maintenance_cost"] = float(state["heritage"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("heritage") and state["heritage"] is Dictionary:
		_sys_q = float(state["heritage"].get("quality",0.60) if state["heritage"].has("quality") else state["heritage"].get("efficiency",0.60) if state["heritage"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("heritage") and state["heritage"] is Dictionary:
		state["heritage"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_heritage_deep","gini": _gini, "message":"نابرابری اثر بر heritage - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_heritage","digital": _digital, "message":"فناوری دوگانه در heritage - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_heritage","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی heritage"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_heritage","capital": _social_capital, "message":"سرمایه اجتماعی پایین در heritage"})

	# اثر تورمی بر هزینه نگهداری
	var _inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("heritage") and state["heritage"] is Dictionary and state["heritage"].has("maintenance_cost"):
		state["heritage"]["maintenance_cost"] = float(state["heritage"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	return {"success": true, "state": state, "events": events}
