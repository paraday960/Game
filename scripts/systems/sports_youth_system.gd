extends BaseSystem
# ۳.۳۶ ورزش و جوانان - پیاده‌سازی کامل

func compute(state: Dictionary, tick: int) -> Dictionary:
	var sports = state.get("sports_youth", {})
	var pop = state.get("population", {})
	var health = state.get("health", {})
	var education = state.get("education", {})
	var econ = state.get("economy", {})

	sports["participation"] = sports.get("participation", 0.40)
	sports["facilities"] = sports.get("facilities", 0.50)
	sports["youth_unemployment"] = sports.get("youth_unemployment", 0.15)
	sports["youth_happiness"] = sports.get("youth_happiness", 0.60)
	sports["sports_achievements"] = sports.get("sports_achievements", 50.0)
	sports["clubs"] = sports.get("clubs", 1200)
	sports["civil_society"] = sports.get("civil_society", 0.55)
	sports["volunteering"] = sports.get("volunteering", 0.30)
	sports["olympic_medals"] = sports.get("olympic_medals", 5)

	var events = []

	var sports_budget_share = econ.get("budget_allocations", {}).get("رفاه",0.15) * 0.15
	var sports_budget = econ.get("government_spending",0.0) * sports_budget_share

	# مشارکت ورزش = f(امکانات، درآمد، زمان، فرهنگ)
	var facilities = sports["facilities"]
	var income = econ.get("gdp_per_capita",5000.0) / 5000.0
	var youth_share = pop.get("age_structure",{}).get("جوان",0.35)
	var participation_target = 0.3 + facilities * 0.3 + income * 0.1 + youth_share * 0.2 + education.get("quality",0.55) * 0.1
	sports["participation"] = clamp(sports["participation"] * 0.99 + participation_target * 0.01, 0.05, 0.85)

	# امکانات
	sports["facilities"] = clamp(sports["facilities"] + (sports_budget_share - 0.02) * 0.002, 0.1, 0.95)

	# بیکاری جوانان
	var general_unemployment = econ.get("unemployment",0.08)
	sports["youth_unemployment"] = clamp(general_unemployment * 1.8 + (1.0 - sports["participation"]) * 0.05, 0.05, 0.50)

	# شادی جوانان
	var youth_happiness = 0.5 + sports["participation"] * 0.2 + (1.0 - sports["youth_unemployment"]) * 0.3 + pop.get("happiness",0.6) * 0.2
	sports["youth_happiness"] = clamp(sports["youth_happiness"] * 0.98 + youth_happiness * 0.02, 0.1, 0.95)

	# دستاورد ورزشی = f(مشارکت، امکانات، بودجه، استعداد)
	var achievements = 40.0 + sports["participation"] * 30.0 + sports["facilities"] * 20.0 + sports_budget / 1_000_000_000.0 * 5.0
	sports["sports_achievements"] = sports["sports_achievements"] * 0.995 + achievements * 0.005

	# باشگاه‌ها
	if sports["participation"] > 0.5 and Deterministic.chance(0.005):
		sports["clubs"] += 2

	# جامعه مدنی و تشکل‌های جوانان
	var civil = 0.5 + sports["participation"] * 0.2 + education.get("quality",0.55) * 0.2 + state.get("culture",{}).get("media_freedom",0.5) * 0.1
	sports["civil_society"] = clamp(sports["civil_society"] * 0.99 + civil * 0.01, 0.1, 0.95)

	# داوطلبی
	sports["volunteering"] = clamp(sports["volunteering"] + (sports["civil_society"] - 0.5) * 0.001, 0.05, 0.80)

	# مدال المپیک ساده
	sports["olympic_medals"] = int(sports["sports_achievements"] / 20.0)

	# اثر بر سلامت و رضایت
	health["population_health"] = clamp(health.get("population_health",0.6) + sports["participation"] * 0.0005, 0.1, 0.95)
	state["health"] = health

	pop["happiness"] = clamp(pop.get("happiness",0.6) + sports["youth_happiness"] * 0.0003, 0.05, 0.95)
	state["population"] = pop

	# حلقه: ورزش → سلامت و هویت؛ بیکاری جوانان → نارضایتی
	if sports["youth_unemployment"] > 0.25:
		state["politics"]["tension"] = clamp(state.get("politics",{}).get("tension",0.35) + 0.0005, 0.0, 1.0)

	# رویدادها
	if sports["youth_unemployment"] > 0.30 and Deterministic.chance(0.012):
		events.append({"type": "youth_unemployment_crisis", "message": "بحران بیکاری جوانان - اعتراض نسل جوان", "rate": sports["youth_unemployment"]})

	if sports["sports_achievements"] > 80.0 and Deterministic.chance(0.01):
		events.append({"type": "sports_victory", "message": "پیروزی ورزشی بزرگ - قهرمانی و غرور ملی! مدال المپیک", "medals": sports["olympic_medals"]})
		pop["happiness"] += 0.02
		state["population"] = pop

	if sports["civil_society"] < 0.3 and Deterministic.chance(0.01):
		events.append({"type": "youth_apathy", "message": "بی‌تفاوتی جوانان و کاهش مشارکت اجتماعی"})

	if Deterministic.chance(0.008):
		events.append({"type": "youth_festival", "message": "جشنواره جوانان - افزایش مشارکت و نشاط"})

	state["sports_youth"] = sports
	
		# ── لایه واقع‌گرایانه اختصاصی ورزش و جوانان (جایگزین قالب خودکار) — بخش ۳.۳۶ ──
	# چرخه المپیک هر ۴ سال: مدال‌ها تابع بستر مشارکت و امکانات هستند، نه تصادف محض
	if tick > 0 and tick % (365 * 4) == 0 and float(sports.get("participation", 0.40)) > 0.30:
		var medals = maxi(int(float(sports.get("participation", 0.40)) * float(sports.get("facilities", 0.50)) * 20.0), 1)
		sports["olympic_medals"] = medals
		sports["sports_achievements"] = float(sports.get("sports_achievements", 50.0)) + medals * 2.0
		events.append({"type": "olympics_result", "message": "بازگشت کاروان المپیک: %d مدال - افتخار ملی و شادی عمومی" % medals, "medals": medals})
	# باشگاه‌ها با بودجه امکانات رشد و در محرومیت تحلیل می‌روند
	sports["clubs"] = maxi(int(float(sports.get("clubs", 1200)) * (1.0 + (float(sports.get("facilities", 0.50)) - 0.45) * 0.001)), 200)
	# داوطلبینی و جامعه مدنی: اعتماد عمومی و شادی جوانان خوراک آن است
	var civil_target = 0.35 + float(state.get("politics", {}).get("trust", 0.55)) * 0.3 + float(sports.get("youth_happiness", 0.60)) * 0.25
	sports["civil_society"] = clampf(float(sports.get("civil_society", 0.55)) * 0.998 + civil_target * 0.002, 0.10, 0.92)
	sports["volunteering"] = clampf(float(sports.get("volunteering", 0.30)) * 0.998 + (float(sports.get("civil_society", 0.55)) * 0.5) * 0.002, 0.05, 0.85)
	# بیکاری شدید جوانان → موج خروج نیروی جوان (رانش مهاجرتی)
	if float(sports.get("youth_unemployment", 0.15)) > 0.28 and Deterministic.chance(0.006):
		events.append({"type": "youth_exodus", "message": "موج مهاجرت جوانان بیکار - از دست رفتن سرمایه انسانی آینده", "rate": sports["youth_unemployment"]})
	# ورزش همگانی → بهبود شاخص تناسب جمعیت که بهداشت می‌تواند بخواند
	health["lifestyle_fitness"] = clampf(float(health.get("lifestyle_fitness", 0.50)) * 0.999 + float(sports.get("participation", 0.40)) * 0.001, 0.10, 0.95)
	state["health"] = health
	state["sports_youth"] = sports

	return {"success": true, "state": state, "events": events}
