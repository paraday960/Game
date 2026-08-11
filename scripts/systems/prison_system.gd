extends BaseSystem
# ۳.۶۷ زندان و نظام زندان - جمعیت، ظرفیت، تراکم، بازپروری، بازگشت، شرایط، بهداشت، آموزش داخل زندان

func compute(state: Dictionary, tick: int) -> Dictionary:
	var prison = state.get("prison", {})
	prison["population"] = prison.get("population", 80000)
	prison["capacity"] = prison.get("capacity", 100000)
	prison["overcrowding"] = prison.get("overcrowding", 0.80)
	prison["rehabilitation"] = prison.get("rehabilitation", 0.40)
	prison["recidivism"] = prison.get("recidivism", 0.35)
	prison["conditions"] = prison.get("conditions", 0.55)
	prison["healthcare"] = prison.get("healthcare", 0.50)
	prison["education_prison"] = prison.get("education_prison", 0.35)
	prison["work_programs"] = prison.get("work_programs", 0.30)
	prison["security_level"] = prison.get("security_level", 0.70)
	prison["escapes"] = prison.get("escapes", 5)
	prison["violence_rate"] = prison.get("violence_rate", 0.05)
	prison["staff_ratio"] = prison.get("staff_ratio", 0.25)
	prison["budget"] = prison.get("budget", 500_000_000.0)

	var events = []
	var judicial = state.get("judicial", {})
	var health = state.get("health", {})
	var edu = state.get("education", {})
	var security = state.get("security", {})
	var econ = state.get("economy", {})

	var crime_rate = judicial.get("crime_rate", 50.0)
	var rule_of_law = judicial.get("rule_of_law", 0.60)
	var efficiency = judicial.get("efficiency", 0.60)

	# جمعیت زندان = تابع جرم، کارآمدی قضایی، سابقه
	var target_pop = int(crime_rate * 1200.0 + (1.0 - efficiency)*20000.0)
	prison["population"] = int(prison["population"]*0.998 + target_pop*0.002)
	prison["population"] = max(prison["population"], 10000)

	# ظرفیت - رشد با بودجه
	if tick % 180 == 0 and prison["overcrowding"] > 0.90:
		prison["capacity"] += Deterministic.next_int_range(1000, 3000)

	prison["overcrowding"] = clamp(float(prison["population"]) / max(float(prison["capacity"]),1.0), 0.2, 2.5)

	# شرایط = تراکم معکوس + بودجه + بهداشت + امنیت
	var budget_factor = prison["budget"]/500_000_000.0
	prison["conditions"] = clamp((1.0 - min(prison["overcrowding"],1.0)*0.5)*0.4 + budget_factor*0.2 + health.get("quality",0.60)*0.15 + security.get("public_security",0.70)*0.15 + 0.10, 0.05, 0.95)

	# بهداشت زندان
	prison["healthcare"] = clamp(prison["healthcare"]*0.99 + health.get("quality",0.60)*0.01 + (1.0 - prison["overcrowding"]*0.3)*0.005, 0.1, 0.90)

	# آموزش و کار - بازپروری
	prison["education_prison"] = clamp(prison["education_prison"] + edu.get("quality",0.55)*0.0003, 0.1, 0.85)
	prison["work_programs"] = clamp(prison["work_programs"] + econ.get("growth_rate",0.02)*0.001, 0.1, 0.80)

	# بازپروری = آموزش + کار + شرایط + بهداشت
	var rehab_target = prison["education_prison"]*0.3 + prison["work_programs"]*0.25 + prison["conditions"]*0.25 + prison["healthcare"]*0.20
	prison["rehabilitation"] = clamp(prison["rehabilitation"]*0.992 + rehab_target*0.008, 0.05, 0.95)

	# بازگشت به جرم = 1 - بازپروری + بیکاری + تراکم
	var unemployment = econ.get("unemployment",0.08)
	prison["recidivism"] = clamp((1.0 - prison["rehabilitation"])*0.5 + unemployment*0.3 + min(prison["overcrowding"],1.5)*0.1 + 0.05, 0.05, 0.85)

	# خشونت داخل زندان = تراکم + شرایط معکوس + امنیت پایین
	prison["violence_rate"] = clamp(prison["overcrowding"]*0.03 + (1.0 - prison["conditions"])*0.05 + (1.0 - prison["security_level"])*0.02, 0.005, 0.30)

	# فرار - امنیت
	prison["escapes"] = int((1.0 - prison["security_level"])*10.0 + prison["overcrowding"]*2.0)
	prison["security_level"] = clamp(prison["security_level"] + security.get("public_security",0.70)*0.0002, 0.3, 0.95)

	# نسبت کارکنان
	prison["staff_ratio"] = clamp(prison["staff_ratio"] + (0.4 - prison["staff_ratio"])*0.001 - prison["overcrowding"]*0.0002, 0.1, 0.80)

	# بودجه - تورم
	prison["budget"] *= (1.0 + econ.get("inflation",0.08)/365.0)

	# رویدادها
	if prison["overcrowding"] > 1.15 and Deterministic.chance(0.016):
		events.append({"type":"prison_overcrowding","overcrowding": prison["overcrowding"], "message":"تراکم بالای زندان - %d%% ظرفیت پر است" % int(prison["overcrowding"]*100.0)})

	if prison["conditions"] < 0.30 and Deterministic.chance(0.012):
		events.append({"type":"prison_conditions_crisis","conditions": prison["conditions"], "message":"وضعیت وخیم زندان‌ها - کمبود تخت و تهویه"})

	if prison["violence_rate"] > 0.15 and Deterministic.chance(0.011):
		events.append({"type":"prison_riot","violence": prison["violence_rate"], "message":"شورش در زندان مرکزی - درگیری طایفه‌ای"})

	if prison["recidivism"] > 0.60 and Deterministic.chance(0.010):
		events.append({"type":"high_recidivism","recidivism": prison["recidivism"], "message":"بازگشت ۶۰٪ زندانیان پس از آزادی - شکست بازپروری"})

	if prison["rehabilitation"] > 0.70 and Deterministic.chance(0.007):
		events.append({"type":"rehabilitation_success","rehab": prison["rehabilitation"], "message":"موفقیت برنامه بازپروری - اشتغال ۷۰٪ آزادشدگان"})

	if prison["escapes"] > 15 and Deterministic.chance(0.008):
		events.append({"type":"prison_escape","escapes": prison["escapes"], "message":"فرار %d زندانی - نقص دوربین و نگهبان" % prison["escapes"]})

	state["prison"] = prison
	return {"success":true,"state":state,"events":events}
