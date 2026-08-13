extends BaseSystem
# ۳.۳۸ خانواده، زنان، کودکان و سالمندان - پیاده‌سازی کامل

func compute(state: Dictionary, tick: int) -> Dictionary:
	var family = state.get("family", {})
	var pop = state.get("population", {})
	var econ = state.get("economy", {})
	var health = state.get("health", {})
	var education = state.get("education", {})
	var welfare = state.get("welfare", {})
	var culture = state.get("culture", {})

	family["marriage_rate"] = family.get("marriage_rate", 0.007)
	family["divorce_rate"] = family.get("divorce_rate", 0.002)
	family["fertility"] = family.get("fertility", 1.8)
	family["child_welfare"] = family.get("child_welfare", 0.65)
	family["gender_equality"] = family.get("gender_equality", 0.55)
	family["child_care_coverage"] = family.get("child_care_coverage", 0.40)
	family["elder_care_coverage"] = family.get("elder_care_coverage", 0.50)
	family["domestic_violence"] = family.get("domestic_violence", 0.15)
	family["family_support_budget"] = family.get("family_support_budget", 0.02)
	family["parental_leave"] = family.get("parental_leave", 0.50)

	var events = []

	var family_budget_share = econ.get("budget_allocations",{}).get("رفاه",0.15) * 0.3
	var family_budget = econ.get("government_spending",0.0) * family_budget_share
	family["family_support_budget"] = family_budget_share

	# نرخ ازدواج = f(اقتصاد، فرهنگ، سن، مسکن)
	var marriage_target = 0.007 + (econ.get("gdp_per_capita",5000.0) / 10000.0 - 0.5) * 0.001 + culture.get("cohesion",0.65) * 0.001 - state.get("housing",{}).get("shortage",0.3) * 0.001 if state.has("housing") else 0.007
	family["marriage_rate"] = clamp(family["marriage_rate"] * 0.995 + marriage_target * 0.005, 0.002, 0.015)

	# طلاق = f(فشار اقتصادی، نارضایتی، فرهنگ، حمایت)
	var divorce_target = 0.002 + (1.0 - pop.get("happiness",0.6)) * 0.002 + econ.get("unemployment",0.08) * 0.005 - family_budget_share * 0.01
	family["divorce_rate"] = clamp(family["divorce_rate"] * 0.99 + divorce_target * 0.01, 0.0005, 0.010)

	# باروری = f(رفاه، حمایت خانواده، برابری، مرخصی، اقتصاد)
	var fertility_target = 1.8 + family["child_care_coverage"] * 0.5 + family["parental_leave"] * 0.3 + welfare.get("social_safety",0.6) * 0.2 + (1.0 - econ.get("unemployment",0.08)) * 0.3 - education.get("higher_coverage",0.3) * 0.2
	family["fertility"] = clamp(family["fertility"] * 0.998 + fertility_target * 0.002, 0.8, 4.5)

	# برابری جنسیتی
	var equality_target = 0.5 + education.get("literacy",0.85) * 0.1 + education.get("higher_coverage",0.3) * 0.2 + family["parental_leave"] * 0.1 + culture.get("media_freedom",0.5) * 0.05
	family["gender_equality"] = clamp(family["gender_equality"] * 0.999 + equality_target * 0.001, 0.2, 0.95)

	# مراقبت کودک
	family["child_care_coverage"] = clamp(family["child_care_coverage"] + (family_budget_share - 0.03) * 0.002, 0.1, 0.85)

	# مراقبت سالمند
	var elderly_share = pop.get("age_structure",{}).get("سالمند",0.10)
	family["elder_care_coverage"] = clamp(family["elder_care_coverage"] + (elderly_share - 0.10) * 0.002 + family_budget_share * 0.001, 0.2, 0.90)

	# رفاه کودک
	var child_welfare_target = 0.6 + family["child_care_coverage"] * 0.2 + health.get("quality",0.6) * 0.15 + education.get("primary_coverage",0.95) * 0.1 - family["domestic_violence"] * 0.3
	family["child_welfare"] = clamp(family["child_welfare"] * 0.99 + child_welfare_target * 0.01, 0.2, 0.95)

	# خشونت خانگی
	var violence_target = 0.15 - family["gender_equality"] * 0.1 - education.get("quality",0.55) * 0.05 - welfare.get("social_safety",0.6) * 0.05 + (1.0 - pop.get("happiness",0.6)) * 0.05
	family["domestic_violence"] = clamp(family["domestic_violence"] * 0.99 + violence_target * 0.01, 0.02, 0.50)

	# مرخصی زایمان/والدین
	family["parental_leave"] = clamp(family["parental_leave"] + (family_budget_share - 0.04) * 0.002, 0.1, 0.95)

	# اثر باروری بر جمعیت - در سیستم جمعیت اعمال می‌شود اما اینجا سیگنال
	if tick % 365 == 0:
		# هر سال باروری روی نرخ تولد اثر می‌گذارد
		pop["birth_rate"] = pop.get("birth_rate",15.0) * 0.9 + family["fertility"] * 5.0 * 0.1
		state["population"] = pop

	# حلقه: حمایت خانواده → باروری → جمعیت → بودجه
	pop["happiness"] = clamp(pop.get("happiness",0.6) + (family["child_welfare"] - 0.5) * 0.0005 + (family["gender_equality"] - 0.5) * 0.0003, 0.05, 0.95)
	state["population"] = pop

	# رویدادها
	if family["fertility"] < 1.5 and Deterministic.chance(0.01):
		events.append({"type": "low_fertility_crisis", "message": "بحران کاهش باروری - پیری جمعیت و کاهش نیروی کار", "fertility": family["fertility"]})

	if family["domestic_violence"] > 0.25 and Deterministic.chance(0.012):
		events.append({"type": "domestic_violence_crisis", "message": "بحران خشونت خانگی - نیاز به مداخله و حمایت", "violence": family["domestic_violence"]})

	if family["divorce_rate"] > 0.006 and Deterministic.chance(0.01):
		events.append({"type": "divorce_wave", "message": "موج طلاق - فروپاشی خانواده‌ها", "divorce_rate": family["divorce_rate"]})

	if family["child_welfare"] > 0.8 and Deterministic.chance(0.008):
		events.append({"type": "child_welfare_success", "message": "موفقیت رفاه کودکان - کاهش فقر کودک"})

	if family["gender_equality"] > 0.7 and Deterministic.chance(0.006):
		events.append({"type": "gender_equality_progress", "message": "پیشرفت برابری جنسیتی - افزایش مشارکت زنان"})

	state["family"] = family
	
	# ── لایه واقع‌گرایانه اختصاصی خانواده (جایگزین قالب خودکار) — بخش ۳.۳۸ ──
	# اندازه خانوار: باروری بزرگ‌کننده، شهرنشینی کوچک‌کننده — سیستم خانوارها آن را می‌خواند
	var urban = float(pop.get("urbanization", 0.74))
	family["avg_household_size"] = clampf(2.6 + float(family.get("fertility", 1.8)) * 0.5 - urban * 0.8, 2.0, 5.5)
	# سهم خانوارهای تک‌والد: طلاق افزایش‌دهنده، ازدواج کاهش‌دهنده — با اینرسی اجتماعی
	var single_target = 0.06 + float(family.get("divorce_rate", 0.002)) * 18.0 - float(family.get("marriage_rate", 0.007)) * 2.0
	family["single_parent_share"] = clampf(float(family.get("single_parent_share", 0.10)) * 0.995 + single_target * 0.005, 0.03, 0.35)
	# مشارکت اقتصادی زنان: برابری جنسیتی + مهدهای کودک (مراقبت کودک موانع اشتغال مادران را کم می‌کند)
	family["female_workforce"] = clampf(0.20 + float(family.get("gender_equality", 0.55)) * 0.45 + float(family.get("child_care_coverage", 0.40)) * 0.20, 0.10, 0.62)
	# فشار سالمندی بر خانوار: وقتی سهم سالمندان بالا و پوشش مراقبت پایین است
	var elderly_now = float(pop.get("age_structure", {}).get("سالمند", 0.10))
	if elderly_now > 0.16 and float(family.get("elder_care_coverage", 0.50)) < 0.40 and Deterministic.chance(0.005):
		events.append({"type": "elder_care_strain", "message": "فشار مراقبت از سالمندان بر دوش خانوارها - پوشش خدمات سالمندی ناکافی"})
	if float(family.get("fertility", 1.8)) < 1.6 and Deterministic.chance(0.004):
		events.append({"type": "fertility_crisis_family", "message": "نرخ باروری زیر سطح جانشینی - هشدار جدی آینده جمعیتی", "fertility": family["fertility"]})
	if float(family.get("domestic_violence", 0.15)) > 0.30 and Deterministic.chance(0.004):
		events.append({"type": "domestic_violence_crisis", "message": "افزایش نگران‌کننده خشونت خانگی - نیاز به مداخله حمایتی فوری"})
	state["family"] = family

	return {"success": true, "state": state, "events": events}
