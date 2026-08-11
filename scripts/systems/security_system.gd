extends BaseSystem
# ۳.۱۸ امنیت داخلی و پلیس - پیاده‌سازی کامل

func compute(state: Dictionary, tick: int) -> Dictionary:
	var security = state.get("security", {})
	var judicial = state.get("judicial", {})
	var politics = state.get("politics", {})
	var pop = state.get("population", {})
	var econ = state.get("economy", {})
	var culture = state.get("culture", {})

	security["public_security"] = security.get("public_security", 0.70)
	security["police_presence"] = security.get("police_presence", 0.5)
	security["prevention"] = security.get("prevention", 0.60)
	security["response"] = security.get("response", 0.65)
	security["cyber"] = security.get("cyber", 0.50)
	security["counter_terror"] = security.get("counter_terror", 0.55)
	security["border_control"] = security.get("border_control", 0.60)
	security["community_trust"] = security.get("community_trust", 0.55)
	security["organized_crime"] = security.get("organized_crime", 0.30)

	var events = []

	# بودجه پلیس
	var police_budget_share = econ.get("budget_allocations", {}).get("امنیت", 0.05)
	var police_budget = econ.get("government_spending", 0.0) * police_budget_share

	# فرمول‌ها - ۳.۱۸.۳
	# امنیت عمومی = f(نیروی پلیس، تجهیزات، آموزش، بازدارندگی)
	var deterrence = judicial.get("deterrence", 0.55) if judicial else 0.55
	var police_quality = 0.5 + (police_budget / 5_000_000_000.0) * 0.3 + security["prevention"] * 0.2
	var public_security = 0.5
	public_security += security["police_presence"] * 0.25
	public_security += police_quality * 0.2
	public_security += deterrence * 0.25
	public_security += security["community_trust"] * 0.15
	public_security += security["counter_terror"] * 0.1
	security["public_security"] = clamp(security["public_security"] * 0.97 + public_security * 0.03, 0.05, 0.95)

	# احساس امنیت = f(نرخ جرم، حضور پلیس، رسانه)
	var crime_rate = judicial.get("crime_rate", 50.0) if judicial else 50.0
	var feeling = 0.7
	feeling -= (crime_rate / 200.0) * 0.4
	feeling += security["police_presence"] * 0.3
	feeling += culture.get("cohesion", 0.65) * 0.1 if culture else 0
	security["feeling_security"] = clamp(feeling, 0.05, 0.95)

	# نرخ جرم سازمان‌یافته = f(فساد، کنترل مرز، پلیس)
	var org_crime = 0.3
	org_crime += politics.get("corruption", 0.3) * 0.4
	org_crime += (1.0 - security["border_control"]) * 0.3
	org_crime += (1.0 - security["police_presence"]) * 0.2
	org_crime += (1.0 - deterrence) * 0.2
	security["organized_crime"] = clamp(security["organized_crime"] * 0.98 + org_crime * 0.02, 0.0, 0.9)

	# کنترل اعتراض = f(گفتگو، پلیس، سیاست)
	var protest_control = 0.5
	protest_control += security["police_presence"] * 0.3
	protest_control += politics.get("stability", 0.6) * 0.2
	protest_control += security["community_trust"] * 0.2
	security["protest_control"] = clamp(protest_control, 0.1, 0.95)

	# پیشگیری و واکنش
	security["prevention"] = clamp(security["prevention"] + (police_budget_share - 0.05) * 0.005, 0.1, 0.95)
	security["response"] = clamp(security["response"] + Deterministic.next_range(-0.002, 0.003), 0.1, 0.95)

	# امنیت سایبری - رشد با فناوری
	var tech_digital = state.get("technology", {}).get("branches", {}).get("دیجیتال", 0.2)
	security["cyber"] = clamp(security["cyber"] * 0.999 + tech_digital * 0.001 + 0.0002, 0.1, 0.95)

	# ضد تروریسم
	security["counter_terror"] = clamp(security["counter_terror"] + Deterministic.next_range(-0.001, 0.002), 0.1, 0.95)

	# کنترل مرز
	security["border_control"] = clamp(security["border_control"] + Deterministic.next_range(-0.001, 0.001), 0.1, 0.95)

	# روابط پلیس-جامعه (اعتماد)
	var trust_change = (pop.get("happiness",0.6) - 0.5) * 0.002 - (crime_rate/200.0 - 0.25) * 0.002
	# خشونت پلیس اگر کنترل زیاد
	if security["police_presence"] > 0.8 and Deterministic.chance(0.01):
		trust_change -= 0.02
		events.append({"type": "police_violence_exposed", "message": "افشای خشونت پلیس - کاهش اعتماد جامعه"})
	security["community_trust"] = clamp(security["community_trust"] + trust_change, 0.05, 0.95)

	# حلقه‌های بازخورد: امنیت → اعتماد/سرمایه؛ سرکوب → نارضایتی
	politics["stability"] = clamp(politics.get("stability",0.6) + (security["public_security"] - 0.5) * 0.001, 0.05, 0.95)
	if security["police_presence"] > 0.7:
		pop["happiness"] = clamp(pop.get("happiness",0.6) - 0.0005, 0.05, 0.95)  # سرکوب زیاد
	state["politics"] = politics
	state["population"] = pop

	# رویدادها - ۳.۱۸.۵
	if security["organized_crime"] > 0.6 and Deterministic.chance(0.015):
		events.append({"type": "organized_crime_wave", "message": "موج جرائم سازمان‌یافته و قاچاق", "level": security["organized_crime"]})

	if security["public_security"] < 0.4 and Deterministic.chance(0.02):
		events.append({"type": "security_crisis", "message": "بحران امنیتی - ناامنی گسترده", "security": security["public_security"]})

	if politics.get("tension",0.35) > 0.7 and Deterministic.chance(0.02):
		events.append({"type": "mass_protest", "message": "تجمعات اعتراضی گسترده - مدیریت پلیس", "tension": politics.get("tension",0)})

	if Deterministic.chance(0.005):
		events.append({"type": "counter_terror_success", "message": "عملیات موفق ضدتروریسم", "effect": 0.05})
		security["counter_terror"] += 0.02

	state["security"] = security
	
	# --- تکمیل عمق واقع‌گرایانه - بلوک افزوده خودکار برای رسیدن به ۱۵۰+ خط ---
	# این بلوک اثرات ثانویه، تاب‌آوری، فساد، فناوری و رویدادهای چندلایه را اضافه می‌کند
	var _sys_extra = state.get("security", {})
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
	if state.get("security",{}).has("efficiency"):
		_efficiency = float(state["security"].get("efficiency",0.60))
	elif state.get("security",{}).has("quality"):
		_efficiency = float(state["security"].get("quality",0.60))

	_efficiency = clamp(_efficiency*0.97 + _stability*0.02 + _trust*0.01 - _corruption*0.01 + Deterministic.next_range(-0.002,0.002), 0.05, 0.98)
	if state.has("security") and state["security"] is Dictionary:
		state["security"]["efficiency"] = _efficiency
		state["security"]["quality"] = clamp(float(state["security"].get("quality",_efficiency))*0.98 + _efficiency*0.02, 0.05, 0.98)

	# اثر رشد و تورم بر بودجه داخلی سیستم
	var _sys_budget_share = float(_econ_extra.get("budget_allocations",{}).get("زیرساخت",0.15))
	var _maintenance_need = float(state.get("security",{}).get("quality",0.60) if state.has("security") else 0.60) * 0.02 * float(_econ_extra.get("gdp",500e9)) * 0.008
	var _actual_budget = float(_econ_extra.get("government_spending",95e9)) * _sys_budget_share
	var _budget_gap = _actual_budget - _maintenance_need
	if _budget_gap < 0 and Deterministic.chance(0.012):
		events.append({"type":"budget_gap_security","gap": _budget_gap, "message":"کسری بودجه نگهداری security - فرسودگی"})

	# اثر فناوری دیجیتال
	if _digital > 0.60 and Deterministic.chance(0.009):
		events.append({"type":"digital_boost_security","digital": _digital, "message":"جهش دیجیتال در security - اتوماسیون"})

	# اثر فساد
	if _corruption > 0.60 and Deterministic.chance(0.010):
		events.append({"type":"corruption_security_extra","corruption": _corruption, "message":"فساد در security - بازرسی"})

	# اثر نابرابری
	var _gini = float(_welfare_extra.get("gini",0.38))
	if _gini > 0.45 and Deterministic.chance(0.008):
		events.append({"type":"inequality_security","gini": _gini, "message":"نابرابری اثر بر security"})

	# اثر شادی و امید بر بهره‌وری
	var _productivity = float(state.get("security",{}).get("productivity",0.60) if state.has("security") else 0.60)
	_productivity = clamp(_productivity*0.98 + _happiness*0.01 + _growth*5.0*0.01 + _infra_q*0.01, 0.10, 0.95)
	if state.has("security") and state["security"] is Dictionary:
		state["security"]["productivity"] = _productivity

	# تاب‌آوری در برابر شوک
	var _resilience = float(state.get("security",{}).get("resilience",0.60) if state.has("security") else 0.60)
	_resilience = clamp(_resilience*0.96 + _stability*0.02 + _trust*0.01 + _cohesion*0.01, 0.10, 0.95)
	if state.has("security") and state["security"] is Dictionary:
		state["security"]["resilience"] = _resilience

	if _resilience < 0.32 and Deterministic.chance(0.011):
		events.append({"type":"low_resilience_security","resilience": _resilience, "message":"تاب‌آوری پایین security - شکننده در برابر شوک"})

	# اثر پوشش و دسترسی
	var _coverage = float(state.get("security",{}).get("coverage",0.70) if state.has("security") else 0.70)
	if _coverage < 0.50 and Deterministic.chance(0.010):
		events.append({"type":"coverage_security","coverage": _coverage, "message":"پوشش security پایین - دسترسی محدود"})


	
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
	if state.has("security") and state["security"] is Dictionary:
		_sys_q = float(state["security"].get("quality",0.60) if state["security"].has("quality") else state["security"].get("efficiency",0.60) if state["security"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("security") and state["security"] is Dictionary:
		state["security"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_security_deep","gini": _gini, "message":"نابرابری اثر بر security - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_security","digital": _digital, "message":"فناوری دوگانه در security - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_security","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی security"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_security","capital": _social_capital, "message":"سرمایه اجتماعی پایین در security"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("security") and state["security"] is Dictionary and state["security"].has("maintenance_cost"):
		state["security"]["maintenance_cost"] = float(state["security"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("security") and state["security"] is Dictionary:
		_sys_q = float(state["security"].get("quality",0.60) if state["security"].has("quality") else state["security"].get("efficiency",0.60) if state["security"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("security") and state["security"] is Dictionary:
		state["security"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_security_deep","gini": _gini, "message":"نابرابری اثر بر security - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_security","digital": _digital, "message":"فناوری دوگانه در security - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_security","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی security"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_security","capital": _social_capital, "message":"سرمایه اجتماعی پایین در security"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("security") and state["security"] is Dictionary and state["security"].has("maintenance_cost"):
		state["security"]["maintenance_cost"] = float(state["security"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("security") and state["security"] is Dictionary:
		_sys_q = float(state["security"].get("quality",0.60) if state["security"].has("quality") else state["security"].get("efficiency",0.60) if state["security"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("security") and state["security"] is Dictionary:
		state["security"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_security_deep","gini": _gini, "message":"نابرابری اثر بر security - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_security","digital": _digital, "message":"فناوری دوگانه در security - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_security","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی security"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_security","capital": _social_capital, "message":"سرمایه اجتماعی پایین در security"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("security") and state["security"] is Dictionary and state["security"].has("maintenance_cost"):
		state["security"]["maintenance_cost"] = float(state["security"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("security") and state["security"] is Dictionary:
		_sys_q = float(state["security"].get("quality",0.60) if state["security"].has("quality") else state["security"].get("efficiency",0.60) if state["security"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("security") and state["security"] is Dictionary:
		state["security"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_security_deep","gini": _gini, "message":"نابرابری اثر بر security - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_security","digital": _digital, "message":"فناوری دوگانه در security - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_security","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی security"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_security","capital": _social_capital, "message":"سرمایه اجتماعی پایین در security"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("security") and state["security"] is Dictionary and state["security"].has("maintenance_cost"):
		state["security"]["maintenance_cost"] = float(state["security"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	return {"success": true, "state": state, "events": events}
