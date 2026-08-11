extends BaseSystem
# ۳.۶۳ مدل اثرگذاری متقابل - جریان‌های پول، کالا، انرژی، نیروی کار، اطلاعات، خدمات، پسماند، شوک، گلوگاه

func compute(state: Dictionary, tick: int) -> Dictionary:
	var inter = state.get("interdependency", {})
	inter["money_flow"] = inter.get("money_flow", state.get("economy", {}).get("gdp", 500_000_000_000.0)/365.0)
	inter["goods_flow"] = inter.get("goods_flow", state.get("industry", {}).get("output", 100.0))
	inter["energy_flow"] = inter.get("energy_flow", state.get("resources", {}).get("inventory", {}).get("برق", 100.0))
	inter["labor_flow"] = inter.get("labor_flow", state.get("population", {}).get("workforce", 55000000))
	inter["information_flow"] = inter.get("information_flow", state.get("technology", {}).get("branches", {}).get("دیجیتال", 0.20)*100.0)
	inter["services_flow"] = inter.get("services_flow", 0.70)
	inter["waste_flow"] = inter.get("waste_flow", state.get("environment", {}).get("pollution", 0.4)*100.0 if state.get("environment", {}).has("pollution") else state.get("environment",{}).get("carbon",0.6)*100.0)
	inter["food_flow"] = inter.get("food_flow", state.get("agriculture", {}).get("production", 100.0))
	inter["water_flow"] = inter.get("water_flow", state.get("resources", {}).get("inventory", {}).get("آب", 90.0))
	inter["bottlenecks"] = inter.get("bottlenecks", [])
	inter["cascade_risk"] = inter.get("cascade_risk", 0.10)
	inter["efficiency"] = inter.get("efficiency", 0.70)
	inter["circularity"] = inter.get("circularity", 0.25)

	var events = []
	var econ = state.get("economy", {})
	var resources = state.get("resources", {})
	var infra = state.get("infrastructure", {})
	var pop = state.get("population", {})
	var industry = state.get("industry", {})
	var agri = state.get("agriculture", {})
	var tech = state.get("technology", {})
	var env = state.get("environment", {})

	# جریان پول = GDP روزانه + رشد
	var gdp_daily = econ.get("gdp", 500e9) / 365.0
	inter["money_flow"] = inter["money_flow"]*0.85 + gdp_daily*0.15
	inter["money_flow"] *= (1.0 + econ.get("growth_rate",0.02)/365.0)

	# جریان کالا = تولید صنعت
	var ind_output = industry.get("output",100.0)
	inter["goods_flow"] = clamp(inter["goods_flow"]*0.9 + ind_output*0.1, 20.0, 500.0)

	# جریان انرژی - تقاضا در برابر عرضه
	var energy_prod = resources.get("production", {}).get("برق", 15.0)
	var energy_demand = resources.get("demand", {}).get("برق", 12.0)
	inter["energy_flow"] = clamp(energy_prod*0.8 + inter["energy_flow"]*0.2, 5.0, 300.0)

	# جریان نیروی کار - جمعیت فعال
	var workforce = pop.get("workforce", 55_000_000.0)
	inter["labor_flow"] = workforce * (1.0 - econ.get("unemployment",0.08))

	# جریان اطلاعات - فناوری دیجیتال
	var digital = tech.get("branches", {}).get("دیجیتال", 0.20)
	inter["information_flow"] = clamp(digital*100.0 + inter["information_flow"]*0.5, 10.0, 200.0)

	# جریان خدمات - زیرساخت
	inter["services_flow"] = clamp(infra.get("quality",0.55)*0.6 + inter["services_flow"]*0.4, 0.1, 0.98)

	# جریان غذا و آب
	inter["food_flow"] = clamp(agri.get("production",100.0)*0.7 + inter["food_flow"]*0.3, 20.0, 300.0)
	inter["water_flow"] = clamp(resources.get("inventory",{}).get("آب",90.0)*0.6 + inter["water_flow"]*0.4, 10.0, 200.0)

	# پسماند - آلودگی + تولید صنعتی
	var pollution = env.get("carbon",0.6) if env.has("carbon") else 0.6
	inter["waste_flow"] = ind_output*0.3 + pollution*50.0

	# کارآمدی کل جریان‌ها - زیرساخت و فناوری
	var eff_target = infra.get("quality",0.55)*0.35 + digital*0.25 + state.get("education",{}).get("quality",0.55)*0.20 + 0.20
	inter["efficiency"] = clamp(inter["efficiency"]*0.97 + eff_target*0.03, 0.2, 0.98)

	# چرخشی بودن - محیط‌زیست
	var green = env.get("green_energy",0.20) if env.has("green_energy") else 0.20
	inter["circularity"] = clamp(inter["circularity"] + green*0.0003 + (1.0 - pollution)*0.0002, 0.05, 0.80)

	# تشخیص گلوگاه‌ها - مدل صف
	inter["bottlenecks"] = [] # هر ماه پاک و دوباره تشخیص

	if inter["energy_flow"] < energy_demand*1.1:
		inter["bottlenecks"].append({"type":"انرژی","flow": inter["energy_flow"], "demand": energy_demand, "severity": (energy_demand - inter["energy_flow"])/max(energy_demand,1.0)})
	if inter["food_flow"] < resources.get("demand",{}).get("غذا",9.0)*1.1:
		inter["bottlenecks"].append({"type":"غذا","flow": inter["food_flow"], "demand": resources.get("demand",{}).get("غذا",9.0), "severity": 0.3})
	if inter["water_flow"] < resources.get("demand",{}).get("آب",10.0):
		inter["bottlenecks"].append({"type":"آب","flow": inter["water_flow"], "demand": resources.get("demand",{}).get("آب",10.0), "severity": 0.4})
	if inter["labor_flow"] < pop.get("total",85_000_000.0)*0.5:
		inter["bottlenecks"].append({"type":"نیروی کار","flow": inter["labor_flow"], "demand": pop.get("total",85_000_000.0)*0.6, "severity": 0.25})
	if infra.get("capacity",0.60) < 0.4:
		inter["bottlenecks"].append({"type":"زیرساخت","flow": infra.get("capacity",0.60), "demand": 0.60, "severity": 0.5})

	# ریسک آبشاری - تعداد گلوگاه‌ها
	var bottleneck_count = inter["bottlenecks"].size()
	inter["cascade_risk"] = clamp(bottleneck_count*0.15 + (1.0 - inter["efficiency"])*0.3 + inter["cascade_risk"]*0.2, 0.02, 0.85)

	# رویدادها - پیامد گلوگاه‌ها
	if bottleneck_count == 1 and Deterministic.chance(0.04):
		var b = inter["bottlenecks"][0]
		events.append({"type":"single_bottleneck","bottleneck": b, "message":"گلوگاه %s - جریان کمتر از تقاضا!" % b.get("type","")})

	if bottleneck_count >= 2 and bottleneck_count <= 3 and Deterministic.chance(0.025):
		events.append({"type":"systemic_bottleneck","count": bottleneck_count, "bottlenecks": inter["bottlenecks"].duplicate(), "message":"گلوگاه‌های چندگانه - %d بخش همزمان تحت فشار" % bottleneck_count})
		# اثر اقتصادی
		econ["growth_rate"] = econ.get("growth_rate",0.02) - 0.002

	if bottleneck_count > 3 and Deterministic.chance(0.02):
		events.append({"type":"cascade_failure","count": bottleneck_count, "risk": inter["cascade_risk"], "message":"خطر فروپاشی آبشاری - قطعی زنجیره‌ای انرژی، غذا، آب"})
		econ["growth_rate"] = econ.get("growth_rate",0.02) - 0.005
		pop["happiness"] = pop.get("happiness",0.60) - 0.02

	if inter["efficiency"] > 0.85 and bottleneck_count == 0 and Deterministic.chance(0.008):
		events.append({"type":"flow_optimization","efficiency": inter["efficiency"], "message":"بهینه‌سازی جریان‌ها - اقتصاد روان شد"})

	if inter["circularity"] > 0.60 and tick % 180 == 0 and Deterministic.chance(0.02):
		events.append({"type":"circular_economy_milestone","circularity": inter["circularity"], "message":"اقتصاد چرخشی ۶۰٪ - بازیافت گسترده"})

	state["interdependency"] = inter
	state["economy"] = econ
	state["population"] = pop
	return {"success":true,"state":state,"events":events}
