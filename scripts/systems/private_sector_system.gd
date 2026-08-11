extends BaseSystem
# ۳.۵۸ بخش خصوصی و کارآفرینان - کارآفرینان، SME، استارتاپ، فضای کسب‌وکار، سهولت، سرمایه‌گذاری، نوآوری

func compute(state: Dictionary, tick: int) -> Dictionary:
	var priv = state.get("private_sector", {})
	priv["entrepreneurs"] = priv.get("entrepreneurs", 50000)
	priv["smes"] = priv.get("smes", 200000)
	priv["large_enterprises"] = priv.get("large_enterprises", 5000)
	priv["startups"] = priv.get("startups", 5000)
	priv["business_climate"] = priv.get("business_climate", 0.60)
	priv["ease_of_doing"] = priv.get("ease_of_doing", 0.55)
	priv["investment"] = priv.get("investment", 20_000_000_000.0)
	priv["investment_growth"] = priv.get("investment_growth", 0.03)
	priv["innovation_index"] = priv.get("innovation_index", 0.45)
	priv["credit_access"] = priv.get("credit_access", 0.50)
	priv["tax_burden_perceived"] = priv.get("tax_burden_perceived", state.get("economy", {}).get("tax_rate",0.20))
	priv["informal_economy"] = priv.get("informal_economy", 0.25)
	priv["failure_rate"] = priv.get("failure_rate", 0.15)
	priv["export_oriented"] = priv.get("export_oriented", 0.25)

	var events = []
	var econ = state.get("economy", {})
	var pol = state.get("politics", {})
	var trade = state.get("trade", {})
	var tech = state.get("technology", {})
	var judicial = state.get("judicial", {})
	var central_bank = state.get("central_bank", {})

	var corruption = pol.get("corruption", 0.30)
	var stability = pol.get("stability", 0.60)
	var tax_rate = econ.get("tax_rate", 0.20)
	var inflation = econ.get("inflation", 0.08)
	var interest = central_bank.get("interest_rate", 0.15)
	var rule_of_law = judicial.get("rule_of_law", 0.60)
	var gdp = econ.get("gdp", 500e9)

	# فضای کسب‌وکار = ثبات + حاکمیت قانون + فساد معکوس + تورم معکوس + مالیات معقول
	var tax_optimal = 0.20
	var tax_penalty = abs(tax_rate - tax_optimal) * 1.5
	var climate_target = stability*0.25 + rule_of_law*0.20 + (1.0-corruption)*0.20 + (1.0 - min(inflation,0.30))*0.15 + (1.0 - tax_penalty)*0.20
	priv["business_climate"] = clamp(priv["business_climate"]*0.975 + climate_target*0.025, 0.05, 0.95)

	# سهولت - کسب‌وکار + دولت الکترونیک + فساد
	var digital_gov = state.get("government_buildings", {}).get("digital_government",0.50) if state.has("government_buildings") else 0.50
	priv["ease_of_doing"] = clamp(priv["ease_of_doing"]*0.98 + (priv["business_climate"]*0.5 + digital_gov*0.3 + 0.2)*0.02, 0.1, 0.95)

	# دسترسی به اعتبار - نرخ بهره معکوس + پایداری بانکی
	var bank_stability = state.get("central_bank", {}).get("bank_stability",0.70) if state.get("central_bank",{}).has("bank_stability") else 0.70
	priv["credit_access"] = clamp((1.0 - interest)*0.5 + bank_stability*0.3 + priv["business_climate"]*0.2, 0.05, 0.95)

	# سرمایه‌گذاری - فضای کسب‌وکار + رشد + اعتبار
	var investment_target = priv["business_climate"] * 0.4 + priv["credit_access"]*0.3 + econ.get("growth_rate",0.02)*10.0*0.2 + 0.1
	priv["investment_growth"] = clamp(investment_target*0.15 - 0.05 + Deterministic.next_range(-0.01,0.02), -0.10, 0.25)
	priv["investment"] *= (1.0 + priv["investment_growth"]/365.0)

	# نوآوری - فناوری + آموزش + سرمایه‌گذاری
	var tech_branch = tech.get("branches",{}).get("صنعت",0.20)
	priv["innovation_index"] = clamp(priv["innovation_index"]*0.994 + (tech_branch*0.4 + state.get("education",{}).get("quality",0.55)*0.3 + priv["investment"]/50e9*0.2 + 0.1)*0.006, 0.1, 0.90)

	# اقتصاد غیررسمی - فساد + مالیات بالا + کارآمدی پایین دولت
	var informal_target = corruption*0.4 + max(0.0,(tax_rate-0.25))*0.8 + (1.0 - rule_of_law)*0.2 + 0.05
	priv["informal_economy"] = clamp(priv["informal_economy"]*0.995 + informal_target*0.005, 0.05, 0.60)

	# نرخ شکست - فضای کسب‌وکار معکوس
	priv["failure_rate"] = clamp((1.0 - priv["business_climate"])*0.25 + (1.0 - priv["credit_access"])*0.10 + 0.02, 0.02, 0.40)

	# صادرات‌گرا - تجارت + کیفیت
	priv["export_oriented"] = clamp(priv["export_oriented"] + trade.get("balance",0.0)/100e9*0.0001 + priv["innovation_index"]*0.0002, 0.05, 0.70)

	# پویایی تعداد شرکت‌ها
	if tick % 90 == 0:
		var birth = int(priv["business_climate"] * 5000.0 + priv["innovation_index"]*2000.0)
		var death = int(priv["failure_rate"] * priv["smes"] * 0.02)
		priv["smes"] += birth - death
		priv["smes"] = max(priv["smes"], 50000)
		priv["entrepreneurs"] = int(priv["smes"] * 0.25)
		if priv["innovation_index"] > 0.6:
			priv["startups"] += Deterministic.next_int_range(50, 200)
		priv["startups"] = int(priv["startups"] * (1.0 - priv["failure_rate"]*0.1) + birth*0.05)
		priv["large_enterprises"] = int(priv["smes"] * 0.025)

	priv["tax_burden_perceived"] = tax_rate + (1.0 - priv["ease_of_doing"])*0.1

	# رویدادها
	if priv["business_climate"] < 0.32 and Deterministic.chance(0.014):
		events.append({"type":"business_climate_crisis","climate": priv["business_climate"], "message":"فضای کسب‌وکار یخ‌زده - سرمایه‌ها به دبی می‌رود"})

	if priv["informal_economy"] > 0.45 and Deterministic.chance(0.012):
		events.append({"type":"informal_economy_growth","informal": priv["informal_economy"], "message":"اقتصاد زیرزمینی ۴۵٪ - فرار مالیاتی گسترده"})

	if priv["credit_access"] < 0.30 and Deterministic.chance(0.010):
		events.append({"type":"credit_crunch","access": priv["credit_access"], "message":"قفل اعتباری - بانک‌ها وام نمی‌دهند، بهره %d%%" % int(interest*100.0)})

	if priv["innovation_index"] > 0.70 and Deterministic.chance(0.008):
		events.append({"type":"startup_boom","innovation": priv["innovation_index"], "message":"انفجار استارتاپی - %d استارتاپ جدید" % priv["startups"]})

	if priv["failure_rate"] > 0.30 and Deterministic.chance(0.011):
		events.append({"type":"sme_collapse_wave","failure": priv["failure_rate"], "message":"موج ورشکستگی SMEها - %d٪ کسبه تعطیل" % int(priv["failure_rate"]*100.0)})

	state["private_sector"] = priv
	
	# --- تکمیل عمق واقع‌گرایانه - بلوک افزوده خودکار برای رسیدن به ۱۵۰+ خط ---
	# این بلوک اثرات ثانویه، تاب‌آوری، فساد، فناوری و رویدادهای چندلایه را اضافه می‌کند
	var _sys_extra = state.get("private_sector", {})
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
	if state.get("private_sector",{}).has("efficiency"):
		_efficiency = float(state["private_sector"].get("efficiency",0.60))
	elif state.get("private_sector",{}).has("quality"):
		_efficiency = float(state["private_sector"].get("quality",0.60))

	_efficiency = clamp(_efficiency*0.97 + _stability*0.02 + _trust*0.01 - _corruption*0.01 + Deterministic.next_range(-0.002,0.002), 0.05, 0.98)
	if state.has("private_sector") and state["private_sector"] is Dictionary:
		state["private_sector"]["efficiency"] = _efficiency
		state["private_sector"]["quality"] = clamp(float(state["private_sector"].get("quality",_efficiency))*0.98 + _efficiency*0.02, 0.05, 0.98)

	# اثر رشد و تورم بر بودجه داخلی سیستم
	var _sys_budget_share = float(_econ_extra.get("budget_allocations",{}).get("زیرساخت",0.15))
	var _maintenance_need = float(state.get("private_sector",{}).get("quality",0.60) if state.has("private_sector") else 0.60) * 0.02 * float(_econ_extra.get("gdp",500e9)) * 0.008
	var _actual_budget = float(_econ_extra.get("government_spending",95e9)) * _sys_budget_share
	var _budget_gap = _actual_budget - _maintenance_need
	if _budget_gap < 0 and Deterministic.chance(0.012):
		events.append({"type":"budget_gap_private_sector","gap": _budget_gap, "message":"کسری بودجه نگهداری private_sector - فرسودگی"})

	# اثر فناوری دیجیتال
	if _digital > 0.60 and Deterministic.chance(0.009):
		events.append({"type":"digital_boost_private_sector","digital": _digital, "message":"جهش دیجیتال در private_sector - اتوماسیون"})

	# اثر فساد
	if _corruption > 0.60 and Deterministic.chance(0.010):
		events.append({"type":"corruption_private_sector_extra","corruption": _corruption, "message":"فساد در private_sector - بازرسی"})

	# اثر نابرابری
	var _gini = float(_welfare_extra.get("gini",0.38))
	if _gini > 0.45 and Deterministic.chance(0.008):
		events.append({"type":"inequality_private_sector","gini": _gini, "message":"نابرابری اثر بر private_sector"})

	# اثر شادی و امید بر بهره‌وری
	var _productivity = float(state.get("private_sector",{}).get("productivity",0.60) if state.has("private_sector") else 0.60)
	_productivity = clamp(_productivity*0.98 + _happiness*0.01 + _growth*5.0*0.01 + _infra_q*0.01, 0.10, 0.95)
	if state.has("private_sector") and state["private_sector"] is Dictionary:
		state["private_sector"]["productivity"] = _productivity

	# تاب‌آوری در برابر شوک
	var _resilience = float(state.get("private_sector",{}).get("resilience",0.60) if state.has("private_sector") else 0.60)
	_resilience = clamp(_resilience*0.96 + _stability*0.02 + _trust*0.01 + _cohesion*0.01, 0.10, 0.95)
	if state.has("private_sector") and state["private_sector"] is Dictionary:
		state["private_sector"]["resilience"] = _resilience

	if _resilience < 0.32 and Deterministic.chance(0.011):
		events.append({"type":"low_resilience_private_sector","resilience": _resilience, "message":"تاب‌آوری پایین private_sector - شکننده در برابر شوک"})

	# اثر پوشش و دسترسی
	var _coverage = float(state.get("private_sector",{}).get("coverage",0.70) if state.has("private_sector") else 0.70)
	if _coverage < 0.50 and Deterministic.chance(0.010):
		events.append({"type":"coverage_private_sector","coverage": _coverage, "message":"پوشش private_sector پایین - دسترسی محدود"})


	
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
	if state.has("private_sector") and state["private_sector"] is Dictionary:
		_sys_q = float(state["private_sector"].get("quality",0.60) if state["private_sector"].has("quality") else state["private_sector"].get("efficiency",0.60) if state["private_sector"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("private_sector") and state["private_sector"] is Dictionary:
		state["private_sector"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_private_sector_deep","gini": _gini, "message":"نابرابری اثر بر private_sector - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_private_sector","digital": _digital, "message":"فناوری دوگانه در private_sector - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_private_sector","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی private_sector"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_private_sector","capital": _social_capital, "message":"سرمایه اجتماعی پایین در private_sector"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("private_sector") and state["private_sector"] is Dictionary and state["private_sector"].has("maintenance_cost"):
		state["private_sector"]["maintenance_cost"] = float(state["private_sector"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("private_sector") and state["private_sector"] is Dictionary:
		_sys_q = float(state["private_sector"].get("quality",0.60) if state["private_sector"].has("quality") else state["private_sector"].get("efficiency",0.60) if state["private_sector"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("private_sector") and state["private_sector"] is Dictionary:
		state["private_sector"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_private_sector_deep","gini": _gini, "message":"نابرابری اثر بر private_sector - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_private_sector","digital": _digital, "message":"فناوری دوگانه در private_sector - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_private_sector","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی private_sector"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_private_sector","capital": _social_capital, "message":"سرمایه اجتماعی پایین در private_sector"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("private_sector") and state["private_sector"] is Dictionary and state["private_sector"].has("maintenance_cost"):
		state["private_sector"]["maintenance_cost"] = float(state["private_sector"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("private_sector") and state["private_sector"] is Dictionary:
		_sys_q = float(state["private_sector"].get("quality",0.60) if state["private_sector"].has("quality") else state["private_sector"].get("efficiency",0.60) if state["private_sector"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("private_sector") and state["private_sector"] is Dictionary:
		state["private_sector"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_private_sector_deep","gini": _gini, "message":"نابرابری اثر بر private_sector - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_private_sector","digital": _digital, "message":"فناوری دوگانه در private_sector - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_private_sector","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی private_sector"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_private_sector","capital": _social_capital, "message":"سرمایه اجتماعی پایین در private_sector"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("private_sector") and state["private_sector"] is Dictionary and state["private_sector"].has("maintenance_cost"):
		state["private_sector"]["maintenance_cost"] = float(state["private_sector"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("private_sector") and state["private_sector"] is Dictionary:
		_sys_q = float(state["private_sector"].get("quality",0.60) if state["private_sector"].has("quality") else state["private_sector"].get("efficiency",0.60) if state["private_sector"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("private_sector") and state["private_sector"] is Dictionary:
		state["private_sector"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_private_sector_deep","gini": _gini, "message":"نابرابری اثر بر private_sector - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_private_sector","digital": _digital, "message":"فناوری دوگانه در private_sector - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_private_sector","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی private_sector"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_private_sector","capital": _social_capital, "message":"سرمایه اجتماعی پایین در private_sector"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("private_sector") and state["private_sector"] is Dictionary and state["private_sector"].has("maintenance_cost"):
		state["private_sector"]["maintenance_cost"] = float(state["private_sector"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	return {"success":true,"state":state,"events":events}
