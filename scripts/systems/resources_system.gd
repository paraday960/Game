extends BaseSystem
# منابع و انرژی - ۳.۹ - نسخه عمیق واقعی - لجستیک جنگی، سوخت، مهمات، زنجیره تامین، ذخایر راهبردی

func compute(state: Dictionary, tick: int) -> Dictionary:
	var res = state.get("resources", {})
	var econ = state.get("economy", {})
	var pop = state.get("population", {})
	var infra = state.get("infrastructure", {})
	var tech = state.get("technology", {})
	var mil = state.get("military", {})
	var trade = state.get("trade", {})
	var world = state.get("world", {})

	res["inventory"] = res.get("inventory", {"برق":100.0,"نفت":80.0,"گاز":70.0,"آب":90.0,"غذا":85.0,"آهن":60.0,"مس":50.0,"مواد_صنعتی":65.0})
	res["capacity"] = res.get("capacity", {"برق":200.0,"نفت":150.0,"گاز":150.0,"آب":150.0,"غذا":150.0,"آهن":120.0,"مس":100.0,"مواد_صنعتی":120.0})
	res["production"] = res.get("production", {"برق":15.0,"نفت":8.0,"گاز":6.0,"آب":12.0,"غذا":10.0,"آهن":4.0,"مس":2.0,"مواد_صنعتی":5.0})
	res["demand"] = res.get("demand", {"برق":12.0,"نفت":6.0,"گاز":5.0,"آب":10.0,"غذا":9.0,"آهن":3.0,"مس":1.5,"مواد_صنعتی":4.0})
	res["self_sufficiency"] = res.get("self_sufficiency", 0.85)
	res["energy_crisis"] = res.get("energy_crisis", false)
	res["food_crisis"] = res.get("food_crisis", false)
	res["strategic_reserves"] = res.get("strategic_reserves", {"نفت":30.0,"غذا":45.0,"آب":20.0,"مهمات":15.0})
	res["import_dependency"] = res.get("import_dependency", {"نفت":0.20,"غذا":0.15,"مواد_صنعتی":0.35})
	res["extraction_rate"] = res.get("extraction_rate", {"نفت":0.02,"گاز":0.02,"آهن":0.01})
	res["refining_capacity"] = res.get("refining_capacity", {"نفت":80.0,"مواد_صنعتی":70.0})
	res["distribution_efficiency"] = res.get("distribution_efficiency", 0.75)
	res["blackout_risk"] = res.get("blackout_risk", 0.10)
	res["water_stress"] = res.get("water_stress", 0.30)

	var events = []

	var is_at_war = not world.get("wars", {}).is_empty()
	var mobilization = mil.get("mobilization", {}).get("level", 0)
	var logistics = mil.get("logistics_detail", {})
	var infra_q = infra.get("quality", 0.55)
	var infra_capacity = infra.get("capacity", 0.60)
	var tech_energy = tech.get("branches", {}).get("انرژی_پاک", 0.15)
	var tech_industry = tech.get("branches", {}).get("صنعت", 0.20)
	var gdp = econ.get("gdp", 500e9)
	var pop_total = pop.get("total", 85_000_000.0)

	# ==================== تولید - استخراج + پالایش + فناوری ====================
	for resource in res["production"].keys():
		var base_prod = float(res["production"][resource])
		var capacity = float(res["capacity"][resource])
		var inv = float(res["inventory"][resource])
		var demand = float(res["demand"][resource])

		# نرخ استخراج - منابع تجدیدناپذیر کاهش با زمان اگر سرمایه‌گذاری نشود
		var extraction = float(res["extraction_rate"].get(resource, 0.01)) if res["extraction_rate"].has(resource) else 0.01
		var depletion = 0.0
		if resource in ["نفت","گاز","آهن","مس"]:
			depletion = extraction * 0.5 / 365.0
			res["inventory"][resource] = max(res["inventory"][resource] - depletion, 5.0)

		# تولید - تابع سرمایه‌گذاری، فناوری، زیرساخت، نیروی کار
		var invest_factor = econ.get("budget_allocations",{}).get("زیرساخت",0.18)*1.5 + 0.5
		var tech_factor = 1.0
		if resource == "برق": tech_factor = 0.7 + tech_energy*0.6 + tech_industry*0.2
		elif resource == "نفت" or resource == "گاز": tech_factor = 0.8 + tech_industry*0.4
		elif resource == "غذا": tech_factor = 0.6 + state.get("agriculture",{}).get("production",100.0)/100.0*0.3 + tech_energy*0.1
		else: tech_factor = 0.7 + tech_industry*0.5

		var prod_change = (invest_factor*0.3 + tech_factor*0.3 + infra_q*0.2 + 0.2) * 0.01 - depletion
		# جنگ - تولید نظامی افزایش، غیرنظامی کاهش اگر بسیج بالا
		if is_at_war:
			if resource in ["نفت","مواد_صنعتی","آهن","برق"]:
				prod_change += mobilization*0.005 # اولویت نظامی
			elif resource == "غذا" and mobilization >= 4:
				prod_change -= 0.008 # کمبود کارگر کشاورزی

		res["production"][resource] = clamp(float(res["production"][resource]) + prod_change + Deterministic.next_range(-0.02,0.03), 1.0, capacity*1.2)

		# پالایش - برای نفت و مواد صنعتی
		if res["refining_capacity"].has(resource):
			var refining = float(res["refining_capacity"][resource])
			var refining_eff = infra_q*0.4 + tech_industry*0.3 + 0.3
			res["refining_capacity"][resource] = clamp(refining*0.999 + refining_eff*0.01, 20.0, 200.0)

		# تقاضا - جمعیت + GDP + فصل + جنگ
		var demand_change = 0.0
		demand_change += (pop_total/85e6 -1.0)*0.1 + (gdp/500e9 -1.0)*0.05
		demand_change += mobilization*0.02 if resource in ["نفت","غذا","برق","مواد_صنعتی"] else 0.0
		if is_at_war and resource in ["نفت","مهمات","مواد_صنعتی"]:
			demand_change += 0.08
		# فصل - برق تابستان و زمستان بیشتر
		var season = state.get("clock",{}).get("season","بهار")
		if resource == "برق":
			if season == "تابستان" or season == "زمستان":
				demand_change += 0.15
		elif resource == "آب" and season == "تابستان":
			demand_change += 0.20

		res["demand"][resource] = clamp(float(res["demand"][resource]) + demand_change/365.0 + Deterministic.next_range(-0.01,0.02), 1.0, 200.0)

		# موجودی = تولید - تقاضا + واردات - صادرات
		var net = float(res["production"][resource]) - float(res["demand"][resource])
		# واردات اگر کمبود
		var import_dep = float(res["import_dependency"].get(resource,0.20)) if res["import_dependency"].has(resource) else 0.20
		if net < 0:
			var import_needed = -net * import_dep
			# اگر محاصره باشد واردات کم
			if logistics.get("is_blockaded",false) and resource in ["نفت","غذا","مواد_صنعتی"]:
				import_needed *= (1.0 - logistics.get("blockade_level",0.0))
			net += import_needed
			res["import_dependency"][resource] = clamp(import_dep + 0.0001, 0.05, 0.85)

		res["inventory"][resource] = clamp(float(res["inventory"][resource]) + net*0.05, 0.0, float(res["capacity"][resource]))

		# بحران - اگر موجودی < ۳۰٪ ظرفیت و تقاضا بالا
		if res["inventory"][resource] < 30.0 and res["demand"][resource] > 10.0:
			if resource == "برق" and res["inventory"]["برق"] < 20.0:
				res["energy_crisis"] = true
				res["blackout_risk"] = clamp(float(res.get("blackout_risk",0.10)) + 0.02, 0.05, 0.85)
				if Deterministic.chance(0.015):
					events.append({"type":"energy_crisis","inventory": res["inventory"]["برق"], "message":"بحران برق - ذخیره %.0f%% - خاموشی برنامه‌ریزی" % res["inventory"]["برق"]})
			elif resource == "غذا" and res["inventory"]["غذا"] < 35.0:
				res["food_crisis"] = true
				if Deterministic.chance(0.012):
					events.append({"type":"food_crisis","inventory": res["inventory"]["غذا"], "message":"بحران غذا - ذخیره %d روز" % int(res["inventory"]["غذا"])})

	# ==================== خودکفایی و ذخایر راهبردی ====================
	var total_prod = 0.0
	var total_demand = 0.0
	for k in res["production"].keys():
		total_prod += float(res["production"][k])
		total_demand += float(res["demand"][k])
	res["self_sufficiency"] = clamp(total_prod / max(total_demand,1.0), 0.20, 1.5)

	# ذخایر راهبردی - نفت، غذا، مهمات
	for reserve_key in res["strategic_reserves"].keys():
		var target_days = {"نفت":60.0,"غذا":90.0,"آب":30.0,"مهمات":30.0}.get(reserve_key,30.0)
		var current = float(res["strategic_reserves"][reserve_key])
		var prod = float(res["production"].get(reserve_key,10.0)) if res["production"].has(reserve_key) else 10.0
		var reserve_change = (prod*0.1 - 0.05) + (0.1 if is_at_war else 0.0) # در جنگ ذخیره بیشتر
		res["strategic_reserves"][reserve_key] = clamp(current + reserve_change + Deterministic.next_range(-0.1,0.2), 5.0, target_days*1.5)
		if res["strategic_reserves"][reserve_key] < target_days*0.5 and Deterministic.chance(0.010):
			events.append({"type":"strategic_reserve_low","resource": reserve_key, "reserve": res["strategic_reserves"][reserve_key], "message":"ذخیره راهبردی %s پایین - %d روز" % [reserve_key, int(res["strategic_reserves"][reserve_key])]})

	# کارآمدی توزیع - زیرساخت + امنیت
	var distribution_target = infra_q*0.35 + infra_capacity*0.25 + state.get("security",{}).get("public_security",0.70)*0.20 + 0.20
	res["distribution_efficiency"] = clamp(res["distribution_efficiency"]*0.97 + distribution_target*0.03, 0.20, 0.95)

	# استرس آبی
	var water_inv = float(res["inventory"].get("آب",90.0))
	var water_demand = float(res["demand"].get("آب",10.0))
	res["water_stress"] = clamp((water_demand*2.0 - water_inv)/100.0 + 0.2, 0.05, 0.90)
	if res["water_stress"] > 0.65 and Deterministic.chance(0.011):
		events.append({"type":"water_stress_crisis","stress": res["water_stress"], "message":"تنش آبی - %d٪ ظرفیت" % int((1.0-res["water_stress"])*100.0)})

	# خطر خاموشی - برق + گرما
	if res["energy_crisis"]:
		if res["inventory"]["برق"] > 50.0:
			res["energy_crisis"] = false
			res["blackout_risk"] = clamp(float(res["blackout_risk"])*0.8, 0.05, 0.85)
			events.append({"type":"energy_crisis_resolved","message":"بحران برق پایان یافت"})

	if res["food_crisis"]:
		if res["inventory"]["غذا"] > 60.0:
			res["food_crisis"] = false
			events.append({"type":"food_crisis_resolved","message":"بحران غذا پایان یافت"})

	# اثر بر اقتصاد و لجستیک نظامی
	if res["energy_crisis"]:
		econ["growth_rate"] = float(econ.get("growth_rate",0.02)) - 0.01
		mil["readiness"] = clamp(float(mil.get("readiness",0.70)) - 0.005, 0.10, 1.0)
	if res["food_crisis"]:
		pop["happiness"] = clamp(float(pop.get("happiness",0.60)) - 0.008, 0.05, 0.95)

	# لجستیک نظامی - سوخت و مهمات از منابع
	var logi = mil.get("logistics_detail", {})
	if not logi.is_empty():
		logi["fuel_stock_days"] = float(res["inventory"].get("نفت",80.0))/80.0*30.0
		logi["ammo_stock_days"] = float(res["inventory"].get("مواد_صنعتی",65.0))/65.0*25.0
		mil["logistics_detail"] = logi

	state["resources"] = res
	state["economy"] = econ
	state["population"] = pop
	state["military"] = mil
	
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
	if state.has("resources") and state["resources"] is Dictionary:
		_sys_q = float(state["resources"].get("quality",0.60) if state["resources"].has("quality") else state["resources"].get("efficiency",0.60) if state["resources"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("resources") and state["resources"] is Dictionary:
		state["resources"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_resources_deep","gini": _gini, "message":"نابرابری اثر بر resources - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_resources","digital": _digital, "message":"فناوری دوگانه در resources - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_resources","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی resources"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_resources","capital": _social_capital, "message":"سرمایه اجتماعی پایین در resources"})

	# اثر تورمی بر هزینه نگهداری
	var _inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("resources") and state["resources"] is Dictionary and state["resources"].has("maintenance_cost"):
		state["resources"]["maintenance_cost"] = float(state["resources"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
	return {"success":true,"state":state,"events":events}
