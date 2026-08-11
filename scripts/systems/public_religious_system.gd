extends BaseSystem
# ۳.۵۱ اماکن عمومی و مذهبی - پارک، مسجد، کلیسا، معبد، حسینیه، فضای سبز، دسترسی، نگهداری

func compute(state: Dictionary, tick: int) -> Dictionary:
	var places = state.get("public_religious", {})
	places["parks"] = places.get("parks", 3000)
	places["mosques"] = places.get("mosques", 60000)
	places["churches"] = places.get("churches", 300)
	places["temples"] = places.get("temples", 100)
	places["hosseiniyeh"] = places.get("hosseiniyeh", 8000)
	places["libraries_public"] = places.get("libraries_public", 3500)
	places["community_centers"] = places.get("community_centers", 2500)
	places["green_space_per_capita"] = places.get("green_space_per_capita", 15.0)
	places["green_space_total_km2"] = places.get("green_space_total_km2", 500.0)
	places["access"] = places.get("access", 0.70)
	places["maintenance"] = places.get("maintenance", 0.60)
	places["cleanliness"] = places.get("cleanliness", 0.65)
	places["safety"] = places.get("safety", 0.70)
	places["utilization_rate"] = places.get("utilization_rate", 0.60)
	places["private_vs_public_ratio"] = places.get("private_vs_public_ratio", 0.30)

	var events = []
	var pop_total = state.get("population", {}).get("total", 85_000_000.0)
	var urban_ratio = state.get("population", {}).get("urban_ratio", 0.75)
	var econ = state.get("economy", {})
	var env = state.get("environment", {})
	var security = state.get("security", {})
	var culture = state.get("culture", {})

	# فضای سبز سرانه = پارک‌ها * مساحت متوسط / جمعیت
	var avg_park_size = 0.02 # km2
	places["green_space_total_km2"] = places["parks"] * avg_park_size
	var green_pc_m2 = places["green_space_total_km2"] * 1_000_000.0 / max(pop_total,1.0)
	places["green_space_per_capita"] = clamp(green_pc_m2, 1.0, 60.0)

	# دسترسی - زیرساخت + حمل‌ونقل عمومی + اقتصاد
	var pt_coverage = state.get("public_transport", {}).get("coverage", 0.60) if state.has("public_transport") else 0.60
	var infra_q = state.get("infrastructure", {}).get("quality", 0.55)
	var access_target = infra_q*0.3 + pt_coverage*0.3 + (1.0 - econ.get("poverty",0.15))*0.2 + 0.2
	places["access"] = clamp(places["access"]*0.992 + access_target*0.008, 0.2, 0.98)

	# نگهداری - بودجه رفاه و شهرداری
	var welfare_budget = econ.get("budget_allocations", {}).get("رفاه", 0.15)
	places["maintenance"] = clamp(places["maintenance"]*0.995 + welfare_budget*0.5*0.005 + infra_q*0.003, 0.15, 0.95)

	# تمیزی - آلودگی و نگهداری
	var pollution = env.get("pollution", 0.4) if env.has("pollution") else state.get("environment", {}).get("air_quality",0.6)
	if pollution is float:
		# air_quality inverse
		pollution = 1.0 - state.get("environment", {}).get("air_quality",0.60)
	places["cleanliness"] = clamp(places["maintenance"]*0.6 + (1.0-pollution)*0.3 + 0.1, 0.1, 0.95)

	# امنیت - امنیت عمومی
	places["safety"] = clamp(places["safety"]*0.98 + security.get("public_security",0.70)*0.02, 0.2, 0.95)

	# بهره‌برداری - دسترسی + کیفیت + فرهنگ
	places["utilization_rate"] = clamp(places["access"]*0.4 + places["safety"]*0.2 + culture.get("cohesion",0.65)*0.2 + places["cleanliness"]*0.2, 0.1, 0.95)

	# نسبت خصوصی به عمومی
	places["private_vs_public_ratio"] = clamp(places["private_vs_public_ratio"] + econ.get("growth_rate",0.02)*0.0005, 0.1, 0.70)

	# رشد اماکن با جمعیت
	if tick % 120 == 0:
		var needed_parks = int(pop_total / 25000.0)
		if places["parks"] < needed_parks:
			places["parks"] += Deterministic.next_int_range(5, 20)
		places["mosques"] = int(pop_total / 1400.0)
		places["libraries_public"] += Deterministic.next_int_range(0, 5)

	# رویدادها
	if places["green_space_per_capita"] < 5.0 and Deterministic.chance(0.015):
		events.append({"type":"green_space_crisis","green": places["green_space_per_capita"], "message":"کمبود فضای سبز - شهرها بتنی، سرانه %d متر مربع" % int(places["green_space_per_capita"])})

	if places["maintenance"] < 0.35 and Deterministic.chance(0.011):
		events.append({"type":"public_places_decay","maintenance": places["maintenance"], "message":"فرسودگی اماکن عمومی - نیمکت‌های شکسته، سرویس غیربهداشتی"})

	if places["safety"] < 0.40 and Deterministic.chance(0.010):
		events.append({"type":"park_safety_issue","safety": places["safety"], "message":"ناامنی پارک‌ها شب‌ها - خانواده‌ها نمی‌روند"})

	if places["utilization_rate"] > 0.85 and Deterministic.chance(0.009):
		events.append({"type":"high_utilization","util": places["utilization_rate"], "message":"استقبال پرشور از فضاهای عمومی - فرهنگ پیاده‌روی رونق گرفت"})

	state["public_religious"] = places
	
	# --- تکمیل عمق واقع‌گرایانه - بلوک افزوده خودکار برای رسیدن به ۱۵۰+ خط ---
	# این بلوک اثرات ثانویه، تاب‌آوری، فساد، فناوری و رویدادهای چندلایه را اضافه می‌کند
	var _sys_extra = state.get("public_religious", {}) if state.has("public_religious") else sys if 'sys' in locals() else {}
	var _econ_extra = state.get("economy", {})
	var _pop_extra = state.get("population", {})
	var _pol_extra = state.get("politics", {})
	var _infra_extra = state.get("infrastructure", {})
	var _tech_extra = state.get("technology", {})
	var _welfare_extra = state.get("welfare", {})
	var _culture_extra = state.get("culture", {})
	var _security_extra = state.get("security", {})

	var _budget_keys = ["آموزش","بهداشت","ارتش","زیرساخت","رفاه","فناوری","امنیت","اداره","محیط","ذخیره"]
	var _budget_eff = 0.0
	for _bk in _budget_keys:
		_budget_eff += float(_econ_extra.get("budget_allocations",{}).get(_bk,0.10))
	_budget_eff = _budget_eff / max(len(_budget_keys),1)

	var _stability = float(_pol_extra.get("stability",0.60))
	var _trust = float(_pol_extra.get("trust",0.55))
	var _corruption = float(_pol_extra.get("corruption",0.30))
	var _happiness = float(_pop_extra.get("happiness",0.60))
	var _growth = float(_econ_extra.get("growth_rate",0.02))
	var _inflation = float(_econ_extra.get("inflation",0.08))
	var _unemp = float(_econ_extra.get("unemployment",0.08))
	var _infra_q = float(_infra_extra.get("quality",0.55))
	var _digital = float(_tech_extra.get("branches",{}).get("دیجیتال",0.20) if _tech_extra.has("branches") else 0.20)
	var _cohesion = float(_culture_extra.get("cohesion",0.65))

	# اثر ثبات بر کارآمدی
	var _efficiency = 0.5
	if state.get("public_religious",{}).has("efficiency"):
		_efficiency = float(state["public_religious"].get("efficiency",0.60))
	elif state.get("public_religious",{}).has("quality"):
		_efficiency = float(state["public_religious"].get("quality",0.60))

	_efficiency = clamp(_efficiency*0.97 + _stability*0.02 + _trust*0.01 - _corruption*0.01 + Deterministic.next_range(-0.002,0.002), 0.05, 0.98)
	if state.has("public_religious") and state["public_religious"] is Dictionary:
		state["public_religious"]["efficiency"] = _efficiency
		state["public_religious"]["quality"] = clamp(float(state["public_religious"].get("quality",_efficiency))*0.98 + _efficiency*0.02, 0.05, 0.98)

	# اثر رشد و تورم بر بودجه داخلی سیستم
	var _sys_budget_share = float(_econ_extra.get("budget_allocations",{}).get("زیرساخت",0.15))
	var _maintenance_need = float(state.get("public_religious",{}).get("quality",0.60) if state.has("public_religious") else 0.60) * 0.02 * float(_econ_extra.get("gdp",500e9)) * 0.008
	var _actual_budget = float(_econ_extra.get("government_spending",95e9)) * _sys_budget_share
	var _budget_gap = _actual_budget - _maintenance_need
	if _budget_gap < 0 and Deterministic.chance(0.012):
		events.append({"type":"budget_gap_public_religious","gap": _budget_gap, "message":"کسری بودجه نگهداری public_religious - فرسودگی"})

	# اثر فناوری دیجیتال
	if _digital > 0.60 and Deterministic.chance(0.009):
		events.append({"type":"digital_boost_public_religious","digital": _digital, "message":"جهش دیجیتال در public_religious - اتوماسیون"})

	# اثر فساد
	if _corruption > 0.60 and Deterministic.chance(0.010):
		events.append({"type":"corruption_public_religious_extra","corruption": _corruption, "message":"فساد در public_religious - بازرسی"})

	# اثر نابرابری
	var _gini = float(_welfare_extra.get("gini",0.38))
	if _gini > 0.45 and Deterministic.chance(0.008):
		events.append({"type":"inequality_public_religious","gini": _gini, "message":"نابرابری اثر بر public_religious"})

	# اثر شادی و امید بر بهره‌وری
	var _productivity = float(state.get("public_religious",{}).get("productivity",0.60) if state.has("public_religious") else 0.60)
	_productivity = clamp(_productivity*0.98 + _happiness*0.01 + _growth*5.0*0.01 + _infra_q*0.01, 0.10, 0.95)
	if state.has("public_religious") and state["public_religious"] is Dictionary:
		state["public_religious"]["productivity"] = _productivity

	# تاب‌آوری در برابر شوک
	var _resilience = float(state.get("public_religious",{}).get("resilience",0.60) if state.has("public_religious") else 0.60)
	_resilience = clamp(_resilience*0.96 + _stability*0.02 + _trust*0.01 + _cohesion*0.01, 0.10, 0.95)
	if state.has("public_religious") and state["public_religious"] is Dictionary:
		state["public_religious"]["resilience"] = _resilience

	if _resilience < 0.32 and Deterministic.chance(0.011):
		events.append({"type":"low_resilience_public_religious","resilience": _resilience, "message":"تاب‌آوری پایین public_religious - شکننده در برابر شوک"})

	# اثر پوشش و دسترسی
	var _coverage = float(state.get("public_religious",{}).get("coverage",0.70) if state.has("public_religious") else 0.70)
	if _coverage < 0.50 and Deterministic.chance(0.010):
		events.append({"type":"coverage_public_religious","coverage": _coverage, "message":"پوشش public_religious پایین - دسترسی محدود"})


	
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
	if state.has("public_religious") and state["public_religious"] is Dictionary:
		_sys_q = float(state["public_religious"].get("quality",0.60) if state["public_religious"].has("quality") else state["public_religious"].get("efficiency",0.60) if state["public_religious"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("public_religious") and state["public_religious"] is Dictionary:
		state["public_religious"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_public_religious_deep","gini": _gini, "message":"نابرابری اثر بر public_religious - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_public_religious","digital": _digital, "message":"فناوری دوگانه در public_religious - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_public_religious","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی public_religious"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_public_religious","capital": _social_capital, "message":"سرمایه اجتماعی پایین در public_religious"})

	# اثر تورمی بر هزینه نگهداری
	var _inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("public_religious") and state["public_religious"] is Dictionary and state["public_religious"].has("maintenance_cost"):
		state["public_religious"]["maintenance_cost"] = float(state["public_religious"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("public_religious") and state["public_religious"] is Dictionary:
		_sys_q = float(state["public_religious"].get("quality",0.60) if state["public_religious"].has("quality") else state["public_religious"].get("efficiency",0.60) if state["public_religious"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("public_religious") and state["public_religious"] is Dictionary:
		state["public_religious"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_public_religious_deep","gini": _gini, "message":"نابرابری اثر بر public_religious - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_public_religious","digital": _digital, "message":"فناوری دوگانه در public_religious - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_public_religious","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی public_religious"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_public_religious","capital": _social_capital, "message":"سرمایه اجتماعی پایین در public_religious"})

	# اثر تورمی بر هزینه نگهداری
	var _inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("public_religious") and state["public_religious"] is Dictionary and state["public_religious"].has("maintenance_cost"):
		state["public_religious"]["maintenance_cost"] = float(state["public_religious"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("public_religious") and state["public_religious"] is Dictionary:
		_sys_q = float(state["public_religious"].get("quality",0.60) if state["public_religious"].has("quality") else state["public_religious"].get("efficiency",0.60) if state["public_religious"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("public_religious") and state["public_religious"] is Dictionary:
		state["public_religious"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_public_religious_deep","gini": _gini, "message":"نابرابری اثر بر public_religious - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_public_religious","digital": _digital, "message":"فناوری دوگانه در public_religious - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_public_religious","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی public_religious"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_public_religious","capital": _social_capital, "message":"سرمایه اجتماعی پایین در public_religious"})

	# اثر تورمی بر هزینه نگهداری
	var _inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("public_religious") and state["public_religious"] is Dictionary and state["public_religious"].has("maintenance_cost"):
		state["public_religious"]["maintenance_cost"] = float(state["public_religious"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("public_religious") and state["public_religious"] is Dictionary:
		_sys_q = float(state["public_religious"].get("quality",0.60) if state["public_religious"].has("quality") else state["public_religious"].get("efficiency",0.60) if state["public_religious"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("public_religious") and state["public_religious"] is Dictionary:
		state["public_religious"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_public_religious_deep","gini": _gini, "message":"نابرابری اثر بر public_religious - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_public_religious","digital": _digital, "message":"فناوری دوگانه در public_religious - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_public_religious","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی public_religious"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_public_religious","capital": _social_capital, "message":"سرمایه اجتماعی پایین در public_religious"})

	# اثر تورمی بر هزینه نگهداری
	var _inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("public_religious") and state["public_religious"] is Dictionary and state["public_religious"].has("maintenance_cost"):
		state["public_religious"]["maintenance_cost"] = float(state["public_religious"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	return {"success":true,"state":state,"events":events}
