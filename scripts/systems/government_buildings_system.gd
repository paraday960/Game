extends BaseSystem
# ۳.۵۲ نهادهای دولتی - وزارتخانه، شهرداری، دادگاه، سفارت، دولت الکترونیک، کارآمدی

func compute(state: Dictionary, tick: int) -> Dictionary:
	var gov = state.get("government_buildings", {})
	gov["ministries"] = gov.get("ministries", 20)
	gov["municipalities"] = gov.get("municipalities", 1200)
	gov["courts"] = gov.get("courts", 400)
	gov["embassies"] = gov.get("embassies", 100)
	gov["consulates"] = gov.get("consulates", 150)
	gov["government_complexes"] = gov.get("government_complexes", 3500)
	gov["digital_government"] = gov.get("digital_government", 0.50)
	gov["efficiency"] = gov.get("efficiency", 0.60)
	gov["paperwork_time_days"] = gov.get("paperwork_time_days", 12.0)
	gov["citizen_satisfaction"] = gov.get("citizen_satisfaction", 0.55)
	gov["maintenance_cost"] = gov.get("maintenance_cost", 2_000_000_000.0)
	gov["one_stop_shops"] = gov.get("one_stop_shops", 120)

	var events = []
	var tech = state.get("technology", {}).get("branches", {}).get("دیجیتال", 0.20)
	var edu = state.get("education", {})
	var pop = state.get("population", {})
	var econ = state.get("economy", {})
	var admin = state.get("administration", {})
	var infra = state.get("infrastructure", {})

	# دولت الکترونیک - فناوری + سواد + بودجه زیرساخت
	var digital_target = tech * 0.5 + edu.get("literacy", 0.85) * 0.2 + admin.get("efficiency", 0.60) * 0.2 + 0.1
	gov["digital_government"] = clamp(gov["digital_government"] * 0.995 + digital_target * 0.005 + tech * 0.001, 0.10, 0.98)

	# کارآمدی - دولت دیجیتال + آموزش کارکنان + فساد معکوس
	var corruption = state.get("politics", {}).get("corruption", 0.30)
	var pub_emp_eff = state.get("public_employees", {}).get("efficiency", 0.60) if state.has("public_employees") else 0.60
	var eff_target = gov["digital_government"] * 0.35 + pub_emp_eff * 0.30 + (1.0 - corruption) * 0.25 + 0.10
	gov["efficiency"] = clamp(gov["efficiency"]*0.993 + eff_target*0.007, 0.15, 0.98)

	# زمان بروکراسی - کارآمدی بالا زمان کمتر
	var bureaucracy_delay = 30.0 * (1.0 - gov["efficiency"]) + 2.0
	gov["paperwork_time_days"] = gov["paperwork_time_days"]*0.9 + bureaucracy_delay*0.1

	# رضایت شهروندان از خدمات دولتی
	var target_sat = gov["efficiency"]*0.5 + (1.0 - gov["paperwork_time_days"]/30.0)*0.3 + admin.get("efficiency",0.60)*0.2
	gov["citizen_satisfaction"] = clamp(gov["citizen_satisfaction"]*0.95 + target_sat*0.05, 0.1, 0.95)

	# هزینه نگهداری - تورم
	gov["maintenance_cost"] *= (1.0 + econ.get("inflation",0.08)/365.0)

	# پیشخوان دولت
	if tick % 90 == 0 and gov["digital_government"] > 0.60:
		gov["one_stop_shops"] += Deterministic.next_int_range(2, 10)

	# تعداد شهرداری‌ها متناسب جمعیت
	var pop_total = pop.get("total", 85_000_000.0)
	var needed_municipalities = int(pop_total / 70000.0)
	if gov["municipalities"] < needed_municipalities and tick % 180 == 0:
		gov["municipalities"] += 5

	# پوشش خدمات دولتی در روستاها - زیرساخت
	var coverage = gov.get("coverage", 0.70)
	var infra_q = infra.get("quality", 0.55)
	gov["coverage"] = clamp(coverage*0.995 + infra_q*0.005, 0.3, 0.95)

	# رویدادها
	if gov["efficiency"] < 0.35 and Deterministic.chance(0.016):
		events.append({"type":"gov_inefficiency","efficiency": gov["efficiency"], "message":"ناکارآمدی نهادهای دولتی - صف‌های طولانی و نارضایتی"})

	if gov["paperwork_time_days"] > 20.0 and Deterministic.chance(0.012):
		events.append({"type":"bureaucracy_delay","days": gov["paperwork_time_days"], "message":"بروکراسی فرساینده - مجوزها ۳ هفته معطل"})

	if gov["digital_government"] > 0.80 and gov["efficiency"] > 0.75 and Deterministic.chance(0.008):
		events.append({"type":"digital_gov_success","digital": gov["digital_government"], "message":"دولت الکترونیک بالغ - ۸۰٪ خدمات غیرحضوری شد"})

	if gov["citizen_satisfaction"] < 0.30 and Deterministic.chance(0.01):
		events.append({"type":"citizen_complaint_wave","satisfaction": gov["citizen_satisfaction"], "message":"موج شکایت مردمی از ادارات - میز خدمت شلوغ"})

	state["government_buildings"] = gov
	return {"success":true,"state":state,"events":events}
