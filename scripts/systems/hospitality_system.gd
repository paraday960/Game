extends BaseSystem
# ۳.۴۴ رستوران و مهمان‌پذیری - اماکن فیزیکی

func compute(state: Dictionary, tick: int) -> Dictionary:
	var hospitality = state.get("hospitality", {})
	var tourism = state.get("tourism", {})
	var pop = state.get("population", {})
	var econ = state.get("economy", {})

	hospitality["restaurants"] = hospitality.get("restaurants", 50000)
	hospitality["cafes"] = hospitality.get("cafes", 30000)
	hospitality["hotels"] = hospitality.get("hotels", 3000)
	hospitality["hotels_capacity"] = hospitality.get("hotels_capacity", 0.65)
	hospitality["guest_houses"] = hospitality.get("guest_houses", 5000)
	hospitality["food_quality"] = hospitality.get("food_quality", 0.70)
	hospitality["service_quality"] = hospitality.get("service_quality", 0.65)
	hospitality["hygiene"] = hospitality.get("hygiene", 0.70)
	hospitality["employment"] = hospitality.get("employment", 500000)
	hospitality["revenue"] = hospitality.get("revenue", 10_000_000_000.0)

	var events = []

	# درآمد گردشگری بر مهمان‌پذیری اثر می‌گذارد
	var tourism_revenue = tourism.get("revenue",5_000_000_000.0)
	var visitors = tourism.get("visitors",5_000_000)

	# تعداد رستوران‌ها با جمعیت و گردشگری
	var pop_factor = pop.get("total",85_000_000) / 85_000_000.0
	hospitality["restaurants"] = int(50000 * pop_factor + visitors / 100.0)
	hospitality["cafes"] = int(30000 * pop_factor + visitors / 200.0)
	hospitality["hotels"] = int(3000 * pop_factor + visitors / 2000.0)

	# ظرفیت هتل = رزرو / ظرفیت
	var occupancy = visitors / max(hospitality["hotels"] * 1000.0, 1.0)  # هر هتل 1000 گردشگر
	hospitality["hotels_capacity"] = clamp(occupancy, 0.2, 1.5)

	# کیفیت غذا = f(کشاورزی، بهداشت، آموزش)
	var agri_quality = state.get("agriculture",{}).get("food_security",0.85)
	var health_hygiene = state.get("health",{}).get("quality",0.60)
	hospitality["food_quality"] = clamp(agri_quality * 0.5 + health_hygiene * 0.3 + 0.2, 0.2, 0.95)
	hospitality["hygiene"] = clamp(health_hygiene * 0.7 + hospitality["food_quality"] * 0.3, 0.2, 0.95)

	# کیفیت خدمات = f(آموزش، گردشگری)
	var edu_quality = state.get("education",{}).get("quality",0.55)
	hospitality["service_quality"] = clamp(edu_quality * 0.4 + tourism.get("service_quality",0.60) * 0.4 + 0.2, 0.2, 0.95)

	# اشتغال
	hospitality["employment"] = hospitality["restaurants"] * 10 + hospitality["hotels"] * 50

	# درآمد
	var revenue = hospitality["restaurants"] * 200000.0 + hospitality["hotels"] * 5000000.0 + hospitality["cafes"] * 100000.0
	# نُرم مرجع: ۱٪ تولید ناخالص سالانه درآمد گردشگری (سطح سالانه) — بدون دلار مطلق
	var tourism_norm: float = max(float(econ.get("gdp", 1.0)), 1.0) * 0.01
	revenue *= (1.0 + clampf(tourism_revenue / tourism_norm, 0.0, 2.0) * 0.12)
	hospitality["revenue"] = hospitality["revenue"] * 0.99 + revenue * 0.01

	# اثر بر اقتصاد
	econ["gdp"] += hospitality["revenue"] * 0.05 / 365.0
	state["economy"] = econ

	# رویدادها
	if hospitality["hotels_capacity"] > 1.0 and Deterministic.chance(0.012):
		events.append({"type": "hotel_overbooking", "message": "تکمیل ظرفیت هتل‌ها - گردشگران بدون جا!", "capacity": hospitality["hotels_capacity"]})
		tourism["revenue"] *= 0.95
		state["tourism"] = tourism

	if hospitality["hygiene"] < 0.5 and Deterministic.chance(0.01):
		events.append({"type": "food_safety_crisis", "message": "بحران بهداشت غذا - مسمومیت در رستوران‌ها", "hygiene": hospitality["hygiene"]})
		tourism["visitors"] = tourism.get("visitors",5_000_000) * 0.95
		state["tourism"] = tourism

	if hospitality["service_quality"] > 0.8 and Deterministic.chance(0.008):
		events.append({"type": "culinary_fame", "message": "شهرت جهانی غذای کشور - جذب گردشگر غذا!"})

	state["hospitality"] = hospitality
	
	# ── لایه واقع‌گرایانه اختصاصی مهمان‌داری (جایگزین قالب خودکار) — بخش ۳.۴۴ ──
	# اشتغال واقعی مهمان‌داری: هر رستوران ~۶ نفر، هر هتل ~۴۰ نفر، هر کافه ~۳ نفر
	hospitality["employment"] = int(float(hospitality.get("restaurants", 50000)) * 6.0 + float(hospitality.get("hotels", 3000)) * 40.0 + float(hospitality.get("cafes", 30000)) * 3.0)
	# درآمد از اشتغال و گردشگر — نه عدد ثابت
	hospitality["revenue"] = float(hospitality.get("employment", 500000)) * float(econ.get("gdp_per_capita", 5000.0)) * 0.9 + float(visitors) * 850.0
	# بوم‌گردی: گردشگری فرهنگی قوی (میراث دور ۱۰) اقامتگاه‌های سنتی را شکوفا می‌کند
	var heritage_ct = float(state.get("heritage", {}).get("cultural_tourism", 0.50))
	hospitality["guest_houses"] = maxi(int(float(hospitality.get("guest_houses", 5000)) * (1.0 + (heritage_ct - 0.45) * 0.002)), 500)
	if heritage_ct > 0.70 and Deterministic.chance(0.004):
		events.append({"type": "ecotourism_boom", "message": "رونق اقامتگاه‌های بوم‌گردی - روستاها مقصد تازه گردشگر شدند"})
	# کیفیت خدمات: آموزش هتلداری و دستمزد منصفانه — فشار تورمی کیفیت را آماس می‌زند
	var service_target = float(state.get("education", {}).get("quality", 0.55)) * 0.45 + (1.0 - float(econ.get("inflation", 0.08)) * 0.5) * 0.35 + 0.15
	hospitality["service_quality"] = clampf(float(hospitality.get("service_quality", 0.65)) * 0.99 + service_target * 0.01, 0.15, 0.97)
	# بهداشت عمومی ضعیف → بحران اعتماد به رستوران‌ها
	if float(hospitality.get("hygiene", 0.70)) < 0.45 and Deterministic.chance(0.005):
		events.append({"type": "food_poisoning_wave", "message": "موج مسمومیت غذایی - بازرسی‌های بهداشتی رستوران‌ها تشدید شد"})
	# اشباع ظرفیت هتل‌ها از موج گردشگری (دور ۸)
	if float(hospitality.get("hotels_capacity", 0.65)) > 1.1 and Deterministic.chance(0.005):
		events.append({"type": "hotel_overbooking", "message": "هتل‌ها سرریز - مسافران نوروزی در صف اتاق", "occupancy": hospitality["hotels_capacity"]})
	state["hospitality"] = hospitality

	return {"success": true, "state": state, "events": events}
