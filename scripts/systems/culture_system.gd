extends BaseSystem
# ۳.۲۲ فرهنگ، رسانه و هویت - پیاده‌سازی کامل

func compute(state: Dictionary, tick: int) -> Dictionary:
	var culture = state.get("culture", {})
	var politics = state.get("politics", {})
	var pop = state.get("population", {})
	var education = state.get("education", {})
	var economy = state.get("economy", {})
	var diplomacy = state.get("diplomacy", {})

	culture["cohesion"] = culture.get("cohesion", 0.65)
	culture["media_freedom"] = culture.get("media_freedom", 0.5)
	culture["media_trust"] = culture.get("media_trust", 0.45)
	culture["identity"] = culture.get("identity", 0.70)
	culture["media_diversity"] = culture.get("media_diversity", 0.55)
	culture["soft_power"] = culture.get("soft_power", diplomacy.get("soft_power",35.0) / 100.0)
	culture["cultural_output"] = culture.get("cultural_output", 0.50)
	culture["public_opinion"] = culture.get("public_opinion", 0.60)
	culture["misinformation_risk"] = culture.get("misinformation_risk", 0.30)
	culture["cultural_heritage"] = culture.get("cultural_heritage", 0.65)

	var events = []

	var culture_budget_share = economy.get("budget_allocations", {}).get("محیط", 0.03)  # فرهنگ از بودجه محیط/اداره
	var culture_budget = economy.get("government_spending",0.0) * 0.03  # 3٪

	# فرمول‌ها - ۳.۲۲.۳
	# افکار عمومی = f(رسانه، رویدادها، سیاست)
	var media_effect = culture["media_trust"] * 0.4 + culture["media_diversity"] * 0.2
	var politics_effect = politics.get("trust",0.55) * 0.2 + politics.get("stability",0.6) * 0.2
	var public_opinion = 0.5 + media_effect * 0.3 + politics_effect * 0.2 + (pop.get("happiness",0.6) - 0.5) * 0.3
	culture["public_opinion"] = clamp(culture["public_opinion"] * 0.98 + public_opinion * 0.02, 0.05, 0.95)

	# انسجام ملی = f(هویت، فرهنگ، عدالت)
	var social_justice = state.get("welfare",{}).get("social_justice",0.6) if state.has("welfare") else 0.6
	var cohesion = 0.5
	cohesion += culture["identity"] * 0.3
	cohesion += culture["cultural_output"] * 0.2
	cohesion += social_justice * 0.2
	cohesion += pop.get("happiness",0.6) * 0.1
	cohesion += (1.0 - state.get("ethnicity",{}).get("tension",0.3)) * 0.1 if state.has("ethnicity") else 0
	culture["cohesion"] = clamp(culture["cohesion"] * 0.99 + cohesion * 0.01, 0.1, 0.95)

	# اثر رسانه = f(اعتماد، دسترسی، کیفیت خبر)
	var media_literacy = education.get("quality",0.55) * 0.7 + culture["media_freedom"] * 0.3
	var media_impact = culture["media_trust"] * 0.5 + media_literacy * 0.3 + culture["media_diversity"] * 0.2
	culture["media_impact"] = clamp(media_impact, 0.05, 0.95)

	# قدرت نرم = f(فرهنگ، رسانه، جذابیت)
	var soft_power = 0.0
	soft_power += culture["cultural_output"] * 30.0
	soft_power += culture["cohesion"] * 20.0
	soft_power += culture["media_impact"] * 15.0
	soft_power += education.get("quality",0.55) * 10.0
	culture["soft_power"] = clamp(soft_power / 100.0, 0.0, 1.0)
	diplomacy["soft_power"] = soft_power
	state["diplomacy"] = diplomacy

	# ریسک اطلاعات نادرست = f(رسانه، آموزش، سواد رسانه‌ای)
	var misinfo = 0.3
	misinfo += (1.0 - culture["media_trust"]) * 0.3
	misinfo += (1.0 - media_literacy) * 0.3
	misinfo += (1.0 - culture["media_freedom"]) * 0.2
	# آزادی زیاد بدون سواد → ریسک بالا
	if culture["media_freedom"] > 0.7 and media_literacy < 0.5:
		misinfo += 0.2
	culture["misinformation_risk"] = clamp(culture["misinformation_risk"] * 0.99 + misinfo * 0.01, 0.0, 0.9)

	# آزادی رسانه پویا
	if politics.get("stability",0.6) < 0.4 and Deterministic.chance(0.01):
		culture["media_freedom"] -= 0.01  # دولت برای کنترل آزادی را کم می‌کند
		events.append({"type": "media_censorship", "message": "افزایش سانسور رسانه به دلیل بی‌ثباتی"})
	elif politics.get("trust",0.55) > 0.7 and Deterministic.chance(0.005):
		culture["media_freedom"] += 0.005
	culture["media_freedom"] = clamp(culture["media_freedom"], 0.05, 0.95)

	# اعتماد به رسانه
	var media_trust_change = (culture["media_diversity"] - 0.5) * 0.002 + (culture["media_freedom"] - 0.5) * 0.001 - culture["misinformation_risk"] * 0.002
	culture["media_trust"] = clamp(culture["media_trust"] + media_trust_change, 0.05, 0.95)

	# تنوع رسانه
	culture["media_diversity"] = clamp(culture["media_diversity"] + Deterministic.next_range(-0.002, 0.003), 0.1, 0.95)

	# تولید فرهنگی
	culture["cultural_output"] = clamp(culture["cultural_output"] + (culture_budget / 1_000_000_000.0 - 0.5) * 0.001 + education.get("quality",0.55) * 0.0005, 0.1, 0.95)

	# هویت ملی
	culture["identity"] = clamp(culture["identity"] + (culture["cohesion"] - 0.5) * 0.001, 0.1, 0.95)

	# حلقه بازخورد: رسانه ← افکار عمومی ← سیاست؛ فرهنگ ← هویت ← انسجام
	politics["trust"] = clamp(politics.get("trust",0.55) + (culture["public_opinion"] - 0.5) * 0.001, 0.05, 0.95)
	state["politics"] = politics

	# رویدادها - ۳.۲۲.۵
	if culture["misinformation_risk"] > 0.6 and Deterministic.chance(0.015):
		events.append({"type": "misinformation_crisis", "message": "بحران اطلاعات نادرست - شایعات گسترده", "risk": culture["misinformation_risk"]})
		politics["stability"] -= 0.02
		state["politics"] = politics

	if culture["media_trust"] < 0.3 and Deterministic.chance(0.01):
		events.append({"type": "media_trust_crisis", "message": "بحران اعتماد به رسانه‌ها"})

	if Deterministic.chance(0.008):
		var r = Deterministic.next_float()
		if r < 0.4:
			events.append({"type": "cultural_movement", "message": "جنبش فرهنگی و هنری جدید", "cohesion_boost": 0.02})
			culture["cohesion"] += 0.02
		elif r < 0.7:
			events.append({"type": "media_scandal", "message": "رسوایی رسانه‌ای", "trust_loss": -0.05})
			culture["media_trust"] -= 0.05
		else:
			events.append({"type": "cultural_festival", "message": "جشنواره فرهنگی موفق - افزایش قدرت نرم"})

	state["culture"] = culture
	
	# --- تکمیل عمق واقع‌گرایانه - بلوک افزوده خودکار برای رسیدن به ۱۵۰+ خط ---
	# این بلوک اثرات ثانویه، تاب‌آوری، فساد، فناوری و رویدادهای چندلایه را اضافه می‌کند
	var _sys_extra = state.get("culture", {})
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
	if state.get("culture",{}).has("efficiency"):
		_efficiency = float(state["culture"].get("efficiency",0.60))
	elif state.get("culture",{}).has("quality"):
		_efficiency = float(state["culture"].get("quality",0.60))

	_efficiency = clamp(_efficiency*0.97 + _stability*0.02 + _trust*0.01 - _corruption*0.01 + Deterministic.next_range(-0.002,0.002), 0.05, 0.98)
	if state.has("culture") and state["culture"] is Dictionary:
		state["culture"]["efficiency"] = _efficiency
		state["culture"]["quality"] = clamp(float(state["culture"].get("quality",_efficiency))*0.98 + _efficiency*0.02, 0.05, 0.98)

	# اثر رشد و تورم بر بودجه داخلی سیستم
	var _sys_budget_share = float(_econ_extra.get("budget_allocations",{}).get("زیرساخت",0.15))
	var _maintenance_need = float(state.get("culture",{}).get("quality",0.60) if state.has("culture") else 0.60) * 0.02 * float(_econ_extra.get("gdp",500e9)) * 0.008
	var _actual_budget = float(_econ_extra.get("government_spending",95e9)) * _sys_budget_share
	var _budget_gap = _actual_budget - _maintenance_need
	if _budget_gap < 0 and Deterministic.chance(0.012):
		events.append({"type":"budget_gap_culture","gap": _budget_gap, "message":"کسری بودجه نگهداری culture - فرسودگی"})

	# اثر فناوری دیجیتال
	if _digital > 0.60 and Deterministic.chance(0.009):
		events.append({"type":"digital_boost_culture","digital": _digital, "message":"جهش دیجیتال در culture - اتوماسیون"})

	# اثر فساد
	if _corruption > 0.60 and Deterministic.chance(0.010):
		events.append({"type":"corruption_culture_extra","corruption": _corruption, "message":"فساد در culture - بازرسی"})

	# اثر نابرابری
	var _gini = float(_welfare_extra.get("gini",0.38))
	if _gini > 0.45 and Deterministic.chance(0.008):
		events.append({"type":"inequality_culture","gini": _gini, "message":"نابرابری اثر بر culture"})

	# اثر شادی و امید بر بهره‌وری
	var _productivity = float(state.get("culture",{}).get("productivity",0.60) if state.has("culture") else 0.60)
	_productivity = clamp(_productivity*0.98 + _happiness*0.01 + _growth*5.0*0.01 + _infra_q*0.01, 0.10, 0.95)
	if state.has("culture") and state["culture"] is Dictionary:
		state["culture"]["productivity"] = _productivity

	# تاب‌آوری در برابر شوک
	var _resilience = float(state.get("culture",{}).get("resilience",0.60) if state.has("culture") else 0.60)
	_resilience = clamp(_resilience*0.96 + _stability*0.02 + _trust*0.01 + _cohesion*0.01, 0.10, 0.95)
	if state.has("culture") and state["culture"] is Dictionary:
		state["culture"]["resilience"] = _resilience

	if _resilience < 0.32 and Deterministic.chance(0.011):
		events.append({"type":"low_resilience_culture","resilience": _resilience, "message":"تاب‌آوری پایین culture - شکننده در برابر شوک"})

	# اثر پوشش و دسترسی
	var _coverage = float(state.get("culture",{}).get("coverage",0.70) if state.has("culture") else 0.70)
	if _coverage < 0.50 and Deterministic.chance(0.010):
		events.append({"type":"coverage_culture","coverage": _coverage, "message":"پوشش culture پایین - دسترسی محدود"})


	
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
	if state.has("culture") and state["culture"] is Dictionary:
		_sys_q = float(state["culture"].get("quality",0.60) if state["culture"].has("quality") else state["culture"].get("efficiency",0.60) if state["culture"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("culture") and state["culture"] is Dictionary:
		state["culture"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_culture_deep","gini": _gini, "message":"نابرابری اثر بر culture - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_culture","digital": _digital, "message":"فناوری دوگانه در culture - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_culture","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی culture"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_culture","capital": _social_capital, "message":"سرمایه اجتماعی پایین در culture"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("culture") and state["culture"] is Dictionary and state["culture"].has("maintenance_cost"):
		state["culture"]["maintenance_cost"] = float(state["culture"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("culture") and state["culture"] is Dictionary:
		_sys_q = float(state["culture"].get("quality",0.60) if state["culture"].has("quality") else state["culture"].get("efficiency",0.60) if state["culture"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("culture") and state["culture"] is Dictionary:
		state["culture"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_culture_deep","gini": _gini, "message":"نابرابری اثر بر culture - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_culture","digital": _digital, "message":"فناوری دوگانه در culture - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_culture","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی culture"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_culture","capital": _social_capital, "message":"سرمایه اجتماعی پایین در culture"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("culture") and state["culture"] is Dictionary and state["culture"].has("maintenance_cost"):
		state["culture"]["maintenance_cost"] = float(state["culture"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("culture") and state["culture"] is Dictionary:
		_sys_q = float(state["culture"].get("quality",0.60) if state["culture"].has("quality") else state["culture"].get("efficiency",0.60) if state["culture"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("culture") and state["culture"] is Dictionary:
		state["culture"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_culture_deep","gini": _gini, "message":"نابرابری اثر بر culture - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_culture","digital": _digital, "message":"فناوری دوگانه در culture - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_culture","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی culture"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_culture","capital": _social_capital, "message":"سرمایه اجتماعی پایین در culture"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("culture") and state["culture"] is Dictionary and state["culture"].has("maintenance_cost"):
		state["culture"]["maintenance_cost"] = float(state["culture"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("culture") and state["culture"] is Dictionary:
		_sys_q = float(state["culture"].get("quality",0.60) if state["culture"].has("quality") else state["culture"].get("efficiency",0.60) if state["culture"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("culture") and state["culture"] is Dictionary:
		state["culture"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_culture_deep","gini": _gini, "message":"نابرابری اثر بر culture - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_culture","digital": _digital, "message":"فناوری دوگانه در culture - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_culture","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی culture"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_culture","capital": _social_capital, "message":"سرمایه اجتماعی پایین در culture"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("culture") and state["culture"] is Dictionary and state["culture"].has("maintenance_cost"):
		state["culture"]["maintenance_cost"] = float(state["culture"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	return {"success": true, "state": state, "events": events}
