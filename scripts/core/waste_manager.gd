extends Node
# ────────────────────────────────────────────────────────────────────────────
# پسماند و اقتصاد چرخه‌ای — عمق مدیریت زباله و بازیافت
# جمع‌آوری، دفن بهداشتی، بازیافت، کمپوست و بازیابی انرژی از زباله. مدیریت
# ضعیف → آلودگی، بیماری، شیرآبه و گاز متان. اقتصاد چرخه‌ای، مواد را به
# چرخه تولید برمی‌گرداند، اشتغال سبز می‌سازد و انتشار کربن را می‌کاهد.
# پیوند: محیط‌زیست، بهداشت، انرژی، صنعت، رفاه و شهرداری‌ها.
#
# state["waste_policy"] = {
#   "collection":0..1, "sanitary_landfill":0..1, "recycling":0..1,
#   "compost":0..1, "wte":0..1, "circular":0..1,
#   "last_plant":turn, "last_circular":turn }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("waste_policy"):
		state["waste_policy"] = {
			"collection": 0.65, "sanitary_landfill": 0.30, "recycling": 0.18,
			"compost": 0.10, "wte": 0.05, "circular": 0.15,
			"last_plant": -99, "last_circular": -99,
			"recycling_rate": 0.15, "landfill_dependency": 0.75,
			"illegal_dumping": 0.35
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var wp: Dictionary = state["waste_policy"]
	var urban: Dictionary = state.get("urban_facilities", {})
	var env: Dictionary = state.get("environment", {})
	var health: Dictionary = state.get("health", {})
	var econ: Dictionary = state.get("economy", {})
	var pop: Dictionary = state.get("population", {})
	var resources: Dictionary = state.get("resources", {})

	var collection := float(wp.get("collection", 0.65))
	var landfill := float(wp.get("sanitary_landfill", 0.30))
	var recycling := float(wp.get("recycling", 0.18))
	var compost := float(wp.get("compost", 0.10))
	var wte := float(wp.get("wte", 0.05))
	var circular := float(wp.get("circular", 0.15))

	# نرخ بازیافت واقعی: زیرساخت + اقتصاد چرخه‌ای
	var recycling_rate := clampf(
		recycling * 0.50 + compost * 0.20 + circular * 0.30, 0.02, 0.85)
	wp["recycling_rate"] = recycling_rate
	var landfill_dep := clampf(1.0 - recycling_rate - wte * 0.15, 0.20, 0.97)
	wp["landfill_dependency"] = landfill_dep
	# دفن غیربهداشتی/رهاسازی
	var illegal := clampf(
		(1.0 - collection) * 0.55 + (1.0 - landfill) * 0.25 - wte * 0.05, 0.02, 0.85)
	wp["illegal_dumping"] = illegal

	# همگام‌سازی با تسهیلات شهری
	urban["waste_collection"] = clampf(float(urban.get("waste_collection", 0.70)) * 0.98 + collection * 0.02, 0.2, 0.99)
	urban["waste_recycling"] = clampf(float(urban.get("waste_recycling", 0.15)) * 0.99 + recycling_rate * 0.01, 0.03, 0.75)
	state["urban_facilities"] = urban

	# اثرهای بهداشتی و محیطی
	var waste_harm := illegal * 0.40 + (1.0 - landfill) * 0.25 - wte * 0.05
	health["quality"] = clampf(float(health.get("quality", 0.60)) - waste_harm * 0.001, 0.1, 1.0)
	state["health"] = health
	var current_pollution: float = float(env.get("pollution", env.get("pollution_level", 0.45)))
	env["pollution"] = clampf(current_pollution + illegal * 0.003 - recycling_rate * 0.002, 0.05, 0.95)
	env["air_quality"] = clampf(float(env.get("air_quality", 0.60)) - (wte * 0.10 + illegal * 0.05) * 0.001, 0.05, 1.0)
	state["environment"] = env

	# اقتصاد چرخه‌ای: مواد و انرژی بازیابی می‌شود
	var gdp := float(econ.get("gdp", 1.0))
	var circular_gdp := gdp * (circular * 0.01 + recycling * 0.005 + wte * 0.003)
	# ممیزی GDP (۱۴۰۵): اثر مداوم از کانال مالک-یکتای sector_boosts (نرخ سالانه؛ ماهانه: ×۱۲)
	var was_boost: Dictionary = econ.get("sector_boosts", {})
	was_boost["اقتصاد چرخه‌ای"] = (circular * 0.0003 + recycling * 0.0001) * 12.0
	econ["sector_boosts"] = was_boost
	econ["unemployment"] = clampf(float(econ.get("unemployment", 0.08)) - recycling_rate * 0.0002, 0.02, 0.30)
	if resources.has("inventory") and resources["inventory"].has("مواد_صنعتی"):
		resources["inventory"]["مواد_صنعتی"] = clampf(
			float(resources["inventory"].get("مواد_صنعتی", 65.0)) + circular * 0.02, 0.0, 150.0)
		# بازیابی انرژی از زباله
		if wte > 0.2:
			resources["inventory"]["برق"] = clampf(
				float(resources["inventory"].get("برق", 100.0)) + wte * 0.05, 0.0, 150.0)
		state["resources"] = resources

	# هزینه مدیریت
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + gdp * (0.001 + collection * 0.0008)
	state["economy"] = econ

	# رضایت محلی/روستایی
	if urban.get("waste_collection", 0.7) < 0.5:
		pop["happiness"] = clampf(float(pop.get("happiness", 0.60)) - 0.001, 0.05, 1.0)
		state["population"] = pop

	# رویدادها
	if illegal > 0.60 and Deterministic.chance(0.05):
		health["quality"] = clampf(float(health.get("quality", 0.60)) - 0.005, 0.1, 1.0)
		state["health"] = health
		events.append({"type": "waste_crisis", "message": "🗑️ بحران پسماند! شیرآبه زباله‌های رهاشده آب و خاک را آلوده کرد"})
	elif recycling_rate > 0.55 and Deterministic.chance(0.03):
		events.append({"type": "circular_win", "message": "♻️ صنایع بازیافت رونق گرفت؛ مواد اولیه از زباله استحصال شد"})
	elif wte > 0.40 and Deterministic.chance(0.02):
		events.append({"type": "wte_win", "message": "🔥 نیروگاه زباله‌سوز بخشی از برق شهر را تامین کرد"})

	state["waste_policy"] = wp
	return {"state": state, "events": events}

# ── توسعه جمع‌آوری و مکانیزه ──
func expand_collection(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var wp: Dictionary = state["waste_policy"]
	if float(wp.get("collection", 0.65)) >= 0.97:
		return {"success": false, "reason": "پوشش جمع‌آوری در سقف است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.003
	wp["collection"] = clampf(float(wp.get("collection", 0.65)) + 0.12, 0.0, 1.0)
	state["economy"] = econ
	state["waste_policy"] = wp
	return {"success": true, "state": state,
		"events": [{"type": "collection", "message": "🚛 ناوگان مکانیزه جمع‌آوری پسماند توسعه یافت؛ رهاسازی کم شد"}]}

# ── احداث کارخانه بازیافت ──
func build_recycling(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var wp: Dictionary = state["waste_policy"]
	if turn - int(wp.get("last_plant", -99)) < 6:
		return {"success": false, "reason": "احداث کارخانه بازیافت هر ۶ نوبت یک بار", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.005
	wp["last_plant"] = turn
	wp["recycling"] = clampf(float(wp.get("recycling", 0.18)) + 0.13, 0.0, 1.0)
	econ["unemployment"] = clampf(float(econ.get("unemployment", 0.08)) - 0.0003, 0.02, 0.30)
	state["economy"] = econ
	state["waste_policy"] = wp
	return {"success": true, "state": state,
		"events": [{"type": "recycling_plant", "message": "♻️ کارخانه بازیافت و پردازش پسماند افتتاح شد؛ دفن و آلودگی کم شد"}]}

# ── دفن بهداشتی و نیروگاه زباله‌سوز ──
func build_sanitary_landfill(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var wp: Dictionary = state["waste_policy"]
	if float(wp.get("sanitary_landfill", 0.30)) >= 0.95:
		return {"success": false, "reason": "پوشش دفن بهداشتی در سقف است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.004
	wp["sanitary_landfill"] = clampf(float(wp.get("sanitary_landfill", 0.30)) + 0.15, 0.0, 1.0)
	wp["wte"] = clampf(float(wp.get("wte", 0.05)) + 0.05, 0.0, 0.80)
	state["economy"] = econ
	state["waste_policy"] = wp
	return {"success": true, "state": state,
		"events": [{"type": "sanitary_landfill", "message": "🏞️ لندفیل بهداشتی با سامانه شیرآبه و گاز راه‌اندازی شد"}]}

# ── اقتصاد چرخه‌ای و طراحی سازگار با محیط ──
func circular_economy(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var wp: Dictionary = state["waste_policy"]
	if turn - int(wp.get("last_circular", -99)) < 8:
		return {"success": false, "reason": "برنامه اقتصاد چرخه‌ای هر ۸ نوبت یک بار", "state": state, "events": []}
	var tech := float(state.get("technology", {}).get("branch_levels", {}).get("صنعت", 0))
	if tech < 6:
		return {"success": false, "reason": "به فناوری صنعت سطح ۶ نیاز است", "state": state, "events": []}
	wp["last_circular"] = turn
	wp["circular"] = clampf(float(wp.get("circular", 0.15)) + 0.13, 0.0, 1.0)
	state["environment"]["carbon"] = clampf(state["environment"].get("carbon", 0.6) - 0.005, 0.0, 1.0)
	state["waste_policy"] = wp
	return {"success": true, "state": state,
		"events": [{"type": "circular", "message": "🔄 آیین‌نامه اقتصاد چرخه‌ای اجرا شد؛ تولید دوباره مواد و طراحی سبز اجباری شد"}]}
