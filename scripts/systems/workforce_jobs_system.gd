extends BaseSystem
# ۳.۵۴ نیروی کار و مشاغل - جمعیت فعال، ترکیب شغلی، دستمزد، بهره‌وری، مهارت، جابجایی، ایمنی شغلی

func compute(state: Dictionary, tick: int) -> Dictionary:
	var workforce = state.get("workforce_detail", {})
	workforce["total"] = workforce.get("total", state.get("population", {}).get("workforce", 55000000))
	workforce["farmers"] = workforce.get("farmers", 0.20)
	workforce["industrial"] = workforce.get("industrial", 0.25)
	workforce["services"] = workforce.get("services", 0.35)
	workforce["gov"] = workforce.get("gov", 0.15)
	workforce["tech"] = workforce.get("tech", 0.05)
	workforce["unemployed"] = workforce.get("unemployed", state.get("economy", {}).get("unemployment", 0.08))
	workforce["avg_wage"] = workforce.get("avg_wage", state.get("economy", {}).get("gdp_per_capita", 5000.0)*0.8)
	workforce["median_wage"] = workforce.get("median_wage", workforce["avg_wage"]*0.75)
	workforce["productivity"] = workforce.get("productivity", 0.60)
	workforce["skill_mismatch"] = workforce.get("skill_mismatch", 0.30)
	workforce["informal"] = workforce.get("informal", 0.25)
	workforce["female_participation"] = workforce.get("female_participation", 0.30)
	workforce["youth_unemployment"] = workforce.get("youth_unemployment", 0.18)
	workforce["safety_index"] = workforce.get("safety_index", 0.65)
	workforce["hours_per_week"] = workforce.get("hours_per_week", 44.0)
	workforce["unionization"] = workforce.get("unionization", 0.15)

	var events = []
	var econ = state.get("economy", {})
	var edu = state.get("education", {})
	var health = state.get("health", {})
	var pop = state.get("population", {})
	var tech = state.get("technology", {})
	var welfare = state.get("welfare", {})

	var total_pop = pop.get("total", 85_000_000.0)
	workforce["total"] = total_pop * pop.get("participation_rate",0.65) * (1.0 - pop.get("age_structure",{}).get("کودک",0.25) - pop.get("age_structure",{}).get("سالمند",0.10)*0.5)

	# بهره‌وری = آموزش + سلامت + شادی + فناوری
	var edu_q = edu.get("quality",0.55)
	var health_q = health.get("quality",0.60)
	var happiness = pop.get("happiness",0.60)
	var tech_ind = tech.get("branches",{}).get("صنعت",0.20)
	var digital = tech.get("branches",{}).get("دیجیتال",0.20)
	var prod_target = 0.3 + edu_q*0.25 + health_q*0.15 + happiness*0.15 + tech_ind*0.10 + digital*0.05
	workforce["productivity"] = clamp(workforce["productivity"]*0.992 + prod_target*0.008, 0.15, 0.98)

	# دستمزد - بهره‌وری + تورم + رشد
	var inflation = econ.get("inflation",0.08)
	var growth = econ.get("growth_rate",0.02)
	workforce["avg_wage"] *= (1.0 + (growth*0.7 + inflation*0.5 + (workforce["productivity"]-0.6)*0.02)/365.0)
	workforce["avg_wage"] = max(workforce["avg_wage"], 800.0)
	workforce["median_wage"] = workforce["avg_wage"] * (0.85 - welfare.get("gini",0.38)*0.5)

	# بیکاری - رشد معکوس + فناوری
	workforce["unemployed"] = econ.get("unemployment",0.08)
	workforce["youth_unemployment"] = workforce["unemployed"] * 1.8 + (1.0 - edu_q)*0.1

	# ترکیب شغلی - گذار اقتصاد با فناوری دیجیتال و صنعت
	var tech_level = digital + tech_ind
	if tech_level > 0.35:
		workforce["farmers"] = clamp(workforce["farmers"] - 0.00015, 0.03, 0.50)
		workforce["industrial"] = clamp(workforce["industrial"] - 0.00005, 0.10, 0.40)
		workforce["services"] = clamp(workforce["services"] + 0.00012, 0.20, 0.70)
		workforce["tech"] = clamp(workforce["tech"] + 0.00010, 0.01, 0.25)
	# نرمالایز ترکیب شغلی
	var sum_jobs = workforce["farmers"] + workforce["industrial"] + workforce["services"] + workforce["gov"] + workforce["tech"]
	workforce["farmers"] /= sum_jobs
	workforce["industrial"] /= sum_jobs
	workforce["services"] /= sum_jobs
	workforce["gov"] /= sum_jobs
	workforce["tech"] /= sum_jobs
	# gov کمی ثابت
	workforce["gov"] = clamp(workforce["gov"], 0.08, 0.25)

	# ناهماهنگی مهارت - سواد و فناوری
	var skill_gap = abs(workforce["tech"] - digital) + abs(workforce["industrial"] - tech_ind)*0.5
	workforce["skill_mismatch"] = clamp(skill_gap*0.5 + (1.0 - edu_q)*0.3 + 0.1, 0.05, 0.70)

	# اقتصاد غیررسمی - بیکاری و فساد
	var corruption = state.get("politics",{}).get("corruption",0.30)
	workforce["informal"] = clamp(corruption*0.3 + workforce["unemployed"]*0.4 + (1.0 - edu_q)*0.1 + 0.10, 0.05, 0.60)

	# مشارکت زنان - فرهنگ و آموزش
	var gender_eq = state.get("family",{}).get("gender_equality",0.45) if state.has("family") else 0.45
	workforce["female_participation"] = clamp(workforce["female_participation"] + gender_eq*0.0002 + edu_q*0.0001, 0.10, 0.70)

	# ایمنی شغلی
	workforce["safety_index"] = clamp(health_q*0.4 + workforce["productivity"]*0.2 + state.get("infrastructure",{}).get("quality",0.55)*0.2 + 0.20, 0.2, 0.95)

	# ساعات کار
	workforce["hours_per_week"] = clamp(44.0 + workforce["informal"]*6.0 - workforce["productivity"]*4.0, 35.0, 60.0)

	# تشکل‌یابی
	workforce["unionization"] = clamp(workforce["unionization"] + (1.0 - workforce["safety_index"])*0.0002, 0.02, 0.50)

	# رویدادها
	if workforce["unemployed"] > 0.15 and Deterministic.chance(0.015):
		events.append({"type":"high_unemployment","unemp": workforce["unemployed"], "message":"بیکاری %d٪ - صف طولانی کاریابی" % int(workforce["unemployed"]*100.0)})

	if workforce["youth_unemployment"] > 0.30 and Deterministic.chance(0.012):
		events.append({"type":"youth_unemployment_crisis","youth_unemp": workforce["youth_unemployment"], "message":"بیکاری جوانان %d٪ - بحران نسل بیکار" % int(workforce["youth_unemployment"]*100.0)})

	if workforce["skill_mismatch"] > 0.50 and Deterministic.chance(0.010):
		events.append({"type":"skill_mismatch_crisis","mismatch": workforce["skill_mismatch"], "message":"شکاف مهارت - ۴۰٪ مشاغل با مدرک نمی‌خواند"})

	if workforce["informal"] > 0.45 and Deterministic.chance(0.011):
		events.append({"type":"informal_economy_rise","informal": workforce["informal"], "message":"اقتصاد زیرزمینی %d٪ نیروی کار" % int(workforce["informal"]*100.0)})

	if workforce["productivity"] > 0.80 and Deterministic.chance(0.008):
		events.append({"type":"productivity_boom","prod": workforce["productivity"], "message":"جهش بهره‌وری نیروی کار - تولید سرانه بالا"})

	state["workforce_detail"] = workforce
	state["economy"]["unemployment"] = workforce["unemployed"]
	
	# ── لایه واقع‌گرایانه اختصاصی نیروی کار (جایگزین قالب خودکار) — بخش ۳.۵۴ ──
	# گذار ساختاری اشتغال: صنعت پیشرفته و دیجیتال، سهم کشاورزی را می‌بلعد و خدمات/فناوری را می‌بردارد
	var shift = float(tech_ind) * 0.0006 + float(digital) * 0.0004
	workforce["farmers"] = clampf(float(workforce.get("farmers", 0.20)) - shift, 0.04, 0.45)
	workforce["tech"] = clampf(float(workforce.get("tech", 0.05)) + float(digital) * 0.0005, 0.01, 0.25)
	workforce["services"] = clampf(float(workforce.get("services", 0.35)) + shift * 0.8, 0.15, 0.65)
	# مشارکت زنان: از سیستم خانواده (دور ۱۰) — برابری و مهدهای کودک تعیین‌کننده واقعی است
	var fam_wf = float(state.get("family", {}).get("female_workforce", 0.35))
	workforce["female_participation"] = clampf(float(workforce.get("female_participation", 0.30)) * 0.998 + fam_wf * 0.002, 0.08, 0.60)
	# بیکاری جوانان: دو برابر عمومی + شکاف مهارت — واقعیت بازار کار
	workforce["youth_unemployment"] = clampf(float(workforce.get("unemployed", 0.08)) * 1.9 + float(workforce.get("skill_mismatch", 0.30)) * 0.25, 0.04, 0.55)
	# شکاف مهارت: سرعت پیشرفت فناوری از سرعت ارتقای آموزش بیشتر شود، شکاف باز می‌ماند
	var mismatch_target = 0.20 + float(digital) * 0.5 - float(edu_q) * 0.35
	workforce["skill_mismatch"] = clampf(float(workforce.get("skill_mismatch", 0.30)) * 0.997 + mismatch_target * 0.003, 0.05, 0.75)
	# اقتصاد غیررسمی اشتغال: از برآورد آماری (دور ۱۰) و ضعف قاعده قانون
	var informal_target = float(state.get("statistics", {}).get("informal_economy_estimate", 0.25)) * 0.6 + (1.0 - float(state.get("judicial", {}).get("rule_of_law", 0.60))) * 0.3
	workforce["informal"] = clampf(float(workforce.get("informal", 0.25)) * 0.997 + informal_target * 0.003, 0.05, 0.60)
	# ایمنی شغلی: نظارت ضعیف و غیررسمی بودن → مرگ‌های شغلی
	workforce["safety_index"] = clampf(float(workforce.get("safety_index", 0.65)) * 0.998 + ((1.0 - float(workforce.get("informal", 0.25))) * 0.7) * 0.002, 0.20, 0.97)
	if float(workforce.get("skill_mismatch", 0.30)) > 0.50 and Deterministic.chance(0.005):
		events.append({"type": "skills_gap_crisis", "message": "بحران شکاف مهارت - فارغ‌التحصیل بی‌کار و کارگاه بی‌نیروی ماهر", "gap": workforce["skill_mismatch"]})
	if float(workforce.get("safety_index", 0.65)) < 0.40 and Deterministic.chance(0.005):
		events.append({"type": "work_accidents_wave", "message": "افزایش حوادث مرگبار شغلی - فقدان بازرسی کار در بنگاه‌های غیررسمی"})
	state["workforce_detail"] = workforce

	return {"success":true,"state":state,"events":events}
