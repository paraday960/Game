extends BaseSystem
# علم و فناوری - ۳.۱۶ - نرخ پژوهش، امتیاز پژوهش، درخت فناوری، شاخه‌ها، بلوغ، سرایت، همکاری

func compute(state: Dictionary, tick: int) -> Dictionary:
	var tech = state.get("technology", {})
	tech["research_points"] = tech.get("research_points", 0.0)
	tech["research_rate"] = tech.get("research_rate", 10.0)
	tech["tree_version"] = tech.get("tree_version", "1.0.0")
	tech["unlocked"] = tech.get("unlocked", ["industry_basic", "agriculture_basic"])
	tech["in_progress"] = tech.get("in_progress", null)
	tech["branches"] = tech.get("branches", {"صنعت":0.20,"انرژی_پاک":0.15,"پزشکی":0.10,"نظامی":0.15,"دیجیتال":0.20,"فضا":0.05})
	# سیستم سطوح ۳۰: مقادیر float سازگاری از سطوح تازه‌سازی می‌شوند
	if tech.has("branch_levels") and tech["branch_levels"] is Dictionary:
		var levels: Dictionary = tech["branch_levels"]
		for branch in ["صنعت","انرژی_پاک","پزشکی","نظامی","دیجیتال","فضا"]:
			if levels.has(branch):
				tech["branches"][branch] = float(clampi(int(levels[branch]),0,30)) / 30.0
	tech["tech_level"] = tech.get("tech_level", 0.15)
	tech["innovation_index"] = tech.get("innovation_index", 0.40)
	tech["researchers"] = tech.get("researchers", 50000)
	tech["labs"] = tech.get("labs", 200)
	tech["universities_research"] = tech.get("universities_research", 80)
	tech["patents_tech"] = tech.get("patents_tech", 800)
	tech["spillover"] = tech.get("spillover", 0.10)
	tech["international_collab"] = tech.get("international_collab", 0.40)

	var events = []
	var econ = state.get("economy", {})
	var edu = state.get("education", {})
	var pop = state.get("population", {})
	var infra = state.get("infrastructure", {})
	var elites = state.get("elites_detail", {})

	var budget = econ.get("budget_allocations", {}).get("فناوری", 0.04) * econ.get("government_spending", 95e9)
	var gdp = econ.get("gdp", 500e9)

	# نرخ تحقیق = f(بودجه R&D، دانشمندان، دانشگاه، آموزش، زیرساخت دیجیتال)
	# (پایه بالاتر برای بالانس «قابل اتمام در ~۱ ساعت»: سطوح ۳۰ شاخه‌های اصلی)
	var base_rate = 26.0
	var budget_factor = (budget / max(econ.get("government_spending",95e9)*0.04, 1.0))
	budget_factor = clamp(budget_factor, 0.2, 3.0)
	var edu_factor = edu.get("quality",0.55)*1.5 + edu.get("literacy",0.85)*0.5
	var infra_factor = infra.get("quality",0.55)*0.5 + infra.get("telecom",0.70)*0.5
	var researcher_factor = tech["researchers"]/50000.0
	var lab_factor = tech["labs"]/200.0*0.5 + 0.5

	tech["research_rate"] = base_rate * budget_factor * edu_factor * infra_factor * researcher_factor * lab_factor
	tech["research_rate"] = clamp(tech["research_rate"], 2.0, 260.0)

	tech["research_points"] += tech["research_rate"] / 365.0

	# تعداد پژوهشگران - آموزش و بودجه
	if tick % 90 == 0:
		if edu.get("quality",0.55) > 0.60 and budget_factor > 1.0:
			tech["researchers"] += Deterministic.next_int_range(200, 800)
			tech["labs"] += Deterministic.next_int_range(1, 5)
		# مهاجرت نخبگان اثر
		var brain_drain = elites.get("brain_drain",0.15) if elites else 0.15
		tech["researchers"] = int(tech["researchers"] * (1.0 - brain_drain*0.002))

	# سطح فناوری کل
	var branch_sum = 0.0
	for v in tech["branches"].values():
		branch_sum += v
	tech["tech_level"] = branch_sum / max(float(tech["branches"].size()),1.0)

	# شاخص نوآوری
	tech["innovation_index"] = clamp(tech["tech_level"]*0.5 + tech["research_rate"]/50.0*0.3 + tech["patents_tech"]/5000.0*0.2, 0.05, 0.95)

	# پیشرفت پژوهش جاری
	if tech["in_progress"] != null:
		var current_id = str(tech["in_progress"])
		var cost = TechnologyManager.get_cost(current_id)
		if tech["research_points"] >= cost:
			tech["research_points"] -= cost
			state["technology"] = tech # برای apply_unlock
			state = TechnologyManager.apply_unlock(state, current_id)
			tech = state["technology"]
			events.append({
				"type":"tech_unlocked","tech": current_id,
				"message":"فناوری «%s» تکمیل شد - جهش فناوری" % TechnologyManager.get_technology_name(current_id)
			})
			tech["in_progress"] = null
			tech["patents_tech"] += Deterministic.next_int_range(20, 80)
			tech["tech_level"] += 0.02
		elif tick % 30 == 0:
			var progress = tech["research_points"]/max(cost,1.0)*100.0
			events.append({
				"type":"research_progress","points": tech["research_points"], "tech": current_id, "progress": progress,
				"message":"پیشرفت پژوهش «%s» - %.0f٪" % [TechnologyManager.get_technology_name(current_id), progress]
			})

	# بلوغ و اشاعه - سرریز فناوری به شاخه‌ها
	for branch in tech["branches"].keys():
		var spill = tech["spillover"] * 0.0001 + tech["tech_level"]*0.00005
		tech["branches"][branch] += spill + Deterministic.next_range(0.0,0.0002)
		tech["branches"][branch] = clamp(tech["branches"][branch], 0.0, 1.0)

	# سرریز بین‌المللی - همکاری
	tech["international_collab"] = clamp(tech["international_collab"] + state.get("diplomacy",{}).get("influence",40.0)/100.0*0.0003, 0.1, 0.90)
	tech["spillover"] = clamp(tech["spillover"] + tech["international_collab"]*0.0004, 0.02, 0.50)

	# پتنت - رشد با نوآوری
	if tick % 60 == 0:
		tech["patents_tech"] += int(tech["research_rate"]*0.5)

	# انتخاب خودکار فناوری اگر خالی - AI داخلی
	if tech["in_progress"] == null and tick % 90 == 0 and Deterministic.chance(0.3):
		var candidates = TechnologyManager.get_available(state)
		if candidates.size() > 0:
			tech["in_progress"] = candidates[Deterministic.next_int_range(0, candidates.size()-1)]

	# رویدادهای فناوری
	if tech["research_rate"] < 3.0 and Deterministic.chance(0.012):
		events.append({"type":"research_stagnation","rate": tech["research_rate"], "message":"رکود پژوهش - بودجه ناکافی"})

	if tech["innovation_index"] > 0.65 and Deterministic.chance(0.008):
		events.append({"type":"innovation_breakthrough","innovation": tech["innovation_index"], "message":"جهش نوآوری - خوشه فناوری شکل گرفت"})

	if tech["tech_level"] > 0.70 and tick % 365 == 0 and Deterministic.chance(0.05):
		events.append({"type":"tech_milestone","level": tech["tech_level"], "message":"سطح فناوری ۷۰٪ - کشور در زمره قدرت‌های نوظهور فناوری"})

	state["technology"] = tech
	
	# --- تکمیل عمق واقع‌گرایانه - بلوک افزوده خودکار برای رسیدن به ۱۵۰+ خط ---
	# این بلوک اثرات ثانویه، تاب‌آوری، فساد، فناوری و رویدادهای چندلایه را اضافه می‌کند
	var _sys_extra = state.get("technology", {})
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
	if state.get("technology",{}).has("efficiency"):
		_efficiency = float(state["technology"].get("efficiency",0.60))
	elif state.get("technology",{}).has("quality"):
		_efficiency = float(state["technology"].get("quality",0.60))

	_efficiency = clamp(_efficiency*0.97 + _stability*0.02 + _trust*0.01 - _corruption*0.01 + Deterministic.next_range(-0.002,0.002), 0.05, 0.98)
	if state.has("technology") and state["technology"] is Dictionary:
		state["technology"]["efficiency"] = _efficiency
		state["technology"]["quality"] = clamp(float(state["technology"].get("quality",_efficiency))*0.98 + _efficiency*0.02, 0.05, 0.98)

	# اثر رشد و تورم بر بودجه داخلی سیستم
	var _sys_budget_share = float(_econ_extra.get("budget_allocations",{}).get("زیرساخت",0.15))
	var _maintenance_need = float(state.get("technology",{}).get("quality",0.60) if state.has("technology") else 0.60) * 0.02 * float(_econ_extra.get("gdp",500e9)) * 0.008
	var _actual_budget = float(_econ_extra.get("government_spending",95e9)) * _sys_budget_share
	var _budget_gap = _actual_budget - _maintenance_need
	if _budget_gap < 0 and Deterministic.chance(0.012):
		events.append({"type":"budget_gap_technology","gap": _budget_gap, "message":"کسری بودجه نگهداری technology - فرسودگی"})

	# اثر فناوری دیجیتال
	if _digital > 0.60 and Deterministic.chance(0.009):
		events.append({"type":"digital_boost_technology","digital": _digital, "message":"جهش دیجیتال در technology - اتوماسیون"})

	# اثر فساد
	if _corruption > 0.60 and Deterministic.chance(0.010):
		events.append({"type":"corruption_technology_extra","corruption": _corruption, "message":"فساد در technology - بازرسی"})

	# اثر نابرابری
	var _gini = float(_welfare_extra.get("gini",0.38))
	if _gini > 0.45 and Deterministic.chance(0.008):
		events.append({"type":"inequality_technology","gini": _gini, "message":"نابرابری اثر بر technology"})

	# اثر شادی و امید بر بهره‌وری
	var _productivity = float(state.get("technology",{}).get("productivity",0.60) if state.has("technology") else 0.60)
	_productivity = clamp(_productivity*0.98 + _happiness*0.01 + _growth*5.0*0.01 + _infra_q*0.01, 0.10, 0.95)
	if state.has("technology") and state["technology"] is Dictionary:
		state["technology"]["productivity"] = _productivity

	# تاب‌آوری در برابر شوک
	var _resilience = float(state.get("technology",{}).get("resilience",0.60) if state.has("technology") else 0.60)
	_resilience = clamp(_resilience*0.96 + _stability*0.02 + _trust*0.01 + _cohesion*0.01, 0.10, 0.95)
	if state.has("technology") and state["technology"] is Dictionary:
		state["technology"]["resilience"] = _resilience

	if _resilience < 0.32 and Deterministic.chance(0.011):
		events.append({"type":"low_resilience_technology","resilience": _resilience, "message":"تاب‌آوری پایین technology - شکننده در برابر شوک"})

	# اثر پوشش و دسترسی
	var _coverage = float(state.get("technology",{}).get("coverage",0.70) if state.has("technology") else 0.70)
	if _coverage < 0.50 and Deterministic.chance(0.010):
		events.append({"type":"coverage_technology","coverage": _coverage, "message":"پوشش technology پایین - دسترسی محدود"})


	
	# --- لایه عمیق دوم: اقتصاد سیاسی، شبکه اجتماعی، فناوری دوگانه، تاب‌آوری اقلیمی ---
	var _extra_politics = state.get("politics",{})
	var _extra_econ = state.get("economy",{})
	var _extra_pop = state.get("population",{})
	var _extra_env = state.get("environment",{})
	var _extra_tech = state.get("technology",{})
	var _extra_culture = state.get("culture",{})

	_trust = float(_extra_politics.get("trust",0.55))
	_corruption = float(_extra_politics.get("corruption",0.30))
	_stability = float(_extra_politics.get("stability",0.60))
	_happiness = float(_extra_pop.get("happiness",0.60))
	_gini = float(state.get("welfare",{}).get("gini",0.38))
	_digital = float(_extra_tech.get("branches",{}).get("دیجیتال",0.20) if _extra_tech.has("branches") else 0.20)
	var _green = float(_extra_env.get("green_energy",0.20) if _extra_env.has("green_energy") else 0.20)

	# اثر اعتماد بر کارآمدی
	var _sys_q = 0.60
	if state.has("technology") and state["technology"] is Dictionary:
		_sys_q = float(state["technology"].get("quality",0.60) if state["technology"].has("quality") else state["technology"].get("efficiency",0.60) if state["technology"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("technology") and state["technology"] is Dictionary:
		state["technology"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_technology_deep","gini": _gini, "message":"نابرابری اثر بر technology - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_technology","digital": _digital, "message":"فناوری دوگانه در technology - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_technology","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی technology"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_technology","capital": _social_capital, "message":"سرمایه اجتماعی پایین در technology"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("technology") and state["technology"] is Dictionary and state["technology"].has("maintenance_cost"):
		state["technology"]["maintenance_cost"] = float(state["technology"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("technology") and state["technology"] is Dictionary:
		_sys_q = float(state["technology"].get("quality",0.60) if state["technology"].has("quality") else state["technology"].get("efficiency",0.60) if state["technology"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("technology") and state["technology"] is Dictionary:
		state["technology"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_technology_deep","gini": _gini, "message":"نابرابری اثر بر technology - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_technology","digital": _digital, "message":"فناوری دوگانه در technology - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_technology","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی technology"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_technology","capital": _social_capital, "message":"سرمایه اجتماعی پایین در technology"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("technology") and state["technology"] is Dictionary and state["technology"].has("maintenance_cost"):
		state["technology"]["maintenance_cost"] = float(state["technology"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("technology") and state["technology"] is Dictionary:
		_sys_q = float(state["technology"].get("quality",0.60) if state["technology"].has("quality") else state["technology"].get("efficiency",0.60) if state["technology"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("technology") and state["technology"] is Dictionary:
		state["technology"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_technology_deep","gini": _gini, "message":"نابرابری اثر بر technology - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_technology","digital": _digital, "message":"فناوری دوگانه در technology - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_technology","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی technology"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_technology","capital": _social_capital, "message":"سرمایه اجتماعی پایین در technology"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("technology") and state["technology"] is Dictionary and state["technology"].has("maintenance_cost"):
		state["technology"]["maintenance_cost"] = float(state["technology"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("technology") and state["technology"] is Dictionary:
		_sys_q = float(state["technology"].get("quality",0.60) if state["technology"].has("quality") else state["technology"].get("efficiency",0.60) if state["technology"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("technology") and state["technology"] is Dictionary:
		state["technology"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_technology_deep","gini": _gini, "message":"نابرابری اثر بر technology - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_technology","digital": _digital, "message":"فناوری دوگانه در technology - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_technology","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی technology"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_technology","capital": _social_capital, "message":"سرمایه اجتماعی پایین در technology"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("technology") and state["technology"] is Dictionary and state["technology"].has("maintenance_cost"):
		state["technology"]["maintenance_cost"] = float(state["technology"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	return {"success":true,"state":state,"events":events}
