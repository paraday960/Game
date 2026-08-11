extends BaseSystem
# ۳.۷۰ حمل‌ونقل عمومی - اتوبوس، مترو، تراموا، تاکسی، پوشش، مقرون‌به‌صرفگی، وقت‌شناسی، ترافیک

func compute(state: Dictionary, tick: int) -> Dictionary:
	var pt = state.get("public_transport", {})
	pt["buses"] = pt.get("buses", 5000)
	pt["metro_lines"] = pt.get("metro_lines", 4)
	pt["metro_stations"] = pt.get("metro_stations", 200)
	pt["metro_length_km"] = pt.get("metro_length_km", 220.0)
	pt["brt_lines"] = pt.get("brt_lines", 8)
	pt["ridership"] = pt.get("ridership", 2000000.0)
	pt["coverage"] = pt.get("coverage", 0.60)
	pt["affordability"] = pt.get("affordability", 0.70)
	pt["punctuality"] = pt.get("punctuality", 0.75)
	pt["fleet_age"] = pt.get("fleet_age", 7.0)
	pt["electrification"] = pt.get("electrification", 0.15)
	pt["daily_trips"] = pt.get("daily_trips", 8000)
	pt["satisfaction"] = pt.get("satisfaction", 0.55)
	pt["accident_rate"] = pt.get("accident_rate", 0.02)
	pt["subsidy"] = pt.get("subsidy", 3_000_000_000.0)

	var events = []
	var pop = state.get("population", {})
	var infra = state.get("infrastructure", {})
	var econ = state.get("economy", {})
	var env = state.get("environment", {})
	var energy = state.get("resources", {})

	var total_pop = pop.get("total", 85_000_000.0)
	var urban_pop = total_pop * pop.get("urban_ratio",0.75)

	# پوشش = زیرساخت + بودجه + تراکم شهری
	var infra_q = infra.get("quality",0.55)
	var budget_share = econ.get("budget_allocations",{}).get("زیرساخت",0.18)
	pt["coverage"] = clamp(pt["coverage"]*0.993 + (infra_q*0.5 + budget_share*1.5 + urban_pop/60_000_000.0*0.2)*0.007, 0.15, 0.98)

	# سفر روزانه = جمعیت شهری * پوشش * مقرون‌به‌صرفگی
	pt["ridership"] = urban_pop * 0.25 * pt["coverage"] * pt["affordability"]
	pt["daily_trips"] = int(pt["buses"]*4.0 + pt["metro_lines"]*200.0)

	# مقرون‌به‌صرفگی = یارانه + درآمد سرانه معکوس + تورم
	var gdp_pc = econ.get("gdp_per_capita",5000.0)
	var inflation = econ.get("inflation",0.08)
	pt["affordability"] = clamp(pt["affordability"]*0.995 + (pt["subsidy"]/3e9*0.2 + (1.0 - inflation)*0.3 + (5000.0/gdp_pc)*0.1)*0.005, 0.1, 0.95)

	# وقت‌شناسی = سن ناوگان معکوس + ترافیک + کیفیت زیرساخت
	var traffic = infra.get("capacity",0.60) # ظرفیت کم = ترافیک
	pt["punctuality"] = clamp(pt["punctuality"]*0.98 + (1.0 - pt["fleet_age"]/15.0)*0.3*0.02 + infra_q*0.3*0.02 + (traffic)*0.2*0.02, 0.2, 0.98)

	# سن ناوگان - فرسودگی
	pt["fleet_age"] += 1.0/365.0
	if tick % 180 == 0 and budget_share > 0.15:
		pt["fleet_age"] = max(pt["fleet_age"] - 0.3, 2.0)
		pt["buses"] += Deterministic.next_int_range(20, 80)

	# برقی‌سازی - فناوری و محیط‌زیست
	var green = env.get("green_energy",0.20) if env.has("green_energy") else state.get("environment",{}).get("green_energy",0.20)
	pt["electrification"] = clamp(pt["electrification"] + green*0.0003 + state.get("technology",{}).get("branches",{}).get("انرژی_پاک",0.15)*0.0004, 0.02, 0.85)

	# رضایت - پوشش + وقت‌شناسی + مقرون‌به‌صرفگی + ایمنی
	pt["satisfaction"] = clamp(pt["coverage"]*0.25 + pt["punctuality"]*0.25 + pt["affordability"]*0.30 + (1.0-pt["accident_rate"]*10.0)*0.20, 0.05, 0.95)

	# تصادف - سن ناوگان و آموزش
	pt["accident_rate"] = clamp((pt["fleet_age"]/20.0)*0.05 + (1.0 - pt["punctuality"])*0.03 + Deterministic.next_range(0.0,0.005), 0.005, 0.15)

	# یارانه - تورم
	pt["subsidy"] *= (1.0 + inflation*0.8/365.0)

	# رشد مترو - شهرهای بزرگ
	if tick % 365 == 0 and pt["metro_lines"] < 10 and total_pop > 50_000_000 and Deterministic.chance(0.4):
		pt["metro_lines"] += 1
		pt["metro_stations"] += Deterministic.next_int_range(10, 25)
		pt["metro_length_km"] += Deterministic.next_range(15.0, 35.0)

	# رویدادها
	if pt["coverage"] < 0.35 and Deterministic.chance(0.014):
		events.append({"type":"pt_coverage_crisis","coverage": pt["coverage"], "message":"پوشش پایین حمل‌ونقل عمومی - حاشیه شهر بی‌اتوبوس"})

	if pt["fleet_age"] > 12.0 and Deterministic.chance(0.012):
		events.append({"type":"fleet_aging","age": pt["fleet_age"], "message":"فرسودگی ناوگان - اتوبوس‌ها دودزا و خراب"})

	if pt["accident_rate"] > 0.08 and Deterministic.chance(0.010):
		events.append({"type":"pt_accident","rate": pt["accident_rate"], "message":"تصادف زنجیره‌ای اتوبوس - نقص فنی"})

	if pt["satisfaction"] > 0.80 and Deterministic.chance(0.008):
		events.append({"type":"pt_success","satisfaction": pt["satisfaction"], "message":"رضایت از مترو - استقبال ۲ میلیونی روزانه"})

	state["public_transport"] = pt
	return {"success":true,"state":state,"events":events}
