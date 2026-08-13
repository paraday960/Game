extends BaseSystem
# ۳.۴۱ برنامه فضایی و هوافضا - پیاده‌سازی کامل

func compute(state: Dictionary, tick: int) -> Dictionary:
	var space = state.get("space", {})
	var tech = state.get("technology", {})
	var military = state.get("military", {})
	var econ = state.get("economy", {})
	var education = state.get("education", {})
	var diplomacy = state.get("diplomacy", {})

	space["level"] = space.get("level", 0.10)
	space["satellites"] = space.get("satellites", 2)
	space["launch_sites"] = space.get("launch_sites", 1)
	space["rockets"] = space.get("rockets", 3)
	space["astronauts"] = space.get("astronauts", 0)
	space["research"] = space.get("research", 0.20)
	space["budget_share"] = space.get("budget_share", 0.01)
	space["international_cooperation"] = space.get("international_cooperation", 0.30)
	space["commercial"] = space.get("commercial", 0.10)
	space["military_space"] = space.get("military_space", 0.20)

	var events = []

	var space_budget_share = econ.get("budget_allocations",{}).get("فناوری",0.04) * 0.25 + 0.005
	var space_budget = econ.get("government_spending",0.0) * space_budget_share
	space["budget_share"] = space_budget_share

	# سطح فضایی = f(بودجه، فناوری، آموزش، تحقیق، همکاری)
	var tech_space = tech.get("branches",{}).get("فضا",0.05)
	var research_rate = tech.get("research_rate",10.0)
	var space_target = 0.05 + space_budget_share * 10.0 + tech_space * 0.5 + education.get("higher_coverage",0.30) * 0.1 + research_rate / 50.0 * 0.1
	space["level"] = clamp(space["level"] * 0.995 + space_target * 0.005, 0.02, 1.0)

	# تحقیق فضایی
	space["research"] = clamp(space["research"] + (space_budget_share * 2.0 + tech_space * 0.01) * 0.001, 0.05, 0.95)

	# ماهواره‌ها
	if space["level"] > 0.3 and space_budget_share > 0.01 and Deterministic.chance(0.008):
		space["satellites"] += 1
		events.append({"type": "satellite_launched", "message": "پرتاب ماهواره موفق - ماهواره %s در مدار!" % str(space["satellites"]), "satellites": space["satellites"]})
		# اثر: ارتباطات، هواشناسی، جاسوسی
		state["infrastructure"]["quality"] = clamp(state.get("infrastructure",{}).get("quality",0.55) + 0.005, 0.1, 0.95)
		state["intelligence"]["foreign_intel"] = clamp(state.get("intelligence",{}).get("foreign_intel",0.50) + 0.01, 0.1, 0.95)

	# سایت پرتاب
	if space["level"] > 0.5 and space["launch_sites"] < 3 and Deterministic.chance(0.003):
		space["launch_sites"] += 1
		events.append({"type": "launch_site_built", "message": "ساخت پایگاه پرتاب فضایی جدید"})

	# موشک‌ها
	space["rockets"] = int(space["level"] * 30.0 + space_budget_share * 200.0)

	# فضانوردان
	if space["level"] > 0.7 and Deterministic.chance(0.002):
		space["astronauts"] += 1
		events.append({"type": "astronaut_program", "message": "برنامه فضانوردی - اعزام فضانورد به مدار!", "astronauts": space["astronauts"]})
		state["culture"]["cohesion"] = clamp(state.get("culture",{}).get("cohesion",0.65) + 0.02, 0.1, 0.95)

	# همکاری بین‌المللی
	var coop_target = 0.3 + diplomacy.get("soft_power",35.0)/100.0 * 0.3 + space["level"] * 0.2
	space["international_cooperation"] = clamp(space["international_cooperation"] * 0.99 + coop_target * 0.01, 0.1, 0.90)

	# تجاری‌سازی فضا
	var commercial_target = 0.1 + space["level"] * 0.3 + tech.get("branches",{}).get("صنعت",0.20) * 0.2
	space["commercial"] = clamp(space["commercial"] * 0.995 + commercial_target * 0.005, 0.02, 0.80)

	# نظامی فضایی
	var mil_space_target = 0.2 + military.get("power",65.0)/100.0 * 0.2 + space["level"] * 0.2
	space["military_space"] = clamp(space["military_space"] * 0.99 + mil_space_target * 0.01, 0.05, 0.85)

	# اثر فناوری - سرریز فناوری فضایی به سایر شاخه‌ها
	tech["branches"]["فضا"] = clamp(tech.get("branches",{}).get("فضا",0.05) + space["research"] * 0.001, 0.02, 1.0)
	tech["branches"]["نظامی"] = clamp(tech.get("branches",{}).get("نظامی",0.15) + space["military_space"] * 0.0005, 0.05, 1.0)
	tech["branches"]["دیجیتال"] = clamp(tech.get("branches",{}).get("دیجیتال",0.20) + space["level"] * 0.0005, 0.05, 1.0)
	state["technology"] = tech

	# اثر بر اقتصاد - بازده بلندمدت
	econ["gdp"] += space["commercial"] * 1_000_000_000.0 / 365.0
	state["economy"] = econ

	# اثر بر قدرت و نفوذ
	diplomacy["influence"] = clamp(diplomacy.get("influence",40.0) + space["level"] * 0.01, 0.0, 100.0)
	state["diplomacy"] = diplomacy

	military["deterrence"] = clamp(military.get("deterrence",60.0) + space["military_space"] * 0.02, 0.0, 100.0)
	state["military"] = military

	# حلقه: فضا → فناوری → قدرت → بودجه
	if space["level"] > 0.6:
		space["budget_share"] += 0.0001  # موفقیت → بودجه بیشتر

	# رویدادها
	if space["level"] < 0.2 and Deterministic.chance(0.01):
		events.append({"type": "space_program_stagnation", "message": "رکود برنامه فضایی - کمبود بودجه و فناوری", "level": space["level"]})

	if space["satellites"] == 0 and space["level"] > 0.4 and Deterministic.chance(0.01):
		events.append({"type": "satellite_failure", "message": "شکست پرتاب ماهواره - خسارت و تاخیر", "satellites": space["satellites"]})
		space["level"] -= 0.02

	if space["international_cooperation"] > 0.6 and Deterministic.chance(0.006):
		events.append({"type": "space_cooperation", "message": "همکاری فضایی بین‌المللی - پروژه مشترک با ابرقدرت‌ها"})

	if space["commercial"] > 0.5 and Deterministic.chance(0.006):
		events.append({"type": "space_commercial_success", "message": "موفقیت تجاری‌سازی فضا - درآمد ارزی از پرتاب ماهواره"})

	if space["level"] > 0.8 and Deterministic.chance(0.004):
		events.append({"type": "moon_mission", "message": "ماموریت ماه - جهش بزرگ! پرچم کشور بر ماه!"})

	state["space"] = space
	
	# ── لایه واقع‌گرایانه اختصاصی برنامه فضایی (جایگزین قالب خودکار) — بخش ۳.۴۱ ──
	# ناوگان موشک: رشد تابع سطح فناوری و پایگاه‌های پرتاب؛ شکست پرتاب در سطوح پایین محتمل است
	var launch_capacity = float(space.get("launch_sites", 1)) * (0.5 + float(space.get("level", 0.10)))
	if float(space.get("level", 0.10)) > 0.40 and Deterministic.chance(0.006 * launch_capacity):
		space["rockets"] = int(space.get("rockets", 3)) + 1
		if float(space.get("level", 0.10)) < 0.55 and Deterministic.chance(0.30):
			space["rockets"] = maxi(int(space["rockets"]) - 1, 1)
			events.append({"type": "launch_failure", "message": "شکست پرتاب موشک - ماهواره از دست رفت و اعتبار برنامه خدشه‌دار شد"})
	# پرواز سرنشین‌دار: نقطه عطف بزرگ که فقط با سطح بالا ممکن است
	if float(space.get("level", 0.10)) > 0.65 and int(space.get("astronauts", 0)) == 0 and Deterministic.chance(0.005):
		space["astronauts"] = 4
		events.append({"type": "first_crewed_flight", "message": "نخستین پرواز سرنشین‌دار فضایی کشور - روز تاریخی!", "astronauts": 4})
	# درآمد تجاری پرتاب: سهم تجاری × سطح فناوری × تقاضای جهانی ماهواره
	space["launch_revenue"] = float(space.get("commercial", 0.10)) * float(space.get("level", 0.10)) * float(space.get("launch_sites", 1)) * 2.0e9
	# زباله فضایی: مدار شلوغ بدون مدیریت → خطر برخوردهای زنجیره‌ای
	if int(space.get("satellites", 2)) > 25 and Deterministic.chance(0.003):
		space["satellites"] = maxi(int(space["satellites"]) - 1, 1)
		events.append({"type": "orbital_collision", "message": "برخورد زباله فضایی با ماهواره - ضرورت مدیریت ترافیک مداری"})
	# ابعاد نظامی فضا: رشد در سکوت → نگرانی دیپلماتیک وقتی روابط تیره است
	if float(space.get("military_space", 0.20)) > 0.50 and float(diplomacy.get("global_reputation", 0.50)) < 0.40 and Deterministic.chance(0.005):
		events.append({"type": "space_militarization_concern", "message": "نگرانی جهانی از نظامی‌سازی فضا - فشار دیپلماتیک بر برنامه موشکی"})
	state["space"] = space

	return {"success": true, "state": state, "events": events}
