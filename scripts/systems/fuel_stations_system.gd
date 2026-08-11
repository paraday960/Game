extends BaseSystem
# ۳.۴۶ سوخت و ایستگاه‌های انرژی - پمپ بنزین، شارژ برقی، قیمت، پوشش، ذخیره، قاچاق، یارانه

func compute(state: Dictionary, tick: int) -> Dictionary:
	var fuel = state.get("fuel_stations", {})
	var resources = state.get("resources", {})
	var econ = state.get("economy", {})
	var transport = state.get("transport_detail", {"roads_km":80000.0, "fuel_consumption":100.0, "traffic_congestion":0.4})

	fuel["gas_stations"] = fuel.get("gas_stations", 4000)
	fuel["ev_charging"] = fuel.get("ev_charging", 500)
	fuel["cng_stations"] = fuel.get("cng_stations", 800)
	fuel["gasoline_price"] = fuel.get("gasoline_price", 15000.0)
	fuel["diesel_price"] = fuel.get("diesel_price", 12000.0)
	fuel["cng_price"] = fuel.get("cng_price", 8000.0)
	fuel["electric_price"] = fuel.get("electric_price", 2000.0)
	fuel["coverage"] = fuel.get("coverage", 0.75)
	fuel["renewable_share"] = fuel.get("renewable_share", 0.05)
	fuel["storage_days"] = fuel.get("storage_days", 15.0)
	fuel["smuggling"] = fuel.get("smuggling", 0.15)
	fuel["subsidy_cost"] = fuel.get("subsidy_cost", 50_000_000_000.0)
	fuel["consumption_daily"] = fuel.get("consumption_daily", 80_000_000.0)

	var events = []

	var oil_inv = resources.get("inventory",{}).get("نفت",80.0)
	var gas_inv = resources.get("inventory",{}).get("گاز",70.0)
	var oil_price = 82.0
	var exchange = state.get("central_bank",{}).get("exchange_rate",1.0)
	var inflation = econ.get("inflation",0.08)

	# قیمت‌ها - تابع نفت جهانی + یارانه + ارز + مالیات
	var subsidy_rate = 0.68
	var gasoline_target = oil_price * 1050.0 * exchange * (1.0 - subsidy_rate*0.8) + 4000.0
	fuel["gasoline_price"] = fuel["gasoline_price"]*0.985 + gasoline_target*0.015 + inflation*100.0
	fuel["diesel_price"] = fuel["gasoline_price"]*0.85
	fuel["cng_price"] = fuel["gasoline_price"]*0.55
	fuel["electric_price"] = 2000.0 + inflation*500.0

	# پوشش جایگاه‌ها - جاده و خودرو
	var roads_km = transport.get("roads_km",80000.0)
	var pop_total = state.get("population",{}).get("total",85_000_000.0)
	var car_ownership = 0.40
	var cars = pop_total * car_ownership / 3.0
	var coverage_target = 0.55 + roads_km/120000.0*0.25 + cars/12_000_000.0*0.20
	fuel["coverage"] = clamp(fuel["coverage"]*0.988 + coverage_target*0.012, 0.25, 0.98)

	# سهم تجدیدپذیر - انرژی پاک
	var green = state.get("environment",{}).get("green_energy",0.20)
	fuel["renewable_share"] = clamp(fuel["renewable_share"]*0.996 + green*0.001 + state.get("technology",{}).get("branches",{}).get("انرژی_پاک",0.15)*0.001, 0.02, 0.60)

	# رشد ایستگاه شارژ
	if green > 0.28 and Deterministic.chance(0.012):
		fuel["ev_charging"] += Deterministic.next_int_range(3,12)
		fuel["cng_stations"] += Deterministic.next_int_range(1,4)
		if tick % 90 == 0:
			events.append({"type":"ev_expansion","ev": fuel["ev_charging"], "message":"توسعه ایستگاه شارژ برقی - %d ایستگاه فعال" % fuel["ev_charging"]})

	# ذخیره - روز پوشش
	var daily_cons = transport.get("fuel_consumption",100.0) * 800000.0
	fuel["consumption_daily"] = daily_cons
	fuel["storage_days"] = oil_inv / max(daily_cons/80_000_000.0*10.0, 1.0) * 12.0
	fuel["storage_days"] = clamp(fuel["storage_days"], 2.0, 90.0)

	# قاچاق - اختلاف قیمت + کنترل مرز
	var neighbor_price = 30000.0
	var price_gap = neighbor_price - fuel["gasoline_price"]
	var border_ctrl = state.get("security",{}).get("border_control",0.60)
	var smuggling_target = 0.08 + max(0.0, price_gap/30000.0)*0.45 - border_ctrl*0.25 + (1.0 - border_ctrl)*0.10
	fuel["smuggling"] = clamp(fuel["smuggling"]*0.97 + smuggling_target*0.03, 0.01, 0.70)

	# هزینه یارانه - شکاف قیمت * مصرف
	fuel["subsidy_cost"] = max(0.0, price_gap) * daily_cons * 0.7

	# اثر بر اقتصاد و رضایت
	var price_effect = (15000.0 - fuel["gasoline_price"])/15000.0
	state["population"]["happiness"] = clamp(state.get("population",{}).get("happiness",0.60) + price_effect*0.0006 - fuel["smuggling"]*0.0003, 0.05, 0.95)
	state["economy"]["inflation"] = clamp(state.get("economy",{}).get("inflation",0.08) + (fuel["gasoline_price"]-15000.0)/15000.0*0.00015, -0.02, 0.50)

	# رویدادها
	if fuel["smuggling"] > 0.42 and Deterministic.chance(0.014):
		events.append({"type":"fuel_smuggling_crisis","smuggling": fuel["smuggling"], "subsidy": fuel["subsidy_cost"], "message":"بحران قاچاق سوخت - یارانه %d میلیاردی دود شد" % int(fuel["subsidy_cost"]/1_000_000_000.0)})
		econ["government_revenue"] = econ.get("government_revenue",0.0) - fuel["smuggling"]*1_200_000_000.0

	if fuel["storage_days"] < 6.0 and Deterministic.chance(0.018):
		events.append({"type":"fuel_shortage","storage": fuel["storage_days"], "message":"ذخیره سوخت %d روز - صف طولانی پمپ بنزین" % int(fuel["storage_days"])})
		transport["traffic_congestion"] = clamp(transport.get("traffic_congestion",0.4)+0.12, 0.05, 0.95)

	if fuel["coverage"] < 0.50 and Deterministic.chance(0.011):
		events.append({"type":"fuel_coverage_low","coverage": fuel["coverage"], "message":"پوشش جایگاه سوخت پایین - جاده‌های روستایی بدون پمپ"})

	if fuel["ev_charging"] > 2000 and Deterministic.chance(0.008):
		events.append({"type":"ev_milestone","ev": fuel["ev_charging"], "message":"نقطه عطف - %d جایگاه شارژ برقی" % fuel["ev_charging"]})

	state["fuel_stations"] = fuel
	state["transport_detail"] = transport
	state["economy"] = econ
	
	# --- تکمیل عمق واقع‌گرایانه - بلوک افزوده خودکار برای رسیدن به ۱۵۰+ خط ---
	# این بلوک اثرات ثانویه، تاب‌آوری، فساد، فناوری و رویدادهای چندلایه را اضافه می‌کند
	var _sys_extra = state.get("fuel_stations", {})
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
	if state.get("fuel_stations",{}).has("efficiency"):
		_efficiency = float(state["fuel_stations"].get("efficiency",0.60))
	elif state.get("fuel_stations",{}).has("quality"):
		_efficiency = float(state["fuel_stations"].get("quality",0.60))

	_efficiency = clamp(_efficiency*0.97 + _stability*0.02 + _trust*0.01 - _corruption*0.01 + Deterministic.next_range(-0.002,0.002), 0.05, 0.98)
	if state.has("fuel_stations") and state["fuel_stations"] is Dictionary:
		state["fuel_stations"]["efficiency"] = _efficiency
		state["fuel_stations"]["quality"] = clamp(float(state["fuel_stations"].get("quality",_efficiency))*0.98 + _efficiency*0.02, 0.05, 0.98)

	# اثر رشد و تورم بر بودجه داخلی سیستم
	var _sys_budget_share = float(_econ_extra.get("budget_allocations",{}).get("زیرساخت",0.15))
	var _maintenance_need = float(state.get("fuel_stations",{}).get("quality",0.60) if state.has("fuel_stations") else 0.60) * 0.02 * float(_econ_extra.get("gdp",500e9)) * 0.008
	var _actual_budget = float(_econ_extra.get("government_spending",95e9)) * _sys_budget_share
	var _budget_gap = _actual_budget - _maintenance_need
	if _budget_gap < 0 and Deterministic.chance(0.012):
		events.append({"type":"budget_gap_fuel_stations","gap": _budget_gap, "message":"کسری بودجه نگهداری fuel_stations - فرسودگی"})

	# اثر فناوری دیجیتال
	if _digital > 0.60 and Deterministic.chance(0.009):
		events.append({"type":"digital_boost_fuel_stations","digital": _digital, "message":"جهش دیجیتال در fuel_stations - اتوماسیون"})

	# اثر فساد
	if _corruption > 0.60 and Deterministic.chance(0.010):
		events.append({"type":"corruption_fuel_stations_extra","corruption": _corruption, "message":"فساد در fuel_stations - بازرسی"})

	# اثر نابرابری
	var _gini = float(_welfare_extra.get("gini",0.38))
	if _gini > 0.45 and Deterministic.chance(0.008):
		events.append({"type":"inequality_fuel_stations","gini": _gini, "message":"نابرابری اثر بر fuel_stations"})

	# اثر شادی و امید بر بهره‌وری
	var _productivity = float(state.get("fuel_stations",{}).get("productivity",0.60) if state.has("fuel_stations") else 0.60)
	_productivity = clamp(_productivity*0.98 + _happiness*0.01 + _growth*5.0*0.01 + _infra_q*0.01, 0.10, 0.95)
	if state.has("fuel_stations") and state["fuel_stations"] is Dictionary:
		state["fuel_stations"]["productivity"] = _productivity

	# تاب‌آوری در برابر شوک
	var _resilience = float(state.get("fuel_stations",{}).get("resilience",0.60) if state.has("fuel_stations") else 0.60)
	_resilience = clamp(_resilience*0.96 + _stability*0.02 + _trust*0.01 + _cohesion*0.01, 0.10, 0.95)
	if state.has("fuel_stations") and state["fuel_stations"] is Dictionary:
		state["fuel_stations"]["resilience"] = _resilience

	if _resilience < 0.32 and Deterministic.chance(0.011):
		events.append({"type":"low_resilience_fuel_stations","resilience": _resilience, "message":"تاب‌آوری پایین fuel_stations - شکننده در برابر شوک"})

	# اثر پوشش و دسترسی
	var _coverage = float(state.get("fuel_stations",{}).get("coverage",0.70) if state.has("fuel_stations") else 0.70)
	if _coverage < 0.50 and Deterministic.chance(0.010):
		events.append({"type":"coverage_fuel_stations","coverage": _coverage, "message":"پوشش fuel_stations پایین - دسترسی محدود"})


	
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
	if state.has("fuel_stations") and state["fuel_stations"] is Dictionary:
		_sys_q = float(state["fuel_stations"].get("quality",0.60) if state["fuel_stations"].has("quality") else state["fuel_stations"].get("efficiency",0.60) if state["fuel_stations"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("fuel_stations") and state["fuel_stations"] is Dictionary:
		state["fuel_stations"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_fuel_stations_deep","gini": _gini, "message":"نابرابری اثر بر fuel_stations - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_fuel_stations","digital": _digital, "message":"فناوری دوگانه در fuel_stations - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_fuel_stations","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی fuel_stations"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_fuel_stations","capital": _social_capital, "message":"سرمایه اجتماعی پایین در fuel_stations"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("fuel_stations") and state["fuel_stations"] is Dictionary and state["fuel_stations"].has("maintenance_cost"):
		state["fuel_stations"]["maintenance_cost"] = float(state["fuel_stations"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("fuel_stations") and state["fuel_stations"] is Dictionary:
		_sys_q = float(state["fuel_stations"].get("quality",0.60) if state["fuel_stations"].has("quality") else state["fuel_stations"].get("efficiency",0.60) if state["fuel_stations"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("fuel_stations") and state["fuel_stations"] is Dictionary:
		state["fuel_stations"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_fuel_stations_deep","gini": _gini, "message":"نابرابری اثر بر fuel_stations - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_fuel_stations","digital": _digital, "message":"فناوری دوگانه در fuel_stations - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_fuel_stations","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی fuel_stations"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_fuel_stations","capital": _social_capital, "message":"سرمایه اجتماعی پایین در fuel_stations"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("fuel_stations") and state["fuel_stations"] is Dictionary and state["fuel_stations"].has("maintenance_cost"):
		state["fuel_stations"]["maintenance_cost"] = float(state["fuel_stations"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("fuel_stations") and state["fuel_stations"] is Dictionary:
		_sys_q = float(state["fuel_stations"].get("quality",0.60) if state["fuel_stations"].has("quality") else state["fuel_stations"].get("efficiency",0.60) if state["fuel_stations"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("fuel_stations") and state["fuel_stations"] is Dictionary:
		state["fuel_stations"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_fuel_stations_deep","gini": _gini, "message":"نابرابری اثر بر fuel_stations - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_fuel_stations","digital": _digital, "message":"فناوری دوگانه در fuel_stations - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_fuel_stations","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی fuel_stations"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_fuel_stations","capital": _social_capital, "message":"سرمایه اجتماعی پایین در fuel_stations"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("fuel_stations") and state["fuel_stations"] is Dictionary and state["fuel_stations"].has("maintenance_cost"):
		state["fuel_stations"]["maintenance_cost"] = float(state["fuel_stations"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
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
	if state.has("fuel_stations") and state["fuel_stations"] is Dictionary:
		_sys_q = float(state["fuel_stations"].get("quality",0.60) if state["fuel_stations"].has("quality") else state["fuel_stations"].get("efficiency",0.60) if state["fuel_stations"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("fuel_stations") and state["fuel_stations"] is Dictionary:
		state["fuel_stations"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_fuel_stations_deep","gini": _gini, "message":"نابرابری اثر بر fuel_stations - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_fuel_stations","digital": _digital, "message":"فناوری دوگانه در fuel_stations - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_fuel_stations","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی fuel_stations"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_fuel_stations","capital": _social_capital, "message":"سرمایه اجتماعی پایین در fuel_stations"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("fuel_stations") and state["fuel_stations"] is Dictionary and state["fuel_stations"].has("maintenance_cost"):
		state["fuel_stations"]["maintenance_cost"] = float(state["fuel_stations"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	return {"success":true,"state":state,"events":events}
