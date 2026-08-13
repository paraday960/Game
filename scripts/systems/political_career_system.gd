extends BaseSystem
# ۳.۷۲ مسیر شغلی سیاسی - شایسته‌سالاری، ارتقا، فساد مسیر، دوره تصدی، شبکه‌سازی

func compute(state: Dictionary, tick: int) -> Dictionary:
	var career = state.get("political_career", {})
	career["ministers_avg_tenure"] = career.get("ministers_avg_tenure", 2.5)
	career["governors_avg_tenure"] = career.get("governors_avg_tenure", 3.0)
	career["mayors_avg_tenure"] = career.get("mayors_avg_tenure", 3.5)
	career["promotion_rate"] = career.get("promotion_rate", 0.15)
	career["corruption_career"] = career.get("corruption_career", state.get("politics", {}).get("corruption", 0.30))
	career["meritocracy"] = career.get("meritocracy", 0.50)
	career["nepotism_index"] = career.get("nepotism_index", 0.35)
	career["training_programs"] = career.get("training_programs", 0.40)
	career["women_in_politics"] = career.get("women_in_politics", 0.18)
	career["youth_in_politics"] = career.get("youth_in_politics", 0.15)
	career["turnover_rate"] = career.get("turnover_rate", 0.12)
	career["salaries"] = career.get("salaries", 5000.0)

	var events = []
	var pol = state.get("politics", {})
	var edu = state.get("education", {})
	var judicial = state.get("judicial", {})
	var admin = state.get("administration", {})

	var stability = pol.get("stability", 0.60)
	var corruption = pol.get("corruption", 0.30)
	var rule_of_law = judicial.get("rule_of_law", 0.60)
	var admin_eff = admin.get("efficiency", 0.60)

	# شایسته‌سالاری = تابع حاکمیت قانون، آموزش، شفافیت، فساد معکوس
	var merit_target = rule_of_law * 0.35 + edu.get("quality", 0.55) * 0.25 + admin_eff * 0.20 + (1.0 - corruption) * 0.20
	career["meritocracy"] = clamp(career["meritocracy"] * 0.993 + merit_target * 0.007, 0.05, 0.95)

	# پارتی‌بازی = فساد + عدم شفافیت
	var nepotism_target = corruption * 0.6 + (1.0 - rule_of_law) * 0.4
	career["nepotism_index"] = clamp(career["nepotism_index"] * 0.995 + nepotism_target * 0.005, 0.05, 0.90)

	# فساد مسیر شغلی
	career["corruption_career"] = clamp(corruption * 0.7 + career["nepotism_index"] * 0.3, 0.05, 0.85)

	# نرخ ارتقا - ثبات بالا ارتقا منصفانه‌تر، بی‌ثباتی بالا ارتقا سیاسی
	var promotion_base = 0.10 + stability * 0.10 + career["meritocracy"] * 0.08
	career["promotion_rate"] = clamp(promotion_base, 0.05, 0.40)

	# دوره تصدی - شایسته‌سالاری بالا دوره طولانی‌تر کارشناسی، پایین دوره کوتاه سیاسی
	if career["meritocracy"] > 0.6:
		career["ministers_avg_tenure"] = clamp(career["ministers_avg_tenure"] + 0.001, 1.0, 8.0)
		career["governors_avg_tenure"] = clamp(career["governors_avg_tenure"] + 0.001, 1.0, 8.0)
	else:
		career["ministers_avg_tenure"] = clamp(career["ministers_avg_tenure"] - 0.001, 0.5, 8.0)

	# آموزش مدیران
	var tech = state.get("technology", {}).get("branches", {}).get("دیجیتال", 0.20)
	career["training_programs"] = clamp(career["training_programs"] + tech * 0.0005 + edu.get("quality", 0.55) * 0.0003, 0.1, 0.95)

	# مشارکت زنان و جوانان - همبسته با فرهنگ و رفاه
	var family_eq = state.get("family", {}).get("gender_equality", 0.45) if state.has("family") else 0.45
	career["women_in_politics"] = clamp(career["women_in_politics"] + family_eq * 0.0002, 0.05, 0.50)
	var youth_hap = state.get("sports_youth", {}).get("youth_happiness", 0.50) if state.has("sports_youth") else 0.50
	career["youth_in_politics"] = clamp(career["youth_in_politics"] + youth_hap * 0.00015, 0.05, 0.40)

	# نرخ گردش - بی‌ثباتی بالا گردش بالا
	career["turnover_rate"] = clamp((1.0 - stability) * 0.15 + corruption * 0.10 + 0.05, 0.02, 0.50)

	# حقوق - تورم‌زدایی
	var inflation = state.get("economy", {}).get("inflation", 0.08)
	career["salaries"] *= (1.0 + inflation * 0.5 / 365.0)

	# رویدادها
	if career["meritocracy"] < 0.30 and Deterministic.chance(0.015):
		events.append({"type":"nepotism_crisis","severity": 1.0-career["meritocracy"], "message":"شایسته‌سالاری پایین - پارتی‌بازی و قوم‌گرایی در انتصابات"})

	if career["nepotism_index"] > 0.70 and Deterministic.chance(0.012):
		events.append({"type":"nepotism_scandal","index": career["nepotism_index"], "message":"افشای شبکه خویشاوندسالاری در استانداری‌ها"})

	if career["turnover_rate"] > 0.35 and Deterministic.chance(0.01):
		events.append({"type":"high_turnover","rate": career["turnover_rate"], "message":"گردش سریع مدیران - بی‌ثباتی مدیریتی"})

	if career["women_in_politics"] < 0.10 and tick % 180 == 0 and Deterministic.chance(0.02):
		events.append({"type":"gender_gap_politics","message":"شکاف جنسیتی در مناصب سیاسی - مطالبه سهم زنان"})

	state["political_career"] = career
	
	# ── لایه واقع‌گرایانه اختصاصی مسیر شغلی سیاسی (جایگزین قالب خودکار) — بخش ۳.۷۲ ──
	# تداوم تصدی: بی‌ثباتی سیاسی و جنگ مدت تصدی وزرا و استاندارها را واقعاً کوتاه می‌کند
	var at_war_pc = not state.get("world", {}).get("wars", {}).is_empty()
	var tenure_target = 1.2 + float(stability) * 3.5 - (1.5 if at_war_pc else 0.0)
	career["ministers_avg_tenure"] = clampf(float(career.get("ministers_avg_tenure", 2.5)) * 0.998 + tenure_target * 0.002, 0.5, 5.0)
	career["governors_avg_tenure"] = clampf(float(career.get("governors_avg_tenure", 3.0)) * 0.998 + (tenure_target + 0.5) * 0.002, 0.5, 6.0)
	# تداوم سیاستی: چرخش مکرر کابینه، برنامه‌های بلندمدت را ناتمام می‌گذارد (اداره می‌تواند بخواند)
	career["policy_continuity"] = clampf(float(career.get("ministers_avg_tenure", 2.5)) / 5.0 * (1.0 - float(career.get("turnover_rate", 0.12))), 0.05, 0.95)
	# حقوق مدیران سیاسی: با تورم تعدیل می‌شود وگرنه انگیزه رانت بالا می‌رود
	career["salaries"] = float(career.get("salaries", 5000.0)) * (1.0 + float(state.get("economy", {}).get("inflation", 0.08)) / 365.0 * 0.9)
	# برابری در مسیر قدرت: برابری جنسیتی خانواده به‌آرامی به سیاست نفوذ می‌کند
	var family_eq_pc = float(state.get("family", {}).get("gender_equality", 0.55))
	career["women_in_politics"] = clampf(float(career.get("women_in_politics", 0.18)) * 0.999 + (family_eq_pc * 0.35) * 0.001, 0.02, 0.50)
	if float(career.get("turnover_rate", 0.12)) > 0.25 and Deterministic.chance(0.005):
		events.append({"type": "cabinet_revolution", "message": "چرخه خروپف کابینه - پروژه‌های ملی نیمه‌تمام روی زمین می‌ماند", "turnover": career["turnover_rate"]})
	if float(career.get("meritocracy", 0.50)) < 0.35 and Deterministic.chance(0.004):
		events.append({"type": "meritocracy_collapse", "message": "تحلیل شایسته‌سالاری - ارتقاها سلیقه‌ای شده و مدیران کاربلد کنار رانده می‌شوند"})
	state["political_career"] = career

	return {"success":true,"state":state,"events":events}
