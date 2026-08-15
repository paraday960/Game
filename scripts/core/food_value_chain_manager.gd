extends Node
# ────────────────────────────────────────────────────────────────────────────
# زنجیره ارزش غذا (کشت تا سفره) — عمق امنیت غذایی
# سردخانه، صنایع تبدیلی، لجستیک مواد غذایی، استاندارد و نظارت بر کیفیت.
# این لایه از ضایعات غذا می‌کاهد، قیمت را کنترل می‌کند و امنیت غذایی را
# بالا می‌برد. پیوند: کشاورزی، آبخیزداری، روستایی، رفاه، بهداشت.
#
# state["food_chain_policy"] = {
#   "storage":0..1, "processing":0..1, "logistics":0..1,
#   "safety":0..1, "last_storage":turn,
#   "waste":0..1, "food_security":0..1, "price_volatility":0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("food_chain_policy"):
		state["food_chain_policy"] = {
			"storage": 0.25, "processing": 0.20, "logistics": 0.30,
			"safety": 0.40, "last_storage": -99,
			"waste": 0.35, "food_security": 0.55, "price_volatility": 0.40,
			"cold_chain": 0.20, "self_sufficiency": 0.60
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var fp: Dictionary = state["food_chain_policy"]
	var agri: Dictionary = state.get("agriculture", {})
	var welfare: Dictionary = state.get("welfare", {})
	var health: Dictionary = state.get("health", {})
	var econ: Dictionary = state.get("economy", {})
	var trade: Dictionary = state.get("trade", {})
	var watershed: Dictionary = state.get("watershed_policy", {})
	var gdp: float = float(econ.get("gdp", 1.0))

	var storage: float = float(fp.get("storage", 0.25))
	var processing: float = float(fp.get("processing", 0.20))
	var logistics: float = float(fp.get("logistics", 0.30))
	var safety: float = float(fp.get("safety", 0.40))

	# ضایعات: نبود سردخانه و جاده زیاد می‌کند
	var waste: float = clampf(0.55 - storage * 0.30 - processing * 0.25 - logistics * 0.20, 0.05, 0.70)
	fp["waste"] = waste
	fp["cold_chain"] = clampf(0.10 + storage * 0.55 + logistics * 0.25, 0.05, 0.95)

	# امنیت غذایی: ذخیره + تولید - ضایعات + خودکفایی
	var food_supply: float = float(agri.get("food_security", 0.80)) if not agri.is_empty() else 0.75
	var soil: float = float(watershed.get("soil_health", 0.55))
	var sec: float = clampf(
		0.30 + food_supply * 0.25 + storage * 0.20 + processing * 0.10 +
		soil * 0.10 + (1.0 - waste) * 0.10, 0.10, 0.98)
	fp["food_security"] = sec
	fp["self_sufficiency"] = clampf(0.40 + storage * 0.30 + processing * 0.20 + food_supply * 0.10, 0.20, 0.98)

	# نوسان قیمت: ضایعات + وابستگی واردات
	var import_dep: float = 1.0 - float(fp.get("self_sufficiency", 0.6))
	var vol: float = clampf(waste * 0.40 + import_dep * 0.30 - storage * 0.20, 0.05, 0.90)
	fp["price_volatility"] = vol

	# اثر اقتصادی: ضایعات زیاد تورم غذا و واردات می‌آورد
	econ["inflation"] = clampf(float(econ.get("inflation", 0.08)) + vol * 0.003, 0.0, 1.0)
	# صنایع تبدیلی ارزش افزوده و اشتغال
	# ممیزی GDP (۱۴۰۵): اثر مداوم از کانال مالک-یکتای sector_boosts (نرخ سالانه؛ ×۱۲)
	var fv_boosts: Dictionary = econ.get("sector_boosts", {})
	if processing > 0.3:
		fv_boosts["زنجیرهٔ غذا"] = processing * 0.0004 * 12.0
	else:
		fv_boosts["زنجیرهٔ غذا"] = 0.0
	econ["sector_boosts"] = fv_boosts
	state["economy"] = econ

	# سلامت: نظارت بر ایمنی غذا
	if not health.is_empty():
		health["quality"] = clampf(float(health.get("quality", 0.60)) + safety * 0.001 - waste * 0.0008, 0.1, 1.0)
		state["health"] = health

	# رویدادها
	if sec < 0.30 and Deterministic.chance(0.05):
		# قحطی فقط خبر نیست: تورم، لطمه به شادی و موج فقر واقعی
		econ["inflation"] = clampf(float(econ.get("inflation", 0.08)) + 0.006, 0.0, 1.0)
		state["population"]["happiness"] = clampf(float(state["population"].get("happiness", 0.60)) - 0.020, 0.05, 1.0)
		state["welfare"]["poverty"] = clampf(float(state.get("welfare", {}).get("poverty", 0.15)) + 0.010, 0.02, 0.60)
		state["economy"] = econ
		events.append({"type": "food_crisis", "message": "🍞 ناامنی غذایی! کمبود و گرانی نان و کالاهای اساسی برخاست"})
	elif waste > 0.50 and Deterministic.chance(0.04):
		var agri_fw: Dictionary = state.get("agriculture", {})
		agri_fw["food_security"] = clampf(float(agri_fw.get("food_security", 0.65)) - 0.015, 0.05, 1.0)
		state["agriculture"] = agri_fw
		events.append({"type": "food_waste", "message": "🗑️ ضایعات بالای غذا در مسیر تولید تا مصرف؛ امنیت غذایی تضعیف شد"})
	elif sec > 0.75 and Deterministic.chance(0.025):
		events.append({"type": "food_secure", "message": "🌾 امنیت غذایی پایدار شد؛ ذخایر و صنایع تبدیلی نتیجه داد"})

	state["food_chain_policy"] = fp
	return {"state": state, "events": events}

func build_storage(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var fp: Dictionary = state["food_chain_policy"]
	if turn - int(fp.get("last_storage", -99)) < 5:
		return {"success": false, "reason": "ساخت سردخانه هر ۵ نوبت یک بار", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.004
	fp["last_storage"] = turn
	fp["storage"] = clampf(float(fp.get("storage", 0.25)) + 0.15, 0.0, 1.0)
	state["economy"] = econ
	state["food_chain_policy"] = fp
	return {"success": true, "state": state,
		"events": [{"type": "storage", "message": "🧊 سردخانه و انبارهای غله توسعه یافت؛ ضایعات کم شد"}]}

func expand_processing(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var fp: Dictionary = state["food_chain_policy"]
	if float(fp.get("processing", 0.20)) >= 0.95:
		return {"success": false, "reason": "صنایع تبدیلی در سقف است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.004
	fp["processing"] = clampf(float(fp.get("processing", 0.20)) + 0.15, 0.0, 1.0)
	state["economy"] = econ
	state["food_chain_policy"] = fp
	return {"success": true, "state": state,
		"events": [{"type": "processing", "message": "🏭 صنایع تبدیلی و بسته‌بندی غذا گسترش یافت"}]}

func improve_logistics(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var fp: Dictionary = state["food_chain_policy"]
	fp["logistics"] = clampf(float(fp.get("logistics", 0.30)) + 0.15, 0.0, 1.0)
	state["food_chain_policy"] = fp
	return {"success": true, "state": state,
		"events": [{"type": "logistics", "message": "🚚 لجستیک سردخانه‌ای مواد غذایی بهینه شد"}]}

func enforce_safety(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var fp: Dictionary = state["food_chain_policy"]
	fp["safety"] = clampf(float(fp.get("safety", 0.40)) + 0.15, 0.0, 1.0)
	state["food_chain_policy"] = fp
	return {"success": true, "state": state,
		"events": [{"type": "food_safety", "message": "🔍 نظارت و استاندارد ایمنی غذا تشدید شد"}]}
