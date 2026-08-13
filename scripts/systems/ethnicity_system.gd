extends BaseSystem
# ۳.۳۱ قومیت، مذهب، زبان‌ها و تنش هویتی - پیاده‌سازی کامل

func compute(state: Dictionary, tick: int) -> Dictionary:
	var ethnicity = state.get("ethnicity", {})
	var pop = state.get("population", {})
	var politics = state.get("politics", {})
	var culture = state.get("culture", {})
	var education = state.get("education", {})
	var welfare = state.get("welfare", {})
	var security = state.get("security", {})

	ethnicity["diversity"] = ethnicity.get("diversity", 0.60)
	ethnicity["tension"] = ethnicity.get("tension", 0.30)
	ethnicity["tolerance"] = ethnicity.get("tolerance", 0.60)
	ethnicity["integration"] = ethnicity.get("integration", 0.55)
	ethnicity["language_diversity"] = ethnicity.get("language_diversity", 0.50)
	ethnicity["religious_diversity"] = ethnicity.get("religious_diversity", 0.60)
	ethnicity["cultural_rights"] = ethnicity.get("cultural_rights", 0.60)
	ethnicity["discrimination"] = ethnicity.get("discrimination", 0.20)
	ethnicity["groups"] = ethnicity.get("groups", [
		{"name": "فارس", "share": 0.61, "happiness": 0.62},
		{"name": "آذری", "share": 0.16, "happiness": 0.60},
		{"name": "کرد", "share": 0.10, "happiness": 0.55},
		{"name": "لر", "share": 0.06, "happiness": 0.58},
		{"name": "بلوچ", "share": 0.02, "happiness": 0.50},
		{"name": "عرب", "share": 0.02, "happiness": 0.52},
		{"name": "سایر", "share": 0.03, "happiness": 0.60}
	])

	var events = []

	# فرمول‌ها
	# تنش هویتی = f(نابرابری، تبعیض، ادغام کم، تحریک سیاسی، آموزش کم)
	var inequality = welfare.get("gini",0.38) if welfare else 0.38
	var discrimination = ethnicity["discrimination"]
	var integration = ethnicity["integration"]
	var edu_q = education.get("quality",0.55)
	var political_tension = politics.get("tension",0.35)

	var tension = 0.2 + inequality * 0.3 + discrimination * 0.4 + (1.0 - integration) * 0.3 + political_tension * 0.2 - edu_q * 0.1
	tension = clamp(tension, 0.0, 0.95)
	ethnicity["tension"] = ethnicity["tension"] * 0.98 + tension * 0.02

	# تحمل = f(آموزش، فرهنگ، ادغام، حقوق فرهنگی)
	var tolerance = 0.5 + edu_q * 0.2 + culture.get("cohesion",0.65) * 0.2 + ethnicity["cultural_rights"] * 0.2 - discrimination * 0.3
	ethnicity["tolerance"] = clamp(ethnicity["tolerance"] * 0.99 + tolerance * 0.01, 0.1, 0.95)

	# ادغام = f(تحمل، آموزش، عدالت، حقوق)
	var integration_target = 0.5 + ethnicity["tolerance"] * 0.3 + edu_q * 0.2 + (1.0 - inequality) * 0.1 + ethnicity["cultural_rights"] * 0.2
	ethnicity["integration"] = clamp(ethnicity["integration"] * 0.995 + integration_target * 0.005, 0.1, 0.95)

	# حقوق فرهنگی
	var rights_target = 0.6 + politics.get("legitimacy",0.58) * 0.1 + culture.get("media_freedom",0.5) * 0.1
	ethnicity["cultural_rights"] = clamp(ethnicity["cultural_rights"] * 0.99 + rights_target * 0.01, 0.1, 0.95)

	# تبعیض - کاهش با آموزش و حقوق
	var discrimination_target = 0.3 - edu_q * 0.2 - ethnicity["cultural_rights"] * 0.2 - ethnicity["tolerance"] * 0.2 + inequality * 0.1
	ethnicity["discrimination"] = clamp(ethnicity["discrimination"] * 0.99 + discrimination_target * 0.01, 0.0, 0.85)

	# تنوع زبانی و مذهبی تقریباً ثابت اما با ادغام کمی تغییر
	ethnicity["language_diversity"] = clamp(ethnicity["language_diversity"] + Deterministic.next_range(-0.001, 0.001), 0.2, 0.85)
	ethnicity["religious_diversity"] = clamp(ethnicity["religious_diversity"] + Deterministic.next_range(-0.001, 0.001), 0.2, 0.90)

	# رضایت گروه‌ها
	for group in ethnicity["groups"]:
		var group_happiness = pop.get("happiness",0.6) + (ethnicity["cultural_rights"] - 0.5) * 0.2 - ethnicity["discrimination"] * 0.3 - ethnicity["tension"] * 0.2
		# اقلیت‌های کوچک حساس‌تر
		if group["share"] < 0.05:
			group_happiness -= ethnicity["discrimination"] * 0.1
		group["happiness"] = clamp(group_happiness, 0.1, 0.95)

	# تنوع کلی
	ethnicity["diversity"] = clamp(ethnicity["language_diversity"] * 0.4 + ethnicity["religious_diversity"] * 0.4 + 0.2, 0.1, 0.90)

	# حلقه بازخورد: تنش هویتی → بی‌ثباتی؛ ادغام خوب → انسجام
	politics["stability"] = clamp(politics.get("stability",0.6) - ethnicity["tension"] * 0.001 + ethnicity["integration"] * 0.0005, 0.05, 0.95)
	culture["cohesion"] = clamp(culture.get("cohesion",0.65) + ethnicity["integration"] * 0.001 - ethnicity["tension"] * 0.0015, 0.1, 0.95)
	state["politics"] = politics
	state["culture"] = culture

	# اگر تنش خیلی بالا، امنیت کاهش
	if ethnicity["tension"] > 0.6:
		security["public_security"] = clamp(security.get("public_security",0.70) - 0.001, 0.05, 0.95)
		state["security"] = security

	# رویدادها
	if ethnicity["tension"] > 0.6 and Deterministic.chance(0.015):
		events.append({"type": "ethnic_tension_crisis", "message": "بحران تنش قومی و مذهبی - اعتراضات هویتی", "tension": ethnicity["tension"]})
		politics["tension"] += 0.05
		state["politics"] = politics

	if ethnicity["discrimination"] > 0.5 and Deterministic.chance(0.01):
		events.append({"type": "discrimination_exposed", "message": "افشای تبعیض علیه اقلیت‌ها - کاهش اعتماد", "discrimination": ethnicity["discrimination"]})

	if ethnicity["integration"] > 0.7 and Deterministic.chance(0.008):
		events.append({"type": "integration_success", "message": "موفقیت سیاست‌های ادغام - افزایش انسجام ملی", "integration": ethnicity["integration"]})
		culture["cohesion"] += 0.02
		state["culture"] = culture

	if ethnicity["cultural_rights"] > 0.7 and Deterministic.chance(0.006):
		events.append({"type": "cultural_festival_ethnic", "message": "جشنواره فرهنگ اقوام - تقویت هویت ملی"})

	state["ethnicity"] = ethnicity
	
		# ── لایه واقع‌گرایانه اختصاصی قومیت و هویت (جایگزین قالب خودکار) — بخش ۳.۳۱ ──
	# شادی گروه‌های قومی: تابع تحمل و حقوق فرهنگی و تبعیض — نه مقدار ثابت؛ گروه اکثریت ملاک اقلیت نیست
	var group_target = 0.40 + float(ethnicity.get("tolerance", 0.60)) * 0.25 + float(ethnicity.get("cultural_rights", 0.60)) * 0.25 - float(ethnicity.get("discrimination", 0.20)) * 0.35
	var minority_happiness = 0.0
	var minority_count = 0
	for g in ethnicity.get("groups", []):
		g["happiness"] = clampf(float(g.get("happiness", 0.60)) + (group_target - float(g.get("happiness", 0.60))) * 0.01, 0.15, 0.95)
		if float(g.get("share", 0.0)) < 0.5:
			minority_happiness += float(g["happiness"])
			minority_count += 1
	if minority_count > 0:
		minority_happiness /= float(minority_count)
		# بازخورد خودتقویه‌شونده: نارضایتی مزمن اقلیت‌ها تنش هویتی را تشدید می‌کند
		ethnicity["tension"] = clampf(float(ethnicity.get("tension", 0.30)) + (0.55 - minority_happiness) * 0.004, 0.05, 0.97)
	# ترکیب تنش × ناتحملی × تنوع → ریسک ناآرامی قومی که سیستم امنیت می‌تواند بخواند
	security["ethnic_unrest_risk"] = clampf(float(ethnicity.get("tension", 0.30)) * (1.0 - float(ethnicity.get("tolerance", 0.60))) * float(ethnicity.get("diversity", 0.60)), 0.0, 0.90)
	state["security"] = security
	if float(ethnicity.get("tension", 0.30)) > 0.70 and Deterministic.chance(0.006):
		events.append({"type": "ethnic_unrest_warning", "message": "هشدار: تنش هویتی در مناطق قوم‌نشین در حال اوج‌گیری است", "tension": ethnicity["tension"]})
	if float(ethnicity.get("discrimination", 0.20)) > 0.50 and Deterministic.chance(0.004):
		events.append({"type": "discrimination_report", "message": "گزارش نهادهای مدنی: تبعیض سیستماتیک علیه شهروندان اقلیت", "disc": ethnicity["discrimination"]})
	if float(ethnicity.get("integration", 0.55)) > 0.70 and Deterministic.chance(0.005):
		events.append({"type": "integration_success", "message": "موفقیت سیاست‌های ادغام ملی - کاهش محسوس شکاف هویتی"})
	state["ethnicity"] = ethnicity

	return {"success": true, "state": state, "events": events}
