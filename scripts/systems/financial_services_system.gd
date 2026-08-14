extends BaseSystem
# ۳.۵۰ خدمات مالی - بانک، شعبه، بیمه، خودپرداز، فراگیری مالی، بانکداری دیجیتال، NPL، فناوری، نفوذ بیمه

func compute(state: Dictionary, tick: int) -> Dictionary:
	var fin = state.get("financial_services", {})
	fin["banks"] = fin.get("banks", 30)
	fin["bank_branches"] = fin.get("bank_branches", 5000)
	fin["insurance_companies"] = fin.get("insurance_companies", 30)
	fin["microfinance"] = fin.get("microfinance", 50)
	fin["atms"] = fin.get("atms", 15000)
	fin["pos"] = fin.get("pos", 500000)
	fin["financial_inclusion"] = fin.get("financial_inclusion", 0.65)
	fin["digital_banking"] = fin.get("digital_banking", 0.50)
	fin["mobile_banking"] = fin.get("mobile_banking", 0.40)
	fin["non_performing_loans"] = fin.get("non_performing_loans", 0.08)
	fin["capital_adequacy"] = fin.get("capital_adequacy", 0.12)
	fin["insurance_penetration"] = fin.get("insurance_penetration", 0.02)
	fin["credit_to_gdp"] = fin.get("credit_to_gdp", 0.60)
	fin["saving_deposits"] = fin.get("saving_deposits", 200_000_000_000.0)
	fin["fintech_companies"] = fin.get("fintech_companies", 150)
	fin["trust_banks"] = fin.get("trust_banks", 0.60)

	var events = []
	var econ = state.get("economy", {})
	var central_bank = state.get("central_bank", {})
	var tech = state.get("technology", {}).get("branches", {}).get("دیجیتال", 0.20)
	var pop = state.get("population", {})
	var edu = state.get("education", {})

	var inflation = econ.get("inflation", 0.08)
	var growth = econ.get("growth_rate", 0.02)
	var gdp_pc = econ.get("gdp_per_capita", 5000.0)
	var unemployment = econ.get("unemployment", 0.08)
	var interest = central_bank.get("interest_rate", 0.15)

	# فراگیری مالی - سواد + فناوری + درآمد
	var inclusion_target = edu.get("literacy",0.85)*0.3 + tech*0.25 + (gdp_pc/8000.0)*0.2 + pop.get("urban_ratio",0.75)*0.15 + 0.10
	fin["financial_inclusion"] = clamp(fin["financial_inclusion"]*0.992 + inclusion_target*0.008, 0.2, 0.98)

	# بانکداری دیجیتال - فناوری + فراگیری
	fin["digital_banking"] = clamp(fin["digital_banking"]*0.991 + (tech*0.5 + fin["financial_inclusion"]*0.3 + 0.2)*0.009, 0.05, 0.98)
	fin["mobile_banking"] = clamp(fin["mobile_banking"] + tech*0.0015 + fin["digital_banking"]*0.0008, 0.05, 0.95)

	# مطالبات معوق - بیکاری + تورم + فساد + رشد معکوس
	var corruption = state.get("politics", {}).get("corruption", 0.30)
	fin["non_performing_loans"] = clamp(fin["non_performing_loans"]*0.995 + (unemployment-0.08)*0.05 + max(0.0, inflation-0.10)*0.1 + corruption*0.01 - growth*0.2, 0.01, 0.40)

	# کفایت سرمایه - NPL معکوس + مقررات بانک مرکزی
	var regulation = central_bank.get("bank_stability", 0.70) if central_bank.has("bank_stability") else 0.70
	fin["capital_adequacy"] = clamp(regulation*0.5 + (1.0 - fin["non_performing_loans"])*0.4 + 0.10, 0.04, 0.30)

	# نفوذ بیمه - درآمد + آگاهی
	fin["insurance_penetration"] = clamp(fin["insurance_penetration"]*0.998 + (gdp_pc/10000.0*0.4 + edu.get("quality",0.55)*0.3 + fin["trust_banks"]*0.2 + 0.05)*0.002, 0.005, 0.20)

	# اعتبار به GDP - فراگیری + رشد
	fin["credit_to_gdp"] = clamp(fin["credit_to_gdp"]*0.995 + (fin["financial_inclusion"]*0.5 + growth*10.0*0.2 + 0.2)*0.005, 0.1, 1.8)

	# سپرده‌ها - پس‌انداز خانوار + رشد
	var saving_rate = state.get("households_detail_full", {}).get("savings_rate",0.15) if state.has("households_detail_full") else 0.15
	# واحد cadence (دور دوازدهم): سیستم ماهانه است (۲۴ اجرا در سال) ⇒ نرخ سالانه با
	# ۱۵/۳۶۵ در هر اجرا؛ پیش از این عمق بانکی ~۲٫۵ برابر کندتر از طراحی رشد می‌کرد.
	fin["saving_deposits"] *= (1.0 + (growth*0.5 + saving_rate*0.1) * 15.0 / 365.0)
	fin["saving_deposits"] = max(fin["saving_deposits"], 10_000_000_000.0)

	# شرکت‌های فین‌تک - فناوری
	if tick % 90 == 15 and tech > 0.4:
		fin["fintech_companies"] += Deterministic.next_int_range(5, 20)

	# اعتماد به بانک‌ها - ثبات + NPL معکوس + تورم
	var trust_target = regulation*0.3 + (1.0 - fin["non_performing_loans"]*2.0)*0.3 + (1.0 - min(inflation,0.30))*0.2 + 0.2
	fin["trust_banks"] = clamp(fin["trust_banks"]*0.98 + trust_target*0.02, 0.1, 0.95)

	# تعداد شعب و خودپرداز - فراگیری
	if tick % 180 == 15:
		if fin["financial_inclusion"] > 0.70 and fin["banks"] < 50:
			fin["banks"] += 1
			fin["bank_branches"] += Deterministic.next_int_range(50, 150)
		fin["atms"] = int(fin["bank_branches"] * 3.0 + fin["digital_banking"]*1000.0)
		fin["pos"] = int(fin["financial_inclusion"] * 800000.0)

	# رویدادها
	if fin["non_performing_loans"] > 0.16 and Deterministic.chance(0.015):
		events.append({"type":"npl_crisis","npl": fin["non_performing_loans"], "message":"بحران مطالبات معوق - NPL %d٪، بانک‌ها محتاط" % int(fin["non_performing_loans"]*100.0)})

	if fin["capital_adequacy"] < 0.08 and Deterministic.chance(0.012):
		events.append({"type":"capital_adequacy_warning","adequacy": fin["capital_adequacy"], "message":"کفایت سرمایه پایین - ریسک نکول بانکی"})

	if fin["digital_banking"] > 0.75 and fin["fintech_companies"] > 200 and Deterministic.chance(0.010):
		events.append({"type":"fintech_boom","digital": fin["digital_banking"], "fintech": fin["fintech_companies"], "message":"انقلاب فین‌تک - %d شرکت، %d٪ تراکنش موبایلی" % [fin["fintech_companies"], int(fin["digital_banking"]*100.0)]})

	if fin["trust_banks"] < 0.35 and Deterministic.chance(0.011):
		events.append({"type":"bank_trust_crisis","trust": fin["trust_banks"], "message":"بی‌اعتمادی به بانک‌ها - هجوم برای برداشت سپرده"})

	if fin["insurance_penetration"] < 0.015 and tick % 180 == 15 and Deterministic.chance(0.02):
		events.append({"type":"low_insurance","penetration": fin["insurance_penetration"], "message":"نفوذ بیمه ۱٪ - ۹۹٪ مردم بیمه عمر ندارند"})

	state["financial_services"] = fin
	state["economy"] = econ
	
	# ── لایه واقع‌گرایانه اختصاصی خدمات مالی (جایگزین قالب خودکار) — بخش ۳.۵۰ ──
	# نرخ بهره واقعی منفی = فرار سپرده‌ها از بانک به سمت طلا و ارز (پدیده کلاسیک)
	var real_interest = float(interest) - float(inflation)
	var deposit_flow = real_interest * 0.02 + float(fin.get("trust_banks", 0.60)) * 0.001 - 0.0005
	fin["saving_deposits"] = maxf(float(fin.get("saving_deposits", 200e9)) * (1.0 + deposit_flow / 30.0), 20e9)
	if real_interest < -0.10 and Deterministic.chance(0.005):
		events.append({"type": "deposit_flight", "message": "خروج سپرده از بانک‌ها - نرخ بهره واقعی عمیقاً منفی است", "real_rate": real_interest})
	# بحران بانکی: مطالبات معوق بالا + کفایت سرمایه ناکافی → هجوم برداشت
	if float(fin.get("non_performing_loans", 0.08)) > 0.18 and float(fin.get("capital_adequacy", 0.12)) < 0.08 and Deterministic.chance(0.006):
		fin["trust_banks"] = clampf(float(fin.get("trust_banks", 0.60)) - 0.04, 0.05, 0.95)
		fin["saving_deposits"] = float(fin.get("saving_deposits", 200e9)) * 0.97
		events.append({"type": "bank_run", "message": "هجوم سپرده‌گذاران به شعب - شایعه ورشکستگی موسسه اعتباری", "npl": fin["non_performing_loans"]})
	# مرگ تدریجی شعبه فیزیکی: بانکداری موبایلی شعب را بی‌مشتری می‌کند
	fin["bank_branches"] = maxi(int(float(fin.get("bank_branches", 5000)) * (1.0 - float(fin.get("mobile_banking", 0.40)) * 0.0004)), 1500)
	fin["fintech_companies"] = maxi(int(float(fin.get("fintech_companies", 150)) * (1.0 + float(tech) * 0.002)), 10)
	# اعتبار بخش خصوصی: نرخ بهره بالا وام را خشک می‌کند
	var credit_target = 0.75 - float(interest) * 1.5 + float(growth) * 2.0
	fin["credit_to_gdp"] = clampf(float(fin.get("credit_to_gdp", 0.60)) * 0.997 + credit_target * 0.003, 0.15, 1.20)
	state["financial_services"] = fin

	return {"success":true,"state":state,"events":events}
