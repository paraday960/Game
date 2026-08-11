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
	return {"success":true,"state":state,"events":events}
