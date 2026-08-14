extends BaseSystem
# ۳.۲۸ صنعت و معدن - پیاده‌سازی کامل با زنجیره ارزش

func compute(state: Dictionary, tick: int) -> Dictionary:
	var industry = state.get("industry", {})
	var resources = state.get("resources", {})
	var econ = state.get("economy", {})
	var tech = state.get("technology", {})
	var pop = state.get("population", {})
	var environment = state.get("environment", {})

	industry["output"] = industry.get("output", 100.0)
	industry["capacity_usage"] = industry.get("capacity_usage", 0.75)
	industry["heavy"] = industry.get("heavy", 0.40)
	industry["light"] = industry.get("light", 0.35)
	industry["advanced"] = industry.get("advanced", 0.15)
	industry["knowledge_based"] = industry.get("knowledge_based", 0.10)
	industry["productivity"] = industry.get("productivity", 0.60)
	industry["supply_chain"] = industry.get("supply_chain", 0.65)
	industry["industrial_parks"] = industry.get("industrial_parks", 20)
	industry["mining_output"] = industry.get("mining_output", 80.0)

	var events = []

	var industry_budget_share = econ.get("budget_allocations",{}).get("زیرساخت",0.18) * 0.5
	var industry_budget = econ.get("government_spending",0.0) * industry_budget_share

	# تولید صنعتی = f(سرمایه، انرژی، نیروی کار، فناوری)
	var energy = resources.get("inventory",{}).get("برق",100.0) / 100.0
	var raw_materials = (resources.get("inventory",{}).get("آهن",60.0) + resources.get("inventory",{}).get("مس",50.0)) / 110.0
	var workforce = pop.get("happiness",0.6) * 0.5 + pop.get("participation_rate",0.65) * 0.5
	var tech_industry = tech.get("branches",{}).get("صنعت",0.20)
	var infra_q = state.get("infrastructure",{}).get("quality",0.55)

	var output_factor = 0.5 + energy * 0.2 + raw_materials * 0.15 + workforce * 0.2 + tech_industry * 0.25 + infra_q * 0.1
	output_factor = clamp(output_factor, 0.3, 1.5)

	# نُرم مرجع: ~۲٪ تولید ناخالص سالانه برای سیاست صنعتی
	var ind_norm: float = max(float(econ.get("gdp", 1.0)), 1.0) * 0.02 / 12.0
	var new_output = 100.0 * output_factor * (1.0 + clampf(industry_budget / ind_norm - 1.0, -1.0, 1.5) * 0.08)
	industry["output"] = industry["output"] * 0.98 + new_output * 0.02

	# بهره‌وری
	var productivity = 0.5 + tech_industry * 0.3 + pop.get("happiness",0.6) * 0.1 + education_quality(state) * 0.1
	industry["productivity"] = clamp(industry["productivity"] * 0.99 + productivity * 0.01, 0.2, 0.95)

	# ظرفیت
	industry["capacity_usage"] = clamp(industry["output"] / 150.0, 0.3, 1.2)  # >1 اضافه کاری

	# ترکیب بخشی
	# سنگین: سرمایه/انرژی زیاد
	# سبک: نیروی کار
	# پیشرفته: فناوری
	# دانش‌بنیان: نوآوری
	var heavy_target = 0.40 - tech_industry * 0.1 + energy * 0.1
	var light_target = 0.35 - tech_industry * 0.05
	var advanced_target = 0.15 + tech_industry * 0.2
	var knowledge_target = 0.10 + tech.get("research_rate",10.0) / 50.0 * 0.1

	industry["heavy"] = clamp(industry["heavy"] * 0.995 + heavy_target * 0.005, 0.1, 0.70)
	industry["light"] = clamp(industry["light"] * 0.995 + light_target * 0.005, 0.1, 0.60)
	industry["advanced"] = clamp(industry["advanced"] * 0.995 + advanced_target * 0.005, 0.05, 0.50)
	industry["knowledge_based"] = clamp(industry["knowledge_based"] * 0.995 + knowledge_target * 0.005, 0.02, 0.40)

	# نرمالایز ترکیب
	var sum_sectors = industry["heavy"] + industry["light"] + industry["advanced"] + industry["knowledge_based"]
	for k in ["heavy", "light", "advanced", "knowledge_based"]:
		industry[k] /= sum_sectors

	# زنجیره تأمین
	var supply = 0.6 + infra_q * 0.2 + industry["capacity_usage"] * 0.1 + tech_industry * 0.1
	industry["supply_chain"] = clamp(industry["supply_chain"] * 0.99 + supply * 0.01, 0.2, 0.95)

	# معدن - استخراج
	var mining = 80.0 * (0.7 + resources.get("capacity",{}).get("آهن",120.0)/120.0 * 0.3 + tech_industry * 0.2)
	industry["mining_output"] = industry["mining_output"] * 0.99 + mining * 0.01

	# اثر بر منابع - مصرف مواد معدنی
	resources["inventory"]["آهن"] = clamp(resources.get("inventory",{}).get("آهن",60.0) - industry["output"] * 0.01 + industry["mining_output"] * 0.02, 0.0, 150.0)
	resources["inventory"]["مس"] = clamp(resources.get("inventory",{}).get("مس",50.0) - industry["output"] * 0.005 + industry["mining_output"] * 0.01, 0.0, 120.0)
	state["resources"] = resources

	# اثر بر محیط - آلودگی
	environment["pollution"] = clamp(environment.get("pollution",0.4) + industry["heavy"] * 0.0005, 0.0, 1.0)
	state["environment"] = environment

	# پارک‌های صنعتی
	if industry_budget_share > 0.10 and Deterministic.chance(0.005):
		industry["industrial_parks"] += 1
		events.append({"type": "industrial_park_opened", "message": "پارک صنعتی جدید افتتاح شد - افزایش ظرفیت"})

	# حلقه بازخورد: صنعت ← درآمد ← سرمایه ← صنعت
	econ["gdp"] *= (1.0 + industry["output"] / 10000.0 * 0.001)
	state["economy"] = econ

	# رویدادها
	if industry["supply_chain"] < 0.4 and Deterministic.chance(0.012):
		events.append({"type": "supply_chain_break", "message": "شکست زنجیره تأمین - گلوگاه لجستیک", "supply": industry["supply_chain"]})

	if industry["capacity_usage"] > 1.0 and Deterministic.chance(0.01):
		events.append({"type": "overcapacity", "message": "اضافه کاری صنعتی - فرسودگی تجهیزات", "usage": industry["capacity_usage"]})

	if tech_industry > 0.5 and industry["knowledge_based"] > 0.2 and Deterministic.chance(0.008):
		events.append({"type": "industry_4.0", "message": "تحول صنعت ۴.۰ - کارخانه هوشمند! بهره‌وری جهش کرد"})
		industry["productivity"] += 0.05
		industry["advanced"] += 0.03

	if Deterministic.chance(0.01):
		var r = Deterministic.next_float()
		if r < 0.5:
			events.append({"type": "mining_discovery", "message": "کشف معدن جدید - افزایش ظرفیت استخراج"})
			industry["mining_output"] += 10.0
		else:
			events.append({"type": "industrial_growth", "message": "رشد تولید صنعتی"})

	state["industry"] = industry
	
	# ── لایه واقع‌گرایانه اختصاصی صنعت (جایگزین قالب خودکار تکراری) — بخش ۳.۲۸ ──
	# ارتقای ساختاری: فناوری بالاتر سهم صنایع پیشرفته و دانش‌بنیان را زیاد می‌کند
	var tech_i: float = float(tech.get("branches", {}).get("صنعت", 0.20))
	var upgrade: float = (tech_i - 0.25) * 0.0002
	industry["advanced"] = clampf(float(industry.get("advanced", 0.15)) + upgrade, 0.02, 0.80)
	industry["knowledge_based"] = clampf(float(industry.get("knowledge_based", 0.10)) + upgrade * 0.7, 0.01, 0.70)
	# بهره‌برداری از ظرفیت وابسته به نگهداشت زیرساخت
	var maint_i: float = (float(econ.get("budget_allocations", {}).get("زیرساخت", 0.15)) - 0.12) * 0.0005
	industry["capacity_usage"] = clampf(float(industry.get("capacity_usage", 0.75)) + maint_i, 0.30, 0.98)
	if bool(resources.get("energy_crisis", false)) and Deterministic.chance(0.006):
		events.append({"type": "industry_energy_cut", "message": "قطعی انرژی صنایع - خطوط تولید نیمه‌فعال شدند"})
	state["industry"] = industry

	return {"success": true, "state": state, "events": events}

func education_quality(state: Dictionary) -> float:
	return state.get("education",{}).get("quality",0.55)
