extends BaseSystem
# ۳.۶۰ نیروهای امنیتی و نظامی - ارتش، پلیس، اطلاعات، مرزبانی، روحیه، آموزش، تجهیزات، لجستیک

func compute(state: Dictionary, tick: int) -> Dictionary:
	var sf = state.get("security_forces_detail", {})
	sf["army"] = sf.get("army", 500000)
	sf["police"] = sf.get("police", 200000)
	sf["intel"] = sf.get("intel", 30000)
	sf["border"] = sf.get("border", 50000)
	sf["cyber_police"] = sf.get("cyber_police", 5000)
	sf["special_forces"] = sf.get("special_forces", 15000)
	sf["morale"] = sf.get("morale", 0.70)
	sf["training"] = sf.get("training", 0.65)
	sf["equipment"] = sf.get("equipment", 0.65)
	sf["logistics"] = sf.get("logistics", 0.60)
	sf["readiness"] = sf.get("readiness", 0.68)
	sf["desertion_rate"] = sf.get("desertion_rate", 0.02)
	sf["casualties"] = sf.get("casualties", 0)
	sf["budget_efficiency"] = sf.get("budget_efficiency", 0.65)

	var events = []
	var mil = state.get("military", {})
	var pol = state.get("politics", {})
	var econ = state.get("economy", {})
	var security = state.get("security", {})
	var intelligence = state.get("intelligence", {})

	var budget_share = econ.get("budget_allocations", {}).get("ارتش", 0.08) + econ.get("budget_allocations", {}).get("امنیت", 0.05)
	var spending = econ.get("government_spending", 95e9) * budget_share
	var corruption = pol.get("corruption", 0.30)
	var stability = pol.get("stability", 0.60)

	# روحیه = آمادگی نظامی + حقوق + ثبات + اعتماد
	var military_readiness = mil.get("readiness", 0.70)
	var real_wage_factor = 1.0 # حقوق واقعی فرض
	sf["morale"] = clamp(sf["morale"]*0.985 + (military_readiness*0.3 + stability*0.25 + real_wage_factor*0.15 + (1.0-corruption)*0.2 + security.get("public_security",0.70)*0.10)*0.015, 0.10, 0.98)

	# آموزش - بودجه + فناوری
	var tech_mil = state.get("technology", {}).get("branches", {}).get("نظامی", 0.15)
	sf["training"] = clamp(sf["training"]*0.993 + (tech_mil*0.4 + budget_share*2.0*0.3 + 0.3)*0.007, 0.15, 0.95)

	# تجهیزات - بودجه و صنعت
	var industry = state.get("industry", {}).get("output", 100.0)/100.0
	sf["equipment"] = clamp(sf["equipment"]*0.991 + (industry*0.3 + spending/20e9*0.3 + tech_mil*0.2 + 0.2)*0.009, 0.10, 0.95)

	# لجستیک - زیرساخت + آموزش
	var infra_q = state.get("infrastructure", {}).get("quality", 0.55)
	sf["logistics"] = clamp(sf["logistics"]*0.992 + (infra_q*0.4 + sf["training"]*0.3 + 0.3)*0.008, 0.15, 0.95)

	# آمادگی ترکیبی
	var readiness_calc = sf["morale"]*0.30 + sf["training"]*0.25 + sf["equipment"]*0.25 + sf["logistics"]*0.20
	sf["readiness"] = clamp(sf["readiness"]*0.90 + readiness_calc*0.10, 0.10, 0.98)

	# فرار از خدمت - روحیه پایین + اقتصاد بد
	var unemployment = econ.get("unemployment", 0.08)
	sf["desertion_rate"] = clamp((1.0 - sf["morale"])*0.08 + unemployment*0.02 + corruption*0.02, 0.005, 0.20)

	# کارآمدی بودجه - فساد معکوس
	sf["budget_efficiency"] = clamp((1.0 - corruption*0.5)*0.7 + sf["training"]*0.3, 0.2, 0.95)

	# تلفات - ماموریت‌ها
	if Deterministic.chance(0.003):
		sf["casualties"] += Deterministic.next_int_range(1, 5)

	# رشد نیروها متناسب جمعیت و تهدید
	if tick % 180 == 0:
		var pop_total = state.get("population", {}).get("total", 85_000_000.0)
		var threat = intelligence.get("threat_level", 0.4) if intelligence.has("threat_level") else 0.4
		if threat > 0.6 and Deterministic.chance(0.3):
			sf["army"] += Deterministic.next_int_range(2000, 8000)
			sf["border"] += Deterministic.next_int_range(500, 2000)

	# رویدادها
	if sf["morale"] < 0.38 and Deterministic.chance(0.013):
		events.append({"type":"force_low_morale","morale": sf["morale"], "message":"روحیه پایین نیروهای مسلح - نارضایتی از تاخیر حقوق"})

	if sf["equipment"] < 0.35 and Deterministic.chance(0.012):
		events.append({"type":"equipment_shortage","equipment": sf["equipment"], "message":"کمبود تجهیزات - نفربرها زمین‌گیر"})

	if sf["desertion_rate"] > 0.10 and Deterministic.chance(0.011):
		events.append({"type":"high_desertion","rate": sf["desertion_rate"], "message":"افزایش فرار از خدمت - %d%% نیروها" % int(sf["desertion_rate"]*100.0)})

	if sf["readiness"] > 0.85 and Deterministic.chance(0.006):
		events.append({"type":"high_readiness","readiness": sf["readiness"], "message":"آمادگی رزمی بالا - رزمایش موفق ذوالفقار"})

	if sf["border"] < 30000 and Deterministic.chance(0.008):
		events.append({"type":"border_understaffed","border": sf["border"], "message":"کمبود نیروی مرزبانی - قاچاق افزایش یافت"})

	state["security_forces_detail"] = sf
	
	# ── لایه واقع‌گرایانه اختصاصی نیروهای امنیتی (جایگزین قالب خودکار) — بخش ۳.۶۰ ──
	# تلفات و فرسایش روحیه در جنگ؛ در صلح تلفات تقریباً صفر است
	var at_war_sf = not state.get("world", {}).get("wars", {}).is_empty()
	if at_war_sf:
		sf["casualties"] = int(sf.get("casualties", 0)) + maxi(int(float(sf.get("army", 500000)) * 0.00002), 1)
		sf["morale"] = clampf(float(sf.get("morale", 0.70)) - 0.0004, 0.20, 0.97)
	# فرار از خدمت: روحیه پایین و جنگ افزایش‌دهنده، حقوق واقعی و اشتغال کاهش‌دهنده
	var desert_target = 0.015 + (1.0 - float(sf.get("morale", 0.70))) * 0.10 + (0.03 if at_war_sf else 0.0) - (1.0 - float(econ.get("unemployment", 0.08))) * 0.01
	sf["desertion_rate"] = clampf(float(sf.get("desertion_rate", 0.02)) * 0.99 + desert_target * 0.01, 0.002, 0.25)
	# آمادگی واقعی = ترکیب ضرب‌مانندگی آموزش × تجهیزات × لجستیک × روحیه (ضعیف‌ترین حلقه تعیین‌کننده است)
	var readiness_true = pow(maxf(float(sf.get("training", 0.65)), 0.05) * maxf(float(sf.get("equipment", 0.65)), 0.05) * maxf(float(sf.get("logistics", 0.60)), 0.05) * maxf(float(sf.get("morale", 0.70)), 0.05), 0.25)
	sf["readiness"] = clampf(float(sf.get("readiness", 0.68)) * 0.995 + readiness_true * 0.005, 0.10, 0.97)
	# حضور پلیس از نسبت واقعی پلیس به جمعیت (هر ۳ پلیس به‌ازای هر ۱۰۰۰ نفر = پوشش کامل)
	var pop_total_sf = float(state.get("population", {}).get("total", 85_000_000))
	var police_ratio = float(sf.get("police", 200000)) / maxf(pop_total_sf / 1000.0, 1.0)
	security["police_presence"] = clampf(float(security.get("police_presence", 0.5)) * 0.998 + (police_ratio / 3.0) * 0.002, 0.05, 0.95)
	state["security"] = security
	# کارایی بودجه: فساد بخشی از بودجه تسلیحات را بلع می‌کند
	sf["budget_efficiency"] = clampf(0.75 - float(pol.get("corruption", 0.30)) * 0.4, 0.30, 0.90)
	if float(sf.get("morale", 0.70)) < 0.45 and Deterministic.chance(0.005):
		events.append({"type": "low_troop_morale", "message": "افت روحیه نیروهای مسلح - خطر در هم‌گسستگی انضباط"})
	if at_war_sf and int(sf.get("casualties", 0)) > 5000 and Deterministic.chance(0.004):
		events.append({"type": "heavy_casualties", "message": "تلفات سنگین نیروها در جبهه - فشار افکار عمومی بر فرماندهی"})
	state["security_forces_detail"] = sf

	return {"success":true,"state":state,"events":events}
