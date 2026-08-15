extends BaseSystem
# سیستم سیاست داخلی و ثبات - ۳.۱۲

func compute(state: Dictionary, tick: int) -> Dictionary:
	var pol = state["politics"]
	var pop = state["population"]
	var econ = state["economy"]
	var welfare = state["welfare"]
	var judicial = state["judicial"]
	var culture = state["culture"]

	var events = []

	# ثبات سیاسی = f(رضایت، فساد، نابرابری، امنیت، مشروعیت، رویدادها) - ۳.۱۲.۳
	var base_stability = float(BalanceConfig.get_value("politics.stability_initial", 0.6))
	var happiness_effect = (pop["happiness"] - 0.5) * 0.5
	var corruption_effect = -pol["corruption"] * 0.4
	var inequality_effect = -welfare["gini"] * 0.3
	var trust_effect = (pol["trust"] - 0.5) * 0.3
	var econ_effect = 0.0
	if econ["unemployment"] > 0.12:
		econ_effect -= 0.1
	if econ["inflation"] > 0.12:
		econ_effect -= 0.1

	# تداوم سیاستگذاری (دور ۱۳) ثبات می‌سازد؛ معوقه حقوق کارکنان دولت (دور ۱۴) اعتراض می‌آورد
	var continuity_p = float(state.get("political_career", {}).get("policy_continuity", 0.50)) - 0.50
	var arrears_p = minf(float(state.get("public_employees", {}).get("wage_arrears_months", 0.0)), 6.0)
	var new_stability = base_stability + happiness_effect + corruption_effect + inequality_effect + trust_effect + econ_effect + continuity_p * 0.10 - arrears_p * 0.015
	new_stability = clamp(new_stability, 0.05, 0.95)
	pol["stability"] = pol["stability"] * 0.97 + new_stability * 0.03

	# اعتماد عمومی = f(شفافیت، نتایج اقتصادی، فساد، امنیت)
	var trust = 0.5
	trust += (pol["stability"] - 0.5) * 0.3
	trust += (1.0 - pol["corruption"]) * 0.3
	trust += (pop["satisfaction"] - 0.5) * 0.2
	trust += (judicial["rule_of_law"] - 0.5) * 0.2
	pol["trust"] = clamp(pol["trust"] * 0.98 + trust * 0.02, 0.05, 0.95)

	# تنش اجتماعی = f(نارضایتی، فساد، نابرابری، بیکاری، سرکوب)
	var tension = 0.3
	tension += (1.0 - pop["happiness"]) * 0.4
	tension += pol["corruption"] * 0.2
	tension += welfare["gini"] * 0.2
	tension += econ["unemployment"] * 0.3
	# ریسک‌های امنیتی دورهای ۱۰ و ۱۳ (ناآرامی قومی و افراطی‌گرایی) مستقیم به تنش تزریق می‌شود
	tension += float(state.get("security", {}).get("ethnic_unrest_risk", 0.0)) * 0.25
	tension += float(state.get("security", {}).get("extremism_risk", 0.0)) * 0.20
	pol["tension"] = clamp(pol["tension"] * 0.97 + tension * 0.03, 0.0, 1.0)

	# فساد پویا
	if pol["stability"] < 0.4 and Deterministic.chance(0.02):
		pol["corruption"] += 0.01
		events.append({"type": "corruption_increase", "level": pol["corruption"]})
	elif pol["stability"] > 0.7 and pol["trust"] > 0.6 and Deterministic.chance(0.02):
		pol["corruption"] -= 0.005
	pol["corruption"] = clamp(pol["corruption"], 0.0, 0.90)

	# مشروعیت — اینرسی نرم به‌سوی هدف (بازرسی ۱۴۰۵، عمق‌بخشی ۴۲):
	# پیش‌تر از صفر بازمحاسبه می‌شد و شوک‌های رویدادی (نتایج انتخابات +۰٫۰۳/−۰٫۰۲،
	# اصلاحات مشروعیت‌ساز) فردای همان روز پاک می‌شدند — اتم ناقص.
	var legitimacy_target = 0.5 + pol["trust"] * 0.3 + (1.0 - pol["corruption"]) * 0.2 \
		+ pol["stability"] * 0.2 + culture["cohesion"] * 0.1
	pol["legitimacy"] = clampf(float(pol.get("legitimacy", 0.55)) * 0.997 + legitimacy_target * 0.003, 0.05, 0.95)

	# رویدادهای سیاسی - ۳.۱۲.۵ - آستانه شورش تنش > 80٪
	if pol["tension"] > float(BalanceConfig.get_value("politics.riot_threshold", 0.8)) and Deterministic.chance(0.1):
		events.append({"type": "protest", "tension": pol["tension"], "message": "اعتراضات گسترده خیابانی"})
		pol["stability"] -= 0.05
		pop["happiness"] -= 0.05

	if pol["stability"] < 0.3 and Deterministic.chance(0.02):
		events.append({"type": "coup_risk", "stability": pol["stability"], "message": "خطر کودتا!"})

	if tick % (4 * 365) == 0:
		events.append({"type": "election", "message": "زمان انتخابات فرا رسید - بخش ۳.۶۵"})
		# شبیه‌سازی نتیجه انتخابات
		var result = (pop["happiness"] + pol["trust"]) / 2.0
		if result > 0.6:
			events.append({"type": "election_win", "result": "پیروزی جناح حاکم"})
		else:
			events.append({"type": "election_loss", "result": "شکست در انتخابات"})

	state["politics"] = pol
	
	# ── لایه واقع‌گرایانه اختصاصی سیاست (جایگزین قالب خودکار تکراری) — بخش ۳.۱۲ ──
	# مشروعیت از قاعده قانون و احساس عدالت (پیوند با سیستم قضا) و عملکرد اقتصادی
	var rule_p: float = float(judicial.get("rule_of_law", 0.60))
	var just_p: float = float(judicial.get("justice", 0.55))
	var growth_p: float = float(econ.get("growth_rate", 0.02))
	pol["legitimacy"] = clampf(float(pol.get("legitimacy", 0.55)) * 0.997 + (rule_p * 0.4 + just_p * 0.3 + clampf(growth_p * 10.0, 0.0, 0.3)) * 0.003, 0.05, 0.95)
	# فساد خودتقویه‌شونده است مگر استقلال قضا مانع شود
	var ind_p: float = float(judicial.get("independence", 0.55))
	var corr_now: float = float(pol.get("corruption", 0.30))
	pol["corruption"] = clampf(corr_now + (0.5 - ind_p) * 0.0003 * (1.0 if corr_now > 0.4 else -0.5), 0.02, 0.95)
	if float(pol.get("legitimacy", 0.55)) < 0.30 and Deterministic.chance(0.005):
		# اثر واقعی بحران مشروعیت: شکاف دولت-ملت ثبات را می‌فرساید و تنش را بالا می‌برد
		pol["stability"] = clampf(float(pol.get("stability", 0.60)) - 0.020, 0.05, 1.0)
		pol["tension"] = clampf(float(pol.get("tension", 0.35)) + 0.030, 0.0, 1.0)
		pop["happiness"] = clampf(float(pop.get("happiness", 0.60)) - 0.010, 0.05, 1.0)
		events.append({"type": "legitimacy_crisis", "message": "بحران مشروعیت - فاصله دولت و ملت عمیق شده است", "legitimacy": pol["legitimacy"]})
	state["politics"] = pol

	return {"success": true, "state": state, "events": events}
