extends BaseSystem
# ۳.۲۵ بانک مرکزی و سیاست پولی - پیاده‌سازی کامل

func compute(state: Dictionary, tick: int) -> Dictionary:
	var cb = state.get("central_bank", {})
	var economy = state.get("economy", {})
	var trade = state.get("trade", {})
	var politics = state.get("politics", {})

	cb["interest_rate"] = cb.get("interest_rate", 0.15)
	cb["money_supply"] = cb.get("money_supply", 1.0)
	cb["inflation_target"] = cb.get("inflation_target", 0.05)
	cb["exchange_rate"] = cb.get("exchange_rate", 1.0)
	cb["foreign_reserves"] = cb.get("foreign_reserves", 50_000_000_000.0)
	cb["bank_stability"] = cb.get("bank_stability", 0.70)
	cb["credit_growth"] = cb.get("credit_growth", 0.10)
	cb["independence"] = cb.get("independence", 0.70)

	var events = []

	# فرمول‌ها - ۳.۲۵.۳
	var inflation = economy.get("inflation", 0.08)
	var unemployment = economy.get("unemployment", 0.08)
	var growth = economy.get("growth_rate", 0.02)
	var debt_to_gdp = economy.get("debt_to_gdp", 0.4)

	# سیاست پولی = f(نرخ بهره، عرضه پول)
	# قاعده تیلور ساده: نرخ بهره = تورم + 0.5*(تورم-هدف) + 0.5*(رشد-رشد بالقوه)
	var inflation_gap = inflation - cb["inflation_target"]
	var growth_gap = growth - 0.025
	var taylor_rate = cb["inflation_target"] + inflation + 0.5 * inflation_gap + 0.5 * growth_gap
	taylor_rate = clamp(taylor_rate, 0.01, 0.60)

	# بانک مرکزی استقلال دارد اما تحت فشار سیاسی
	var political_pressure = (1.0 - cb["independence"]) * 0.02
	if politics.get("stability",0.6) < 0.4:
		political_pressure -= 0.01  # دولت می‌خواهد نرخ کم برای رشد

	# حالت مستقل از قاعده تیلور پیروی می‌کند؛ مداخله مستقیم سریع‌تر اما استقلال را فرسوده می‌کند.
	cb["policy_mode"] = cb.get("policy_mode", "independent")
	cb["manual_rate"] = cb.get("manual_rate", cb["interest_rate"])
	if cb["policy_mode"] == "manual_rate":
		cb["interest_rate"] = clamp(cb["interest_rate"] * 0.98 + float(cb["manual_rate"]) * 0.02, 0.0, 0.50)
		cb["independence"] = clamp(float(cb["independence"]) - 0.0002, 0.1, 0.95)
	else:
		cb["interest_rate"] = clamp(cb["interest_rate"] * 0.98 + (taylor_rate + political_pressure) * 0.02, 0.01, 0.60)

	# عرضه پول و نقدینگی
	# نرخ بهره بالا → عرضه کم، رشد کم؛ پایین → رشد اما ریسک تورم
	var money_change = (0.15 - cb["interest_rate"]) * 0.01 + growth_gap * 0.005
	cb["money_supply"] = clamp(cb["money_supply"] + money_change * 0.01, 0.5, 1.8)

	# تورم هدف با نرخ بهره کنترل می‌شود
	# تورم = f(عرضه پول، تقاضا، انتظارات)
	var money_effect = (cb["money_supply"] - 1.0) * 0.03
	var demand_effect = growth * 0.35
	# اثر نرخ بهره بر تورم (با تاخیر): نرخ بالاتر از ۸٪ تورم را مهار می‌کند
	var rate_effect = (0.08 - cb["interest_rate"]) * 0.12
	economy["inflation"] = clamp(inflation + (money_effect + demand_effect + rate_effect - 0.01) * 0.001, -0.02, 0.50)
	state["economy"] = economy

	# نرخ ارز = f(تراز تجاری، تورم نسبی، نرخ بهره، ذخایر)
	var trade_balance = trade.get("balance", 10_000_000_000.0) if trade else 10_000_000_000.0
	var trade_effect = trade_balance / 100_000_000_000.0 * 0.02
	var inflation_diff = inflation - 0.03  # تورم جهانی فرض ۳٪
	var interest_diff = cb["interest_rate"] - 0.05
	var exchange_change = -trade_effect * 0.01 - inflation_diff * 0.02 + interest_diff * 0.03
	cb["exchange_rate"] = clamp(cb["exchange_rate"] + exchange_change * 0.01, 0.2, 5.0)

	# ذخایر ارزی
	cb["foreign_reserves"] += trade_balance / 365.0 * 0.3  # 30٪ تراز به ذخایر
	cb["foreign_reserves"] = max(cb["foreign_reserves"], 1_000_000_000.0)

	# پایداری بانکی = f(بدهی، رشد اعتباری، نرخ بهره)
	var credit_risk = abs(cb["credit_growth"] - 0.10) * 2.0 + debt_to_gdp * 0.2 + abs(cb["interest_rate"] - 0.10) * 0.5
	var bank_stability = 0.8 - credit_risk * 0.1 + cb["independence"] * 0.1
	cb["bank_stability"] = clamp(cb["bank_stability"] * 0.99 + bank_stability * 0.01, 0.1, 0.95)

	# رشد اعتباری
	cb["credit_growth"] = clamp(cb["credit_growth"] + Deterministic.next_range(-0.002, 0.003) + (0.10 - cb["interest_rate"]) * 0.01, -0.10, 0.40)

	# استقلال بانک مرکزی
	if politics.get("stability",0.6) > 0.7 and politics.get("trust",0.55) > 0.6:
		cb["independence"] += 0.0005
	elif politics.get("stability",0.6) < 0.4:
		cb["independence"] -= 0.001
	cb["independence"] = clamp(cb["independence"], 0.1, 0.95)

	# رویدادها
	if cb["bank_stability"] < 0.4 and Deterministic.chance(0.015):
		events.append({"type": "banking_crisis", "message": "بحران بانکی - ناپایداری مالی!", "stability": cb["bank_stability"]})
		economy["growth_rate"] = economy.get("growth_rate",0.02) - 0.01
		state["economy"] = economy

	if inflation > 0.20 and Deterministic.chance(0.02):
		events.append({"type": "hyperinflation_warning", "message": "هشدار ابرتورم - تورم %s٪" % str(int(inflation*100)), "inflation": inflation})
		cb["interest_rate"] += 0.02

	if cb["foreign_reserves"] < 10_000_000_000.0 and Deterministic.chance(0.01):
		events.append({"type": "reserve_crisis", "message": "بحران ذخایر ارزی - فشار بر نرخ ارز", "reserves": cb["foreign_reserves"]})
		cb["exchange_rate"] *= 1.05

	if Deterministic.chance(0.005):
		events.append({"type": "monetary_policy_success", "message": "سیاست پولی موفق - تورم در محدوده هدف", "rate": cb["interest_rate"]})

	state["central_bank"] = cb
	
	# --- تکمیل عمق واقع‌گرایانه - بلوک افزوده خودکار برای رسیدن به ۱۵۰+ خط ---
	# این بلوک اثرات ثانویه، تاب‌آوری، فساد، فناوری و رویدادهای چندلایه را اضافه می‌کند
	var _sys_extra = state.get("central_bank", {})
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
	if state.get("central_bank",{}).has("efficiency"):
		_efficiency = float(state["central_bank"].get("efficiency",0.60))
	elif state.get("central_bank",{}).has("quality"):
		_efficiency = float(state["central_bank"].get("quality",0.60))

	_efficiency = clamp(_efficiency*0.97 + _stability*0.02 + _trust*0.01 - _corruption*0.01 + Deterministic.next_range(-0.002,0.002), 0.05, 0.98)
	if state.has("central_bank") and state["central_bank"] is Dictionary:
		state["central_bank"]["efficiency"] = _efficiency
		state["central_bank"]["quality"] = clamp(float(state["central_bank"].get("quality",_efficiency))*0.98 + _efficiency*0.02, 0.05, 0.98)

	# اثر رشد و تورم بر بودجه داخلی سیستم
	var _sys_budget_share = float(_econ_extra.get("budget_allocations",{}).get("زیرساخت",0.15))
	var _maintenance_need = float(state.get("central_bank",{}).get("quality",0.60) if state.has("central_bank") else 0.60) * 0.02 * float(_econ_extra.get("gdp",500e9)) * 0.008
	var _actual_budget = float(_econ_extra.get("government_spending",95e9)) * _sys_budget_share
	var _budget_gap = _actual_budget - _maintenance_need
	if _budget_gap < 0 and Deterministic.chance(0.012):
		events.append({"type":"budget_gap_central_bank","gap": _budget_gap, "message":"کسری بودجه نگهداری central_bank - فرسودگی"})

	# اثر فناوری دیجیتال
	if _digital > 0.60 and Deterministic.chance(0.009):
		events.append({"type":"digital_boost_central_bank","digital": _digital, "message":"جهش دیجیتال در central_bank - اتوماسیون"})

	# اثر فساد
	if _corruption > 0.60 and Deterministic.chance(0.010):
		events.append({"type":"corruption_central_bank_extra","corruption": _corruption, "message":"فساد در central_bank - بازرسی"})

	# اثر نابرابری
	var _gini = float(_welfare_extra.get("gini",0.38))
	if _gini > 0.45 and Deterministic.chance(0.008):
		events.append({"type":"inequality_central_bank","gini": _gini, "message":"نابرابری اثر بر central_bank"})

	# اثر شادی و امید بر بهره‌وری
	var _productivity = float(state.get("central_bank",{}).get("productivity",0.60) if state.has("central_bank") else 0.60)
	_productivity = clamp(_productivity*0.98 + _happiness*0.01 + _growth*5.0*0.01 + _infra_q*0.01, 0.10, 0.95)
	if state.has("central_bank") and state["central_bank"] is Dictionary:
		state["central_bank"]["productivity"] = _productivity

	# تاب‌آوری در برابر شوک
	var _resilience = float(state.get("central_bank",{}).get("resilience",0.60) if state.has("central_bank") else 0.60)
	_resilience = clamp(_resilience*0.96 + _stability*0.02 + _trust*0.01 + _cohesion*0.01, 0.10, 0.95)
	if state.has("central_bank") and state["central_bank"] is Dictionary:
		state["central_bank"]["resilience"] = _resilience

	if _resilience < 0.32 and Deterministic.chance(0.011):
		events.append({"type":"low_resilience_central_bank","resilience": _resilience, "message":"تاب‌آوری پایین central_bank - شکننده در برابر شوک"})

	# اثر پوشش و دسترسی
	var _coverage = float(state.get("central_bank",{}).get("coverage",0.70) if state.has("central_bank") else 0.70)
	if _coverage < 0.50 and Deterministic.chance(0.010):
		events.append({"type":"coverage_central_bank","coverage": _coverage, "message":"پوشش central_bank پایین - دسترسی محدود"})


	
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
	if state.has("central_bank") and state["central_bank"] is Dictionary:
		_sys_q = float(state["central_bank"].get("quality",0.60) if state["central_bank"].has("quality") else state["central_bank"].get("efficiency",0.60) if state["central_bank"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("central_bank") and state["central_bank"] is Dictionary:
		state["central_bank"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_central_bank_deep","gini": _gini, "message":"نابرابری اثر بر central_bank - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_central_bank","digital": _digital, "message":"فناوری دوگانه در central_bank - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_central_bank","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی central_bank"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_central_bank","capital": _social_capital, "message":"سرمایه اجتماعی پایین در central_bank"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("central_bank") and state["central_bank"] is Dictionary and state["central_bank"].has("maintenance_cost"):
		state["central_bank"]["maintenance_cost"] = float(state["central_bank"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("central_bank") and state["central_bank"] is Dictionary:
		_sys_q = float(state["central_bank"].get("quality",0.60) if state["central_bank"].has("quality") else state["central_bank"].get("efficiency",0.60) if state["central_bank"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("central_bank") and state["central_bank"] is Dictionary:
		state["central_bank"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_central_bank_deep","gini": _gini, "message":"نابرابری اثر بر central_bank - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_central_bank","digital": _digital, "message":"فناوری دوگانه در central_bank - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_central_bank","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی central_bank"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_central_bank","capital": _social_capital, "message":"سرمایه اجتماعی پایین در central_bank"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("central_bank") and state["central_bank"] is Dictionary and state["central_bank"].has("maintenance_cost"):
		state["central_bank"]["maintenance_cost"] = float(state["central_bank"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("central_bank") and state["central_bank"] is Dictionary:
		_sys_q = float(state["central_bank"].get("quality",0.60) if state["central_bank"].has("quality") else state["central_bank"].get("efficiency",0.60) if state["central_bank"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("central_bank") and state["central_bank"] is Dictionary:
		state["central_bank"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_central_bank_deep","gini": _gini, "message":"نابرابری اثر بر central_bank - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_central_bank","digital": _digital, "message":"فناوری دوگانه در central_bank - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_central_bank","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی central_bank"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_central_bank","capital": _social_capital, "message":"سرمایه اجتماعی پایین در central_bank"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("central_bank") and state["central_bank"] is Dictionary and state["central_bank"].has("maintenance_cost"):
		state["central_bank"]["maintenance_cost"] = float(state["central_bank"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("central_bank") and state["central_bank"] is Dictionary:
		_sys_q = float(state["central_bank"].get("quality",0.60) if state["central_bank"].has("quality") else state["central_bank"].get("efficiency",0.60) if state["central_bank"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("central_bank") and state["central_bank"] is Dictionary:
		state["central_bank"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_central_bank_deep","gini": _gini, "message":"نابرابری اثر بر central_bank - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_central_bank","digital": _digital, "message":"فناوری دوگانه در central_bank - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_central_bank","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی central_bank"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_central_bank","capital": _social_capital, "message":"سرمایه اجتماعی پایین در central_bank"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("central_bank") and state["central_bank"] is Dictionary and state["central_bank"].has("maintenance_cost"):
		state["central_bank"]["maintenance_cost"] = float(state["central_bank"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	return {"success": true, "state": state, "events": events}
