extends BaseSystem
# ۳.۴۳ راه‌ها و حمل‌ونقل - جاده، ریل، بندر، فرودگاه، ایستگاه

func compute(state: Dictionary, tick: int) -> Dictionary:
	var transport = state.get("transport_detail", {})
	var econ = state.get("economy", {})
	var infra = state.get("infrastructure", {})
	var pop = state.get("population", {})

	transport["roads_km"] = transport.get("roads_km", 80000.0)
	transport["roads_quality"] = transport.get("roads_quality", 0.60)
	transport["rail_km"] = transport.get("rail_km", 12000.0)
	transport["rail_quality"] = transport.get("rail_quality", 0.55)
	transport["ports"] = transport.get("ports", 20)
	transport["ports_capacity"] = transport.get("ports_capacity", 0.70)
	transport["airports"] = transport.get("airports", 60)
	transport["airports_capacity"] = transport.get("airports_capacity", 0.65)
	transport["metro_stations"] = transport.get("metro_stations", 200)
	transport["traffic_congestion"] = transport.get("traffic_congestion", 0.40)
	transport["logistics_efficiency"] = transport.get("logistics_efficiency", 0.65)
	transport["fuel_consumption"] = transport.get("fuel_consumption", 100.0)

	var events = []

	var transport_budget_share = econ.get("budget_allocations",{}).get("زیرساخت",0.18) * 0.4
	var transport_budget = econ.get("government_spend_base",0.0) * transport_budget_share

	# کیفیت راه‌ها = f(بودجه، نگهداری، ترافیک)
	var maintenance_need = transport["roads_km"] * 10000.0  # هزینه نگهداری
	if transport_budget > maintenance_need:
		transport["roads_quality"] = clamp(transport["roads_quality"] + 0.0005, 0.1, 0.95)
	else:
		transport["roads_quality"] -= 0.0003
		events.append({"type": "road_decay", "message": "فرسودگی جاده‌ها - کمبود بودجه نگهداری"})

	transport["roads_quality"] = clamp(transport["roads_quality"], 0.1, 0.95)

	# ریل
	transport["rail_quality"] = clamp(transport["rail_quality"] + (transport_budget_share - 0.07) * 0.001, 0.1, 0.95)
	if tick % 360 == 15 and transport_budget_share > 0.08 and Deterministic.chance(0.3):
		transport["rail_km"] += 100.0
		events.append({"type": "rail_expansion", "message": "توسعه خطوط راه‌آهن - %s کیلومتر جدید" % str(int(transport["rail_km"]))})

	# بنادر
	var trade = state.get("trade",{})
	var trade_volume = trade.get("exports",80_000_000_000.0) + trade.get("imports",70_000_000_000.0)
	transport["ports_capacity"] = clamp(trade_volume / 200_000_000_000.0, 0.2, 1.2)
	if transport["ports_capacity"] > 1.0 and Deterministic.chance(0.01):
		events.append({"type": "port_bottleneck", "message": "گلوگاه بندر - ظرفیت بنادر تکمیل، کشتی‌ها در صف!", "capacity": transport["ports_capacity"]})

	# فرودگاه‌ها
	transport["airports_capacity"] = clamp(state.get("tourism",{}).get("visitors",5_000_000)/10_000_000.0, 0.2, 1.5)
	if transport["airports_capacity"] > 1.0 and Deterministic.chance(0.008):
		events.append({"type": "airport_congestion", "message": "ازدحام فرودگاه‌ها - تاخیر پروازها"})

	# ترافیک = f(خودرو، جاده، حمل‌ونقل عمومی)
	var cars = state.get("people",{}).get("households_details",{}).get("دارای_خودرو",0.40) * pop.get("total",85_000_000) / 3.0
	var car_density = cars / max(transport["roads_km"],1.0)
	transport["traffic_congestion"] = clamp(car_density / 100.0 + (1.0 - transport["metro_stations"]/500.0) * 0.2, 0.05, 0.90)

	# کارآمدی لجستیک = f(جاده، ریل، بندر، فناوری)
	var logistics = 0.5 + transport["roads_quality"] * 0.2 + transport["rail_quality"] * 0.15 + transport["ports_capacity"] * 0.1 + transport["logistics_efficiency"] * 0.1
	transport["logistics_efficiency"] = clamp(transport["logistics_efficiency"] * 0.99 + logistics * 0.01, 0.2, 0.95)

	# مصرف سوخت
	transport["fuel_consumption"] = transport["roads_km"] * 0.01 + transport["traffic_congestion"] * 20.0 + cars * 0.001

	# اثر بر اقتصاد — ممیزی GDP (۱۴۰۵): از کانال مالک-یکتای sector_boosts
	# (نرخ سالانه؛ سیستم هفتگی ۵ بار در ماه ≈ ×۶۰)
	var tr_boosts: Dictionary = econ.get("sector_boosts", {})
	tr_boosts["لجستیک حمل‌ونقل"] = float(transport["logistics_efficiency"]) * 0.0001 * 60.0
	econ["sector_boosts"] = tr_boosts
	state["economy"] = econ

	# اثر بر محیط - آلودگی
	state["environment"]["air_quality"] = clamp(state.get("environment",{}).get("air_quality",0.60) - transport["traffic_congestion"] * 0.0001, 0.1, 0.95)

	# رویدادها
	if transport["traffic_congestion"] > 0.7 and Deterministic.chance(0.012):
		events.append({"type": "traffic_crisis", "message": "بحران ترافیک شهری - آلودگی و زمان تلف شده", "congestion": transport["traffic_congestion"]})

	if transport["logistics_efficiency"] < 0.4 and Deterministic.chance(0.01):
		events.append({"type": "logistics_crisis", "message": "بحران لجستیک - تاخیر در توزیع کالا"})

	state["transport_detail"] = transport
	
	# ── لایه واقع‌گرایانه اختصاصی راه‌ها و حمل‌ونقل (جایگزین قالب خودکار) — بخش ۳.۴۳ ──
	# تراکم ترافیک: جمعیت شهری فزاینده، مسیر فشاینده، و حمل‌ونقل عمومی قوی کاهنده
	var urban_pop_t = float(pop.get("total", 85_000_000.0)) * float(pop.get("urban_ratio", 0.75))
	var pt_relief = float(state.get("public_transport", {}).get("coverage", 0.60)) * 0.20
	var congestion_target = clampf(urban_pop_t / 60_000_000.0 * 0.30 * (90_000.0 / maxf(float(transport.get("roads_km", 80000.0)), 1000.0)) + 0.10 - pt_relief, 0.05, 0.95)
	transport["traffic_congestion"] = clampf(float(transport.get("traffic_congestion", 0.40)) * 0.995 + congestion_target * 0.005, 0.05, 0.95)
	# کارایی لجستیک = میانگین وزنی کیفیت چهار شبکه — حلقه ضعیف کل زنجیره را کند می‌کند
	var logistics_true = float(transport.get("roads_quality", 0.60)) * 0.4 + float(transport.get("rail_quality", 0.55)) * 0.25 + float(transport.get("ports_capacity", 0.70)) * 0.20 + float(transport.get("airports_capacity", 0.65)) * 0.15
	var weakest = minf(minf(float(transport.get("roads_quality", 0.60)), float(transport.get("rail_quality", 0.55))), minf(float(transport.get("ports_capacity", 0.70)), float(transport.get("airports_capacity", 0.65))))
	transport["logistics_efficiency"] = clampf(float(transport.get("logistics_efficiency", 0.65)) * 0.995 + (logistics_true * 0.8 + weakest * 0.2) * 0.005, 0.15, 0.97)
	# مصرف سوخت: ترافیک بیشتر و حمل‌ونقل عمومی ضعیف → بنزین بیشتر
	transport["fuel_consumption"] = 100.0 * (0.6 + float(transport.get("traffic_congestion", 0.40)) * 0.8) * (1.0 - pt_relief * 0.4)
	# ایمنی جاده: کیفیت پایین راه‌ها → کشته‌های تصادف
	if float(transport.get("roads_quality", 0.60)) < 0.40 and Deterministic.chance(0.005):
		events.append({"type": "road_safety_crisis", "message": "آمار بالای تصادفات جاده‌ای - نقص فنی راه‌ها قربانی می‌گیرد"})
	if float(transport.get("traffic_congestion", 0.40)) > 0.70 and Deterministic.chance(0.004):
		events.append({"type": "gridlock", "message": "قفل ترافیکی در کلان‌شهرها - هزینه اقتصادی روزانه معطل‌های شهری"})
	state["transport_detail"] = transport

	return {"success": true, "state": state, "events": events}
