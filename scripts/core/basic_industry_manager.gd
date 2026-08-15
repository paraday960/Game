extends Node
# ────────────────────────────────────────────────────────────────────────────
# صنایع بنیادی (فولاد و سیمان) — عمق زنجیره ساخت
# تولید فولاد و سیمان، خودکفایی مصالح، صادرات و بهره‌وری. این صنایع سنگین
# ستون ساخت‌وساز، زیرساخت و صنایع پایین‌دستی هستند. پیوند: معدن، مسکن،
# زیرساخت، پتروشیمی، انرژی.
#
# state["basic_industry_policy"] = {
#   "steel":0..1, "cement":0..1, "integration":0..1,
#   "efficiency":0..1, "last_capacity":turn,
#   "output":0..1, "self_sufficiency":0..1, "exports":0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("basic_industry_policy"):
		state["basic_industry_policy"] = {
			"steel": 0.35, "cement": 0.40, "integration": 0.25,
			"efficiency": 0.30, "last_capacity": -99,
			"output": 0.35, "self_sufficiency": 0.60,
			"exports": 0.15, "import_dep": 0.40,
			"construction_materials": 0.50
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var bp: Dictionary = state["basic_industry_policy"]
	var econ: Dictionary = state.get("economy", {})
	var mining: Dictionary = state.get("mining_policy", {})
	var energy: Dictionary = state.get("energy_policy", {})
	var downstream: Dictionary = state.get("downstream_policy", {})
	var housing: Dictionary = state.get("housing_policy", {})
	var infra: Dictionary = state.get("infrastructure", {})

	var steel: float = float(bp.get("steel", 0.35))
	var cement: float = float(bp.get("cement", 0.40))
	var integration: float = float(bp.get("integration", 0.25))
	var efficiency: float = float(bp.get("efficiency", 0.30))

	# سنگ معدن و انرژی ورودی صنایع بنیادی
	var ore: float = float(mining.get("output", 0.40))
	var energy_security: float = float(downstream.get("fuel_security", 0.45))

	# تولید کل
	var output: float = clampf(
		0.15 + steel * 0.35 + cement * 0.30 + integration * 0.20 + efficiency * 0.15, 0.05, 0.98)
	bp["output"] = output

	# خودکفایی مصالح: مسکن و زیرساخت به این صنایع وابسته‌اند
	var construction_demand: float = float(housing.get("social_supply", 0.2)) + float(infra.get("quality", 0.5))
	var self_suff: float = clampf(
		0.30 + output * 0.40 + ore * 0.15 + energy_security * 0.15, 0.10, 0.98)
	bp["self_sufficiency"] = self_suff
	bp["construction_materials"] = clampf(0.20 + output * 0.60 + self_suff * 0.20, 0.1, 0.98)

	# وابستگی واردات
	var import_dep: float = clampf(1.0 - self_suff - integration * 0.10, 0.05, 0.90)
	bp["import_dep"] = import_dep

	# صادرات مازاد
	var exports: float = clampf(steel * 0.25 + output * 0.10 - construction_demand * 0.05, 0.0, 0.90)
	bp["exports"] = exports

	# اثر اقتصادی
	var gdp: float = float(econ.get("gdp", 1.0))
	# ممیزی GDP (۱۴۰۵): اثر مداوم از کانال مالک-یکتای sector_boosts (نرخ سالانه؛ ماهانه: ×۱۲)
	var bi_boosts: Dictionary = econ.get("sector_boosts", {})
	bi_boosts["صنایع بنیادی"] = (output * 0.0006 + exports * 0.0003) * 12.0
	# صنایع سنگین انرژی‌بر هستند — ناامنی انرژی همان کلید را کم می‌کند (بازنویسی، نه انباشت)
	if energy_security < 0.3:
		bi_boosts["صنایع بنیادی"] = float(bi_boosts["صنایع بنیادی"]) - 0.0002 * 12.0
	econ["sector_boosts"] = bi_boosts
	state["economy"] = econ

	# رویدادها
	if output > 0.70 and exports > 0.30 and Deterministic.chance(0.03):
		var ri_steel: Dictionary = state.get("economy", {}).get("reserve_inflows", {})
		ri_steel["صادرات فولاد"] = float(state.get("economy", {}).get("gdp", 500e9)) * 0.0004
		state["economy"]["reserve_inflows"] = ri_steel
		events.append({"type": "steel_export", "message": "🏗️ صادرات فولاد و سیمان جهش کرد؛ صنایع بنیادی ارزآور شدند"})
	elif self_suff < 0.40 and Deterministic.chance(0.04):
		# اثر واقعی کمبود مصالح: پروژه‌ها کند می‌شوند و قیمت مصالح/مسکن جهش می‌زند
		econ["gdp"] = float(econ.get("gdp", gdp)) * (1.0 - 0.0005)
		econ["inflation"] = clampf(float(econ.get("inflation", 0.08)) + 0.001, 0.0, 0.50)
		state["economy"] = econ
		if state.has("housing_policy"):
			var hpol: Dictionary = state["housing_policy"]
			hpol["price_index"] = clampf(float(hpol.get("price_index", 0.50)) + 0.02, 0.0, 1.0)
			state["housing_policy"] = hpol
			events.append({"type": "material_shortage", "message": "🧱 کمبود مصالح ساختمانی؛ پروژه‌های مسکن و زیرساخت کند شد"})

	state["basic_industry_policy"] = bp
	return {"state": state, "events": events}

func expand_steel(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var bp: Dictionary = state["basic_industry_policy"]
	if turn - int(bp.get("last_capacity", -99)) < 6:
		return {"success": false, "reason": "توسعه ظرفیت هر ۶ نوبت یک بار", "state": state, "events": []}
	var tech: float = float(state.get("technology", {}).get("branch_levels", {}).get("صنعت", 0))
	if tech < 4:
		return {"success": false, "reason": "به فناوری صنعت سطح ۴ نیاز است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.008
	bp["last_capacity"] = turn
	bp["steel"] = clampf(float(bp.get("steel", 0.35)) + 0.15, 0.0, 1.0)
	state["economy"] = econ
	state["basic_industry_policy"] = bp
	return {"success": true, "state": state,
		"events": [{"type": "steel", "message": "🔩 کارخانه فولاد جدید به بهره‌برداری رسید"}]}

func expand_cement(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var bp: Dictionary = state["basic_industry_policy"]
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.006
	bp["cement"] = clampf(float(bp.get("cement", 0.40)) + 0.15, 0.0, 1.0)
	state["economy"] = econ
	state["basic_industry_policy"] = bp
	return {"success": true, "state": state,
		"events": [{"type": "cement", "message": "🏭 کارخانه سیمان توسعه یافت"}]}

func integrate_chain(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var bp: Dictionary = state["basic_industry_policy"]
	bp["integration"] = clampf(float(bp.get("integration", 0.25)) + 0.15, 0.0, 1.0)
	# یکپارچه‌سازی معدن-فولاد-ساخت وابستگی را کم می‌کند
	bp["import_dep"] = clampf(float(bp.get("import_dep", 0.40)) - 0.08, 0.05, 0.90)
	state["basic_industry_policy"] = bp
	return {"success": true, "state": state,
		"events": [{"type": "integration", "message": "🔗 زنجیره معدن تا فولاد و ساخت یکپارچه شد"}]}

func efficiency_program(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var bp: Dictionary = state["basic_industry_policy"]
	var tech: float = float(state.get("technology", {}).get("branch_levels", {}).get("صنعت", 0))
	if tech < 5:
		return {"success": false, "reason": "به فناوری صنعت سطح ۵ نیاز است", "state": state, "events": []}
	bp["efficiency"] = clampf(float(bp.get("efficiency", 0.30)) + 0.15, 0.0, 1.0)
	state["basic_industry_policy"] = bp
	return {"success": true, "state": state,
		"events": [{"type": "efficiency", "message": "⚡ بهره‌وری و بهینه‌سازی انرژی صنایع بنیادی بالا رفت"}]}
