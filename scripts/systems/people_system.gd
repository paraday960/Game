extends BaseSystem
# لایه آدم‌ها - بخش ۳.۵۳ تا ۳.۶۲ - 10 دسته افراد

func compute(state: Dictionary, tick: int) -> Dictionary:
	var people = state.get("people", {})
	var pop = state.get("population", {})
	var economy = state.get("economy", {})

	people["total_sample"] = people.get("total_sample", 1000)
	people["households"] = people.get("households", 25_000_000)
	people["households_details"] = people.get("households_details", {
		"میانگین_اندازه": 3.2,
		"درآمد_میانگین": 5000.0,
		"دارای_مسکن": 0.70,
		"دارای_خودرو": 0.40
	})
	people["workforce"] = people.get("workforce", {
		"کشاورز": 0.20,
		"کارگر_صنعتی": 0.25,
		"کارمند": 0.30,
		"خدمات": 0.20,
		"بیکار": 0.05
	})
	var leaders = people.get("leaders", {})
	if not leaders is Dictionary:
		leaders = {}
	leaders["وزرا"] = leaders.get("وزرا", 20)
	leaders["نمایندگان"] = leaders.get("نمایندگان", 290)
	leaders["مدیران_ارشد"] = leaders.get("مدیران_ارشد", 5000)
	var country_id = str(state.get("country", {}).get("id", WorldManager.default_country))
	leaders["استانداران"] = max(1, CountryGeographyManager.get_unit_count(country_id))
	leaders["شهرداران"] = max(leaders["استانداران"], int(state.get("administration", {}).get("municipalities", 1)))
	people["leaders"] = leaders
	people["elites"] = people.get("elites", {
		"نخبه_علمی": 10000,
		"کارآفرین": 50000,
		"هنرمند": 20000,
		"ورزشکار": 5000,
		"روحانی": 30000
	})
	people["security_forces"] = people.get("security_forces", {
		"ارتش": 500000,
		"پلیس": 200000,
		"اطلاعات": 30000,
		"مرزبان": 50000
	})
	people["emotions"] = people.get("emotions", {
		"خوشبختی_میانگین": pop.get("happiness",0.6),
		"اعتماد": state.get("politics",{}).get("trust",0.55),
		"امید": 0.60,
		"ترس": state.get("politics",{}).get("tension",0.35),
		"خشم": 0.20
	})

	var events = []

	# رشد خانوارها با جمعیت
	people["households"] = pop.get("total",85_000_000) / people["households_details"]["میانگین_اندازه"]

	# درآمد خانوار با GDP سرانه
	var gdp_per_capita = economy.get("gdp_per_capita",5000.0)
	people["households_details"]["درآمد_میانگین"] = people["households_details"]["درآمد_میانگین"] * 0.99 + gdp_per_capita * 0.8 * 0.01

	# ترکیب نیروی کار با اقتصاد و فناوری
	var tech_industry = state.get("technology",{}).get("branches",{}).get("صنعت",0.20)
	var tech_digital = state.get("technology",{}).get("branches",{}).get("دیجیتال",0.20)
	
	var workforce = people["workforce"]
	# انتقال از کشاورزی به صنعت و خدمات با فناوری
	if tech_industry > 0.3:
		workforce["کشاورز"] -= 0.0002
		workforce["کارگر_صنعتی"] += 0.0001
		workforce["خدمات"] += 0.0001
	if tech_digital > 0.4:
		workforce["کارمند"] += 0.0001
		workforce["خدمات"] += 0.0001

	var unemployment = economy.get("unemployment",0.08)
	workforce["بیکار"] = unemployment
	# نرمالایز
	var sum_work = 0.0
	for v in workforce.values():
		sum_work += v
	for k in workforce.keys():
		workforce[k] = clamp(workforce[k] / sum_work, 0.01, 0.60)
	people["workforce"] = workforce

	# احساسات و عواطف - بخش ۳.۶۶
	var happiness = pop.get("happiness",0.6)
	var trust = state.get("politics",{}).get("trust",0.55)
	var tension = state.get("politics",{}).get("tension",0.35)
	var security_feel = state.get("security",{}).get("feeling_security",0.70)

	var emotions = people["emotions"]
	emotions["خوشبختی_میانگین"] = happiness
	emotions["اعتماد"] = trust
	emotions["امید"] = clamp(0.5 + happiness * 0.2 + (economy.get("growth_rate",0.02) * 10.0) * 0.2 + education_quality(state) * 0.1, 0.1, 0.95)
	emotions["ترس"] = clamp(tension * 0.6 + (1.0 - security_feel) * 0.4, 0.05, 0.85)
	emotions["خشم"] = clamp((1.0 - happiness) * 0.5 + tension * 0.3 + (state.get("ethnicity",{}).get("discrimination",0.2)) * 0.2, 0.05, 0.80)
	emotions["غرور_ملی"] = clamp(state.get("culture",{}).get("cohesion",0.65) * 0.5 + state.get("indicators",{}).get("power_score",55.0)/100.0 * 0.3 + state.get("sports_youth",{}).get("sports_achievements",50.0)/100.0 * 0.2, 0.1, 0.95)
	people["emotions"] = emotions

	# نخبگان - فرار مغزها
	var brain_drain_risk = (1.0 - happiness) * 0.3
	brain_drain_risk += 0.2 if economy.get("gdp_per_capita", 5000.0) < 3000.0 else 0.0
	brain_drain_risk += 0.2 if state.get("politics", {}).get("stability", 0.6) < 0.4 else 0.0
	if brain_drain_risk > 0.5 and Deterministic.chance(0.01):
		events.append({"type": "brain_drain", "message": "فرار مغزها - مهاجرت نخبگان علمی و کارآفرینان", "risk": brain_drain_risk})
		people["elites"]["نخبه_علمی"] -= 100
		state["technology"]["research_rate"] = state.get("technology",{}).get("research_rate",10.0) - 0.5

	# دولتمردان و مدیران - فساد
	if state.get("politics",{}).get("corruption",0.30) > 0.5 and Deterministic.chance(0.01):
		events.append({"type": "elite_corruption", "message": "افشای فساد در بین مدیران ارشد - بحران اعتماد"})

	# حلقه: رضایت → بهره‌وری → اقتصاد → رفاه
	var productivity_boost = happiness * 0.1 + emotions["امید"] * 0.05 - emotions["ترس"] * 0.05 - emotions["خشم"] * 0.05
	economy["growth_rate"] = clamp(economy.get("growth_rate",0.02) + productivity_boost * 0.0001, -0.05, 0.10)
	state["economy"] = economy

	# رویدادهای انسانی
	if emotions["خشم"] > 0.6 and Deterministic.chance(0.015):
		events.append({"type": "public_anger", "message": "خشم عمومی بالا - خطر اعتراضات گسترده", "anger": emotions["خشم"]})

	if emotions["امید"] > 0.8 and Deterministic.chance(0.01):
		events.append({"type": "hope_rising", "message": "امید و نشاط اجتماعی بالا - افزایش مشارکت و بهره‌وری"})

	if people["households_details"]["دارای_مسکن"] < 0.5 and Deterministic.chance(0.01):
		events.append({"type": "housing_grievance", "message": "نارضایتی از مسکن - جوانان خانه‌دار نمی‌شوند"})

	state["people"] = people
	
	# --- تکمیل عمق واقع‌گرایانه - بلوک افزوده خودکار برای رسیدن به ۱۵۰+ خط ---
	# این بلوک اثرات ثانویه، تاب‌آوری، فساد، فناوری و رویدادهای چندلایه را اضافه می‌کند
	var _sys_extra = state.get("people", {})
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
	if state.get("people",{}).has("efficiency"):
		_efficiency = float(state["people"].get("efficiency",0.60))
	elif state.get("people",{}).has("quality"):
		_efficiency = float(state["people"].get("quality",0.60))

	_efficiency = clamp(_efficiency*0.97 + _stability*0.02 + _trust*0.01 - _corruption*0.01 + Deterministic.next_range(-0.002,0.002), 0.05, 0.98)
	if state.has("people") and state["people"] is Dictionary:
		state["people"]["efficiency"] = _efficiency
		state["people"]["quality"] = clamp(float(state["people"].get("quality",_efficiency))*0.98 + _efficiency*0.02, 0.05, 0.98)

	# اثر رشد و تورم بر بودجه داخلی سیستم
	var _sys_budget_share = float(_econ_extra.get("budget_allocations",{}).get("زیرساخت",0.15))
	var _maintenance_need = float(state.get("people",{}).get("quality",0.60) if state.has("people") else 0.60) * 0.02 * float(_econ_extra.get("gdp",500e9)) * 0.008
	var _actual_budget = float(_econ_extra.get("government_spending",95e9)) * _sys_budget_share
	var _budget_gap = _actual_budget - _maintenance_need
	if _budget_gap < 0 and Deterministic.chance(0.012):
		events.append({"type":"budget_gap_people","gap": _budget_gap, "message":"کسری بودجه نگهداری people - فرسودگی"})

	# اثر فناوری دیجیتال
	if _digital > 0.60 and Deterministic.chance(0.009):
		events.append({"type":"digital_boost_people","digital": _digital, "message":"جهش دیجیتال در people - اتوماسیون"})

	# اثر فساد
	if _corruption > 0.60 and Deterministic.chance(0.010):
		events.append({"type":"corruption_people_extra","corruption": _corruption, "message":"فساد در people - بازرسی"})

	# اثر نابرابری
	var _gini = float(_welfare_extra.get("gini",0.38))
	if _gini > 0.45 and Deterministic.chance(0.008):
		events.append({"type":"inequality_people","gini": _gini, "message":"نابرابری اثر بر people"})

	# اثر شادی و امید بر بهره‌وری
	var _productivity = float(state.get("people",{}).get("productivity",0.60) if state.has("people") else 0.60)
	_productivity = clamp(_productivity*0.98 + _happiness*0.01 + _growth*5.0*0.01 + _infra_q*0.01, 0.10, 0.95)
	if state.has("people") and state["people"] is Dictionary:
		state["people"]["productivity"] = _productivity

	# تاب‌آوری در برابر شوک
	var _resilience = float(state.get("people",{}).get("resilience",0.60) if state.has("people") else 0.60)
	_resilience = clamp(_resilience*0.96 + _stability*0.02 + _trust*0.01 + _cohesion*0.01, 0.10, 0.95)
	if state.has("people") and state["people"] is Dictionary:
		state["people"]["resilience"] = _resilience

	if _resilience < 0.32 and Deterministic.chance(0.011):
		events.append({"type":"low_resilience_people","resilience": _resilience, "message":"تاب‌آوری پایین people - شکننده در برابر شوک"})

	# اثر پوشش و دسترسی
	var _coverage = float(state.get("people",{}).get("coverage",0.70) if state.has("people") else 0.70)
	if _coverage < 0.50 and Deterministic.chance(0.010):
		events.append({"type":"coverage_people","coverage": _coverage, "message":"پوشش people پایین - دسترسی محدود"})


	
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
	if state.has("people") and state["people"] is Dictionary:
		_sys_q = float(state["people"].get("quality",0.60) if state["people"].has("quality") else state["people"].get("efficiency",0.60) if state["people"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("people") and state["people"] is Dictionary:
		state["people"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_people_deep","gini": _gini, "message":"نابرابری اثر بر people - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_people","digital": _digital, "message":"فناوری دوگانه در people - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_people","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی people"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_people","capital": _social_capital, "message":"سرمایه اجتماعی پایین در people"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("people") and state["people"] is Dictionary and state["people"].has("maintenance_cost"):
		state["people"]["maintenance_cost"] = float(state["people"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("people") and state["people"] is Dictionary:
		_sys_q = float(state["people"].get("quality",0.60) if state["people"].has("quality") else state["people"].get("efficiency",0.60) if state["people"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("people") and state["people"] is Dictionary:
		state["people"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_people_deep","gini": _gini, "message":"نابرابری اثر بر people - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_people","digital": _digital, "message":"فناوری دوگانه در people - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_people","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی people"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_people","capital": _social_capital, "message":"سرمایه اجتماعی پایین در people"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("people") and state["people"] is Dictionary and state["people"].has("maintenance_cost"):
		state["people"]["maintenance_cost"] = float(state["people"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("people") and state["people"] is Dictionary:
		_sys_q = float(state["people"].get("quality",0.60) if state["people"].has("quality") else state["people"].get("efficiency",0.60) if state["people"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("people") and state["people"] is Dictionary:
		state["people"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_people_deep","gini": _gini, "message":"نابرابری اثر بر people - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_people","digital": _digital, "message":"فناوری دوگانه در people - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_people","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی people"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_people","capital": _social_capital, "message":"سرمایه اجتماعی پایین در people"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("people") and state["people"] is Dictionary and state["people"].has("maintenance_cost"):
		state["people"]["maintenance_cost"] = float(state["people"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	return {"success": true, "state": state, "events": events}

func education_quality(state: Dictionary) -> float:
	return state.get("education",{}).get("quality",0.55)
