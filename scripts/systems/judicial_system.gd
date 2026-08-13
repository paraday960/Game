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
	
	# ── لایه واقع‌گرایانه اختصاصی قضا (جایگزین قالب خودکار تکراری) — بخش ۳.۱۷ ──
	# جریان پرونده: ورودی از جرم و نزاع‌های اقتصادی، خروجی با کارآمدی دادگاه‌ها
	var unemp_j: float = float(econ.get("unemployment", 0.08))
	var poverty_j: float = float(welfare.get("poverty", 0.15))
	var case_inflow: float = 0.0012 * (0.55 + float(judicial.get("crime_rate", 50.0)) / 100.0) + 0.0008 * (unemp_j * 3.0 + poverty_j)
	var clearance: float = 0.0022 * float(judicial.get("efficiency", 0.60)) * (0.6 + float(judicial.get("access", 0.60)) * 0.4)
	# فشار تراکم نرمال‌شده ۰ تا ۱ (کلید جداگانه؛ شمارش خام case_backlog دست نمی‌خورد)
	var case_count: float = float(judicial.get("case_backlog", 10000.0))
	var backlog: float = clampf(float(judicial.get("backlog_pressure", 0.35)) + (case_inflow - clearance) * 0.5 + (case_count / 50000.0 - 0.35) * 0.001, 0.02, 1.0)
	judicial["backlog_pressure"] = backlog
	# تراکم پرونده → احساس عدالت و فرسایش قاعده قانون (بازخورد واقعی)
	var justice_felt: float = clampf(1.0 - backlog, 0.0, 1.0)
	judicial["justice"] = clampf(float(judicial.get("justice", 0.55)) * 0.995 + justice_felt * 0.005, 0.05, 0.95)
	judicial["rule_of_law"] = clampf(float(judicial.get("rule_of_law", 0.60)) * 0.998 + (float(judicial.get("justice", 0.55)) * 0.7 + (1.0 - float(judicial.get("corruption_judicial", 0.20))) * 0.3) * 0.002, 0.05, 0.95)
	# تراکم بالا قاطعیت مجازات (بازدارندگی) را می‌فرساید
	judicial["deterrence"] = clampf(float(judicial.get("deterrence", 0.55)) * 0.997 + (1.0 - backlog) * 0.003, 0.05, 0.95)
	if backlog > 0.80 and Deterministic.chance(0.004):
		events.append({"type": "court_gridlock", "message": "قفل شدن دادگاه‌ها - تراکم پرونده‌ها به حد بحرانی رسید", "backlog": backlog})
	if float(judicial.get("justice", 0.55)) < 0.30 and Deterministic.chance(0.004):
		events.append({"type": "justice_distrust", "message": "بی‌اعتمادی عمومی به دستگاه قضا - احساس بی‌عدالتی در جامعه گسترش یافت", "justice": judicial["justice"]})
	state["judicial"] = judicial

	return {"success": true, "state": state, "events": events}
