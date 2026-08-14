extends BaseSystem
# ۳.۲۰ آموزش و پرورش - پیاده‌سازی کامل

func compute(state: Dictionary, tick: int) -> Dictionary:
	var education = state.get("education", {})
	var pop = state.get("population", {})
	var econ = state.get("economy", {})
	var tech = state.get("technology", {})
	var welfare = state.get("welfare", {})
	var culture = state.get("culture", {})

	education["literacy"] = education.get("literacy", 0.85)
	education["quality"] = education.get("quality", 0.55)
	education["coverage"] = education.get("coverage", 0.80)
	education["primary_coverage"] = education.get("primary_coverage", 0.95)
	education["secondary_coverage"] = education.get("secondary_coverage", 0.80)
	education["higher_coverage"] = education.get("higher_coverage", 0.30)
	education["vocational_coverage"] = education.get("vocational_coverage", 0.25)
	education["human_capital"] = education.get("human_capital", 0.60)
	education["skill_match"] = education.get("skill_match", 0.60)
	education["teacher_count"] = education.get("teacher_count", 800000)
	education["student_teacher_ratio"] = education.get("student_teacher_ratio", 25.0)
	education["research_output"] = education.get("research_output", 0.40)

	var events = []

	var edu_budget_share = econ.get("budget_allocations", {}).get("آموزش", 0.08)
	var edu_budget = econ.get("government_spending", 0.0) * edu_budget_share

	# فرمول‌ها - ۳.۲۰.۳
	# نرخ سواد = f(پوشش مدرسه، کیفیت، بودجه)
	# نُرم مرجع واقع‌گرایانه: ۳٪ تولید ناخالص سالانه برای آموزش (بودجه ماهانه ÷۱۲)
	var edu_norm: float = max(float(econ.get("gdp", 1.0)), 1.0) * 0.03 / 12.0
	var literacy_target = 0.6 + education["primary_coverage"] * 0.3 + education["quality"] * 0.2 + clampf(edu_budget / edu_norm, 0.0, 2.0) * 0.05
	# پویش خودکفا: literacy_bonus انباشتِ سرمایه‌گذاری یادگیری دیجیتال بود که هرگز مصرف نمی‌شد؛ حالا به سواد می‌رسد
	literacy_target += float(state.get("education_policy", {}).get("literacy_bonus", 0.0)) * 0.25
	education["literacy"] = clamp(education["literacy"] * 0.999 + literacy_target * 0.001, 0.1, 0.99)

	# پوشش‌ها با بودجه
	education["primary_coverage"] = clamp(education["primary_coverage"] + (edu_budget_share - 0.06) * 0.002, 0.5, 0.99)
	education["secondary_coverage"] = clamp(education["secondary_coverage"] + (edu_budget_share - 0.06) * 0.0015, 0.3, 0.95)
	education["higher_coverage"] = clamp(education["higher_coverage"] + (edu_budget_share - 0.08) * 0.001, 0.05, 0.80)

	# کیفیت آموزش = f(معلم، بودجه، زیرساخت، برنامه)
	var teacher_ratio_effect = 1.0 / max(education["student_teacher_ratio"], 1.0) * 20.0  # نسبت کمتر بهتر
	var quality_target = 0.4 + edu_budget_share * 1.5 + teacher_ratio_effect * 0.1 + tech.get("branches", {}).get("دیجیتال",0.2) * 0.2
	education["quality"] = clamp(education["quality"] * 0.998 + quality_target * 0.002, 0.1, 0.95)

	# سرمایه انسانی = f(آموزش، کیفیت، مهارت)
	var human_capital = 0.5
	human_capital += education["literacy"] * 0.2
	human_capital += education["quality"] * 0.3
	human_capital += education["higher_coverage"] * 0.2
	human_capital += education["vocational_coverage"] * 0.15
	education["human_capital"] = clamp(education["human_capital"] * 0.99 + human_capital * 0.01, 0.1, 0.95)

	# بهره‌وری = f(سرمایه انسانی، فناوری) - در جمعیت اثر دارد
	pop["happiness"] = pop.get("happiness",0.6) * 0.999 + human_capital * 0.001
	state["population"] = pop

	# هماهنگی با بازار کار = f(آموزش فنی، تقاضای شغل)
	var unemployment = econ.get("unemployment",0.08)
	var skill_mismatch = abs(education["vocational_coverage"] - 0.4) + unemployment * 0.5
	education["skill_match"] = clamp(1.0 - skill_mismatch, 0.1, 0.95)

	# نسبت دانش‌آموز به معلم
	var students = pop.get("total",85_000_000) * 0.25  # 25٪ دانش‌آموز
	education["student_teacher_ratio"] = students / max(education["teacher_count"],1.0)

	# کمبود معلم
	if education["student_teacher_ratio"] > 35.0 and Deterministic.chance(0.01):
		events.append({"type": "teacher_shortage", "message": "بحران کمبود معلم - نسبت شاگرد به معلم بالا", "ratio": education["student_teacher_ratio"]})

	# پژوهش و نوآوری
	education["research_output"] = clamp(education["research_output"] + education["higher_coverage"] * 0.001 + tech.get("research_rate",10.0) / 1000.0 * 0.001, 0.05, 0.95)

	# اثر فناوری
	tech["branches"]["دیجیتال"] = clamp(tech.get("branches",{}).get("دیجیتال",0.2) + education["research_output"] * 0.0001, 0.0, 1.0)
	state["technology"] = tech

	# حلقه‌های بازخورد: آموزش → بهره‌وری/نوآوری؛ نابرابری → تنش
	var inequality = welfare.get("gini",0.38) if welfare else 0.38
	if education["coverage"] < 0.6 and inequality > 0.45 and Deterministic.chance(0.01):
		events.append({"type": "education_inequality", "message": "نابرابری آموزشی و کاهش تحرک اجتماعی"})

	# رویدادها - ۳.۲۰.۵
	if Deterministic.chance(0.01):
		var r = Deterministic.next_float()
		if r < 0.3 and unemployment > 0.12:
			events.append({"type": "graduate_unemployment", "message": "بحران بیکاری فارغ‌التحصیلان", "unemployment": unemployment})
		elif r < 0.6 and edu_budget_share < 0.05:
			events.append({"type": "student_protest", "message": "اعتراض دانشجویان به کاهش بودجه آموزش", "budget_share": edu_budget_share})
		elif r < 0.8:
			events.append({"type": "education_reform", "message": "اصلاحات آموزشی پیشنهاد شد", "effect": 0.02})
			education["quality"] = clampf(float(education.get("quality", 0.5)) + 0.01, 0.05, 0.98)
		else:
			events.append({"type": "talent_discovered", "message": "کشف استعداد درخشان!", "bonus": 0.05})
			education["human_capital"] += 0.01

	state["education"] = education
	
	# ── لایه واقع‌گرایانه اختصاصی آموزش (جایگزین قالب خودکار تکراری) — بخش ۳.۲۰ ──
	# سواد «نسل‌ای» است: دیر تغییر می‌کند و ماندگار است
	var school_input: float = float(education.get("quality", 0.50)) * 0.6 + float(education.get("coverage", 0.75)) * 0.4
	education["literacy"] = clampf(float(education.get("literacy", 0.85)) * 0.9999 + school_input * 0.0001, 0.30, 0.99)
	# ناهماهنگی مهارت: آموزش عالی انباشته + مهارت‌آموزی خالی = فارغ‌التحصیل سرگردان
	var skill_gap: float = float(education.get("higher_coverage", 0.40)) - float(education.get("vocational_coverage", 0.35))
	if skill_gap > 0.25 and float(econ.get("unemployment", 0.08)) > 0.10 and Deterministic.chance(0.004):
		events.append({"type": "skill_mismatch", "message": "ناپختی بازار کار و آموزش - انباشت فارغ‌التحصیلان بدون مهارت کاربردی", "gap": skill_gap})
	# ترک تحصیل از ریشه فقر
	if float(welfare.get("poverty", 0.15)) > 0.30 and Deterministic.chance(0.004):
		events.append({"type": "dropout_poverty", "message": "ترک تحصیل دانش‌آموزان مناطق کم‌درآمد - چرخه فقر در حال تکرار است", "poverty": welfare["poverty"]})
	state["education"] = education

	return {"success": true, "state": state, "events": events}
