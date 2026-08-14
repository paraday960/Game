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
	# بیکاری: منبع واحد economy_system است (لنگر NAIRU با تعدیل مهارت + اوکن + بسیج/فناوری).
	# پیش از این اینجا مدلِ فرمولیِ بی‌حافظهٔ موازی هر روز econ["unemployment"] را بازنویسی
	# می‌کرد (پرش ۸٪→۱۲٪ در روز اول + پاک‌شدن شوک‌های مدیران) — رفع باگ shadow-write.
	var growth = econ.get("growth_rate", 0.02)
	var unemployment = clampf(float(econ.get("unemployment", 0.08)), 0.0, 1.0)
	welfare["unemployment_rate"] = unemployment

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
	# خیریه‌های مذهبی (دور ۱۳) بخشی از فقر را جبران می‌کنند
	poverty -= float(welfare.get("charity_contribution", 0.0)) * 0.15
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
	welfare["pension_coverage"] = clamp(welfare["pension_coverage"] + Deterministic.next_range(-0.0015, 0.0015), 0.3, 0.95)

	# حلقه بازخورد: اشتغال ← رضایت ← ثبات؛ فقر ← تنش
	pop["happiness"] = clamp(pop.get("happiness",0.6) + (0.08 - unemployment) * 0.001 + (0.15 - welfare["poverty"]) * 0.001, 0.05, 0.95)
	# فشار اجتماعی فقر/بیکاری بر تنش — کشف آینهٔ ۳۰ساله: قبلاً جمع‌گرایی فقط‌مثبت بود
	# (ratchet) و تنش آرام‌آرام فقط بالا می‌رفت تا به سقف ۱٫۰ بچسبد؛ نوسانِ پایین‌رفتن
	# فقر هرگز تنش را پایین نمی‌آورد. حالا کشش به سمت «هدف فشار» (دوطرفه).
	var tension_pressure: float = clampf(welfare["poverty"] * 0.5 + unemployment * 1.2, 0.0, 0.6)
	politics["tension"] = clampf(float(politics.get("tension", 0.35)) * 0.995 + tension_pressure * 0.005, 0.0, 1.0)
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
	
	# ── لایه واقع‌گرایانه اختصاصی رفاه (جایگزین قالب خودکار تکراری) — بخش ۳.۲۱ ──
	# فقر نسبی: تورم و بیکاری قدرت خرید را می‌خورند؛ شبکه امنیت اجتماعی بالشتک است
	var infl_w: float = float(econ.get("inflation", 0.08))
	var poverty_push: float = (infl_w - 0.05) * 0.15 + (float(econ.get("unemployment", 0.08)) - 0.08) * 0.2
	welfare["poverty"] = clampf(float(welfare.get("poverty", 0.15)) + poverty_push * 0.002 * (1.0 - float(welfare.get("social_safety", 0.60)) * 0.7), 0.03, 0.60)
	# تعادل صندوق بازنشستگی: فشار سالمندی در برابر مشارکت نیروی کار
	var aging_w: float = float(pop.get("aging_index", 0.20))
	var fund_flow: float = (float(welfare.get("participation_rate", 0.65)) * 0.6 - float(welfare.get("pension_coverage", 0.70)) * aging_w) * 0.000001
	welfare["pension_fund_balance"] = float(welfare.get("pension_fund_balance", 1_000_000_000.0)) * (1.0 + fund_flow)
	if float(welfare.get("pension_fund_balance", 1.0)) < 0.0 and Deterministic.chance(0.006):
		events.append({"type": "pension_deficit", "message": "کسری صندوق‌های بازنشستگی - فشار بر بودجه دولت", "balance": welfare["pension_fund_balance"]})
	# نابرابری با رانش آهسته تابع سیاست رفاهی
	welfare["gini"] = clampf(float(welfare.get("gini", 0.38)) + (0.40 - float(welfare.get("social_safety", 0.60))) * 0.0001, 0.25, 0.60)
	state["welfare"] = welfare

	return {"success": true, "state": state, "events": events}
