extends BaseSystem
# سیستم جمعیت و دموگرافی - بخش ۳.۱۱

func compute(state: Dictionary, tick: int) -> Dictionary:
	var pop = state["population"]
	var econ = state["economy"]
	var health = state["health"]
	var edu = state["education"]
	var welfare = state["welfare"]
	var pol = state["politics"]
	var resources = state["resources"]

	var events = []

	# رشد طبیعی - ۳.۱۱.۳
	# تولد و مرگ: «مدل هدف+بازگشت میانگین» (اصلاح آینه بلندمدت).
	# پیش از این اثرها هر روز به‌صورت انباشتی (integral) روی نرخ سوار می‌شدند و در همان
	# سال اول به دیوارهٔ clamp می‌چسبیدند (تولد ۳۵/مرگ ۴ دائمی → جمعیت +۳٫۱٪/سال!).
	# حالا هدف = پایهٔ BalanceConfig + اثرها و نرخ واقعی با τ≈۷ماه به سمت هدف نرم می‌رود.
	var birth_base: float = float(BalanceConfig.get_value("population.birth_base", 15.0))
	var death_base: float = float(BalanceConfig.get_value("population.death_base", 8.0))

	# اثر رفاه بر تولد
	var welfare_effect = (econ["gdp_per_capita"] / 5000.0 - 1.0) * 0.5 + welfare["poverty"] * -2.0
	var birth_target = clamp(birth_base + welfare_effect + (pop["happiness"] - 0.5) * 2.0, 5.0, 35.0)
	var birth_rate = pop["birth_rate"] * 0.995 + birth_target * 0.005

	# اثر بهداشت بر مرگ
	var health_effect = (health["quality"] - 0.5) * -3.0
	var death_target = clamp(death_base + health_effect + (food_crisis_penalty(resources) + energy_crisis_penalty(resources)), 4.0, 25.0)
	var death_rate = pop["death_rate"] * 0.995 + death_target * 0.005

	pop["birth_rate"] = birth_rate
	pop["death_rate"] = death_rate

	var natural_growth = (birth_rate - death_rate) / 1000.0  # سالانه به نسبت
	# مهاجرت
	var migration_rate = pop["migration_net"] / max(pop["total"], 1.0)
	# جذابیت کشور
	var attractiveness = 0.0
	attractiveness += pop["happiness"] * 0.5
	attractiveness += (1.0 - welfare["poverty"]) * 0.3
	attractiveness += pol["stability"] * 0.2
	attractiveness -= pol["tension"] * 0.3

	# مهاجرت تصادفی دترمینستیک
	if Deterministic.chance(0.05):
		var mig_change = Deterministic.next_range(-5000, 20000) * attractiveness
		pop["migration_net"] += mig_change
	# واقع‌گرایی: مهاجرت خالص انباشته نمی‌شود؛ بازگشت تدریجی به تعادل + سقف ±۲٪ جمعیت
	# تا ورودی تصادفی روزانه در بلندمدت به جابه‌جایی غیرواقعی میلیونی تبدیل نشود
	var mig_cap: float = max(float(pop.get("total", 85_000_000.0)) * 0.02, 10000.0)
	pop["migration_net"] = clampf(float(pop.get("migration_net", 0.0)) * 0.999, -mig_cap, mig_cap)

	var total_growth_rate = natural_growth + migration_rate
	pop["growth_rate"] = total_growth_rate / 365.0  # روزانه
	pop["total"] *= (1.0 + pop["growth_rate"])
	pop["total"] = max(pop["total"], 1000.0)

	# نیروی کار
	pop["workforce"] = pop["total"] * pop["participation_rate"] * (1.0 - pop["age_structure"]["کودک"] - pop["age_structure"]["سالمند"] * 0.5)

	# نسبت وابستگی
	var children = pop["age_structure"]["کودک"]
	var elderly = pop["age_structure"]["سالمند"]
	var adults = pop["age_structure"]["بزرگسال"] + pop["age_structure"]["جوان"] * 0.7
	pop["dependency_ratio"] = (children + elderly) / max(adults, 0.01)

	# ترکیب سنی کند تغییر می‌کند
	if tick % 365 == 0:
		# هر سال
		pop["age_structure"]["سالمند"] += 0.002  # پیری جمعیت
		pop["age_structure"]["کودک"] -= 0.001
		# نرمالایز
		var sum_age = 0.0
		for v in pop["age_structure"].values():
			sum_age += v
		for k in pop["age_structure"].keys():
			pop["age_structure"][k] /= sum_age

	# رضایت - ۳.۱۱.۳
	# رضایت = f(رفاه، بیکاری، تورم، امنیت، آزادی، بهداشت)
	# مبنای ۰.۰۵ - تعادل در شرایط متوسط ≈ ۰.۶۷ (بدون مدیریت به سقف نمی‌رسد)
	var happiness = 0.05
	happiness += (1.0 - econ["unemployment"]) * 0.2
	happiness += (1.0 - econ["inflation"]) * 0.15
	happiness += health["quality"] * 0.15
	happiness += edu["quality"] * 0.1
	happiness += (1.0 - welfare["poverty"]) * 0.2
	happiness += pol["trust"] * 0.1
	happiness -= pol["tension"] * 0.2
	if resources["food_crisis"]:
		happiness -= 0.2
	if resources["energy_crisis"]:
		happiness -= 0.1
	# درخشش جشنواره‌ها و رویدادهای شادی‌بخش: تعادل شادی را موقتاً بالا نگه می‌دارد و آرام محو می‌شود
	happiness += float(pop.get("festival_glow", 0.0))
	happiness = clamp(happiness, 0.05, 0.95)
	pop["happiness"] = pop["happiness"] * 0.95 + happiness * 0.05  # نرم شدن تغییرات
	pop["festival_glow"] = maxf(float(pop.get("festival_glow", 0.0)) - 0.0015, 0.0)
	pop["satisfaction"] = pop["happiness"] * 0.9 + pol["trust"] * 0.1

	# آستانه شورش - ۳.۱۱.۴ (آستانه از منبع واحد بالانس)
	var happiness_critical = float(BalanceConfig.get_value("population.happiness_critical", 0.30))
	if pop["happiness"] < happiness_critical and Deterministic.chance(0.05):
		events.append({"type": "unrest_risk", "happiness": pop["happiness"], "message": "نارضایتی شدید مردمی - خطر شورش"})

	# رویدادهای جمعیتی - ۳.۱۱.۵
	if Deterministic.chance(0.01):
		var r = Deterministic.next_float()
		if r < 0.2:
			events.append({"type": "baby_boom", "effect": 0.02})
			pop["birth_rate"] += 2.0
		elif r < 0.4:
			events.append({"type": "epidemic", "severity": Deterministic.next_range(0.1, 0.5)})
			pop["death_rate"] += 5.0
			health["quality"] -= 0.05
		elif r < 0.6:
			events.append({"type": "migration_wave", "size": Deterministic.next_int_range(10000, 100000)})
			pop["migration_net"] += Deterministic.next_int_range(10000, 100000)

	state["population"] = pop
	state["health"] = health

	
	# ── لایه واقع‌گرایانه اختصاصی جمعیت (جایگزین قالب خودکار تکراری) — بخش ۳.۱۱ ──
	# سالمندی: زادآوری پایین بار منفوسان را بالا می‌برد (فرصت/فشار رفاهی و صندوق‌ها)
	var birth_p: float = float(pop.get("birth_rate", 14.0))
	pop["aging_index"] = clampf(float(pop.get("aging_index", 0.20)) + (16.0 - birth_p) * 0.00004, 0.05, 0.80)
	# پنجره جمعیتی: بار منفوسان پایین = فرصت رشد
	pop["demographic_window"] = float(pop.get("aging_index", 0.20)) < 0.35
	if float(pop.get("aging_index", 0.20)) > 0.45 and Deterministic.chance(0.003):
		events.append({"type": "aging_wave", "message": "موج سالمندی - فشار بر صندوق‌های بازنشستگی و نظام سلامت", "aging": pop["aging_index"]})
	state["population"] = pop

	return {"success": true, "state": state, "events": events}

func food_crisis_penalty(resources: Dictionary) -> float:
	if resources["food_crisis"]:
		return 5.0
	return 0.0

func energy_crisis_penalty(resources: Dictionary) -> float:
	if resources["energy_crisis"]:
		return 2.0
	return 0.0
