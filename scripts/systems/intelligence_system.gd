extends BaseSystem
# اطلاعات و امنیت ملی - ۳.۲۳ - نسخه عمیق واقعی - ISR، سایبری، جنگ الکترونیک، ضدجاسوسی، عملیات ویژه اطلاعاتی

func compute(state: Dictionary, tick: int) -> Dictionary:
	var intel = state.get("intelligence", {})
	var econ = state.get("economy", {})
	var mil = state.get("military", {})
	var tech = state.get("technology", {})
	var pol = state.get("politics", {})
	var diplomacy = state.get("diplomacy", {})
	var world = state.get("world", {})

	intel["power"] = intel.get("power", 50.0)
	intel["cyber_readiness"] = intel.get("cyber_readiness", 0.50)
	intel["cyber_offense"] = intel.get("cyber_offense", 0.45)
	intel["cyber_defense"] = intel.get("cyber_defense", 0.55)
	intel["sigint"] = intel.get("sigint", 0.50) # شنود سیگنال
	intel["humint"] = intel.get("humint", 0.55) # عامل انسانی
	intel["osint"] = intel.get("osint", 0.60) # اطلاعات باز
	intel["imint"] = intel.get("imint", 0.50) # تصویری + ماهواره
	intel["comint"] = intel.get("comint", 0.48)
	intel["elint"] = intel.get("elint", 0.45) # الکترونیک
	intel["counter_intel"] = intel.get("counter_intel", 0.55)
	intel["counter_terror"] = intel.get("counter_terror", 0.60)
	intel["infiltration_risk"] = intel.get("infiltration_risk", 0.15)
	intel["intel_sharing_allies"] = intel.get("intel_sharing_allies", 0.40)
	intel["satellite_coverage"] = intel.get("satellite_coverage", 0.50)
	intel["drone_surveillance"] = intel.get("drone_surveillance", 0.45)
	intel["ew_capability"] = intel.get("ew_capability", 0.50) # جنگ الکترونیک
	intel["psyops"] = intel.get("psyops", 0.40)
	intel["disinfo_defense"] = intel.get("disinfo_defense", 0.45)
	intel["threat_level"] = intel.get("threat_level", 0.40)
	intel["threat_internal"] = intel.get("threat_internal", 0.35)
	intel["threat_external"] = intel.get("threat_external", 0.45)
	intel["operations_active"] = intel.get("operations_active", 3)
	intel["budget_efficiency"] = intel.get("budget_efficiency", 0.65)

	var events = []

	var budget_share = econ.get("budget_allocations", {}).get("امنیت", 0.05) + econ.get("budget_allocations", {}).get("فناوری", 0.04)*0.5
	var budget = econ.get("government_spending", 95e9) * budget_share
	var digital = tech.get("branches", {}).get("دیجیتال", 0.20)
	var military_tech = tech.get("branches", {}).get("نظامی", 0.15)
	var edu_q = state.get("education", {}).get("quality", 0.55)
	var stability = pol.get("stability", 0.60)
	var corruption = pol.get("corruption", 0.30)
	var is_at_war = not world.get("wars", {}).is_empty()

	# ==================== قدرت اطلاعاتی کل ====================
	var power_target = budget_share*2.0*0.25 + digital*0.20 + edu_q*0.15 + stability*0.15 + military_tech*0.15 + 0.10
	intel["power"] = clamp(intel["power"]*0.985 + power_target*50.0*0.015, 10.0, 100.0)

	# ==================== ISR - اطلاعات، مراقبت، شناسایی ====================
	# SIGINT - شنود - فناوری دیجیتال + ماهواره
	var sigint_target = digital*0.35 + float(mil.get("equipment_detail",{}).get("ew_systems",40))/40.0*0.25 + edu_q*0.20 + 0.20
	intel["sigint"] = clamp(intel["sigint"]*0.978 + sigint_target*0.022, 0.10, 0.96)

	# HUMINT - عامل انسانی - اعتماد و فساد معکوس + دیپلماسی
	var humint_target = (1.0 - corruption)*0.30 + stability*0.20 + diplomacy.get("influence",40.0)/100.0*0.20 + 0.30
	intel["humint"] = clamp(intel["humint"]*0.982 + humint_target*0.018 + Deterministic.next_range(-0.005,0.005), 0.10, 0.95)

	# OSINT - اطلاعات باز - دیجیتال + رسانه آزاد
	var media_free = state.get("culture",{}).get("media_freedom",0.5)
	intel["osint"] = clamp(intel["osint"]*0.975 + (digital*0.40 + media_free*0.30 + edu_q*0.20 + 0.10)*0.025, 0.20, 0.98)

	# IMINT - تصویری - ماهواره + پهپاد
	var sat_count = float(mil.get("equipment_detail",{}).get("satellites_recon",4))
	var uav_recon = float(mil.get("equipment_detail",{}).get("uav_recon",150))
	intel["imint"] = clamp(intel["imint"]*0.980 + (sat_count/10.0*0.40 + uav_recon/200.0*0.30 + digital*0.20 + 0.10)*0.02, 0.15, 0.96)
	intel["satellite_coverage"] = clamp(sat_count/10.0*0.6 + digital*0.2 + 0.2, 0.10, 0.95)
	intel["drone_surveillance"] = clamp(uav_recon/200.0*0.5 + digital*0.3 + 0.2, 0.10, 0.95)

	# COMINT / ELINT - ارتباطات و الکترونیک دشمن
	intel["comint"] = clamp(intel["comint"]*0.982 + (intel["sigint"]*0.5 + digital*0.3 + 0.2)*0.018, 0.10, 0.95)
	intel["elint"] = clamp(intel["elint"]*0.983 + (float(mil.get("equipment_detail",{}).get("ew_systems",40))/40.0*0.4 + intel["sigint"]*0.3 + 0.3)*0.017, 0.10, 0.95)

	# ==================== سایبری - تهاجمی و تدافعی ====================
	var cyber_units = float(mil.get("equipment_detail",{}).get("cyber_units",15))
	var cyber_target_off = cyber_units/20.0*0.35 + digital*0.30 + edu_q*0.20 + military_tech*0.15
	intel["cyber_offense"] = clamp(intel["cyber_offense"]*0.980 + cyber_target_off*0.020, 0.10, 0.96)

	var cyber_def_target = cyber_units/20.0*0.25 + digital*0.30 + edu_q*0.20 + stability*0.15 + 0.10
	intel["cyber_defense"] = clamp(intel["cyber_defense"]*0.982 + cyber_def_target*0.018, 0.10, 0.96)
	intel["cyber_readiness"] = clamp(intel["cyber_offense"]*0.4 + intel["cyber_defense"]*0.6, 0.10, 0.96)

	# جنگ الکترونیک - اخلالگر
	intel["ew_capability"] = clamp(intel["ew_capability"]*0.984 + (float(mil.get("equipment_detail",{}).get("ew_systems",40))/40.0*0.4 + intel["sigint"]*0.2 + digital*0.2 + 0.2)*0.016, 0.10, 0.95)

	# ==================== ضد اطلاعات و ضد تروریسم ====================
	var counter_target = (1.0 - corruption)*0.25 + stability*0.25 + intel["power"]/100.0*0.25 + 0.25
	intel["counter_intel"] = clamp(intel["counter_intel"]*0.985 + counter_target*0.015, 0.15, 0.95)

	var terror_threat = pol.get("tension",0.35)*0.4 + (1.0 - stability)*0.3 + 0.1
	intel["counter_terror"] = clamp(intel["counter_terror"]*0.983 + (1.0 - terror_threat)*0.5*0.017 + intel["humint"]*0.3*0.017, 0.20, 0.96)

	# خطر نفوذ - فساد + نارضایتی + جنگ سایبری
	var infiltration_target = corruption*0.35 + (1.0 - stability)*0.25 + (1.0 - intel["counter_intel"])*0.25 + 0.05
	if is_at_war:
		infiltration_target += 0.15
	intel["infiltration_risk"] = clamp(intel["infiltration_risk"]*0.96 + infiltration_target*0.04, 0.02, 0.65)

	# اشتراک اطلاعات با متحدان
	var alliance_count = float(world.get("alliances",[]).size())
	intel["intel_sharing_allies"] = clamp(alliance_count*0.15 + intel["power"]/100.0*0.3 + 0.2, 0.10, 0.90)

	# ==================== عملیات روانی و جنگ اطلاعاتی ====================
	intel["psyops"] = clamp(intel["psyops"]*0.988 + (intel["humint"]*0.3 + intel["osint"]*0.3 + digital*0.2 + 0.2)*0.012, 0.10, 0.90)
	intel["disinfo_defense"] = clamp(intel["disinfo_defense"]*0.986 + (edu_q*0.3 + intel["osint"]*0.2 + digital*0.2 + stability*0.2 + 0.1)*0.014, 0.15, 0.95)

	# سطح تهدید کلی
	var external_threat = 0.0
	for war_target in world.get("wars",{}).keys():
		external_threat += 0.15
	external_threat += (1.0 - diplomacy.get("influence",40.0)/100.0)*0.2 + pol.get("tension",0.35)*0.2
	intel["threat_external"] = clamp(external_threat, 0.05, 0.95)
	intel["threat_internal"] = clamp((1.0 - stability)*0.4 + pol.get("tension",0.35)*0.3 + intel["infiltration_risk"]*0.3, 0.05, 0.85)
	intel["threat_level"] = clamp(intel["threat_external"]*0.55 + intel["threat_internal"]*0.45, 0.05, 0.95)

	# عملیات فعال - تعداد
	intel["operations_active"] = int(clamp(intel["power"]/100.0*8.0 + (1.0 if is_at_war else 0.0)*4.0, 1.0, 15.0))

	# کارآمدی بودجه
	intel["budget_efficiency"] = clamp((1.0 - corruption*0.5)*0.6 + edu_q*0.2 + intel["power"]/100.0*0.2, 0.20, 0.95)

	# ==================== اثرات جنگی واقعی ====================
	var recon_bonus = 0.0
	if is_at_war:
		# ISR خوب = برتری اطلاعاتی، پیشرفت سریع‌تر، تلفات کمتر
		var isr_combined = intel["sigint"]*0.20 + intel["imint"]*0.25 + intel["humint"]*0.15 + intel["drone_surveillance"]*0.20 + intel["satellite_coverage"]*0.20
		recon_bonus = isr_combined*0.15
		# جنگ الکترونیک موفق = اخلال دشمن
		if intel["ew_capability"] > 0.70 and Deterministic.chance(0.012):
			events.append({"type":"ew_success","ew": intel["ew_capability"], "message":"اخلال الکترونیک موفق - رادار دشمن کور شد"})

		# حمله سایبری
		if intel["cyber_offense"] > 0.65 and Deterministic.chance(0.010):
			events.append({"type":"cyber_attack_success","cyber": intel["cyber_offense"], "message":"حمله سایبری به زیرساخت دشمن - نیروگاه خاموش شد"})

		# حمله سایبری دشمن به ما
		if intel["cyber_defense"] < 0.45 and Deterministic.chance(0.013):
			events.append({"type":"cyber_attack_on_us","defense": intel["cyber_defense"], "message":"حمله سایبری دشمن - اخلال در شبکه بانکی"})
			econ["gdp"] = float(econ.get("gdp",500e9)) * 0.9998

		# عملیات پهپادی شناسایی
		if intel["drone_surveillance"] > 0.65 and Deterministic.chance(0.015):
			events.append({"type":"drone_recon_success","drone": intel["drone_surveillance"], "message":"شناسایی پهپادی - کاروان زرهی دشمن لو رفت"})

	# رویدادهای عمومی اطلاعاتی
	if intel["infiltration_risk"] > 0.40 and Deterministic.chance(0.011):
		events.append({"type":"infiltration_detected","risk": intel["infiltration_risk"], "message":"کشف شبکه نفوذ - جاسوس دوجانبه دستگیر شد"})

	if intel["threat_level"] > 0.70 and Deterministic.chance(0.012):
		events.append({"type":"high_threat_level","threat": intel["threat_level"], "message":"سطح تهدید بالا - آماده‌باش اطلاعاتی"})

	if intel["counter_terror"] < 0.45 and Deterministic.chance(0.010):
		events.append({"type":"terror_threat","counter": intel["counter_terror"], "message":"تهدید تروریستی - خنثی‌سازی بمب در پایتخت"})

	if intel["disinfo_defense"] < 0.40 and Deterministic.chance(0.013):
		events.append({"type":"disinfo_wave","defense": intel["disinfo_defense"], "message":"موج اخبار جعلی - روایت دشمن در شبکه‌های اجتماعی پخش شد"})

	if intel["satellite_coverage"] > 0.75 and tick % 180 == 0 and Deterministic.chance(0.02):
		events.append({"type":"satellite_intel_breakthrough","coverage": intel["satellite_coverage"], "message":"پوشش ماهواره‌ای کامل - هر تحرک دشمن رصد می‌شود"})

	if intel["psyops"] > 0.70 and is_at_war and Deterministic.chance(0.009):
		events.append({"type":"psyops_success","psyops": intel["psyops"], "message":"عملیات روانی موفق - روحیه دشمن فروپاشید"})

	# اثر بر ثبات و امنیت و دیپلماسی
	pol["stability"] = clamp(float(pol.get("stability",0.60)) + (intel["counter_intel"]-0.5)*0.0003 - intel["infiltration_risk"]*0.0004, 0.05, 0.95)
	var security_state = state.get("security", {})
	security_state["public_security"] = clamp(float(security_state.get("public_security",0.70)) + intel["counter_terror"]*0.0002, 0.10, 0.95)
	state["security"] = security_state

	state["intelligence"] = intel
	state["politics"] = pol
	state["economy"] = econ
	
	# --- لایه عمیق دوم: اقتصاد سیاسی، شبکه اجتماعی، فناوری دوگانه، تاب‌آوری اقلیمی ---
	var _extra_politics = state.get("politics",{})
	var _extra_econ = state.get("economy",{})
	var _extra_pop = state.get("population",{})
	var _extra_env = state.get("environment",{})
	var _extra_tech = state.get("technology",{})
	var _extra_culture = state.get("culture",{})

	var _trust = float(_extra_politics.get("trust",0.55))
	var _corruption = float(_extra_politics.get("corruption",0.30))
	var _stability = float(_extra_politics.get("stability",0.60))
	var _happiness = float(_extra_pop.get("happiness",0.60))
	var _gini = float(state.get("welfare",{}).get("gini",0.38))
	var _digital = float(_extra_tech.get("branches",{}).get("دیجیتال",0.20) if _extra_tech.has("branches") else 0.20)
	var _green = float(_extra_env.get("green_energy",0.20) if _extra_env.has("green_energy") else 0.20)

	# اثر اعتماد بر کارآمدی
	var _sys_q = 0.60
	if state.has("intelligence") and state["intelligence"] is Dictionary:
		_sys_q = float(state["intelligence"].get("quality",0.60) if state["intelligence"].has("quality") else state["intelligence"].get("efficiency",0.60) if state["intelligence"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("intelligence") and state["intelligence"] is Dictionary:
		state["intelligence"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_intelligence_deep","gini": _gini, "message":"نابرابری اثر بر intelligence - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_intelligence","digital": _digital, "message":"فناوری دوگانه در intelligence - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_intelligence","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی intelligence"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_intelligence","capital": _social_capital, "message":"سرمایه اجتماعی پایین در intelligence"})

	# اثر تورمی بر هزینه نگهداری
	var _inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("intelligence") and state["intelligence"] is Dictionary and state["intelligence"].has("maintenance_cost"):
		state["intelligence"]["maintenance_cost"] = float(state["intelligence"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
	# --- لایه عمیق دوم: اقتصاد سیاسی، شبکه اجتماعی، فناوری دوگانه، تاب‌آوری اقلیمی ---
	_extra_politics = state.get("politics",{})
	_extra_econ = state.get("economy",{})
	_extra_pop = state.get("population",{})
	_extra_env = state.get("environment",{})
	_extra_tech = state.get("technology",{})
	_extra_culture = state.get("culture",{})

	_trust = float(_extra_politics.get("trust",0.55))
	_corruption = float(_extra_politics.get("corruption",0.30))
	_stability = float(_extra_politics.get("stability",0.60))
	_happiness = float(_extra_pop.get("happiness",0.60))
	_gini = float(state.get("welfare",{}).get("gini",0.38))
	_digital = float(_extra_tech.get("branches",{}).get("دیجیتال",0.20) if _extra_tech.has("branches") else 0.20)
	_green = float(_extra_env.get("green_energy",0.20) if _extra_env.has("green_energy") else 0.20)

	# اثر اعتماد بر کارآمدی
	_sys_q = 0.60
	if state.has("intelligence") and state["intelligence"] is Dictionary:
		_sys_q = float(state["intelligence"].get("quality",0.60) if state["intelligence"].has("quality") else state["intelligence"].get("efficiency",0.60) if state["intelligence"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("intelligence") and state["intelligence"] is Dictionary:
		state["intelligence"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_intelligence_deep","gini": _gini, "message":"نابرابری اثر بر intelligence - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_intelligence","digital": _digital, "message":"فناوری دوگانه در intelligence - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_intelligence","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی intelligence"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_intelligence","capital": _social_capital, "message":"سرمایه اجتماعی پایین در intelligence"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("intelligence") and state["intelligence"] is Dictionary and state["intelligence"].has("maintenance_cost"):
		state["intelligence"]["maintenance_cost"] = float(state["intelligence"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
	# --- لایه عمیق دوم: اقتصاد سیاسی، شبکه اجتماعی، فناوری دوگانه، تاب‌آوری اقلیمی ---
	_extra_politics = state.get("politics",{})
	_extra_econ = state.get("economy",{})
	_extra_pop = state.get("population",{})
	_extra_env = state.get("environment",{})
	_extra_tech = state.get("technology",{})
	_extra_culture = state.get("culture",{})

	_trust = float(_extra_politics.get("trust",0.55))
	_corruption = float(_extra_politics.get("corruption",0.30))
	_stability = float(_extra_politics.get("stability",0.60))
	_happiness = float(_extra_pop.get("happiness",0.60))
	_gini = float(state.get("welfare",{}).get("gini",0.38))
	_digital = float(_extra_tech.get("branches",{}).get("دیجیتال",0.20) if _extra_tech.has("branches") else 0.20)
	_green = float(_extra_env.get("green_energy",0.20) if _extra_env.has("green_energy") else 0.20)

	# اثر اعتماد بر کارآمدی
	_sys_q = 0.60
	if state.has("intelligence") and state["intelligence"] is Dictionary:
		_sys_q = float(state["intelligence"].get("quality",0.60) if state["intelligence"].has("quality") else state["intelligence"].get("efficiency",0.60) if state["intelligence"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("intelligence") and state["intelligence"] is Dictionary:
		state["intelligence"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_intelligence_deep","gini": _gini, "message":"نابرابری اثر بر intelligence - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_intelligence","digital": _digital, "message":"فناوری دوگانه در intelligence - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_intelligence","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی intelligence"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_intelligence","capital": _social_capital, "message":"سرمایه اجتماعی پایین در intelligence"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("intelligence") and state["intelligence"] is Dictionary and state["intelligence"].has("maintenance_cost"):
		state["intelligence"]["maintenance_cost"] = float(state["intelligence"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
	# --- لایه عمیق دوم: اقتصاد سیاسی، شبکه اجتماعی، فناوری دوگانه، تاب‌آوری اقلیمی ---
	_extra_politics = state.get("politics",{})
	_extra_econ = state.get("economy",{})
	_extra_pop = state.get("population",{})
	_extra_env = state.get("environment",{})
	_extra_tech = state.get("technology",{})
	_extra_culture = state.get("culture",{})

	_trust = float(_extra_politics.get("trust",0.55))
	_corruption = float(_extra_politics.get("corruption",0.30))
	_stability = float(_extra_politics.get("stability",0.60))
	_happiness = float(_extra_pop.get("happiness",0.60))
	_gini = float(state.get("welfare",{}).get("gini",0.38))
	_digital = float(_extra_tech.get("branches",{}).get("دیجیتال",0.20) if _extra_tech.has("branches") else 0.20)
	_green = float(_extra_env.get("green_energy",0.20) if _extra_env.has("green_energy") else 0.20)

	# اثر اعتماد بر کارآمدی
	_sys_q = 0.60
	if state.has("intelligence") and state["intelligence"] is Dictionary:
		_sys_q = float(state["intelligence"].get("quality",0.60) if state["intelligence"].has("quality") else state["intelligence"].get("efficiency",0.60) if state["intelligence"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("intelligence") and state["intelligence"] is Dictionary:
		state["intelligence"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_intelligence_deep","gini": _gini, "message":"نابرابری اثر بر intelligence - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_intelligence","digital": _digital, "message":"فناوری دوگانه در intelligence - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_intelligence","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی intelligence"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_intelligence","capital": _social_capital, "message":"سرمایه اجتماعی پایین در intelligence"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("intelligence") and state["intelligence"] is Dictionary and state["intelligence"].has("maintenance_cost"):
		state["intelligence"]["maintenance_cost"] = float(state["intelligence"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	return {"success":true,"state":state,"events":events}
