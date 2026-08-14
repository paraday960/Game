extends Node
# ────────────────────────────────────────────────────────────────────────────
# دارو و صنعت سلامت‌محور — عمق امنیت درمانی
# تولید داروی داخلی، داروی ژنریک/بیوسیمیلار، ذخیره راهبردی دارو، واکسن و
# تجهیزات پزشکی. وابستگی به واردات در بحران/تحریم آسیب‌پذیر است؛ تولید داخلی
# ارز می‌برد، قیمت دارو را کنترل و مرگ‌ومیر را کم می‌کند.
# پیوند: بهداشت، اقتصاد، پژوهش، زنجیره تأمین، پدافند.
#
# state["pharma_policy"] = {
#   "domestic":0..1, "generic":0..1, "stockpile":0..1,
#   "vaccine":0..1, "medical_devices":0..1,
#   "last_plant":turn, "import_dep":0..1, "drug_security":0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("pharma_policy"):
		state["pharma_policy"] = {
			"domestic": 0.30, "generic": 0.40, "stockpile": 0.30,
			"vaccine": 0.20, "medical_devices": 0.25,
			"last_plant": -99, "import_dep": 0.65,
			"drug_security": 0.40, "drug_cost": 0.60,
			"local_production": 0.35
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var pp: Dictionary = state["pharma_policy"]
	var econ: Dictionary = state.get("economy", {})
	var health: Dictionary = state.get("health", {})
	var research: Dictionary = state.get("research_policy", {})
	var supply: Dictionary = state.get("supply_policy", {})

	var domestic: float = float(pp.get("domestic", 0.30))
	var generic: float = float(pp.get("generic", 0.40))
	var stockpile: float = float(pp.get("stockpile", 0.30))
	var vaccine: float = float(pp.get("vaccine", 0.20))
	var devices: float = float(pp.get("medical_devices", 0.25))

	# تولید داخلی: ژنریک + واکسن + دستگاه
	var local_prod: float = clampf(
		0.15 + domestic * 0.35 + generic * 0.20 + vaccine * 0.15 + devices * 0.15,
		0.05, 0.95)
	pp["local_production"] = local_prod
	var import_dep: float = clampf(1.0 - local_prod, 0.10, 0.95)
	pp["import_dep"] = import_dep

	# امنیت دارو: تولید داخلی + ذخیره + لجستیک
	var supply_resilience: float = float(supply.get("logistics_index", 0.45))
	var drug_sec: float = clampf(
		0.15 + local_prod * 0.35 + stockpile * 0.30 + supply_resilience * 0.15, 0.05, 0.98)
	pp["drug_security"] = drug_sec

	# هزینه دارو: تولید داخلی و ژنریک ارزان‌تر؛ واردات گران‌تر
	var sanction: float = float(state.get("world", {}).get("sanctions_pressure", 0.3))
	var drug_cost: float = clampf(0.70 - local_prod * 0.25 - generic * 0.20 + import_dep * sanction * 0.20, 0.15, 1.5)
	pp["drug_cost"] = drug_cost

	# اثر بر سلامت و اقتصاد
	var gdp: float = float(econ.get("gdp", 1.0))
	if not health.is_empty():
		health["quality"] = clampf(float(health.get("quality", 0.60)) + drug_sec * 0.002 - drug_cost * 0.0008, 0.1, 1.0)
		state["health"] = health
	econ["inflation"] = clampf(float(econ.get("inflation", 0.08)) + drug_cost * 0.001 - local_prod * 0.001, 0.0, 1.0)
	# صنعت دارو در GDP
	econ["gdp"] = gdp * (1.0 + local_prod * 0.0005)
	state["economy"] = econ

	# رویدادها
	if drug_sec < 0.30 and Deterministic.chance(0.05):
		# بیمار بدون دارو واقعاً ضربه می‌خورد: سلامت و شادی پایین می‌آید
		state["health"]["quality"] = clampf(float(state.get("health", {}).get("quality", 0.60)) - 0.020, 0.1, 0.95)
		state["population"]["happiness"] = clampf(float(state["population"].get("happiness", 0.60)) - 0.010, 0.05, 1.0)
		events.append({"type": "drug_shortage", "message": "💊 کمبود دارو! بیماران و بیمارستان‌ها تحت فشار"})
	elif local_prod > 0.65 and Deterministic.chance(0.025):
		events.append({"type": "pharma_export", "message": "🧪 صادرات داروی داخلی رشد کرد؛ ارزآوری سلامت بالا رفت"})
	elif vaccine > 0.60 and Deterministic.chance(0.02):
		events.append({"type": "vaccine_self", "message": "💉 خودکفایی واکسن به ثمر نشست؛ آمادگی همه‌گیری بالا رفت"})

	state["pharma_policy"] = pp
	return {"state": state, "events": events}

func build_plant(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var pp: Dictionary = state["pharma_policy"]
	if turn - int(pp.get("last_plant", -99)) < 6:
		return {"success": false, "reason": "احداث کارخانه دارو هر ۶ نوبت یک بار", "state": state, "events": []}
	var tech: float = float(state.get("technology", {}).get("branch_levels", {}).get("پزشکی", state.get("technology", {}).get("branch_levels", {}).get("دیجیتال", 0)))
	if tech < 4:
		return {"success": false, "reason": "به فناوری سطح ۴ نیاز است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.007
	pp["last_plant"] = turn
	pp["domestic"] = clampf(float(pp.get("domestic", 0.30)) + 0.15, 0.0, 1.0)
	state["economy"] = econ
	state["pharma_policy"] = pp
	return {"success": true, "state": state,
		"events": [{"type": "plant", "message": "🏭 کارخانه تولید دارو و مواد اولیه افتتاح شد"}]}

func expand_generic(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var pp: Dictionary = state["pharma_policy"]
	pp["generic"] = clampf(float(pp.get("generic", 0.40)) + 0.15, 0.0, 1.0)
	state["pharma_policy"] = pp
	return {"success": true, "state": state,
		"events": [{"type": "generic", "message": "💊 سهم داروی ژنریک داخلی افزایش یافت؛ قیمت دارو کم شد"}]}

func stockpile_drugs(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var pp: Dictionary = state["pharma_policy"]
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.003
	pp["stockpile"] = clampf(float(pp.get("stockpile", 0.30)) + 0.15, 0.0, 1.0)
	state["economy"] = econ
	state["pharma_policy"] = pp
	return {"success": true, "state": state,
		"events": [{"type": "stockpile", "message": "📦 ذخیره راهبردی دارو تقویت شد"}]}

func vaccine_program(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var pp: Dictionary = state["pharma_policy"]
	pp["vaccine"] = clampf(float(pp.get("vaccine", 0.20)) + 0.15, 0.0, 1.0)
	state["pharma_policy"] = pp
	return {"success": true, "state": state,
		"events": [{"type": "vaccine", "message": "💉 برنامه تولید واکسن و واکسیناسیون گسترش یافت"}]}
