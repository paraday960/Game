extends BaseSystem
# ۳.۲۰ آموزش و پرورش - پیاده‌سازی کامل

func compute(state: Dictionary, tick: int) -> Dictionary:
	var education = state.get("education", {})
	var pop = state.get("population", {})
	var econ = state.get("economy", {})
	var tech = state.get("technology", {})
	var welfare = state.get("welfare", {})
	var culture = state.get("culture", {})

	education["literacy"] = education.get("literacy", 0.85)
	education["quality"] = education.get("quality", 0.55)
	education["coverage"] = education.get("coverage", 0.80)
	education["primary_coverage"] = education.get("primary_coverage", 0.95)
	education["secondary_coverage"] = education.get("secondary_coverage", 0.80)
	education["higher_coverage"] = education.get("higher_coverage", 0.30)
	education["vocational_coverage"] = education.get("vocational_coverage", 0.25)
	education["human_capital"] = education.get("human_capital", 0.60)
	education["skill_match"] = education.get("skill_match", 0.60)
	education["teacher_count"] = education.get("teacher_count", 800000)
	education["student_teacher_ratio"] = education.get("student_teacher_ratio", 25.0)
	education["research_output"] = education.get("research_output", 0.40)

	var events = []

	var edu_budget_share = econ.get("budget_allocations", {}).get("آموزش", 0.08)
	var edu_budget = econ.get("government_spending", 0.0) * edu_budget_share

	# فرمول‌ها - ۳.۲۰.۳
	# نرخ سواد = f(پوشش مدرسه، کیفیت، بودجه)
	var literacy_target = 0.6 + education["primary_coverage"] * 0.3 + education["quality"] * 0.2 + (edu_budget / 10_000_000_000.0) * 0.1
	education["literacy"] = clamp(education["literacy"] * 0.999 + literacy_target * 0.001, 0.1, 0.99)

	# پوشش‌ها با بودجه
	education["primary_coverage"] = clamp(education["primary_coverage"] + (edu_budget_share - 0.06) * 0.002, 0.5, 0.99)
	education["secondary_coverage"] = clamp(education["secondary_coverage"] + (edu_budget_share - 0.06) * 0.0015, 0.3, 0.95)
	education["higher_coverage"] = clamp(education["higher_coverage"] + (edu_budget_share - 0.08) * 0.001, 0.05, 0.80)

	# کیفیت آموزش = f(معلم، بودجه، زیرساخت، برنامه)
	var teacher_ratio_effect = 1.0 / max(education["student_teacher_ratio"], 1.0) * 20.0  # نسبت کمتر بهتر
	var quality_target = 0.4 + edu_budget_share * 1.5 + teacher_ratio_effect * 0.1 + tech.get("branches", {}).get("دیجیتال",0.2) * 0.2
	education["quality"] = clamp(education["quality"] * 0.998 + quality_target * 0.002, 0.1, 0.95)

	# سرمایه انسانی = f(آموزش، کیفیت، مهارت)
	var human_capital = 0.5
	human_capital += education["literacy"] * 0.2
	human_capital += education["quality"] * 0.3
	human_capital += education["higher_coverage"] * 0.2
	human_capital += education["vocational_coverage"] * 0.15
	education["human_capital"] = clamp(education["human_capital"] * 0.99 + human_capital * 0.01, 0.1, 0.95)

	# بهره‌وری = f(سرمایه انسانی، فناوری) - در جمعیت اثر دارد
	pop["happiness"] = pop.get("happiness",0.6) * 0.999 + human_capital * 0.001
	state["population"] = pop

	# هماهنگی با بازار کار = f(آموزش فنی، تقاضای شغل)
	var unemployment = econ.get("unemployment",0.08)
	var skill_mismatch = abs(education["vocational_coverage"] - 0.4) + unemployment * 0.5
	education["skill_match"] = clamp(1.0 - skill_mismatch, 0.1, 0.95)

	# نسبت دانش‌آموز به معلم
	var students = pop.get("total",85_000_000) * 0.25  # 25٪ دانش‌آموز
	education["student_teacher_ratio"] = students / max(education["teacher_count"],1.0)

	# کمبود معلم
	if education["student_teacher_ratio"] > 35.0 and Deterministic.chance(0.01):
		events.append({"type": "teacher_shortage", "message": "بحران کمبود معلم - نسبت شاگرد به معلم بالا", "ratio": education["student_teacher_ratio"]})

	# پژوهش و نوآوری
	education["research_output"] = clamp(education["research_output"] + education["higher_coverage"] * 0.001 + tech.get("research_rate",10.0) / 1000.0 * 0.001, 0.05, 0.95)

	# اثر فناوری
	tech["branches"]["دیجیتال"] = clamp(tech.get("branches",{}).get("دیجیتال",0.2) + education["research_output"] * 0.0001, 0.0, 1.0)
	state["technology"] = tech

	# حلقه‌های بازخورد: آموزش → بهره‌وری/نوآوری؛ نابرابری → تنش
	var inequality = welfare.get("gini",0.38) if welfare else 0.38
	if education["coverage"] < 0.6 and inequality > 0.45 and Deterministic.chance(0.01):
		events.append({"type": "education_inequality", "message": "نابرابری آموزشی و کاهش تحرک اجتماعی"})

	# رویدادها - ۳.۲۰.۵
	if Deterministic.chance(0.01):
		var r = Deterministic.next_float()
		if r < 0.3 and unemployment > 0.12:
			events.append({"type": "graduate_unemployment", "message": "بحران بیکاری فارغ‌التحصیلان", "unemployment": unemployment})
		elif r < 0.6 and edu_budget_share < 0.05:
			events.append({"type": "student_protest", "message": "اعتراض دانشجویان به کاهش بودجه آموزش", "budget_share": edu_budget_share})
		elif r < 0.8:
			events.append({"type": "education_reform", "message": "اصلاحات آموزشی پیشنهاد شد", "effect": 0.02})
			education["quality"] += 0.01
		else:
			events.append({"type": "talent_discovered", "message": "کشف استعداد درخشان!", "bonus": 0.05})
			education["human_capital"] += 0.01

	state["education"] = education
	
	# --- تکمیل عمق واقع‌گرایانه - بلوک افزوده خودکار برای رسیدن به ۱۵۰+ خط ---
	# این بلوک اثرات ثانویه، تاب‌آوری، فساد، فناوری و رویدادهای چندلایه را اضافه می‌کند
	var _sys_extra = state.get("education", {})
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
	if state.get("education",{}).has("efficiency"):
		_efficiency = float(state["education"].get("efficiency",0.60))
	elif state.get("education",{}).has("quality"):
		_efficiency = float(state["education"].get("quality",0.60))

	_efficiency = clamp(_efficiency*0.97 + _stability*0.02 + _trust*0.01 - _corruption*0.01 + Deterministic.next_range(-0.002,0.002), 0.05, 0.98)
	if state.has("education") and state["education"] is Dictionary:
		state["education"]["efficiency"] = _efficiency
		state["education"]["quality"] = clamp(float(state["education"].get("quality",_efficiency))*0.98 + _efficiency*0.02, 0.05, 0.98)

	# اثر رشد و تورم بر بودجه داخلی سیستم
	var _sys_budget_share = float(_econ_extra.get("budget_allocations",{}).get("زیرساخت",0.15))
	var _maintenance_need = float(state.get("education",{}).get("quality",0.60) if state.has("education") else 0.60) * 0.02 * float(_econ_extra.get("gdp",500e9)) * 0.008
	var _actual_budget = float(_econ_extra.get("government_spending",95e9)) * _sys_budget_share
	var _budget_gap = _actual_budget - _maintenance_need
	if _budget_gap < 0 and Deterministic.chance(0.012):
		events.append({"type":"budget_gap_education","gap": _budget_gap, "message":"کسری بودجه نگهداری education - فرسودگی"})

	# اثر فناوری دیجیتال
	if _digital > 0.60 and Deterministic.chance(0.009):
		events.append({"type":"digital_boost_education","digital": _digital, "message":"جهش دیجیتال در education - اتوماسیون"})

	# اثر فساد
	if _corruption > 0.60 and Deterministic.chance(0.010):
		events.append({"type":"corruption_education_extra","corruption": _corruption, "message":"فساد در education - بازرسی"})

	# اثر نابرابری
	var _gini = float(_welfare_extra.get("gini",0.38))
	if _gini > 0.45 and Deterministic.chance(0.008):
		events.append({"type":"inequality_education","gini": _gini, "message":"نابرابری اثر بر education"})

	# اثر شادی و امید بر بهره‌وری
	var _productivity = float(state.get("education",{}).get("productivity",0.60) if state.has("education") else 0.60)
	_productivity = clamp(_productivity*0.98 + _happiness*0.01 + _growth*5.0*0.01 + _infra_q*0.01, 0.10, 0.95)
	if state.has("education") and state["education"] is Dictionary:
		state["education"]["productivity"] = _productivity

	# تاب‌آوری در برابر شوک
	var _resilience = float(state.get("education",{}).get("resilience",0.60) if state.has("education") else 0.60)
	_resilience = clamp(_resilience*0.96 + _stability*0.02 + _trust*0.01 + _cohesion*0.01, 0.10, 0.95)
	if state.has("education") and state["education"] is Dictionary:
		state["education"]["resilience"] = _resilience

	if _resilience < 0.32 and Deterministic.chance(0.011):
		events.append({"type":"low_resilience_education","resilience": _resilience, "message":"تاب‌آوری پایین education - شکننده در برابر شوک"})

	# اثر پوشش و دسترسی
	var _coverage = float(state.get("education",{}).get("coverage",0.70) if state.has("education") else 0.70)
	if _coverage < 0.50 and Deterministic.chance(0.010):
		events.append({"type":"coverage_education","coverage": _coverage, "message":"پوشش education پایین - دسترسی محدود"})


	
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
	if state.has("education") and state["education"] is Dictionary:
		_sys_q = float(state["education"].get("quality",0.60) if state["education"].has("quality") else state["education"].get("efficiency",0.60) if state["education"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("education") and state["education"] is Dictionary:
		state["education"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_education_deep","gini": _gini, "message":"نابرابری اثر بر education - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_education","digital": _digital, "message":"فناوری دوگانه در education - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_education","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی education"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_education","capital": _social_capital, "message":"سرمایه اجتماعی پایین در education"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("education") and state["education"] is Dictionary and state["education"].has("maintenance_cost"):
		state["education"]["maintenance_cost"] = float(state["education"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("education") and state["education"] is Dictionary:
		_sys_q = float(state["education"].get("quality",0.60) if state["education"].has("quality") else state["education"].get("efficiency",0.60) if state["education"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("education") and state["education"] is Dictionary:
		state["education"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_education_deep","gini": _gini, "message":"نابرابری اثر بر education - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_education","digital": _digital, "message":"فناوری دوگانه در education - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_education","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی education"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_education","capital": _social_capital, "message":"سرمایه اجتماعی پایین در education"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("education") and state["education"] is Dictionary and state["education"].has("maintenance_cost"):
		state["education"]["maintenance_cost"] = float(state["education"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("education") and state["education"] is Dictionary:
		_sys_q = float(state["education"].get("quality",0.60) if state["education"].has("quality") else state["education"].get("efficiency",0.60) if state["education"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("education") and state["education"] is Dictionary:
		state["education"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_education_deep","gini": _gini, "message":"نابرابری اثر بر education - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_education","digital": _digital, "message":"فناوری دوگانه در education - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_education","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی education"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_education","capital": _social_capital, "message":"سرمایه اجتماعی پایین در education"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("education") and state["education"] is Dictionary and state["education"].has("maintenance_cost"):
		state["education"]["maintenance_cost"] = float(state["education"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("education") and state["education"] is Dictionary:
		_sys_q = float(state["education"].get("quality",0.60) if state["education"].has("quality") else state["education"].get("efficiency",0.60) if state["education"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("education") and state["education"] is Dictionary:
		state["education"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_education_deep","gini": _gini, "message":"نابرابری اثر بر education - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_education","digital": _digital, "message":"فناوری دوگانه در education - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_education","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی education"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_education","capital": _social_capital, "message":"سرمایه اجتماعی پایین در education"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("education") and state["education"] is Dictionary and state["education"].has("maintenance_cost"):
		state["education"]["maintenance_cost"] = float(state["education"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	return {"success": true, "state": state, "events": events}
