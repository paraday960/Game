extends BaseSystem
# ۳.۶۴ دقیق‌سازی کمّی و زمانی - مقیاس‌های زمانی ساعت تا دهه، نسبت‌های واقعی، شوک‌ها، شاخص‌های کلان

func compute(state: Dictionary, tick: int) -> Dictionary:
	var quant = state.get("quantitative", {})
	quant["time_scales"] = quant.get("time_scales", {"hourly":0,"daily":tick,"monthly":int(tick/30),"yearly":int(tick/365),"decadal":int(tick/3650)})
	quant["real_ratios"] = quant.get("real_ratios", {"gdp_pop":0.6,"energy_gdp":0.3,"food_pop":0.85,"water_pop":0.9,"household_income_gdp":0.65})
	quant["shock_absorption"] = quant.get("shock_absorption",0.60)
	quant["shock_history"] = quant.get("shock_history", [])
	quant["macro_indicators"] = quant.get("macro_indicators", {"hdi":state.get("indicators",{}).get("hdi",0.75),"gini":state.get("welfare",{}).get("gini",0.38),"life_expectancy":state.get("health",{}).get("life_expectancy",74.0) if state.get("health",{}).has("life_expectancy") else 74.0,"literacy": state.get("education",{}).get("literacy",0.85)})
	quant["seasonality"] = quant.get("seasonality", {"current_season": state.get("clock",{}).get("season","بهار"), "seasonal_effect":0.0})
	quant["business_cycle"] = quant.get("business_cycle", {"phase":"رونق","duration_months":0,"strength":0.02})
	quant["demographic_transition"] = quant.get("demographic_transition", {"stage":2,"fertility_trend":-0.01,"urbanization_trend":0.005})
	quant["convergence"] = quant.get("convergence", {"gdp_world_ratio":0.3,"technology_gap":0.5})

	var events = []

	# مقیاس‌های زمانی - دقیق‌سازی
	quant["time_scales"]["daily"] = tick
	quant["time_scales"]["monthly"] = int(tick/30)
	quant["time_scales"]["yearly"] = int(tick/365)
	quant["time_scales"]["decadal"] = int(tick/3650)
	quant["time_scales"]["hourly"] = tick*24
	quant["time_scales"]["quarterly"] = int(tick/90)
	quant["time_scales"]["weekly"] = int(tick/7)

	# نسبت‌های واقعی - اعتبارسنجی مدل
	var gdp = state.get("economy",{}).get("gdp",500e9)
	var pop_total = state.get("population",{}).get("total",85_000_000.0)
	var energy_self = state.get("resources",{}).get("self_sufficiency",0.85)
	var food_sec = state.get("agriculture",{}).get("food_security",0.85)
	var water_inv = state.get("resources",{}).get("inventory",{}).get("آب",90.0)

	quant["real_ratios"]["gdp_pop"] = clamp((gdp/pop_total)/20000.0, 0.05, 2.5)
	quant["real_ratios"]["energy_gdp"] = clamp(energy_self, 0.1, 1.5)
	quant["real_ratios"]["food_pop"] = clamp(food_sec, 0.2, 1.2)
	quant["real_ratios"]["water_pop"] = clamp(water_inv/100.0, 0.1, 1.2)
	quant["real_ratios"]["household_income_gdp"] = clamp(state.get("households_detail_full",{}).get("income_avg",5000.0) / max(state.get("economy",{}).get("gdp_per_capita",5000.0),1.0), 0.3, 1.2)

	# جذب شوک - تاب‌آوری
	var emergency_prep = state.get("emergency",{}).get("preparedness",0.5)
	var infra_q = state.get("infrastructure",{}).get("quality",0.55)
	var inter_eff = state.get("interdependency",{}).get("efficiency",0.70) if state.has("interdependency") else 0.70
	var shock_target = emergency_prep*0.35 + infra_q*0.25 + inter_eff*0.20 + state.get("indicators",{}).get("stability",0.60)*0.20
	quant["shock_absorption"] = clamp(quant["shock_absorption"]*0.992 + shock_target*0.008, 0.15, 0.98)

	# شاخص‌های کلان - به‌روزرسانی
	quant["macro_indicators"]["hdi"] = state.get("indicators",{}).get("hdi",0.75)
	quant["macro_indicators"]["gini"] = state.get("welfare",{}).get("gini",0.38)
	quant["macro_indicators"]["life_expectancy"] = state.get("health",{}).get("life_expectancy",74.0) if state.get("health",{}).has("life_expectancy") else 74.0 + edu_to_life(state.get("education",{}).get("quality",0.55))
	quant["macro_indicators"]["literacy"] = state.get("education",{}).get("literacy",0.85)
	quant["macro_indicators"]["gdp_per_capita"] = gdp / max(pop_total,1.0)
	quant["macro_indicators"]["happiness"] = state.get("population",{}).get("happiness",0.60)

	# فصلی بودن - اثر بر کشاورزی و انرژی
	var clock = state.get("clock",{})
	var season = clock.get("season","بهار")
	quant["seasonality"]["current_season"] = season
	var seasonal_effect = 0.0
	match season:
		"بهار": seasonal_effect = 0.10
		"تابستان": seasonal_effect = -0.05 # گرما مصرف انرژی بالا
		"پاییز": seasonal_effect = 0.05
		"زمستان": seasonal_effect = -0.10
		_: seasonal_effect = 0.0
	quant["seasonality"]["seasonal_effect"] = seasonal_effect

	# چرخه کسب‌وکار - ۳ تا ۷ سال
	var business = quant["business_cycle"]
	business["duration_months"] += 1
	var growth = state.get("economy",{}).get("growth_rate",0.02)
	if growth > 0.03:
		business["phase"] = "رونق"
	elif growth > 0.005:
		business["phase"] = "رکود خفیف"
	elif growth >= 0.0:
		business["phase"] = "رکود"
	else:
		business["phase"] = "بحران"
	business["strength"] = growth
	if business["duration_months"] > 60 and Deterministic.chance(0.05):
		business["duration_months"] = 0
		events.append({"type":"business_cycle_shift","phase": business["phase"], "message":"تغییر فاز چرخه کسب‌وکار - وارد %s شدیم" % business["phase"]})
	quant["business_cycle"] = business

	# گذار جمعیتی
	var demo = quant["demographic_transition"]
	var birth = state.get("population",{}).get("birth_rate",15.0)
	var death = state.get("population",{}).get("death_rate",8.0)
	if birth > 20.0 and death > 10.0:
		demo["stage"] = 1
	elif birth > 15.0 and death < 10.0:
		demo["stage"] = 2
	elif birth <= 15.0 and death < 8.0:
		demo["stage"] = 3
	else:
		demo["stage"] = 4
	demo["fertility_trend"] = (state.get("family",{}).get("fertility",1.8) - 2.1)/100.0 if state.has("family") else -0.01
	demo["urbanization_trend"] = 0.005
	quant["demographic_transition"] = demo

	# همگرایی جهانی
	quant["convergence"]["gdp_world_ratio"] = gdp / 1_000_000_000_000_000.0 # نسبت به جهان 100 تریلیون
	quant["convergence"]["technology_gap"] = 1.0 - state.get("technology",{}).get("branches",{}).get("دیجیتال",0.20)

	# تاریخ شوک
	if tick % 30 == 0 and quant["shock_history"].size() < 200:
		quant["shock_history"].append({
			"tick": tick,
			"absorption": quant["shock_absorption"],
			"growth": growth,
			"happiness": pop.get("happiness",0.60)
		})
		if quant["shock_history"].size() > 100:
			quant["shock_history"] = quant["shock_history"].slice(-100)

	# رویدادهای سالانه
	if tick % 365 == 0:
		events.append({"type":"yearly_report","hdi": quant["macro_indicators"]["hdi"], "gini": quant["macro_indicators"]["gini"], "life": quant["macro_indicators"]["life_expectancy"], "message":"گزارش سالانه - HDI: %.2f | جینی: %.2f | امید زندگی: %.1f" % [quant["macro_indicators"]["hdi"], quant["macro_indicators"]["gini"], quant["macro_indicators"]["life_expectancy"]]})

	if quant["shock_absorption"] < 0.30 and Deterministic.chance(0.015):
		events.append({"type":"low_shock_absorption","absorption": quant["shock_absorption"], "message":"تاب‌آوری پایین در برابر شوک - کشور شکننده"})

	if quant["real_ratios"]["gdp_pop"] < 0.15 and Deterministic.chance(0.010):
		events.append({"type":"productivity_gap","ratio": quant["real_ratios"]["gdp_pop"], "message":"شکاف بهره‌وری - GDP سرانه پایین‌تر از مدل جهانی"})

	state["quantitative"] = quant
	return {"success":true,"state":state,"events":events}

func edu_to_life(edu_q: float) -> float:
	return edu_q * 10.0 + 65.0
