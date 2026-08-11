extends BaseSystem
# ۳.۴۸ خدمات عمومی - بیمارستان، مدرسه، دانشگاه، کلانتری، آتش‌نشانی، اورژانس، کتابخانه، پوشش، زمان واکنش

func compute(state: Dictionary, tick: int) -> Dictionary:
	var pub = state.get("public_services_detail", {})
	pub["hospitals"] = pub.get("hospitals", 500)
	pub["hospital_beds"] = pub.get("hospital_beds", 150000)
	pub["clinics"] = pub.get("clinics", 3000)
	pub["schools"] = pub.get("schools", 10000)
	pub["universities"] = pub.get("universities", 150)
	pub["vocational"] = pub.get("vocational", 500)
	pub["police_stations"] = pub.get("police_stations", 2000)
	pub["fire_stations"] = pub.get("fire_stations", 500)
	pub["ems_stations"] = pub.get("ems_stations", 800)
	pub["libraries"] = pub.get("libraries", 2000)
	pub["coverage_health"] = pub.get("coverage_health", 0.75)
	pub["coverage_education"] = pub.get("coverage_education", 0.80)
	pub["coverage_security"] = pub.get("coverage_security", 0.70)
	pub["response_police"] = pub.get("response_police", 8.0)
	pub["response_fire"] = pub.get("response_fire", 7.0)
	pub["response_ems"] = pub.get("response_ems", 9.0)
	pub["quality_health"] = pub.get("quality_health", 0.60)
	pub["quality_education"] = pub.get("quality_education", 0.55)
	pub["staff_shortage"] = pub.get("staff_shortage", 0.15)
	pub["budget_maintenance"] = pub.get("budget_maintenance", 2_000_000_000.0)

	var events = []
	var econ = state.get("economy", {})
	var pop = state.get("population", {})
	var health = state.get("health", {})
	var edu = state.get("education", {})
	var security = state.get("security", {})
	var infra = state.get("infrastructure", {})

	var budget_health = econ.get("budget_allocations", {}).get("بهداشت", 0.10)
	var budget_edu = econ.get("budget_allocations", {}).get("آموزش", 0.08)
	var budget_sec = econ.get("budget_allocations", {}).get("امنیت", 0.05)
	var pop_total = pop.get("total", 85_000_000.0)
	var gdp = econ.get("gdp", 500e9)
	var inflation = econ.get("inflation", 0.08)

	# پوشش سلامت = بودجه + بیمارستان + پزشک + زیرساخت
	var doctor_density = state.get("health", {}).get("doctors_per_1000", 1.5) if state.get("health", {}).has("doctors_per_1000") else 1.5
	var health_coverage_target = budget_health*2.0*0.3 + health.get("quality",0.60)*0.3 + infra.get("quality",0.55)*0.2 + 0.20
	pub["coverage_health"] = clamp(pub["coverage_health"]*0.992 + health_coverage_target*0.008, 0.2, 0.98)

	# پوشش آموزش
	var edu_coverage_target = budget_edu*2.5*0.35 + edu.get("quality",0.55)*0.35 + infra.get("quality",0.55)*0.15 + 0.15
	pub["coverage_education"] = clamp(pub["coverage_education"]*0.992 + edu_coverage_target*0.008, 0.2, 0.98)

	# پوشش امنیتی
	var sec_coverage_target = budget_sec*3.0*0.3 + security.get("public_security",0.70)*0.4 + infra.get("quality",0.55)*0.2 + 0.10
	pub["coverage_security"] = clamp(pub["coverage_security"]*0.993 + sec_coverage_target*0.007, 0.2, 0.98)

	# تعداد مراکز با رشد جمعیت و بودجه
	if tick % 90 == 0:
		var needed_hospitals = int(pop_total / 150000.0)
		var needed_schools = int(pop_total / 8000.0)
		var needed_police = int(pop_total / 40000.0)
		var needed_fire = int(pop_total / 150000.0)
		if budget_health > 0.08 and pub["hospitals"] < needed_hospitals:
			pub["hospitals"] += Deterministic.next_int_range(2, 8)
			pub["hospital_beds"] += Deterministic.next_int_range(200, 800)
		if budget_edu > 0.06 and pub["schools"] < needed_schools:
			pub["schools"] += Deterministic.next_int_range(10, 50)
		if budget_sec > 0.04 and pub["police_stations"] < needed_police:
			pub["police_stations"] += Deterministic.next_int_range(5, 20)
		pub["fire_stations"] = max(pub["fire_stations"], int(needed_fire))
		pub["ems_stations"] = int(pub["hospitals"] * 1.5)
		pub["clinics"] = pub["hospitals"] * 6
		pub["libraries"] = int(pop_total / 40000.0)
		pub["universities"] = int(pop_total / 500000.0)
		pub["vocational"] = int(pub["universities"] * 3.0)

	# زمان واکنش - تابع تعداد و ترافیک و کیفیت زیرساخت
	var traffic_factor = 1.0 / max(infra.get("capacity",0.60),0.2)
	pub["response_police"] = clamp(12.0 - pub["police_stations"]/250.0 + traffic_factor*2.0, 2.0, 30.0)
	pub["response_fire"] = clamp(10.0 - pub["fire_stations"]/60.0 + traffic_factor*1.5, 1.5, 25.0)
	pub["response_ems"] = clamp(11.0 - pub["ems_stations"]/80.0 + traffic_factor*1.8 + (1.0 - pub["coverage_health"])*5.0, 2.0, 30.0)

	# کیفیت خدمات - پرسنل + بودجه
	var shortage_target = (1.0 - edu.get("quality",0.55))*0.2 + (1.0 - budget_health)*0.3 + 0.05
	pub["staff_shortage"] = clamp(pub["staff_shortage"]*0.97 + shortage_target*0.03, 0.02, 0.60)

	pub["quality_health"] = clamp(health.get("quality",0.60)*0.6 + (1.0 - pub["staff_shortage"])*0.3 + pub["coverage_health"]*0.1, 0.1, 0.95)
	pub["quality_education"] = clamp(edu.get("quality",0.55)*0.6 + (1.0 - pub["staff_shortage"])*0.2 + pub["coverage_education"]*0.2, 0.1, 0.95)

	# هزینه نگهداری - تورم
	pub["budget_maintenance"] *= (1.0 + inflation/365.0)

	# رویدادها
	if pub["response_police"] > 16.0 and Deterministic.chance(0.014):
		events.append({"type":"police_slow","response": pub["response_police"], "message":"کندی واکنش پلیس - زمان رسیدن %d دقیقه" % int(pub["response_police"])})

	if pub["response_fire"] > 12.0 and Deterministic.chance(0.012):
		events.append({"type":"fire_slow","response": pub["response_fire"], "message":"آتش‌نشانی دیر رسید - کمبود ایستگاه در حاشیه شهر"})

	if pub["response_ems"] > 14.0 and Deterministic.chance(0.012):
		events.append({"type":"ems_slow","response": pub["response_ems"], "message":"اورژانس تاخیر - بیمار در راه بیمارستان فوت کرد"})

	if pub["staff_shortage"] > 0.35 and Deterministic.chance(0.013):
		events.append({"type":"staff_shortage_crisis","shortage": pub["staff_shortage"], "message":"کمبود پرسنل خدمات عمومی - یک پزشک برای ۳۰۰۰ نفر"})

	if pub["coverage_health"] < 0.45 and Deterministic.chance(0.011):
		events.append({"type":"health_coverage_low","coverage": pub["coverage_health"], "message":"پوشش سلامت پایین - روستاها بدون درمانگاه"})

	if pub["coverage_education"] > 0.90 and pub["quality_education"] > 0.75 and tick % 180 == 0 and Deterministic.chance(0.03):
		events.append({"type":"education_coverage_success","coverage": pub["coverage_education"], "message":"پوشش آموزشی ۹۰٪ - همه کودکان در مدرسه"})

	state["public_services_detail"] = pub
	return {"success":true,"state":state,"events":events}
