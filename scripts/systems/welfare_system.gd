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
	var welfare_budget = econ.get("government_spend_base", 0.0) * welfare_budget_share

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

	# نظام بازنشستگی و مستمری - ۳.۲۱.۲ — بازرسی ۱۴۰۵ (دور دهم): واحدها شکسته بود.
	# قبل: مستمری ثابت ۵۰۰۰ × ~۸٫۵M بازنشسته در هر اجرای هفتگی ≈ خروجی ۴۳B
	#   (صدها برابر تعهدات واقعی) ⇒ موجودی صندوق از همان اجرای اول برای همیشه
	#   به صفر میخکوب می‌شد و رویداد «بحران صندوق» فانتوم با احتمال ۱٪ در هر اجرا
	#   (~۲۶٪ در ماه، مستقل از هر سیاستی) پایداری را می‌خورد.
	# حالا مدل تأمین اجتماعی واقعی (پرداخت-از-محل-جاری + بافر):
	#   تعهدات = بازنشستگان (واجدشدگی تابع سن بازنشستگی) × نسبت جایگزینی ۵۵٪ × درآمد سرانه؛
	#   منابع  = سهم‌برداری ۹٪ شاغلان + تکمیلی دولت از ردیف بودجهٔ «رفاه» (۵۰٪ ردیف)؛
	#   موجودی = بافر تعدیل. کسری پایدار ⇒ تأخیر مستمری ⇒ اعتراض سالمندان و فرسایش ثبات
	#   (شارژ خاموش بدهی نیست — هزینهٔ واقعی، اجتماعی است نه حسابداری).
	var pop_total_p: float = maxf(float(pop.get("total", 85_000_000)), 1.0)
	var elderly_sh: float = clampf(float(pop.get("age_structure", {}).get("سالمند", 0.10)), 0.03, 0.45)
	var children_sh: float = clampf(float(pop.get("age_structure", {}).get("کودک", 0.24)), 0.10, 0.50)
	var work_sh: float = clampf(1.0 - elderly_sh - children_sh, 0.30, 0.80)
	var pen_age: float = float(state.get("welfare_policy", {}).get("pension_age", 65))
	# سن پایین‌تر ⇒ دههٔ ۶۰-۶۴ (و پایین‌تر) هم واجد مستمری: +۱۲٪ مستحق به‌ازای هر سال
	var eligibility: float = clampf(1.0 + (65.0 - pen_age) * 0.12, 0.55, 1.6)
	welfare["retirees"] = pop_total_p * elderly_sh * eligibility
	var pc_month: float = float(econ.get("gdp", 1.0)) / pop_total_p / 12.0
	var obligations_m: float = welfare["retirees"] * pc_month * 0.55
	var contributions_m: float = pop_total_p * work_sh * pc_month * 0.09
	var topup_m: float = welfare_budget * 0.5  # سهم دولت از ردیف «رفاه» (نرخ ماهانه)
	welfare["pension_obligations_monthly"] = obligations_m
	welfare["pension_resources_monthly"] = contributions_m + topup_m
	welfare["pension_solvency"] = clampf((contributions_m + topup_m) / maxf(obligations_m, 1.0), 0.0, 2.0)
	# جریان هر اجرا: این سیستم هفتگی ۵ بار در ماه می‌دود ⇒ ۱/۵ نرخ ماهانه در هر اجرا
	var flow_w: float = (contributions_m + topup_m - obligations_m) * 0.2
	var bal_before: float = float(welfare["pension_fund_balance"])
	var bal_new: float = bal_before + flow_w + bal_before * 0.03 * (6.0 / 365.0)
	welfare["pension_fund_balance"] = maxf(bal_new, 0.0)
	if bal_new < 0.0:
		politics["stability"] = clampf(float(politics.get("stability", 0.6)) - 0.004, 0.05, 0.95)
		state["politics"] = politics
		var retirees_grp: Dictionary = state.get("media", {}).get("groups", {}).get("بازنشستگان", {})
		if not retirees_grp.is_empty():
			retirees_grp["approval"] = clampf(float(retirees_grp.get("approval", 52.0)) - 0.8, 5.0, 100.0)
		if bal_before > 0.0 or (tick - int(welfare.get("last_shortfall_tick", -9999))) >= 56:
			welfare["last_shortfall_tick"] = tick
			events.append({"type": "pension_shortfall", "message": "⚠️ صندوق بازنشستگی ناتوان شد: مستمری سالمندان با تأخیر پرداخت می‌شود — سن بازنشستگی یا ردیف بودجهٔ رفاه را بازبینی کنید", "shortfall": -bal_new})

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
