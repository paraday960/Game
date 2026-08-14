extends BaseSystem
# ۳.۴۹ صنعت و انبار - کارخانه، انبار، معدن، نیروگاه، شهرک صنعتی، بهره‌برداری، آلودگی، ایمنی

func compute(state: Dictionary, tick: int) -> Dictionary:
	var sites = state.get("industry_sites_detail", {})
	sites["factories"] = sites.get("factories", 5000)
	sites["warehouses"] = sites.get("warehouses", 10000)
	sites["mines"] = sites.get("mines", 200)
	sites["power_plants"] = sites.get("power_plants", 100)
	sites["refineries"] = sites.get("refineries", 10)
	sites["industrial_parks"] = sites.get("industrial_parks", 20)
	sites["utilization"] = sites.get("utilization", 0.75)
	sites["pollution_industrial"] = sites.get("pollution_industrial", 0.40)
	sites["safety_index"] = sites.get("safety_index", 0.65)
	sites["automation"] = sites.get("automation", 0.30)
	sites["energy_consumption"] = sites.get("energy_consumption", 120.0)
	sites["water_consumption"] = sites.get("water_consumption", 80.0)
	sites["export_capacity"] = sites.get("export_capacity", 0.60)
	sites["maintenance_backlog"] = sites.get("maintenance_backlog", 0.20)

	var events = []
	var ind = state.get("industry", {})
	var resources = state.get("resources", {})
	var env = state.get("environment", {})
	var econ = state.get("economy", {})
	var tech = state.get("technology", {})

	var output = ind.get("output", 100.0)
	var capacity_usage = ind.get("capacity_usage", 0.75)
	var productivity = ind.get("productivity", 0.68) if ind.has("productivity") else 0.68

	# بهره‌برداری = استفاده ظرفیت + بهره‌وری
	sites["utilization"] = clamp(capacity_usage*0.7 + productivity*0.3, 0.1, 0.98)

	# آلودگی صنعتی = بهره‌برداری + فناوری پاک معکوس
	var clean_tech = tech.get("branches", {}).get("انرژی_پاک", 0.15)
	var green = env.get("green_energy", 0.20) if env.has("green_energy") else 0.20
	sites["pollution_industrial"] = clamp(sites["pollution_industrial"]*0.993 + (sites["utilization"]-0.5)*0.002 - clean_tech*0.001 - green*0.0005, 0.05, 0.95)

	# ایمنی - آموزش + نگهداری + آلودگی معکوس
	var safety_target = 0.6 + (1.0 - sites["pollution_industrial"])*0.1 + (1.0 - sites["maintenance_backlog"])*0.2 + 0.1
	sites["safety_index"] = clamp(sites["safety_index"]*0.99 + safety_target*0.01, 0.1, 0.95)

	# اتوماسیون - فناوری صنعت
	var ind_tech = tech.get("branches", {}).get("صنعت", 0.20)
	sites["automation"] = clamp(sites["automation"] + ind_tech*0.0004 + econ.get("growth_rate",0.02)*0.0005, 0.05, 0.85)

	# مصرف انرژی و آب - بهره‌برداری
	sites["energy_consumption"] = output * 1.2 * (0.8 + sites["automation"]*0.2)
	sites["water_consumption"] = output * 0.8 * (1.0 - sites["automation"]*0.1)

	# ظرفیت صادرات - کیفیت و زیرساخت
	var infra_q = state.get("infrastructure", {}).get("quality", 0.55)
	sites["export_capacity"] = clamp(infra_q*0.3 + sites["utilization"]*0.3 + sites["automation"]*0.2 + 0.2, 0.1, 0.95)

	# عقب‌ماندگی نگهداری
	sites["maintenance_backlog"] = clamp(sites["maintenance_backlog"] + sites["utilization"]*0.0005 - econ.get("budget_allocations",{}).get("زیرساخت",0.18)*0.001, 0.05, 0.70)

	# رشد کارخانه‌ها
	if tick % 90 == 15:
		if output > 120.0 and econ.get("growth_rate",0.02) > 0.02:
			sites["factories"] += Deterministic.next_int_range(5, 15)
			sites["warehouses"] += Deterministic.next_int_range(10, 30)
			if Deterministic.chance(0.3):
				sites["industrial_parks"] += 1
		if output < 80.0 and Deterministic.chance(0.2):
			sites["factories"] = max(sites["factories"] - Deterministic.next_int_range(2, 8), 3000)

	# نیروگاه‌ها - انرژی
	if tick % 180 == 15 and resources.get("demand",{}).get("برق",12.0) > sites["power_plants"]*1.2:
		sites["power_plants"] += Deterministic.next_int_range(1, 3)

	# پالایشگاه‌ها - نفت
	if tick % 180 == 15 and resources.get("inventory",{}).get("نفت",80.0) > 70.0 and sites["refineries"] < 20:
		sites["refineries"] += Deterministic.next_int_range(0,1)

	# رویدادها
	if sites["pollution_industrial"] > 0.72 and Deterministic.chance(0.015):
		events.append({"type":"industrial_pollution","pollution": sites["pollution_industrial"], "message":"آلودگی صنعتی شدید - ساکنان اطراف شهرک صنعتی شکایت کردند"})

	if sites["safety_index"] < 0.35 and Deterministic.chance(0.012):
		events.append({"type":"industrial_accident","safety": sites["safety_index"], "message":"حادثه کار در کارخانه - ۳ مصدوم، بازرسی ایمنی"})

	if sites["maintenance_backlog"] > 0.50 and Deterministic.chance(0.010):
		events.append({"type":"maintenance_backlog_crisis","backlog": sites["maintenance_backlog"], "message":"عقب‌ماندگی نگهداری - ماشین‌آلات فرسوده، توقف خط"})

	if sites["utilization"] > 0.90 and Deterministic.chance(0.009):
		events.append({"type":"full_utilization","util": sites["utilization"], "message":"ظرفیت تولید تکمیل - نیاز به توسعه شهرک صنعتی جدید"})

	if sites["automation"] > 0.60 and tick % 180 == 15 and Deterministic.chance(0.02):
		events.append({"type":"automation_milestone","automation": sites["automation"], "message":"اتوماسیون ۶۰٪ - ربات‌ها جای ۲۰۰۰ کارگر را گرفتند"})

	state["industry_sites_detail"] = sites
	
	# ── لایه واقع‌گرایانه اختصاصی سایت‌های صنعتی (جایگزین قالب خودکار) — بخش ۳.۴۹ ──
	# انباشت تعمیرات: بودجه زیرساخت کمتر از آستانه → عقب‌ماندگی نگهداشت و کاهش بهره‌برداری
	var infra_budget = float(econ.get("budget_allocations", {}).get("زیرساخت", 0.18))
	var backlog_flow = (0.16 - infra_budget) * 0.004
	sites["maintenance_backlog"] = clampf(float(sites.get("maintenance_backlog", 0.20)) + backlog_flow, 0.03, 0.85)
	sites["utilization"] = clampf(float(sites.get("utilization", 0.75)) - float(sites.get("maintenance_backlog", 0.20)) * 0.0006, 0.10, 0.98)
	# خاموشی برق (تأسیسات شهری دور ۱۲ → اقتصاد) خط تولید را می‌خواباند
	var power_rel = float(econ.get("power_reliability", 1.0))
	if power_rel < 0.70:
		sites["utilization"] = clampf(float(sites.get("utilization", 0.75)) - (0.70 - power_rel) * 0.002, 0.10, 0.98)
	# مصرف انرژی و آب از بهره‌برداری واقعی و اتوماسیون (اتوماسیون انرژی‌برتر ولی آب‌کاه)
	sites["energy_consumption"] = 120.0 * float(sites.get("utilization", 0.75)) * (1.0 + float(sites.get("automation", 0.30)) * 0.15)
	sites["water_consumption"] = 80.0 * float(sites.get("utilization", 0.75)) * (1.0 - float(sites.get("automation", 0.30)) * 0.10)
	# ظرفیت صادرات از لجستیک واقعی بنادر و ریل (راه‌ها دور ۱۲)
	sites["export_capacity"] = clampf(float(sites.get("export_capacity", 0.60)) * 0.997 + float(state.get("transport_detail", {}).get("logistics_efficiency", 0.65)) * 0.003, 0.10, 0.97)
	if float(sites.get("maintenance_backlog", 0.20)) > 0.55 and Deterministic.chance(0.005):
		events.append({"type": "industrial_breakdown", "message": "توقف خط تولید در شهرک صنعتی - انباشت تعمیرات فنی", "backlog": sites["maintenance_backlog"]})
	if power_rel < 0.55 and Deterministic.chance(0.005):
		events.append({"type": "factory_blackout", "message": "خاموشی برق صنایع - تولید فولاد و سیمان با ضرر مواجه شد"})
	if float(sites.get("safety_index", 0.65)) < 0.40 and Deterministic.chance(0.004):
		events.append({"type": "mine_explosion", "message": "انفجار در معدن زغال‌سنگ - کارگران محبوب؛ تحقیقات ایمنی آغاز شد"})
	state["industry_sites_detail"] = sites

	return {"success":true,"state":state,"events":events}
