extends BaseSystem
# ۳.۳۷ کهنه‌سربازان (بازنشستگان نظامی) - پیاده‌سازی کامل

func compute(state: Dictionary, tick: int) -> Dictionary:
	var veterans = state.get("veterans", {})
	var military = state.get("military", {})
	var econ = state.get("economy", {})
	var health = state.get("health", {})
	var welfare = state.get("welfare", {})

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

	# تعداد کهنه‌سربازان - با بازنشستگی نظامی افزایش
	var retirement_rate = 0.05  # 5٪ نظامی‌ها در سال بازنشسته
	veterans["count"] += military.get("personnel",500000) * retirement_rate / 365.0 * 2.0  # ساده‌سازی
	veterans["count"] = max(veterans["count"] - veterans["count"] * 0.02 / 365.0, 10000.0)  # مرگ و میر

	# مستمری = f(بودجه، تعداد، اقتصاد)
	var pension_target = 0.6 + veterans_budget_share * 5.0 + (econ.get("gdp_per_capita",5000.0) / 10000.0) * 0.2
	veterans["pension"] = clamp(veterans["pension"] * 0.99 + pension_target * 0.01, 0.2, 0.95)

	# مراقبت سلامت
	var health_target = 0.6 + health.get("quality",0.6) * 0.2 + veterans_budget_share * 3.0
	veterans["health_care"] = clamp(veterans["health_care"] * 0.99 + health_target * 0.01, 0.2, 0.95)

	# اشتغال پس از خدمت
	var employment_target = 0.5 + (1.0 - econ.get("unemployment",0.08)) * 0.3 + welfare.get("social_safety",0.6) * 0.1
	veterans["employment"] = clamp(veterans["employment"] * 0.99 + employment_target * 0.01, 0.1, 0.90)

	# مسکن
	veterans["housing"] = clamp(veterans["housing"] + (veterans_budget_share - 0.03) * 0.002, 0.2, 0.90)

	# سلامت روان - PTSD
	var mental_target = 0.5 + veterans["health_care"] * 0.2 + veterans["employment"] * 0.15 + veterans["recognition"] * 0.15 - 0.1  # اثر جنگ
	veterans["mental_health"] = clamp(veterans["mental_health"] * 0.99 + mental_target * 0.01, 0.2, 0.90)

	# قدردانی و تکریم
	veterans["recognition"] = clamp(veterans["recognition"] + (state.get("culture",{}).get("cohesion",0.65) - 0.5) * 0.001, 0.3, 0.95)

	# صندوق
	var fund_income = veterans_budget * 0.5
	var fund_cost = veterans["count"] * 2000.0  # مستمری هر نفر
	veterans["fund_balance"] += (fund_income - fund_cost) / 365.0
	veterans["fund_balance"] = max(veterans["fund_balance"], 0.0)

	# حلقه بازخورد: حمایت از کهنه‌سربازان → روحیه ارتش → قدرت
	military["readiness"] = military.get("readiness",0.70) + (veterans["recognition"] - 0.5) * 0.0005
	state["military"] = military

	# رویدادها
	if veterans["pension"] < 0.4 and Deterministic.chance(0.012):
		events.append({"type": "veteran_pension_crisis", "message": "بحران مستمری کهنه‌سربازان - اعتراض و نارضایتی", "pension": veterans["pension"]})

	if veterans["mental_health"] < 0.4 and Deterministic.chance(0.01):
		events.append({"type": "veteran_mental_health_crisis", "message": "بحران سلامت روان کهنه‌سربازان - نیاز به مراقبت ویژه"})

	if veterans["fund_balance"] < 100_000_000.0 and Deterministic.chance(0.01):
		events.append({"type": "veteran_fund_crisis", "message": "بحران صندوق کهنه‌سربازان - ناترازی مالی"})

	if veterans["recognition"] > 0.8 and Deterministic.chance(0.008):
		events.append({"type": "veteran_recognition", "message": "تکریم کهنه‌سربازان - مراسم قدردانی و افزایش روحیه ملی"})

	if Deterministic.chance(0.006):
		events.append({"type": "veteran_employment_program", "message": "برنامه اشتغال‌زایی برای کهنه‌سربازان - موفقیت"})

	state["veterans"] = veterans
	return {"success": true, "state": state, "events": events}
