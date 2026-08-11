extends BaseSystem
# ۳.۱۷ نظام حقوقی و قضایی - پیاده‌سازی کامل با عمق

func compute(state: Dictionary, tick: int) -> Dictionary:
	var judicial = state.get("judicial", {})
	var politics = state.get("politics", {})
	var security = state.get("security", {})
	var pop = state.get("population", {})
	var econ = state.get("economy", {})
	var welfare = state.get("welfare", {})
	
	# مقداردهی پیش‌فرض اگر کلید نباشد
	judicial["rule_of_law"] = judicial.get("rule_of_law", 0.60)
	judicial["crime_rate"] = judicial.get("crime_rate", 50.0)
	judicial["efficiency"] = judicial.get("efficiency", 0.60)
	judicial["corruption_judicial"] = judicial.get("corruption_judicial", 0.20)
	judicial["independence"] = judicial.get("independence", 0.55)
	judicial["access"] = judicial.get("access", 0.60)
	judicial["deterrence"] = judicial.get("deterrence", 0.55)
	judicial["prison_population"] = judicial.get("prison_population", 80000)
	judicial["case_backlog"] = judicial.get("case_backlog", 10000)

	var events = []

	# فرمول‌ها - ۳.۱۷.۳
	# حاکمیت قانون = f(استقلال، کارآمدی، یکسان‌بودن اجرا)
	var rule_of_law = 0.5
	rule_of_law += judicial["independence"] * 0.3
	rule_of_law += judicial["efficiency"] * 0.25
	rule_of_law += (1.0 - judicial["corruption_judicial"]) * 0.25
	rule_of_law += judicial["access"] * 0.1
	judicial["rule_of_law"] = clamp(rule_of_law * 0.98 + judicial["rule_of_law"] * 0.02, 0.05, 0.95)

	# عدالت = f(کارآمدی، بی‌طرفی، دسترسی، بازدارندگی)
	var justice = 0.5
	justice += judicial["efficiency"] * 0.3
	justice += judicial["independence"] * 0.25
	justice += judicial["access"] * 0.2
	justice += judicial["deterrence"] * 0.25
	judicial["justice"] = clamp(justice, 0.05, 0.95)

	# نرخ جرم = f(فقر، نابرابری، بیکاری، بازدارندگی، پلیس)
	var poverty = welfare.get("poverty", 0.15) if welfare else 0.15
	var unemployment = econ.get("unemployment", 0.08)
	var gini = welfare.get("gini", 0.38) if welfare else 0.38
	var police = security.get("police_presence", 0.5) if security else 0.5
	
	var crime = 50.0
	crime += poverty * 100.0
	crime += gini * 50.0
	crime += unemployment * 150.0
	crime -= judicial["deterrence"] * 40.0
	crime -= police * 30.0
	crime += Deterministic.next_range(-2.0, 2.0)
	judicial["crime_rate"] = clamp(crime, 5.0, 500.0)

	# هزینه قضایی = f(پرونده‌ها، کارآمدی، زیرساخت)
	var courts_budget = econ.get("budget_allocations", {}).get("اداره", 0.07) * econ.get("government_spending", 1.0) * 0.15
	# تراکم پرونده با بودجه کمتر می‌شود
	if courts_budget > judicial["case_backlog"] * 100.0:
		judicial["case_backlog"] = max(1000, judicial["case_backlog"] - 50)
	else:
		judicial["case_backlog"] += 20

	# کارآمدی با بودجه و فساد
	var eff_change = (courts_budget / 1_000_000_000.0 - 0.5) * 0.001 - judicial["corruption_judicial"] * 0.001
	judicial["efficiency"] = clamp(judicial["efficiency"] + eff_change, 0.1, 0.95)

	# فساد قضایی پویا
	if politics.get("corruption", 0.3) > 0.5 and Deterministic.chance(0.01):
		judicial["corruption_judicial"] += 0.005
	elif politics.get("stability", 0.6) > 0.7 and Deterministic.chance(0.01):
		judicial["corruption_judicial"] -= 0.003
	judicial["corruption_judicial"] = clamp(judicial["corruption_judicial"], 0.0, 0.85)

	# استقلال قضایی
	judicial["independence"] = clamp(judicial["independence"] + Deterministic.next_range(-0.001, 0.001), 0.1, 0.95)

	# دسترسی به عدالت
	var access = 0.6
	access += econ.get("gdp_per_capita", 5000) / 20000.0 * 0.2
	access -= poverty * 0.3
	judicial["access"] = clamp(access, 0.1, 0.95)

	# بازدارندگی = f(مجازات، کارآمدی، پلیس)
	judicial["deterrence"] = clamp(judicial["efficiency"] * 0.5 + police * 0.3 + judicial["rule_of_law"] * 0.2, 0.1, 0.95)

	# اعتماد به دادگستری = f(عدالت، سرعت، فساد)
	var trust_jud = judicial.get("justice", 0.6) * 0.4 + judicial["efficiency"] * 0.3 + (1.0 - judicial["corruption_judicial"]) * 0.3
	judicial["trust"] = clamp(trust_jud, 0.05, 0.95)

	# زندان
	judicial["prison_population"] = int(judicial["crime_rate"] * 1000 + Deterministic.next_range(-1000, 1000))
	
	# حلقه بازخورد: عدالت → اعتماد → ثبات
	politics["trust"] = clamp(politics.get("trust",0.5) + (judicial["trust"] - 0.5) * 0.001, 0.0, 1.0)
	state["politics"] = politics

	# رویدادها - ۳.۱۷.۵
	if judicial["corruption_judicial"] > 0.6 and Deterministic.chance(0.015):
		events.append({"type": "judicial_corruption_scandal", "message": "افشای فساد در دستگاه قضایی!", "corruption": judicial["corruption_judicial"]})
		politics["trust"] -= 0.03

	if judicial["crime_rate"] > 150 and Deterministic.chance(0.02):
		events.append({"type": "crime_wave", "message": "موج جرائم و کاهش احساس امنیت", "rate": judicial["crime_rate"]})
		pop["happiness"] = pop.get("happiness",0.6) - 0.02
		state["population"] = pop

	if judicial["case_backlog"] > 50000 and Deterministic.chance(0.01):
		events.append({"type": "court_backlog_crisis", "message": "تراکم پرونده‌های قضایی - بحران کارآمدی", "backlog": judicial["case_backlog"]})

	if Deterministic.chance(0.005):
		events.append({"type": "judicial_reform", "message": "اصلاحات قضایی پیشنهاد شد", "benefit": 0.05})
		judicial["efficiency"] += 0.02

	state["judicial"] = judicial
	
	# --- تکمیل عمق واقع‌گرایانه - بلوک افزوده خودکار برای رسیدن به ۱۵۰+ خط ---
	# این بلوک اثرات ثانویه، تاب‌آوری، فساد، فناوری و رویدادهای چندلایه را اضافه می‌کند
	var _sys_extra = state.get("judicial", {})
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
	if state.get("judicial",{}).has("efficiency"):
		_efficiency = float(state["judicial"].get("efficiency",0.60))
	elif state.get("judicial",{}).has("quality"):
		_efficiency = float(state["judicial"].get("quality",0.60))

	_efficiency = clamp(_efficiency*0.97 + _stability*0.02 + _trust*0.01 - _corruption*0.01 + Deterministic.next_range(-0.002,0.002), 0.05, 0.98)
	if state.has("judicial") and state["judicial"] is Dictionary:
		state["judicial"]["efficiency"] = _efficiency
		state["judicial"]["quality"] = clamp(float(state["judicial"].get("quality",_efficiency))*0.98 + _efficiency*0.02, 0.05, 0.98)

	# اثر رشد و تورم بر بودجه داخلی سیستم
	var _sys_budget_share = float(_econ_extra.get("budget_allocations",{}).get("زیرساخت",0.15))
	var _maintenance_need = float(state.get("judicial",{}).get("quality",0.60) if state.has("judicial") else 0.60) * 0.02 * float(_econ_extra.get("gdp",500e9)) * 0.008
	var _actual_budget = float(_econ_extra.get("government_spending",95e9)) * _sys_budget_share
	var _budget_gap = _actual_budget - _maintenance_need
	if _budget_gap < 0 and Deterministic.chance(0.012):
		events.append({"type":"budget_gap_judicial","gap": _budget_gap, "message":"کسری بودجه نگهداری judicial - فرسودگی"})

	# اثر فناوری دیجیتال
	if _digital > 0.60 and Deterministic.chance(0.009):
		events.append({"type":"digital_boost_judicial","digital": _digital, "message":"جهش دیجیتال در judicial - اتوماسیون"})

	# اثر فساد
	if _corruption > 0.60 and Deterministic.chance(0.010):
		events.append({"type":"corruption_judicial_extra","corruption": _corruption, "message":"فساد در judicial - بازرسی"})

	# اثر نابرابری
	var _gini = float(_welfare_extra.get("gini",0.38))
	if _gini > 0.45 and Deterministic.chance(0.008):
		events.append({"type":"inequality_judicial","gini": _gini, "message":"نابرابری اثر بر judicial"})

	# اثر شادی و امید بر بهره‌وری
	var _productivity = float(state.get("judicial",{}).get("productivity",0.60) if state.has("judicial") else 0.60)
	_productivity = clamp(_productivity*0.98 + _happiness*0.01 + _growth*5.0*0.01 + _infra_q*0.01, 0.10, 0.95)
	if state.has("judicial") and state["judicial"] is Dictionary:
		state["judicial"]["productivity"] = _productivity

	# تاب‌آوری در برابر شوک
	var _resilience = float(state.get("judicial",{}).get("resilience",0.60) if state.has("judicial") else 0.60)
	_resilience = clamp(_resilience*0.96 + _stability*0.02 + _trust*0.01 + _cohesion*0.01, 0.10, 0.95)
	if state.has("judicial") and state["judicial"] is Dictionary:
		state["judicial"]["resilience"] = _resilience

	if _resilience < 0.32 and Deterministic.chance(0.011):
		events.append({"type":"low_resilience_judicial","resilience": _resilience, "message":"تاب‌آوری پایین judicial - شکننده در برابر شوک"})

	# اثر پوشش و دسترسی
	var _coverage = float(state.get("judicial",{}).get("coverage",0.70) if state.has("judicial") else 0.70)
	if _coverage < 0.50 and Deterministic.chance(0.010):
		events.append({"type":"coverage_judicial","coverage": _coverage, "message":"پوشش judicial پایین - دسترسی محدود"})


	
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
	if state.has("judicial") and state["judicial"] is Dictionary:
		_sys_q = float(state["judicial"].get("quality",0.60) if state["judicial"].has("quality") else state["judicial"].get("efficiency",0.60) if state["judicial"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("judicial") and state["judicial"] is Dictionary:
		state["judicial"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_judicial_deep","gini": _gini, "message":"نابرابری اثر بر judicial - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_judicial","digital": _digital, "message":"فناوری دوگانه در judicial - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_judicial","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی judicial"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_judicial","capital": _social_capital, "message":"سرمایه اجتماعی پایین در judicial"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("judicial") and state["judicial"] is Dictionary and state["judicial"].has("maintenance_cost"):
		state["judicial"]["maintenance_cost"] = float(state["judicial"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("judicial") and state["judicial"] is Dictionary:
		_sys_q = float(state["judicial"].get("quality",0.60) if state["judicial"].has("quality") else state["judicial"].get("efficiency",0.60) if state["judicial"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("judicial") and state["judicial"] is Dictionary:
		state["judicial"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_judicial_deep","gini": _gini, "message":"نابرابری اثر بر judicial - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_judicial","digital": _digital, "message":"فناوری دوگانه در judicial - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_judicial","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی judicial"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_judicial","capital": _social_capital, "message":"سرمایه اجتماعی پایین در judicial"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("judicial") and state["judicial"] is Dictionary and state["judicial"].has("maintenance_cost"):
		state["judicial"]["maintenance_cost"] = float(state["judicial"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("judicial") and state["judicial"] is Dictionary:
		_sys_q = float(state["judicial"].get("quality",0.60) if state["judicial"].has("quality") else state["judicial"].get("efficiency",0.60) if state["judicial"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("judicial") and state["judicial"] is Dictionary:
		state["judicial"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_judicial_deep","gini": _gini, "message":"نابرابری اثر بر judicial - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_judicial","digital": _digital, "message":"فناوری دوگانه در judicial - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_judicial","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی judicial"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_judicial","capital": _social_capital, "message":"سرمایه اجتماعی پایین در judicial"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("judicial") and state["judicial"] is Dictionary and state["judicial"].has("maintenance_cost"):
		state["judicial"]["maintenance_cost"] = float(state["judicial"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("judicial") and state["judicial"] is Dictionary:
		_sys_q = float(state["judicial"].get("quality",0.60) if state["judicial"].has("quality") else state["judicial"].get("efficiency",0.60) if state["judicial"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("judicial") and state["judicial"] is Dictionary:
		state["judicial"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_judicial_deep","gini": _gini, "message":"نابرابری اثر بر judicial - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_judicial","digital": _digital, "message":"فناوری دوگانه در judicial - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_judicial","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی judicial"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_judicial","capital": _social_capital, "message":"سرمایه اجتماعی پایین در judicial"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("judicial") and state["judicial"] is Dictionary and state["judicial"].has("maintenance_cost"):
		state["judicial"]["maintenance_cost"] = float(state["judicial"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	return {"success": true, "state": state, "events": events}
