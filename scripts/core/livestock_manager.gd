extends Node
# ────────────────────────────────────────────────────────────────────────────
# دامپروری و امنیت پروتئین — عمق زنجیره دام و طیور
# تولید گوشت/شیر/تخم‌مرغ، واکسیناسیون دام، بهداشت دام، دامداری صنعتی و
# علوفه. خشکسالی و بیابان‌زایی به دام لطمه می‌زند؛ خودکفایی پروتئین
# امنیت غذایی را بالا می‌برد. پیوند: کشاورزی، آبخیزداری، غذا، بهداشت.
#
# state["livestock_policy"] = {
#   "industrial":0..1, "vaccination":0..1, "feed":0..1,
#   "breeding":0..1, "last_program":turn,
#   "self_suff":0..1, "protein_security":0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("livestock_policy"):
		state["livestock_policy"] = {
			"industrial": 0.30, "vaccination": 0.45, "feed": 0.35,
			"breeding": 0.25, "last_program": -99,
			"self_suff": 0.65, "protein_security": 0.55,
			"herd_size": 0.50, "disease_risk": 0.30,
			"milk_production": 0.45, "meat_production": 0.40
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var lp: Dictionary = state["livestock_policy"]
	var agri: Dictionary = state.get("agriculture", {})
	var food: Dictionary = state.get("food_chain_policy", {})
	var watershed: Dictionary = state.get("watershed_policy", {})
	var health: Dictionary = state.get("health", {})
	var econ: Dictionary = state.get("economy", {})

	var industrial: float = float(lp.get("industrial", 0.30))
	var vacc: float = float(lp.get("vaccination", 0.45))
	var feed: float = float(lp.get("feed", 0.35))
	var breeding: float = float(lp.get("breeding", 0.25))

	# تنش خشکسالی و مرتع
	var desert: float = float(watershed.get("desertification", 0.45))
	var soil: float = float(watershed.get("soil_health", 0.55))
	var drought: float = clampf(desert * 0.5 + (1.0 - soil) * 0.2, 0.0, 1.0)

	# اندازه گله: صنعتی + اصلاح نژاد - خشکسالی
	var herd: float = clampf(
		0.30 + industrial * 0.30 + breeding * 0.20 + feed * 0.15 - drought * 0.25, 0.05, 0.95)
	lp["herd_size"] = herd

	# ریسک بیماری دامی
	var disease: float = clampf(0.65 - vacc * 0.50 - industrial * 0.15, 0.05, 0.90)
	lp["disease_risk"] = disease

	# تولید شیر و گوشت
	var milk: float = clampf(herd * 0.6 + industrial * 0.20 + breeding * 0.10 - disease * 0.15, 0.05, 0.98)
	var meat: float = clampf(herd * 0.55 + feed * 0.20 + breeding * 0.10 - disease * 0.15, 0.05, 0.98)
	lp["milk_production"] = milk
	lp["meat_production"] = meat

	# خودکفایی پروتئین
	var self_suff: float = clampf(0.40 + milk * 0.25 + meat * 0.25 + industrial * 0.10, 0.10, 0.98)
	lp["self_suff"] = self_suff
	var protein_sec: float = clampf(
		0.30 + self_suff * 0.40 + float(food.get("food_security", 0.55)) * 0.20 - drought * 0.15, 0.10, 0.98)
	lp["protein_security"] = protein_sec

	# اثر اقتصادی و غذایی
	var gdp: float = float(econ.get("gdp", 1.0))
	econ["gdp"] = gdp * (1.0 + (milk + meat) * 0.0003)
	state["economy"] = econ
	if not agri.is_empty():
		agri["food_security"] = clampf(float(agri.get("food_security", 0.80)) + protein_sec * 0.0008, 0.1, 1.0)
		state["agriculture"] = agri

	# بیماری دامی که به سلامت عمومی سرایت کند
	if disease > 0.65 and Deterministic.chance(0.04):
		if not health.is_empty():
			health["quality"] = clampf(float(health.get("quality", 0.60)) - 0.004, 0.1, 1.0)
			state["health"] = health
		events.append({"type": "livestock_disease", "message": "🦠 شیوع بیماری دامی؛ تولید پروتئین و سلامت آسیب دید"})
	elif protein_sec > 0.75 and Deterministic.chance(0.025):
		events.append({"type": "protein_secure", "message": "🥩 خودکفایی پروتئین حیوانی به ثبات رسید"})

	state["livestock_policy"] = lp
	return {"state": state, "events": events}

func expand_industrial(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var lp: Dictionary = state["livestock_policy"]
	if turn - int(lp.get("last_program", -99)) < 5:
		return {"success": false, "reason": "توسعه دامداری صنعتی هر ۵ نوبت یک بار", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.004
	lp["last_program"] = turn
	lp["industrial"] = clampf(float(lp.get("industrial", 0.30)) + 0.15, 0.0, 1.0)
	state["economy"] = econ
	state["livestock_policy"] = lp
	return {"success": true, "state": state,
		"events": [{"type": "industrial", "message": "🏭 دامداری‌های صنعتی و مکانیزه توسعه یافت"}]}

func vaccination(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var lp: Dictionary = state["livestock_policy"]
	lp["vaccination"] = clampf(float(lp.get("vaccination", 0.45)) + 0.15, 0.0, 1.0)
	state["livestock_policy"] = lp
	return {"success": true, "state": state,
		"events": [{"type": "vaccine", "message": "💉 واکسیناسیون سراسری دام اجرا شد"}]}

func improve_feed(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var lp: Dictionary = state["livestock_policy"]
	var agri: Dictionary = state.get("agriculture", {})
	lp["feed"] = clampf(float(lp.get("feed", 0.35)) + 0.15, 0.0, 1.0)
	if not agri.is_empty():
		agri["yield"] = clampf(float(agri.get("yield", 0.70)) + 0.005, 0.2, 1.6)
		state["agriculture"] = agri
	state["livestock_policy"] = lp
	return {"success": true, "state": state,
		"events": [{"type": "feed", "message": "🌾 تولید علوفه و خوراک دام بهبود یافت"}]}

func breeding_program(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var lp: Dictionary = state["livestock_policy"]
	lp["breeding"] = clampf(float(lp.get("breeding", 0.25)) + 0.15, 0.0, 1.0)
	state["livestock_policy"] = lp
	return {"success": true, "state": state,
		"events": [{"type": "breeding", "message": "🐂 اصلاح نژاد دام و طیور انجام شد"}]}
