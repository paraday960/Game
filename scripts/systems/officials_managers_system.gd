extends BaseSystem
# ۳.۵۵ دولتمردان و مدیران - وزرا، استانداران، فرمانداران، شهرداران، شایستگی، فساد، گردش، آموزش

func compute(state: Dictionary, tick: int) -> Dictionary:
	var officials = state.get("officials", {})
	officials["ministers"] = officials.get("ministers", 20)
	var country_id = str(state.get("country", {}).get("id", WorldManager.default_country))
	officials["governors"] = max(1, CountryGeographyManager.get_unit_count(country_id))
	officials["mayors"] = max(officials["governors"], int(state.get("administration", {}).get("municipalities", 1200)))
	officials["governors_general"] = officials.get("governors_general", int(state.get("population", {}).get("total",85_000_000.0)/2_000_000.0))
	officials["senior_managers"] = officials.get("senior_managers", 5000)
	officials["middle_managers"] = officials.get("middle_managers", 25000)
	officials["competence"] = officials.get("competence", 0.60)
	officials["corruption"] = officials.get("corruption", state.get("politics", {}).get("corruption", 0.30))
	officials["turnover"] = officials.get("turnover", 0.15)
	officials["training"] = officials.get("training", 0.45)
	officials["merit_based_promotion"] = officials.get("merit_based_promotion", 0.50)
	officials["public_trust_officials"] = officials.get("public_trust_officials", 0.50)
	officials["decision_speed"] = officials.get("decision_speed", 0.55)
	officials["avg_age"] = officials.get("avg_age", 52.0)

	var events = []
	var corruption = state.get("politics", {}).get("corruption", 0.30)
	var stability = state.get("politics", {}).get("stability", 0.60)
	var edu_q = state.get("education", {}).get("quality", 0.55)
	var trust = state.get("politics", {}).get("trust", 0.55)
	var judicial = state.get("judicial", {}).get("rule_of_law", 0.60)

	# شایستگی = آموزش + شایسته‌سالاری + تجربه
	var meritocracy = state.get("political_career", {}).get("meritocracy", 0.50) if state.has("political_career") else 0.50
	var competence_target = edu_q*0.35 + meritocracy*0.30 + officials["training"]*0.20 + 0.15
	officials["competence"] = clamp(officials["competence"]*0.993 + competence_target*0.007 - corruption*0.001, 0.15, 0.95)

	officials["corruption"] = clamp(corruption*0.7 + (1.0 - judicial)*0.2 + (1.0 - officials["merit_based_promotion"])*0.1, 0.05, 0.85)

	# گردش = بی‌ثباتی + فساد + سن بالا
	officials["turnover"] = clamp(0.10 + (1.0 - stability)*0.20 + corruption*0.10 + max(0.0,(officials["avg_age"]-55.0)/100.0), 0.03, 0.55)

	# آموزش مدیران
	officials["training"] = clamp(officials["training"] + edu_q*0.0004 + state.get("technology", {}).get("branches", {}).get("دیجیتال",0.20)*0.0003, 0.1, 0.90)

	# ارتقای شایسته‌محور
	officials["merit_based_promotion"] = clamp(meritocracy*0.6 + judicial*0.2 + 0.2, 0.1, 0.90)

	# اعتماد عمومی به مدیران
	var trust_target = officials["competence"]*0.35 + (1.0 - officials["corruption"])*0.35 + stability*0.20 + 0.10
	officials["public_trust_officials"] = clamp(officials["public_trust_officials"]*0.96 + trust_target*0.04, 0.05, 0.90)

	# سرعت تصمیم‌گیری - تمرکززدایی + کارآمدی
	var decentral = state.get("administration", {}).get("decentralization", 0.4)
	officials["decision_speed"] = clamp(officials["competence"]*0.3 + decentral*0.2 + officials["training"]*0.2 + 0.3, 0.2, 0.95)

	# میانگین سنی - پیری + گردش
	officials["avg_age"] += (0.02 - officials["turnover"]*0.1) / 365.0
	officials["avg_age"] = clamp(officials["avg_age"], 38.0, 65.0)

	# تعداد مدیران میانی - رشد بوروکراسی
	if tick % 180 == 0 and officials["competence"] < 0.6:
		officials["middle_managers"] += Deterministic.next_int_range(100, 500)
	else:
		officials["middle_managers"] = max(officials["middle_managers"] - 10, 15000)

	# رویدادها
	if officials["corruption"] > 0.62 and Deterministic.chance(0.014):
		events.append({"type":"manager_corruption","corruption": officials["corruption"], "message":"افشای فساد مدیران ارشد - پرونده ۳ مدیرکل به قوه قضائیه"})

	if officials["competence"] < 0.35 and Deterministic.chance(0.012):
		events.append({"type":"low_competence_managers","competence": officials["competence"], "message":"ناشایستگی مدیریتی - ۴۰٪ مدیران بدون تخصص مرتبط"})

	if officials["turnover"] > 0.40 and Deterministic.chance(0.010):
		events.append({"type":"high_manager_turnover","turnover": officials["turnover"], "message":"سونامی برکناری مدیران - هر وزیر تیم خودش را آورد"})

	if officials["public_trust_officials"] < 0.30 and Deterministic.chance(0.011):
		events.append({"type":"trust_officials_low","trust": officials["public_trust_officials"], "message":"بی‌اعتمادی به مدیران - کار مردم معطل امضای مدیرکل"})

	state["officials"] = officials
	
	# ── لایه واقع‌گرایانه اختصاصی دولتمردان (جایگزین قالب خودکار) — بخش ۳.۵۵ ──
	# سرعت تصمیم‌گیری: دولت الکترونیک (دور ۱۲) کارایی مدیر را آزاد می‌کند، بار بروکراتیک خفه‌اش
	var digi_om = float(state.get("government_buildings", {}).get("digital_government", 0.50))
	var burden_om = float(state.get("government_buildings", {}).get("bureaucracy_burden", 0.40))
	var speed_target = float(officials.get("competence", 0.60)) * 0.4 + digi_om * 0.3 + (1.0 - burden_om) * 0.3
	officials["decision_speed"] = clampf(float(officials.get("decision_speed", 0.55)) * 0.993 + speed_target * 0.007, 0.10, 0.97)
	# جوانگرایی مدیران: ورود جوانان به سیاست (مسیر شغلی دور ۱۳) میانگین سن را پایین می‌آورد
	var youth_pol = float(state.get("political_career", {}).get("youth_in_politics", 0.15))
	officials["avg_age"] = clampf(float(officials.get("avg_age", 52.0)) + (45.0 + (0.25 - youth_pol) * 40.0 - float(officials.get("avg_age", 52.0))) * 0.001, 42.0, 62.0)
	# اعتماد عمومی به مدیران: شفافیت مالی و سرعت خدمت — نه سخنرانی
	var trust_o_target = (1.0 - float(officials.get("corruption", 0.30))) * 0.5 + float(officials.get("decision_speed", 0.55)) * 0.3 + float(officials.get("competence", 0.60)) * 0.2
	officials["public_trust_officials"] = clampf(float(officials.get("public_trust_officials", 0.50)) * 0.995 + trust_o_target * 0.005, 0.05, 0.95)
	if float(officials.get("turnover", 0.15)) > 0.30 and Deterministic.chance(0.005):
		events.append({"type": "minister_reshuffle_wave", "message": "استیضاح پیاپی وزرا - هر وزیر پیش از شناخت پرونده می‌رود", "turnover": officials["turnover"]})
	if float(officials.get("avg_age", 52.0)) > 58.0 and Deterministic.chance(0.004):
		events.append({"type": "aging_management", "message": "پیری بدنه مدیریتی - شکاف نسلی میان مدیران و جامعه جوان"})
	state["officials"] = officials

	return {"success":true,"state":state,"events":events}
