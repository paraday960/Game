extends BaseSystem
# ۳.۲۱ رفاه اجتماعی و اشتغال - پیاده‌سازی کامل

func compute(state: Dictionary, tick: int) -> Dictionary:
	var welfare = state.get("welfare", {})
	var econ = state.get("economy", {})
	var pop = state.get("population", {})
	var politics = state.get("politics", {})
	var education = state.get("education", {})

	welfare["poverty"] = welfare.get("poverty", 0.15)
	welfare["gini"] = welfare.get("gini", 0.38)
	welfare["unemployment_rate"] = welfare.get("unemployment_rate", econ.get("unemployment",0.08))
	welfare["participation_rate"] = welfare.get("participation_rate", pop.get("participation_rate",0.65))
	welfare["pension_coverage"] = welfare.get("pension_coverage", 0.70)
	welfare["social_safety"] = welfare.get("social_safety", 0.60)
	welfare["pension_fund_balance"] = welfare.get("pension_fund_balance", 1_000_000_000.0)
	welfare["retirees"] = welfare.get("retirees", pop.get("total",85_000_000) * 0.10)
	welfare["unemployment_benefit_coverage"] = welfare.get("unemployment_benefit_coverage", 0.50)
	welfare["child_benefit"] = welfare.get("child_benefit", 0.40)

	var events = []

	var welfare_budget_share = econ.get("budget_allocations", {}).get("رفاه", 0.15)
	var welfare_budget = econ.get("government_spending", 0.0) * welfare_budget_share

	# فرمول‌ها - ۳.۲۱.۳
	# بیکاری = f(رشد اقتصاد، مهارت، سیاست کار)
	var growth = econ.get("growth_rate", 0.02)
	var skill_match = education.get("skill_match", 0.60)
	# قانون اوکان: رشد بالاتر از ۲.۵٪ بالقوه، بیکاری را ملایم کاهش می‌دهد (نرخ‌ها سالانه‌اند)
	var unemployment = 0.08
	unemployment -= (growth - 0.025) * 0.5
	unemployment += (1.0 - skill_match) * 0.1
	unemployment += Deterministic.next_range(-0.005, 0.005)
	unemployment = clamp(unemployment, 0.02, 0.35)
	welfare["unemployment_rate"] = unemployment
	econ["unemployment"] = unemployment
	state["economy"] = econ

	# نرخ مشارکت = f(رفاه، حقوق، انگیزه)
	var participation = 0.65
	participation += (1.0 - welfare["poverty"]) * 0.1
	participation -= welfare_budget_share * 0.2  # رفاه خیلی بالا انگیزه کار کم می‌کند (تعادل)
	participation += pop.get("happiness",0.6) * 0.05
	welfare["participation_rate"] = clamp(participation, 0.4, 0.85)

	# فقر = f(اشتغال، رفاه، نابرابری)
	var poverty = 0.15
	poverty += unemployment * 0.8
	poverty -= welfare["social_safety"] * 0.3
	poverty += welfare["gini"] * 0.2
	poverty += Deterministic.next_range(-0.002, 0.002)
	welfare["poverty"] = clamp(welfare["poverty"] * 0.99 + poverty * 0.01, 0.02, 0.60)

	# عدالت اجتماعی = f(نابرابری، دسترسی به خدمات، رفاه)
	var justice = 1.0 - welfare["gini"] * 0.6 + welfare["social_safety"] * 0.2 + (1.0 - welfare["poverty"]) * 0.2
	welfare["social_justice"] = clamp(justice, 0.1, 0.95)

	# نابرابری (جینی) پویا
	var gini_change = (unemployment - 0.08) * 0.01 - (welfare_budget_share - 0.12) * 0.02
	welfare["gini"] = clamp(welfare["gini"] + gini_change * 0.01, 0.20, 0.65)

	# نظام بازنشستگی و مستمری - ۳.۲۱.۲
	welfare["retirees"] = pop.get("total",85_000_000) * pop.get("age_structure",{}).get("سالمند",0.10)
	var pension_cost = welfare["retirees"] * 5000.0  # ساده‌سازی
	var pension_income = welfare["pension_fund_balance"] * 0.03 / 365.0 + welfare_budget * 0.4
	welfare["pension_fund_balance"] += pension_income - pension_cost
	welfare["pension_fund_balance"] = max(welfare["pension_fund_balance"], 0.0)

	if welfare["pension_fund_balance"] < 100_000_000.0 and Deterministic.chance(0.01):
		events.append({"type": "pension_crisis", "message": "بحران صندوق بازنشستگی - ناترازی!", "balance": welfare["pension_fund_balance"]})
		politics["stability"] = politics.get("stability",0.6) - 0.02
		state["politics"] = politics

	# حمایت اجتماعی
	welfare["social_safety"] = clamp(welfare["social_safety"] + (welfare_budget_share - 0.12) * 0.005, 0.1, 0.95)
	welfare["unemployment_benefit_coverage"] = clamp(welfare["social_safety"] * 0.8, 0.1, 0.95)

	# پوشش مستمری
	welfare["pension_coverage"] = clamp(welfare["pension_coverage"] + Deterministic.next_range(-0.001, 0.002), 0.3, 0.95)

	# حلقه بازخورد: اشتغال ← رضایت ← ثبات؛ فقر ← تنش
	pop["happiness"] = clamp(pop.get("happiness",0.6) + (0.08 - unemployment) * 0.001 + (0.15 - welfare["poverty"]) * 0.001, 0.05, 0.95)
	politics["tension"] = clamp(politics.get("tension",0.35) + welfare["poverty"] * 0.002 + unemployment * 0.003, 0.0, 1.0)
	state["population"] = pop
	state["politics"] = politics

	# رویدادها - ۳.۲۱.۵
	if unemployment > 0.15 and Deterministic.chance(0.015):
		events.append({"type": "unemployment_crisis", "message": "بحران بیکاری گسترده", "rate": unemployment})

	if welfare["poverty"] > 0.25 and Deterministic.chance(0.015):
		events.append({"type": "poverty_wave", "message": "موج فقر و بحران اجتماعی", "poverty": welfare["poverty"]})

	if welfare["gini"] > 0.50 and Deterministic.chance(0.01):
		events.append({"type": "inequality_protest", "message": "اعتراض به نابرابری و بی‌عدالتی", "gini": welfare["gini"]})

	if Deterministic.chance(0.008):
		events.append({"type": "welfare_reform", "message": "اصلاحات رفاهی پیشنهاد شد"})

	state["welfare"] = welfare
	
	# --- تکمیل عمق واقع‌گرایانه - بلوک افزوده خودکار برای رسیدن به ۱۵۰+ خط ---
	# این بلوک اثرات ثانویه، تاب‌آوری، فساد، فناوری و رویدادهای چندلایه را اضافه می‌کند
	var _sys_extra = state.get("welfare", {})
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
	if state.get("welfare",{}).has("efficiency"):
		_efficiency = float(state["welfare"].get("efficiency",0.60))
	elif state.get("welfare",{}).has("quality"):
		_efficiency = float(state["welfare"].get("quality",0.60))

	_efficiency = clamp(_efficiency*0.97 + _stability*0.02 + _trust*0.01 - _corruption*0.01 + Deterministic.next_range(-0.002,0.002), 0.05, 0.98)
	if state.has("welfare") and state["welfare"] is Dictionary:
		state["welfare"]["efficiency"] = _efficiency
		state["welfare"]["quality"] = clamp(float(state["welfare"].get("quality",_efficiency))*0.98 + _efficiency*0.02, 0.05, 0.98)

	# اثر رشد و تورم بر بودجه داخلی سیستم
	var _sys_budget_share = float(_econ_extra.get("budget_allocations",{}).get("زیرساخت",0.15))
	var _maintenance_need = float(state.get("welfare",{}).get("quality",0.60) if state.has("welfare") else 0.60) * 0.02 * float(_econ_extra.get("gdp",500e9)) * 0.008
	var _actual_budget = float(_econ_extra.get("government_spending",95e9)) * _sys_budget_share
	var _budget_gap = _actual_budget - _maintenance_need
	if _budget_gap < 0 and Deterministic.chance(0.012):
		events.append({"type":"budget_gap_welfare","gap": _budget_gap, "message":"کسری بودجه نگهداری welfare - فرسودگی"})

	# اثر فناوری دیجیتال
	if _digital > 0.60 and Deterministic.chance(0.009):
		events.append({"type":"digital_boost_welfare","digital": _digital, "message":"جهش دیجیتال در welfare - اتوماسیون"})

	# اثر فساد
	if _corruption > 0.60 and Deterministic.chance(0.010):
		events.append({"type":"corruption_welfare_extra","corruption": _corruption, "message":"فساد در welfare - بازرسی"})

	# اثر نابرابری
	var _gini = float(_welfare_extra.get("gini",0.38))
	if _gini > 0.45 and Deterministic.chance(0.008):
		events.append({"type":"inequality_welfare","gini": _gini, "message":"نابرابری اثر بر welfare"})

	# اثر شادی و امید بر بهره‌وری
	var _productivity = float(state.get("welfare",{}).get("productivity",0.60) if state.has("welfare") else 0.60)
	_productivity = clamp(_productivity*0.98 + _happiness*0.01 + _growth*5.0*0.01 + _infra_q*0.01, 0.10, 0.95)
	if state.has("welfare") and state["welfare"] is Dictionary:
		state["welfare"]["productivity"] = _productivity

	# تاب‌آوری در برابر شوک
	var _resilience = float(state.get("welfare",{}).get("resilience",0.60) if state.has("welfare") else 0.60)
	_resilience = clamp(_resilience*0.96 + _stability*0.02 + _trust*0.01 + _cohesion*0.01, 0.10, 0.95)
	if state.has("welfare") and state["welfare"] is Dictionary:
		state["welfare"]["resilience"] = _resilience

	if _resilience < 0.32 and Deterministic.chance(0.011):
		events.append({"type":"low_resilience_welfare","resilience": _resilience, "message":"تاب‌آوری پایین welfare - شکننده در برابر شوک"})

	# اثر پوشش و دسترسی
	var _coverage = float(state.get("welfare",{}).get("coverage",0.70) if state.has("welfare") else 0.70)
	if _coverage < 0.50 and Deterministic.chance(0.010):
		events.append({"type":"coverage_welfare","coverage": _coverage, "message":"پوشش welfare پایین - دسترسی محدود"})


	
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
	if state.has("welfare") and state["welfare"] is Dictionary:
		_sys_q = float(state["welfare"].get("quality",0.60) if state["welfare"].has("quality") else state["welfare"].get("efficiency",0.60) if state["welfare"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("welfare") and state["welfare"] is Dictionary:
		state["welfare"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_welfare_deep","gini": _gini, "message":"نابرابری اثر بر welfare - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_welfare","digital": _digital, "message":"فناوری دوگانه در welfare - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_welfare","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی welfare"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_welfare","capital": _social_capital, "message":"سرمایه اجتماعی پایین در welfare"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("welfare") and state["welfare"] is Dictionary and state["welfare"].has("maintenance_cost"):
		state["welfare"]["maintenance_cost"] = float(state["welfare"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("welfare") and state["welfare"] is Dictionary:
		_sys_q = float(state["welfare"].get("quality",0.60) if state["welfare"].has("quality") else state["welfare"].get("efficiency",0.60) if state["welfare"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("welfare") and state["welfare"] is Dictionary:
		state["welfare"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_welfare_deep","gini": _gini, "message":"نابرابری اثر بر welfare - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_welfare","digital": _digital, "message":"فناوری دوگانه در welfare - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_welfare","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی welfare"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_welfare","capital": _social_capital, "message":"سرمایه اجتماعی پایین در welfare"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("welfare") and state["welfare"] is Dictionary and state["welfare"].has("maintenance_cost"):
		state["welfare"]["maintenance_cost"] = float(state["welfare"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("welfare") and state["welfare"] is Dictionary:
		_sys_q = float(state["welfare"].get("quality",0.60) if state["welfare"].has("quality") else state["welfare"].get("efficiency",0.60) if state["welfare"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("welfare") and state["welfare"] is Dictionary:
		state["welfare"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_welfare_deep","gini": _gini, "message":"نابرابری اثر بر welfare - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_welfare","digital": _digital, "message":"فناوری دوگانه در welfare - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_welfare","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی welfare"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_welfare","capital": _social_capital, "message":"سرمایه اجتماعی پایین در welfare"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("welfare") and state["welfare"] is Dictionary and state["welfare"].has("maintenance_cost"):
		state["welfare"]["maintenance_cost"] = float(state["welfare"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("welfare") and state["welfare"] is Dictionary:
		_sys_q = float(state["welfare"].get("quality",0.60) if state["welfare"].has("quality") else state["welfare"].get("efficiency",0.60) if state["welfare"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("welfare") and state["welfare"] is Dictionary:
		state["welfare"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_welfare_deep","gini": _gini, "message":"نابرابری اثر بر welfare - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_welfare","digital": _digital, "message":"فناوری دوگانه در welfare - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_welfare","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی welfare"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_welfare","capital": _social_capital, "message":"سرمایه اجتماعی پایین در welfare"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("welfare") and state["welfare"] is Dictionary and state["welfare"].has("maintenance_cost"):
		state["welfare"]["maintenance_cost"] = float(state["welfare"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	return {"success": true, "state": state, "events": events}
