extends BaseSystem
# زیرساخت - ۳.۱۵ - کیفیت، ظرفیت، پوشش، راه، برق، آب، مخابرات، مسکن، نگهداری، گلوگاه، سرمایه‌گذاری

func compute(state: Dictionary, tick: int) -> Dictionary:
	var infra = state.get("infrastructure", {})
	infra["quality"] = infra.get("quality", 0.55)
	infra["capacity"] = infra.get("capacity", 0.60)
	infra["coverage"] = infra.get("coverage", 0.70)
	infra["road_quality"] = infra.get("road_quality", 0.55)
	infra["rail_quality"] = infra.get("rail_quality", 0.45)
	infra["electricity_grid"] = infra.get("electricity_grid", 0.70)
	infra["water_network"] = infra.get("water_network", 0.65)
	infra["telecom"] = infra.get("telecom", 0.70)
	infra["housing_quality"] = infra.get("housing_quality", 0.60)
	infra["maintenance_cost"] = infra.get("maintenance_cost", 0.02)
	infra["investment"] = infra.get("investment", 5_000_000_000.0)
	infra["decay_rate"] = infra.get("decay_rate", 0.03)
	infra["projects"] = infra.get("projects", [])
	infra["bottleneck_score"] = infra.get("bottleneck_score", 0.20)

	var events = []
	var econ = state.get("economy", {})
	var pop = state.get("population", {})
	var resources = state.get("resources", {})
	var tech = state.get("technology", {})

	var budget_share = econ.get("budget_allocations", {}).get("زیرساخت", 0.18)
	var budget = budget_share * econ.get("government_spending", 95e9)
	var gdp = econ.get("gdp", 500e9)
	var growth = econ.get("growth_rate", 0.02)
	var total_pop = pop.get("total", 85_000_000.0)

	# نیاز نگهداری - ۲٪ ارزش جایگزینی سالانه، فرسودگی با کیفیت بالاتر بیشتر!
	var maintenance_need = infra["quality"] * 0.02 * gdp * 0.015
	infra["maintenance_cost"] = maintenance_need / max(gdp,1.0)

	# سیاست نگهداری/تمرکز بازیکن (infrastructure_policy از مدیر ماهانه) اثر واقعی دارد:
	# نگهداری بالاتر = نیاز مؤثر کمتر؛ تمرکز = رشد روزانهٔ افزوده بر همان زیرشاخه.
	var infra_policy: Dictionary = state.get("infrastructure_policy", {})
	var maint_policy: float = clampf(float(infra_policy.get("maintenance", 0.4)), 0.0, 1.0)
	var focus_policy: String = str(infra_policy.get("focus", ""))
	maintenance_need *= (1.30 - maint_policy)
	if focus_policy == "roads":
		infra["road_quality"] = clamp(float(infra.get("road_quality", 0.55)) + 0.0004, 0.1, 0.95)
	elif focus_policy == "power":
		infra["electricity_grid"] = clamp(float(infra.get("electricity_grid", 0.60)) + 0.0004, 0.2, 0.98)
	elif focus_policy == "telecom":
		infra["telecom"] = clamp(float(infra.get("telecom", 0.70)) + 0.0004, 0.3, 0.98)

	# کیفیت زیرساخت - بودجه کافی vs فرسودگی
	if budget < maintenance_need:
		infra["decay_rate"] = 0.05 # ۵٪ سالانه اگر نگهداری کم
		infra["quality"] -= infra["decay_rate"]/365.0
		if tick % 30 == 0 and Deterministic.chance(0.10):
			events.append({"type":"infra_decay","quality": infra["quality"], "message":"فرسودگی زیرساخت - بودجه نگهداری کم است"})
	else:
		infra["decay_rate"] = 0.01
		infra["quality"] += (0.0006 + budget_share*0.001) # رشد کند با سرمایه‌گذاری

	infra["quality"] = clamp(infra["quality"], 0.05, 0.98)

	# زیرشاخه‌ها - هرکدام با تاخیر به کیفیت کل همگرا
	infra["road_quality"] = clamp(infra["road_quality"]*0.995 + infra["quality"]*0.005 + Deterministic.next_range(-0.0005,0.0008), 0.1, 0.95)
	infra["rail_quality"] = clamp(infra["rail_quality"]*0.995 + infra["quality"]*0.004 + tech.get("branches",{}).get("صنعت",0.20)*0.001, 0.1, 0.90)
	infra["electricity_grid"] = clamp(infra["electricity_grid"]*0.994 + infra["quality"]*0.005 + (resources.get("production",{}).get("برق",15.0)/20.0)*0.001, 0.2, 0.98)
	infra["water_network"] = clamp(infra["water_network"]*0.996 + infra["quality"]*0.004, 0.2, 0.95)
	infra["telecom"] = clamp(infra["telecom"]*0.990 + infra["quality"]*0.005 + tech.get("branches",{}).get("دیجیتال",0.20)*0.005, 0.3, 0.98)
	infra["housing_quality"] = clamp(infra["housing_quality"]*0.993 + infra["quality"]*0.004 + econ.get("gdp_per_capita",5000.0)/10000.0*0.003, 0.2, 0.95)

	# پوشش - جمعیت و کیفیت
	var coverage_target = infra["quality"]*0.6 + pop.get("urban_ratio",0.75)*0.2 + 0.2
	infra["coverage"] = clamp(infra["coverage"]*0.992 + coverage_target*0.008, 0.3, 0.98)

	# ظرفیت - اثر گلوگاه - تقاضای جمعیت و GDP
	var demand = (total_pop / 85_000_000.0)*0.6 + (gdp/500e9)*0.4
	var capacity_ratio = demand / max(infra["capacity"], 0.05)
	infra["bottleneck_score"] = clamp(capacity_ratio - 1.0, -0.5, 2.0)

	if capacity_ratio > 1.15:
		events.append({"type":"bottleneck","ratio": capacity_ratio, "score": infra["bottleneck_score"], "message":"گلوگاه زیرساختی - تقاضا %.0f%% بیش از ظرفیت" % (capacity_ratio*100.0)})
		infra["capacity"] += 0.0005 # سرمایه‌گذاری خودکار اضطراری
		# بازرسی ۱۴۰۵: نویسهٔ نمایشی growth_rate حذف شد — دوشماره‌ای بود: اثر واقعی
		# زیرساخت در growth_potential (infra_effect) سیستم اقتصاد لحاظ می‌شود (مالکیت یکتا)
	elif capacity_ratio > 1.0:
		infra["capacity"] += 0.0003
	else:
		infra["capacity"] = clamp(infra["capacity"] + 0.00015 + budget_share*0.0002, 0.2, 1.8)

	# سرمایه‌گذاری - رشد با اقتصاد
	infra["investment"] *= (1.0 + growth*0.3/365.0)
	if budget > maintenance_need:
		infra["investment"] += (budget - maintenance_need) * 0.3 / 365.0

	# بلایای طبیعی به زیرساخت آسیب می‌زند - ۰.۵٪ احتمال روزانه
	if Deterministic.chance(0.006):
		var damage = Deterministic.next_range(0.01, 0.06)
		infra["quality"] -= damage
		infra["road_quality"] -= damage*0.8
		infra["electricity_grid"] -= damage*0.6
		events.append({"type":"infrastructure_damage","damage": damage, "quality": infra["quality"], "message":"آسیب به زیرساخت - خسارت %d٪ بر اثر بلای طبیعی" % int(damage*100.0)})

	# پروژه‌های بزرگ - هر ۶ ماه
	if tick % 180 == 0 and infra["quality"] < 0.70 and budget_share > 0.12:
		if infra["projects"].size() < 5:
			infra["projects"].append({
				"name": "توسعه زیرساخت %d" % (infra["projects"].size()+1),
				"progress": 0.0,
				"cost": 1_000_000_000.0,
				"tick_start": tick
			})
	# پیشرفت پروژه‌ها
	for proj in infra["projects"]:
		proj["progress"] += 0.05
		if proj["progress"] >= 1.0:
			events.append({"type":"infra_project_complete","project": proj["name"], "message":"پروژه %s تکمیل شد" % proj["name"]})
	infra["projects"] = infra["projects"].filter(func(p): return p["progress"] < 1.0)

	state["infrastructure"] = infra
	state["economy"] = econ
	
	# ── لایه واقع‌گرایانه اختصاصی زیرساخت (جایگزین قالب خودکار تکراری) — بخش ۳.۱۵ ──
	# فرسودگی طبیعی شبکه‌ها در برابر نگهداشت از بودجه زیرساخت
	var infra_budget_i: float = float(state.get("economy", {}).get("budget_allocations", {}).get("زیرساخت", 0.15))
	var upkeep: float = (infra_budget_i - 0.12) * 0.0009  # بودجه بالای ۱۲٪ = ترمیم خالص روزانه
	infra["road_quality"] = clampf(float(infra.get("road_quality", 0.55)) + upkeep, 0.05, 0.98)
	infra["rail_quality"] = clampf(float(infra.get("rail_quality", 0.45)) + upkeep * 0.8, 0.05, 0.98)
	infra["electricity_grid"] = clampf(float(infra.get("electricity_grid", 0.70)) + upkeep, 0.05, 0.98)
	infra["water_network"] = clampf(float(infra.get("water_network", 0.65)) + upkeep, 0.05, 0.98)
	# اشباع ظرفیت در برابر رشد جمعیت
	var util_i: float = float(state.get("population", {}).get("total", 85_000_000.0)) / 85_000_000.0 / maxf(float(infra.get("capacity", 0.60)), 0.10)
	if util_i > 1.8 and Deterministic.chance(0.005):
		events.append({"type": "infra_overload", "message": "اشباع ظرفیت زیرساخت - رشد جمعیت از ظرفیت شبکه‌ها پیشی گرفت", "utilization": util_i})
	state["infrastructure"] = infra

	return {"success":true,"state":state,"events":events}
