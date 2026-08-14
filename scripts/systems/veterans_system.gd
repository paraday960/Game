extends BaseSystem
# ۳.۳۷ کهنه‌سربازان (بازنشستگان نظامی) - پیاده‌سازی کامل

func compute(state: Dictionary, tick: int) -> Dictionary:
	var veterans = state.get("veterans", {})
	var military = state.get("military", {})
	var econ = state.get("economy", {})
	var health = state.get("health", {})

	veterans["count"] = veterans.get("count", 500000)
	veterans["pension"] = veterans.get("pension", 0.70)
	veterans["health_care"] = veterans.get("health_care", 0.65)
	veterans["employment"] = veterans.get("employment", 0.60)
	veterans["housing"] = veterans.get("housing", 0.60)
	veterans["mental_health"] = veterans.get("mental_health", 0.55)
	veterans["recognition"] = veterans.get("recognition", 0.70)
	veterans["fund_balance"] = veterans.get("fund_balance", 500_000_000.0)

	var events = []

	var veterans_budget_share = econ.get("budget_allocations",{}).get("رفاه",0.15) * 0.15 + econ.get("budget_allocations",{}).get("ارتش",0.08) * 0.1
	var veterans_budget = econ.get("government_spending",0.0) * veterans_budget_share

	# شمار کهنه‌سربازان (بازرسی ۱۴۰۵ — دور دوازدهم): تک‌مالک شد. قبلاً دو مدل
	# دونویسنده بودند: این سیستم با واحد شکسته (+۲٫۷k/ماه) و مدیر ماهانه با
	# دریفت موازی (در صلح ×۰٫۹۹۵/ماه ⇒ ظرف ~۱۵ سال به کف ۲۰k فرو می‌رفت!). حالا
	# جریان واقعی: ورودی = بازنشستگی ۵٪/سال پرسنل نظامی (+ جانبازان تازه در جنگ)؛
	# خروجی = مرگ‌ومیر ۲٫۵٪/سال (گروه سنی بالا). سیستم ماهانه ۲ بار ⇒ نیم‌ماه در هر اجرا.
	var personnel_v: float = float(military.get("personnel", 500000.0))
	var at_war_v: bool = not state.get("world", {}).get("wars", {}).is_empty()
	var v_inflow: float = personnel_v * 0.05 / 12.0 * 0.5
	if at_war_v:
		v_inflow += (personnel_v * 0.004 + 3000.0) / 12.0 * 0.5
	var v_death: float = float(veterans["count"]) * 0.025 / 12.0 * 0.5
	veterans["count"] = maxf(float(veterans["count"]) + v_inflow - v_death, 20000.0)

	# مستمری کهنه‌سربازان: مالک = veterans_manager (سیاست بازیکن، pension_level)؛
	# مدل EM موازیِ این فایل (که هر ماه بازنویسی می‌شد) حذف شد — دور دوازدهم.
	# مراقبت سلامت
	var health_target = 0.6 + health.get("quality",0.6) * 0.2 + veterans_budget_share * 3.0
	veterans["health_care"] = clamp(veterans["health_care"] * 0.99 + health_target * 0.01, 0.2, 0.95)

	# اشتغال پس از خدمت: مالک = veterans_manager (ترکیب با employment_program)؛
	# مدل EM موازیِ این فایل حذف شد — دور دوازدهم.

	# مسکن
	veterans["housing"] = clamp(veterans["housing"] + (veterans_budget_share - 0.03) * 0.002, 0.2, 0.90)

	# سلامت روان - PTSD
	var mental_target = 0.5 + veterans["health_care"] * 0.2 + veterans["employment"] * 0.15 + veterans["recognition"] * 0.15 - 0.1  # اثر جنگ
	veterans["mental_health"] = clamp(veterans["mental_health"] * 0.99 + mental_target * 0.01, 0.2, 0.90)

	# قدردانی و تکریم
	veterans["recognition"] = clamp(veterans["recognition"] + (state.get("culture",{}).get("cohesion",0.65) - 0.5) * 0.001, 0.3, 0.95)

	# صندوق کهنه‌سربازان واقعی (بازرسی ۱۴۰۵ — دور دوازدهم): قبلاً واحدسازی مخلوط
	# بود — ورودی نرخ «ماهانهٔ» بودجه، خروجی count × ۲۰۰۰ با مقیاس نامعلوم و تسویهٔ
	# /۳۶۵ در اجرای ماهانه ⇒ موجودی یا انفجار می‌کرد یا می‌مرد. حالا مثل صندوق
	# بازنشستگی (دور دهم): تعهدات = شمار × مستمری سرانه (تابع سطح سیاست و GDP
	# سرانه)؛ منابع = جریان قانونی واقعی که خزانه پرداخت می‌کند (کانال policy_costs
	# مدیر ~ یگانه مسیر پول)؛ موجودی = بافر. ناتوانی ⇒ فرسایش تکریم/روحیه + رویداد
	# قطعی با کول‌داون (شارژ خاموش بدهی نیست؛ بحرانِ قدیمیِ شانسی ۱٪ حذف شد).
	var pension_level_v: float = float(state.get("veterans_policy", {}).get("pension_level", 0.5))
	var pc_month_v: float = float(econ.get("gdp_per_capita", 5000.0)) / 12.0
	var obligations_mv: float = float(veterans["count"]) * pc_month_v * (0.20 + 0.30 * pension_level_v)
	var resources_mv: float = float(econ.get("policy_costs", {}).get("مستمری و خدمات کهنه‌سربازان", veterans_budget * 0.5))
	veterans["obligations_monthly"] = obligations_mv
	veterans["resources_monthly"] = resources_mv
	veterans["fund_solvency"] = clampf(resources_mv / maxf(obligations_mv, 1.0), 0.0, 2.0)
	var bal_before_v: float = float(veterans["fund_balance"])
	var bal_new_v: float = bal_before_v + (resources_mv - obligations_mv) * 0.5
	veterans["fund_balance"] = maxf(bal_new_v, 0.0)
	if bal_new_v < 0.0:
		veterans["recognition"] = maxf(float(veterans["recognition"]) - 0.01, 0.3)
		military["readiness"] = float(military.get("readiness", 0.70)) - 0.001
		if bal_before_v > 0.0 or (tick - int(veterans.get("last_fund_crisis", -9999))) >= 56:
			veterans["last_fund_crisis"] = tick
			events.append({"type": "veteran_fund_crisis", "message": "⚠️ صندوق کهنه‌سربازان ناتوان شد: مستمری ایثارگران با تأخیر پرداخت می‌شود — مستمری/اشتغال یا بودجهٔ بنیاد را بازبینی کنید", "shortfall": -bal_new_v})

	# حلقه بازخورد: حمایت از کهنه‌سربازان → روحیه ارتش → قدرت
	military["readiness"] = military.get("readiness",0.70) + (veterans["recognition"] - 0.5) * 0.0005
	state["military"] = military

	# رویدادها
	if veterans["pension"] < 0.4 and Deterministic.chance(0.012):
		events.append({"type": "veteran_pension_crisis", "message": "بحران مستمری کهنه‌سربازان - اعتراض و نارضایتی", "pension": veterans["pension"]})

	if veterans["mental_health"] < 0.4 and Deterministic.chance(0.01):
		events.append({"type": "veteran_mental_health_crisis", "message": "بحران سلامت روان کهنه‌سربازان - نیاز به مراقبت ویژه"})

	if veterans["recognition"] > 0.8 and Deterministic.chance(0.008):
		events.append({"type": "veteran_recognition", "message": "تکریم کهنه‌سربازان - مراسم قدردانی و افزایش روحیه ملی"})

	if Deterministic.chance(0.006):
		events.append({"type": "veteran_employment_program", "message": "برنامه اشتغال‌زایی برای کهنه‌سربازان - موفقیت"})

	state["veterans"] = veterans
	
	# ── لایه واقع‌گرایانه اختصاصی کهنه‌سربازان (جایگزین قالب خودکار) — بخش ۳.۳۷ ──
	# بحران صندوق: مانده منفی → فشار بر مستمری و اعتراض کهنه‌سربازان
	if float(veterans.get("fund_balance", 500_000_000.0)) < 0.0:
		veterans["pension"] = clampf(float(veterans.get("pension", 0.70)) - 0.0015, 0.15, 0.95)
		if Deterministic.chance(0.008):
			events.append({"type": "veterans_fund_deficit", "message": "کسری صندوق کهنه‌سربازان - تأخیر در پرداخت مستمری‌ها"})
	# جنگ: موج تازه جانبازان و آسیب روانی — جمعیت کهنه‌سربازان در جنگ رشد شتابان می‌گیرد
	var wars_v = state.get("world", {}).get("wars", {})
	if not wars_v.is_empty():
		veterans["count"] = float(veterans.get("count", 500000)) + 350.0
		veterans["mental_health"] = clampf(float(veterans.get("mental_health", 0.55)) - 0.001, 0.15, 0.90)
		if Deterministic.chance(0.006):
			events.append({"type": "war_veterans_influx", "message": "افزایش شمار جانبازان جنگ - فشار مضاعف بر خدمات کهنه‌سربازان"})
	# جاذبه خدمت نظامی برای نسل جوان: تابع تکریم، مستمری و اشتغال کهنه‌سربازان
	veterans["service_appeal"] = clampf(float(veterans.get("recognition", 0.70)) * 0.5 + float(veterans.get("pension", 0.70)) * 0.3 + float(veterans.get("employment", 0.60)) * 0.2, 0.05, 0.95)
	if float(veterans.get("employment", 0.60)) < 0.35 and Deterministic.chance(0.005):
		events.append({"type": "veteran_unemployment", "message": "بیکاری گسترده کهنه‌سربازان - وعده‌های اشتغال محقق نشده است"})
	if float(veterans.get("mental_health", 0.55)) < 0.35 and Deterministic.chance(0.004):
		events.append({"type": "veteran_mental_crisis", "message": "بحران سلامت روان کهنه‌سربازان - نیاز فوری به حمایت روان‌پزشکی"})
	state["veterans"] = veterans

	return {"success": true, "state": state, "events": events}
