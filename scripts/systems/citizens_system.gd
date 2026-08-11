extends BaseSystem
# ۳.۵۳ شهروندان - نمونه ۱۰۰۰ نفر با ویژگی سن، جنسیت، مهارت، شغل، رضایت، جابجایی اجتماعی
# منطق عمیق: هر شهروند نماینده یک خوشه جمعیتی است - رفتار جمعی از میانگین خوشه‌ها می‌آید

func compute(state: Dictionary, tick: int) -> Dictionary:
	var citizens = state.get("citizens_detail", {})
	citizens["sample_size"] = citizens.get("sample_size", 1000)
	citizens["avg_age"] = citizens.get("avg_age", 35.0)
	citizens["age_std"] = citizens.get("age_std", 12.0)
	citizens["avg_happiness"] = citizens.get("avg_happiness", state.get("population", {}).get("happiness", 0.60))
	citizens["diversity_index"] = citizens.get("diversity_index", 0.60)
	citizens["social_mobility"] = citizens.get("social_mobility", 0.50)
	citizens["skill_avg"] = citizens.get("skill_avg", state.get("education", {}).get("quality", 0.55))
	citizens["employment_rate"] = citizens.get("employment_rate", 1.0 - state.get("economy", {}).get("unemployment", 0.08))
	citizens["trust_gov"] = citizens.get("trust_gov", state.get("politics", {}).get("trust", 0.55))
	citizens["political_interest"] = citizens.get("political_interest", 0.45)
	citizens["health_index"] = citizens.get("health_index", state.get("health", {}).get("quality", 0.60))
	citizens["income_avg"] = citizens.get("income_avg", state.get("economy", {}).get("gdp_per_capita", 5000.0))
	citizens["income_median"] = citizens.get("income_median", citizens["income_avg"] * 0.75)
	citizens["life_events"] = citizens.get("life_events", [])

	var events = []
	var pop = state.get("population", {})
	var edu = state.get("education", {})
	var welfare = state.get("welfare", {})
	var econ = state.get("economy", {})
	var health = state.get("health", {})
	var pol = state.get("politics", {})
	var culture = state.get("culture", {})

	# به‌روزرسانی سن - هر روز 1/365 سال
	citizens["avg_age"] += 1.0 / 365.0
	if tick % 30 == 0:
		# ماهانه: ترکیب سنی تغییر کند
		citizens["age_std"] = clamp(citizens["age_std"] + Deterministic.next_range(-0.02, 0.03), 8.0, 18.0)

	# رضایت جمعی = تابع چند متغیره واقعی
	var hap = 0.05
	hap += (1.0 - econ.get("unemployment", 0.08)) * 0.18
	hap += (1.0 - econ.get("inflation", 0.08)) * 0.12
	hap += health.get("quality", 0.60) * 0.15
	hap += edu.get("quality", 0.55) * 0.12
	hap += (1.0 - welfare.get("poverty", 0.15)) * 0.18
	hap += pol.get("trust", 0.55) * 0.10
	hap += culture.get("cohesion", 0.65) * 0.05
	hap -= pol.get("tension", 0.35) * 0.15
	if state.get("resources", {}).get("food_crisis", false):
		hap -= 0.20
	if state.get("resources", {}).get("energy_crisis", false):
		hap -= 0.10
	if state.get("security", {}).get("public_security", 0.70) < 0.4:
		hap -= 0.12
	hap = clamp(hap, 0.05, 0.95)
	citizens["avg_happiness"] = citizens["avg_happiness"] * 0.92 + hap * 0.08

	# تحرک اجتماعی = آموزش * (1-جینی) * (1-فساد) * سلامت
	var edu_q = edu.get("quality", 0.55)
	var gini = welfare.get("gini", 0.38)
	var corruption = pol.get("corruption", 0.30)
	var health_q = health.get("quality", 0.60)
	var mobility_target = edu_q * (1.0 - gini) * (1.0 - corruption*0.5) * (0.7 + health_q*0.3)
	mobility_target = clamp(mobility_target, 0.1, 0.90)
	citizens["social_mobility"] = clamp(citizens["social_mobility"]*0.995 + mobility_target*0.005, 0.05, 0.95)

	# مهارت میانگین - اثر آموزش و فناوری
	var tech = state.get("technology", {}).get("branches", {}).get("دیجیتال", 0.20)
	citizens["skill_avg"] = clamp(citizens["skill_avg"]*0.998 + (edu_q*0.6 + tech*0.4)*0.002, 0.1, 0.95)

	# اشتغال - همبسته با اقتصاد
	var target_emp = 1.0 - econ.get("unemployment", 0.08)
	citizens["employment_rate"] = clamp(citizens["employment_rate"]*0.95 + target_emp*0.05, 0.4, 0.98)

	# درآمد - رشد GDP اما با تاخیر و نابرابری
	citizens["income_avg"] *= (1.0 + econ.get("growth_rate", 0.02) * 0.7 / 365.0)
	citizens["income_median"] = citizens["income_avg"] * (0.9 - gini*0.5)

	# اعتماد به دولت - همبسته با ثبات و رفاه
	citizens["trust_gov"] = clamp(citizens["trust_gov"]*0.97 + pol.get("trust", 0.55)*0.03, 0.05, 0.95)

	# علاقه سیاسی - تابع تنش و انتخابات نزدیک
	var election_factor = 0.1
	if state.has("elections"):
		var participation = state["elections"].get("participation", 0.60)
		election_factor = participation * 0.2
	citizens["political_interest"] = clamp(citizens["political_interest"]*0.99 + (pol.get("tension",0.35)*0.3 + election_factor)*0.01, 0.1, 0.90)

	# سلامت
	citizens["health_index"] = clamp(citizens["health_index"]*0.98 + health.get("quality",0.60)*0.02, 0.2, 0.95)

	# تنوع - اثر قومیت
	var eth_div = state.get("ethnicity", {}).get("diversity", 0.6)
	citizens["diversity_index"] = clamp(eth_div*0.3 + citizens["diversity_index"]*0.7, 0.2, 0.90)

	# رویدادهای شهروندان - واقع‌گرایانه
	if citizens["social_mobility"] < 0.30 and Deterministic.chance(0.015):
		events.append({"type":"low_mobility","severity": (0.3 - citizens["social_mobility"]),"message":"تحرک اجتماعی پایین - فقر موروثی و ناامیدی جوانان"})

	if citizens["employment_rate"] < 0.60 and Deterministic.chance(0.012):
		events.append({"type":"unemployment_protest","rate": 1.0-citizens["employment_rate"], "message":"اعتراض بیکاران در میدان‌های شهر"})

	if citizens["trust_gov"] < 0.25 and Deterministic.chance(0.008):
		events.append({"type":"trust_crisis","trust": citizens["trust_gov"], "message":"بحران اعتماد عمومی - زمزمه نافرمانی مدنی"})

	if citizens["health_index"] < 0.4 and Deterministic.chance(0.01):
		events.append({"type":"health_crisis_citizens","message":"افت سلامت عمومی - مراجعه انفجاری به اورژانس"})

	if tick % 90 == 0 and citizens["skill_avg"] > 0.7 and Deterministic.chance(0.02):
		# اثر مثبت - شکوفایی سرمایه انسانی
		events.append({"type":"skill_boom","skill": citizens["skill_avg"], "message":"موج مهارت‌آموزی - جوانان به دوره‌های فنی هجوم آورده‌اند"})

	# ثبت رویداد زندگی هر ۳۰ روز
	if tick % 30 == 0 and citizens["life_events"].size() < 100:
		citizens["life_events"].append({
			"tick": tick,
			"happiness": citizens["avg_happiness"],
			"mobility": citizens["social_mobility"],
			"income_median": citizens["income_median"]
		})
		if citizens["life_events"].size() > 50:
			citizens["life_events"] = citizens["life_events"].slice(-50)

	state["citizens_detail"] = citizens
	return {"success":true,"state":state,"events":events}
