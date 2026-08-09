extends BaseSystem
# ۳.۲۷ کشاورزی و امنیت غذایی - پیاده‌سازی کامل

func compute(state: Dictionary, tick: int) -> Dictionary:
	var agri = state.get("agriculture", {})
	var resources = state.get("resources", {})
	var econ = state.get("economy", {})
	var pop = state.get("population", {})
	var environment = state.get("environment", {})
	var water_infra = state.get("water_infrastructure", {})

	agri["production"] = agri.get("production", 100.0)
	agri["food_security"] = agri.get("food_security", 0.85)
	agri["yield"] = agri.get("yield", 0.70)
	agri["irrigated_land"] = agri.get("irrigated_land", 0.40)
	agri["mechanization"] = agri.get("mechanization", 0.50)
	agri["fertilizer_use"] = agri.get("fertilizer_use", 0.60)
	agri["crop_diversity"] = agri.get("crop_diversity", 0.55)
	agri["storage_capacity"] = agri.get("storage_capacity", 0.60)
	agri["waste"] = agri.get("waste", 0.20)
	agri["self_sufficiency"] = agri.get("self_sufficiency", 0.80)

	var events = []

	var agri_budget_share = 0.05  # از زیرساخت و منابع
	var agri_budget = econ.get("government_spending",0.0) * agri_budget_share

	# فرمول‌ها
	# تولید کشاورزی = f(زمین آبی، مکانیزاسیون، کود، آب، اقلیم، فناوری)
	var water = resources.get("inventory",{}).get("آب",90.0) / 100.0
	var tech_agri = state.get("technology",{}).get("branches",{}).get("صنعت",0.20) * 0.5
	var climate = 1.0 - environment.get("climate_change",0.50) * 0.3
	var soil = environment.get("soil_quality",0.60)

	var yield_factor = 0.5 + agri["irrigated_land"] * 0.2 + agri["mechanization"] * 0.15 + agri["fertilizer_use"] * 0.1 + water * 0.2 + soil * 0.15 + tech_agri * 0.1
	yield_factor *= climate
	yield_factor = clamp(yield_factor, 0.2, 1.5)
	agri["yield"] = yield_factor

	var production = 100.0 * yield_factor * (1.0 + agri_budget / 10_000_000_000.0 * 0.1)
	agri["production"] = agri["production"] * 0.99 + production * 0.01

	# امنیت غذایی = f(تولید، ذخیره، واردات، توزیع، ضایعات)
	var storage = agri["storage_capacity"]
	var waste = agri["waste"]
	var trade = state.get("trade",{}).get("imports",70_000_000_000.0) / 70_000_000_000.0
	var self_suff = agri["production"] / 100.0
	var food_security = 0.5 + self_suff * 0.3 + storage * 0.1 + (1.0 - waste) * 0.1 + trade * 0.05
	agri["food_security"] = clamp(agri["food_security"] * 0.99 + food_security * 0.01, 0.1, 0.95)
	agri["self_sufficiency"] = clamp(self_suff, 0.1, 1.5)

	# آبیاری
	agri["irrigated_land"] = clamp(agri["irrigated_land"] + (water - 0.5) * 0.001 + agri_budget_share * 0.001, 0.1, 0.85)

	# مکانیزاسیون با فناوری و بودجه
	agri["mechanization"] = clamp(agri["mechanization"] + tech_agri * 0.001, 0.1, 0.95)

	# ضایعات غذایی - با زیرساخت و ذخیره کاهش
	var infra_q = state.get("infrastructure",{}).get("quality",0.55)
	agri["waste"] = clamp(agri["waste"] + (0.25 - infra_q * 0.1 - storage * 0.1) * 0.001, 0.05, 0.50)

	# تنوع محصول
	agri["crop_diversity"] = clamp(agri["crop_diversity"] + Deterministic.next_range(-0.001, 0.002), 0.2, 0.90)

	# ذخیره
	agri["storage_capacity"] = clamp(agri["storage_capacity"] + (agri_budget_share - 0.04) * 0.002, 0.2, 0.95)

	# اثر بر منابع - غذا
	resources["inventory"]["غذا"] = clamp(resources.get("inventory",{}).get("غذا",85.0) + (agri["production"] - 100.0) * 0.05, 0.0, 150.0)
	state["resources"] = resources

	# حلقه بازخورد: کشاورزی → امنیت غذایی → رضایت
	pop["happiness"] = clamp(pop.get("happiness",0.6) + (agri["food_security"] - 0.5) * 0.001, 0.05, 0.95)
	state["population"] = pop

	# رویدادها
	if agri["food_security"] < 0.5 and Deterministic.chance(0.015):
		events.append({"type": "food_security_crisis", "message": "بحران امنیت غذایی - ذخایر غذا رو به پایان!", "security": agri["food_security"]})
		resources["food_crisis"] = true
		state["resources"] = resources

	if water < 0.4 and Deterministic.chance(0.012):
		events.append({"type": "drought", "message": "خشکسالی و کمبود آب کشاورزی - افت تولید", "water": water})
		agri["production"] *= 0.90

	if agri["yield"] > 1.2 and Deterministic.chance(0.01):
		events.append({"type": "bumper_harvest", "message": "برداشت فراوان - مازاد تولید کشاورزی!"})

	if Deterministic.chance(0.008):
		events.append({"type": "agri_tech_adoption", "message": "پذیرش فناوری نوین کشاورزی - افزایش بهره‌وری"})
		agri["mechanization"] += 0.02
		agri["yield"] += 0.05

	state["agriculture"] = agri
	return {"success": true, "state": state, "events": events}
