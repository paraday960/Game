extends Node
# ────────────────────────────────────────────────────────────────────────────
# زنجیره تأمین و تدارکات ملی — عمق تاب‌آوری لجستیک
# ذخایر راهبردی، وابستگی واردات، گلوگاه‌های تولید، تنوع تأمین‌کننده و
# ذخیره‌سازی غذا/دارو/سوخت/ریزتراشه. اختلال زنجیره به تورم و تولید می‌انجامد.
# پیوند: تجارت، صنعت، کشاورزی، پدافند، اقتصاد.
#
# state["supply_policy"] = {
#   "strategic_reserve":0..1, "diversification":0..1, "domestic_capacity":0..1,
#   "stockpile_rotation":0..1, "last_reserve":turn,
#   "disruption":0..1, "import_dependency":0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("supply_policy"):
		state["supply_policy"] = {
			"strategic_reserve": 0.35, "diversification": 0.40,
			"domestic_capacity": 0.40, "stockpile_rotation": 0.30,
			"last_reserve": -99, "disruption": 0.20,
			"import_dependency": 0.45, "logistics_index": 0.45,
			"inventory_days": 60.0
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var sp: Dictionary = state["supply_policy"]
	var econ: Dictionary = state.get("economy", {})
	var trade: Dictionary = state.get("trade", {})
	var industry: Dictionary = state.get("industry", {})
	var agriculture: Dictionary = state.get("agriculture", {})
	var civil: Dictionary = state.get("civil_defense_policy", {})

	var reserve: float = float(sp.get("strategic_reserve", 0.35))
	var diversify: float = float(sp.get("diversification", 0.40))
	var domestic: float = float(sp.get("domestic_capacity", 0.40))
	var rotation: float = float(sp.get("stockpile_rotation", 0.30))

	# شاخص لجستیک
	var logistics: float = clampf(0.25 + reserve * 0.25 + diversify * 0.25 + domestic * 0.20 + rotation * 0.15, 0.1, 0.98)
	sp["logistics_index"] = logistics

	# اختلال: وابستگی واردات زیاد + تأمین‌کننده محدود + تنش جهانی
	var import_dep: float = clampf(0.60 - domestic * 0.35 - diversify * 0.20, 0.10, 0.85)
	sp["import_dependency"] = import_dep
	var global_shock: float = float(state.get("world", {}).get("tension", 0.3))
	var disruption: float = clampf(
		sp.get("disruption", 0.20) * 0.85 + (import_dep - diversify * 0.4) * 0.03 +
		(global_shock - 0.3) * 0.02 - reserve * 0.02, 0.02, 0.95)
	sp["disruption"] = disruption

	# روزهای موجودی: ذخیره + گردش موجودی
	var days: float = 30.0 + reserve * 90.0 + rotation * 30.0 - disruption * 40.0
	sp["inventory_days"] = clampf(days, 7.0, 240.0)

	# پدافند غیرعامل به ذخایر کمک می‌کند
	if not civil.is_empty() and civil.has("strategic_stock"):
		sp["inventory_days"] = clampf(days + float(civil.get("strategic_stock", 0)) * 15.0, 7.0, 270.0)

	# اثر اقتصادی: اختلال → تورم + کاهش تولید
	var gdp: float = float(econ.get("gdp", 1.0))
	econ["inflation"] = clampf(float(econ.get("inflation", 0.08)) + disruption * 0.004, 0.0, 1.0)
	econ["gdp"] = gdp * (1.0 - disruption * 0.0006 + logistics * 0.0003)
	if industry.has("capacity_usage"):
		industry["capacity_usage"] = clampf(float(industry.get("capacity_usage", 0.75)) - disruption * 0.003, 0.3, 0.98)
	state["economy"] = econ
	state["industry"] = industry

	# رویدادها
	if disruption > 0.60 and Deterministic.chance(0.05):
		events.append({"type": "supply_crisis", "message": "🚢 اختلال جدی در زنجیره تأمین! کمبود کالا و تورم برخاست"})
	elif logistics > 0.70 and Deterministic.chance(0.025):
		events.append({"type": "supply_resilient", "message": "📦 زنجیره تأمین تاب‌آور، شوک جهانی را بی‌اثر کرد"})
	elif sp.get("inventory_days", 60.0) < 30.0 and Deterministic.chance(0.04):
		events.append({"type": "low_inventory", "message": "⚠️ موجودی کالاهای اساسی به زیر ۳۰ روز رسید"})

	state["supply_policy"] = sp
	return {"state": state, "events": events}

func build_reserve(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["supply_policy"]
	if turn - int(sp.get("last_reserve", -99)) < 5:
		return {"success": false, "reason": "تقویت ذخایر هر ۵ نوبت یک بار", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["government_spending"] = float(econ.get("government_spending", 0.0)) + float(econ.get("gdp", 1.0)) * 0.005
	sp["last_reserve"] = turn
	sp["strategic_reserve"] = clampf(float(sp.get("strategic_reserve", 0.35)) + 0.15, 0.0, 1.0)
	state["economy"] = econ
	state["supply_policy"] = sp
	return {"success": true, "state": state,
		"events": [{"type": "reserve", "message": "🏭 ذخایر راهبردی غذا، دارو و سوخت تقویت شد"}]}

func diversify_suppliers(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["supply_policy"]
	sp["diversification"] = clampf(float(sp.get("diversification", 0.40)) + 0.15, 0.0, 1.0)
	state["supply_policy"] = sp
	return {"success": true, "state": state,
		"events": [{"type": "diversify", "message": "🌐 تنوع تأمین‌کنندگان واردات افزایش یافت؛ ریسک تک‌منبعی کم شد"}]}

func build_domestic_capacity(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["supply_policy"]
	sp["domestic_capacity"] = clampf(float(sp.get("domestic_capacity", 0.40)) + 0.15, 0.0, 1.0)
	var industry: Dictionary = state.get("industry", {})
	industry["output"] = clampf(float(industry.get("output", 100.0)) + 0.5, 10.0, 200.0)
	state["industry"] = industry
	state["supply_policy"] = sp
	return {"success": true, "state": state,
		"events": [{"type": "domestic_capacity", "message": "🏗️ ظرفیت تولید داخلی قطعات و مواد کلیدی افزایش یافت"}]}

func rotate_stockpile(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["supply_policy"]
	sp["stockpile_rotation"] = clampf(float(sp.get("stockpile_rotation", 0.30)) + 0.15, 0.0, 1.0)
	sp["inventory_days"] = clampf(float(sp.get("inventory_days", 60.0)) + 10.0, 7.0, 270.0)
	state["supply_policy"] = sp
	return {"success": true, "state": state,
		"events": [{"type": "rotation", "message": "🔄 گردش موجودی ذخایر راهبردی بهینه شد؛ ضایعات کم شد"}]}
