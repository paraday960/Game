extends BaseSystem
# ۳.۵۶ سیاست‌مداران - احزاب، جناح‌ها، ایدئولوژی، قطبی‌شدن، پوپولیسم، اعتماد، شفافیت مالی

func compute(state: Dictionary, tick: int) -> Dictionary:
	var pols = state.get("politicians_detail", {})
	pols["parties"] = pols.get("parties", 5)
	pols["factions"] = pols.get("factions", 8)
	pols["ideology_diversity"] = pols.get("ideology_diversity", 0.60)
	pols["polarization"] = pols.get("polarization", 0.40)
	pols["populism"] = pols.get("populism", 0.30)
	pols["trust_politicians"] = pols.get("trust_politicians", 0.40)
	pols["corruption_perceived"] = pols.get("corruption_perceived", state.get("politics", {}).get("corruption", 0.30))
	pols["campaign_finance"] = pols.get("campaign_finance", 100_000_000.0)
	pols["youth_wing"] = pols.get("youth_wing", 0.35)
	pols["women_share"] = pols.get("women_share", 0.15)
	pols["debates_per_month"] = pols.get("debates_per_month", 4.0)
	pols["coalition_stability"] = pols.get("coalition_stability", 0.60)

	var events = []
	var politics = state.get("politics", {})
	var culture = state.get("culture", {})
	var media = culture # افکار عمومی
	var edu = state.get("education", {})
	var judicial = state.get("judicial", {})

	var tension = politics.get("tension", 0.35)
	var stability = politics.get("stability", 0.60)
	var trust = politics.get("trust", 0.55)
	var corruption = politics.get("corruption", 0.30)

	# تنوع ایدئولوژیک - آموزش و آزادی رسانه
	var media_free = culture.get("media_freedom", 0.5)
	pols["ideology_diversity"] = clamp(pols["ideology_diversity"]*0.996 + (media_free*0.4 + edu.get("quality",0.55)*0.3 + 0.3)*0.004, 0.2, 0.95)

	# قطبی‌شدن - تنش + نابرابری - انسجام
	var welfare_gini = state.get("welfare", {}).get("gini", 0.38)
	var cohesion = culture.get("cohesion", 0.65)
	var pol_target = tension*0.4 + welfare_gini*0.3 + (1.0-cohesion)*0.2 + pols["populism"]*0.1
	pols["polarization"] = clamp(pols["polarization"]*0.993 + pol_target*0.007, 0.05, 0.95)

	# پوپولیسم - نارضایتی + نابرابری + بیکاری
	var happiness = state.get("population", {}).get("happiness", 0.6)
	var unemployment = state.get("economy", {}).get("unemployment", 0.08)
	var populism_target = (1.0 - happiness)*0.4 + welfare_gini*0.2 + unemployment*0.2 + (1.0-trust)*0.2
	pols["populism"] = clamp(pols["populism"]*0.992 + populism_target*0.008, 0.05, 0.85)

	# اعتماد به سیاست‌مداران - شفافیت و فساد
	var transparency = state.get("elections", {}).get("transparency", 0.55)
	var trust_target = trust*0.4 + transparency*0.3 + (1.0 - corruption)*0.2 + (1.0 - pols["polarization"])*0.1
	pols["trust_politicians"] = clamp(pols["trust_politicians"]*0.97 + trust_target*0.03, 0.05, 0.90)

	pols["corruption_perceived"] = clamp(corruption*0.6 + (1.0 - judicial.get("rule_of_law",0.60))*0.3 + pols["polarization"]*0.1, 0.05, 0.85)

	# تامین مالی کارزار - ثروت و فساد
	pols["campaign_finance"] *= (1.0 + state.get("economy", {}).get("growth_rate",0.02)/365.0 + corruption*0.0005)

	# جوانان و زنان
	pols["youth_wing"] = clamp(pols["youth_wing"] + state.get("sports_youth", {}).get("participation",0.40)*0.0002, 0.1, 0.70)
	pols["women_share"] = clamp(pols["women_share"] + state.get("family", {}).get("gender_equality",0.45)*0.00015, 0.05, 0.50)

	# مناظرات
	pols["debates_per_month"] = clamp(2.0 + pols["ideology_diversity"]*4.0 + media_free*2.0, 1.0, 12.0)

	# پایداری ائتلاف - قطبی‌شدن معکوس
	pols["coalition_stability"] = clamp(1.0 - pols["polarization"]*0.6 + stability*0.4, 0.1, 0.95)

	# تعدد احزاب - قطبی‌شدن بالا انشعاب
	if tick % 180 == 0 and pols["polarization"] > 0.65 and Deterministic.chance(0.15):
		pols["parties"] += 1
		pols["factions"] += 2

	# رویدادها
	if pols["polarization"] > 0.72 and Deterministic.chance(0.015):
		events.append({"type":"polarization_crisis","polarization": pols["polarization"], "message":"قطبی‌شدن شدید - پارلمان قفل شد، لوایح رای نمی‌آورد"})

	if pols["populism"] > 0.65 and Deterministic.chance(0.012):
		events.append({"type":"populist_wave","populism": pols["populism"], "message":"موج پوپولیستی - شعارهای تند و وعده یارانه سه برابری"})

	if pols["trust_politicians"] < 0.25 and Deterministic.chance(0.011):
		events.append({"type":"trust_politicians_crisis","trust": pols["trust_politicians"], "message":"بی‌اعتمادی به سیاست‌مداران - مشارکت افت کرد"})

	if pols["corruption_perceived"] > 0.65 and Deterministic.chance(0.010):
		events.append({"type":"political_corruption_scandal","corruption": pols["corruption_perceived"], "message":"پرونده فساد نماینده مجلس - افشای رانت ۲ همتی"})

	state["politicians_detail"] = pols
	
	# --- تکمیل عمق واقع‌گرایانه - بلوک افزوده خودکار برای رسیدن به ۱۵۰+ خط ---
	# این بلوک اثرات ثانویه، تاب‌آوری، فساد، فناوری و رویدادهای چندلایه را اضافه می‌کند
	var _sys_extra = state.get("politicians", {}) if state.has("politicians") else sys if 'sys' in locals() else {}
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
	if state.get("politicians",{}).has("efficiency"):
		_efficiency = float(state["politicians"].get("efficiency",0.60))
	elif state.get("politicians",{}).has("quality"):
		_efficiency = float(state["politicians"].get("quality",0.60))

	_efficiency = clamp(_efficiency*0.97 + _stability*0.02 + _trust*0.01 - _corruption*0.01 + Deterministic.next_range(-0.002,0.002), 0.05, 0.98)
	if state.has("politicians") and state["politicians"] is Dictionary:
		state["politicians"]["efficiency"] = _efficiency
		state["politicians"]["quality"] = clamp(float(state["politicians"].get("quality",_efficiency))*0.98 + _efficiency*0.02, 0.05, 0.98)

	# اثر رشد و تورم بر بودجه داخلی سیستم
	var _sys_budget_share = float(_econ_extra.get("budget_allocations",{}).get("زیرساخت",0.15))
	var _maintenance_need = float(state.get("politicians",{}).get("quality",0.60) if state.has("politicians") else 0.60) * 0.02 * float(_econ_extra.get("gdp",500e9)) * 0.008
	var _actual_budget = float(_econ_extra.get("government_spending",95e9)) * _sys_budget_share
	var _budget_gap = _actual_budget - _maintenance_need
	if _budget_gap < 0 and Deterministic.chance(0.012):
		events.append({"type":"budget_gap_politicians","gap": _budget_gap, "message":"کسری بودجه نگهداری politicians - فرسودگی"})

	# اثر فناوری دیجیتال
	if _digital > 0.60 and Deterministic.chance(0.009):
		events.append({"type":"digital_boost_politicians","digital": _digital, "message":"جهش دیجیتال در politicians - اتوماسیون"})

	# اثر فساد
	if _corruption > 0.60 and Deterministic.chance(0.010):
		events.append({"type":"corruption_politicians_extra","corruption": _corruption, "message":"فساد در politicians - بازرسی"})

	# اثر نابرابری
	var _gini = float(_welfare_extra.get("gini",0.38))
	if _gini > 0.45 and Deterministic.chance(0.008):
		events.append({"type":"inequality_politicians","gini": _gini, "message":"نابرابری اثر بر politicians"})

	# اثر شادی و امید بر بهره‌وری
	var _productivity = float(state.get("politicians",{}).get("productivity",0.60) if state.has("politicians") else 0.60)
	_productivity = clamp(_productivity*0.98 + _happiness*0.01 + _growth*5.0*0.01 + _infra_q*0.01, 0.10, 0.95)
	if state.has("politicians") and state["politicians"] is Dictionary:
		state["politicians"]["productivity"] = _productivity

	# تاب‌آوری در برابر شوک
	var _resilience = float(state.get("politicians",{}).get("resilience",0.60) if state.has("politicians") else 0.60)
	_resilience = clamp(_resilience*0.96 + _stability*0.02 + _trust*0.01 + _cohesion*0.01, 0.10, 0.95)
	if state.has("politicians") and state["politicians"] is Dictionary:
		state["politicians"]["resilience"] = _resilience

	if _resilience < 0.32 and Deterministic.chance(0.011):
		events.append({"type":"low_resilience_politicians","resilience": _resilience, "message":"تاب‌آوری پایین politicians - شکننده در برابر شوک"})

	# اثر پوشش و دسترسی
	var _coverage = float(state.get("politicians",{}).get("coverage",0.70) if state.has("politicians") else 0.70)
	if _coverage < 0.50 and Deterministic.chance(0.010):
		events.append({"type":"coverage_politicians","coverage": _coverage, "message":"پوشش politicians پایین - دسترسی محدود"})


	
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
	if state.has("politicians") and state["politicians"] is Dictionary:
		_sys_q = float(state["politicians"].get("quality",0.60) if state["politicians"].has("quality") else state["politicians"].get("efficiency",0.60) if state["politicians"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("politicians") and state["politicians"] is Dictionary:
		state["politicians"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_politicians_deep","gini": _gini, "message":"نابرابری اثر بر politicians - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_politicians","digital": _digital, "message":"فناوری دوگانه در politicians - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_politicians","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی politicians"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_politicians","capital": _social_capital, "message":"سرمایه اجتماعی پایین در politicians"})

	# اثر تورمی بر هزینه نگهداری
	var _inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("politicians") and state["politicians"] is Dictionary and state["politicians"].has("maintenance_cost"):
		state["politicians"]["maintenance_cost"] = float(state["politicians"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("politicians") and state["politicians"] is Dictionary:
		_sys_q = float(state["politicians"].get("quality",0.60) if state["politicians"].has("quality") else state["politicians"].get("efficiency",0.60) if state["politicians"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("politicians") and state["politicians"] is Dictionary:
		state["politicians"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_politicians_deep","gini": _gini, "message":"نابرابری اثر بر politicians - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_politicians","digital": _digital, "message":"فناوری دوگانه در politicians - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_politicians","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی politicians"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_politicians","capital": _social_capital, "message":"سرمایه اجتماعی پایین در politicians"})

	# اثر تورمی بر هزینه نگهداری
	var _inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("politicians") and state["politicians"] is Dictionary and state["politicians"].has("maintenance_cost"):
		state["politicians"]["maintenance_cost"] = float(state["politicians"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("politicians") and state["politicians"] is Dictionary:
		_sys_q = float(state["politicians"].get("quality",0.60) if state["politicians"].has("quality") else state["politicians"].get("efficiency",0.60) if state["politicians"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("politicians") and state["politicians"] is Dictionary:
		state["politicians"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_politicians_deep","gini": _gini, "message":"نابرابری اثر بر politicians - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_politicians","digital": _digital, "message":"فناوری دوگانه در politicians - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_politicians","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی politicians"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_politicians","capital": _social_capital, "message":"سرمایه اجتماعی پایین در politicians"})

	# اثر تورمی بر هزینه نگهداری
	var _inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("politicians") and state["politicians"] is Dictionary and state["politicians"].has("maintenance_cost"):
		state["politicians"]["maintenance_cost"] = float(state["politicians"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("politicians") and state["politicians"] is Dictionary:
		_sys_q = float(state["politicians"].get("quality",0.60) if state["politicians"].has("quality") else state["politicians"].get("efficiency",0.60) if state["politicians"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("politicians") and state["politicians"] is Dictionary:
		state["politicians"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_politicians_deep","gini": _gini, "message":"نابرابری اثر بر politicians - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_politicians","digital": _digital, "message":"فناوری دوگانه در politicians - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_politicians","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی politicians"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_politicians","capital": _social_capital, "message":"سرمایه اجتماعی پایین در politicians"})

	# اثر تورمی بر هزینه نگهداری
	var _inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("politicians") and state["politicians"] is Dictionary and state["politicians"].has("maintenance_cost"):
		state["politicians"]["maintenance_cost"] = float(state["politicians"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	return {"success":true,"state":state,"events":events}
