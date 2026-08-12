extends Node
# ────────────────────────────────────────────────────────────────────────────
# بازار جهانی کالا — عمق اقتصاد بین‌الملل
# چهار کالای راهبردی (نفت، گاز، گندم، فلزات) قیمت جهانی ماهانه دارند که با
# عرضه/تقاضا، جنگ‌ها، فناوری سبز و شوک‌های تصادفی نوسان می‌کند. کشور ذخایر
# راهبردی دارد و بازیکن با خرید/فروش (صادرات/واردات) از بازار سود می‌کند؛
# قیمت کالاها به درآمد کشور (نفت) و تورم خوراک (گندم) اثر می‌گذارد.
#
# state["commodities"] = {
#   "prices": { "نفت": 75.0, "گاز": 3.2, "گندم": 260.0, "فلزات": 1800.0 },
#   "reserves": { "نفت": 90.0, "گاز": 60.0, "گندم": 120.0, "فلزات": 40.0 },
#   "history": [ {turn, prices} ... ],
#   "shock": ""
# }
# ────────────────────────────────────────────────────────────────────────────

const COMMODITIES := ["نفت", "گاز", "گندم", "فلزات"]
const BASE_PRICES := {"نفت": 75.0, "گاز": 3.2, "گندم": 260.0, "فلزات": 1800.0}
const PRICE_FLOOR := {"نفت": 30.0, "گاز": 1.2, "گندم": 120.0, "فلزات": 800.0}
const PRICE_CEIL := {"نفت": 180.0, "گاز": 8.0, "گندم": 600.0, "فلزات": 4200.0}
const MAX_HISTORY := 60

func ensure(state: Dictionary) -> Dictionary:
	if not state.has("commodities"):
		state["commodities"] = {
			"prices": BASE_PRICES.duplicate(),
			"reserves": {"نفت": 90.0, "گاز": 60.0, "گندم": 120.0, "فلزات": 40.0},
			"history": [],
			"shock": ""
		}
	return state

func get_price(state: Dictionary, commodity: String) -> float:
	state = ensure(state)
	return float(state["commodities"].get("prices", {}).get(commodity, BASE_PRICES.get(commodity, 0.0)))

# ── خرید/فروش ذخایر (با ذخایر ارزی) ──
func can_trade(state: Dictionary, commodity: String, amount: float) -> Dictionary:
	state = ensure(state)
	if not COMMODITIES.has(commodity) or amount <= 0.0:
		return {"valid": false, "reason": "کالا یا مقدار نامعتبر"}
	var price := get_price(state, commodity)
	var reserves_commodity := float(state["commodities"].get("reserves", {}).get(commodity, 0.0))
	var foreign := float(state.get("economy", {}).get("foreign_reserves", 0.0))
	if amount > reserves_commodity:
		return {"valid": false, "reason": "ذخیره کافی نیست"}
	if amount * price > foreign:
		return {"valid": false, "reason": "ذخایر ارزی کافی نیست"}
	return {"valid": true, "reason": ""}

func trade(state: Dictionary, commodity: String, amount: float) -> Dictionary:
	state = ensure(state)
	var check := can_trade(state, commodity, amount)
	if not check.valid:
		return {"success": false, "reason": check.reason, "state": state, "events": []}
	var price := get_price(state, commodity)
	var value := amount * price
	var econ: Dictionary = state.get("economy", {})
	var reserves_c: Dictionary = state["commodities"].get("reserves", {})
	var foreign := float(econ.get("foreign_reserves", 0.0))
	reserves_c[commodity] = maxf(0.0, float(reserves_c.get(commodity, 0.0)) - amount)
	state["commodities"]["reserves"] = reserves_c
	econ["foreign_reserves"] = foreign + value
	state["economy"] = econ
	return {"success": true, "state": state,
		"events": [{"type": "commodity_trade", "message": "📦 %s واحد %s به قیمت %s فروخته شد (%s به ذخایر ارزی اضافه شد)" % [
			PersianFormatter.to_persian_digits(str(int(amount))), commodity,
			PersianFormatter.format_money(price), PersianFormatter.format_money(value)]}]}

# ── شبیه‌سازی ماهانه قیمت‌ها + شوک‌ها ──
func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var com: Dictionary = state["commodities"]
	var prices: Dictionary = com.get("prices", {})
	var reserves: Dictionary = com.get("reserves", {})
	var world: Dictionary = state.get("world", {})
	var at_war: bool = not world.get("wars", {}).is_empty()
	var tech: Dictionary = state.get("technology", {})
	var green := float(tech.get("branches", {}).get("انرژی_پاک", 0.15))
	var wars_count: int = world.get("wars", {}).size() + world.get("npc_wars", {}).size()

	# ── روند قیمت هر کالا ──
	var oil_drift := 0.0
	var gas_drift := 0.0
	var wheat_drift := 0.0
	var metal_drift := 0.0
	# جنگ‌ها قیمت نفت و فلزات را می‌برند
	if at_war:
		oil_drift += 0.8
		metal_drift += 0.6
	oil_drift += float(wars_count) * 0.15
	metal_drift += float(wars_count) * 0.1
	# فناوری سبز تقاضای نفت را می‌کاهد
	oil_drift -= green * 0.7
	# شوک تصادفی هر ~۸ ماه یک‌بار
	var shock := str(com.get("shock", ""))
	if shock == "" and Deterministic.chance(0.06):
		var shock_type := str(["oil_boom", "oil_crash", "drought", "mineral_strike", "gas_dispute"][Deterministic.next_int_range(0, 4)])
		com["shock"] = shock_type
		match shock_type:
			"oil_boom":
				oil_drift += 6.0
				events.append({"type": "commodity_shock", "message": "🛢️ شوک نفتی: کاهش عرضه اوپک قیمت نفت را جهش داد!"})
			"oil_crash":
				oil_drift -= 6.0
				events.append({"type": "commodity_shock", "message": "📉 سقوط قیمت نفت: مازاد عرضه جهانی بازار را شکست"})
			"drought":
				wheat_drift += 5.0
				events.append({"type": "commodity_shock", "message": "🌾 خشکسالی جهانی: قیمت گندم به‌شدت بالا رفت"})
			"mineral_strike":
				metal_drift += 4.0
				events.append({"type": "commodity_shock", "message": "⛏️ اعتصاب معدن‌چیان آمریکای جنوبی قیمت فلزات را بالا برد"})
			"gas_dispute":
				gas_drift += 0.35
				events.append({"type": "commodity_shock", "message": "🔥 اختلاف گازی روسیه و اروپا قیمت گاز را جهش داد"})
	else:
		com["shock"] = ""
	# نویز ماهانه
	oil_drift += Deterministic.next_range(-0.9, 0.9)
	gas_drift += Deterministic.next_range(-0.08, 0.08)
	wheat_drift += Deterministic.next_range(-4.0, 4.0)
	metal_drift += Deterministic.next_range(-30.0, 30.0)
	# بازگشت تدریجی به تعادل
	for cid in COMMODITIES:
		var base := float(BASE_PRICES.get(cid, 1.0))
		prices[cid] = float(prices.get(cid, base)) + (base - float(prices.get(cid, base))) * 0.02

	prices["نفت"] = clampf(float(prices.get("نفت", 75.0)) + oil_drift, PRICE_FLOOR["نفت"], PRICE_CEIL["نفت"])
	prices["گاز"] = clampf(float(prices.get("گاز", 3.2)) + gas_drift, PRICE_FLOOR["گاز"], PRICE_CEIL["گاز"])
	prices["گندم"] = clampf(float(prices.get("گندم", 260.0)) + wheat_drift, PRICE_FLOOR["گندم"], PRICE_CEIL["گندم"])
	prices["فلزات"] = clampf(float(prices.get("فلزات", 1800.0)) + metal_drift, PRICE_FLOOR["فلزات"], PRICE_CEIL["فلزات"])
	com["prices"] = prices

	# ── اثر بر کشور ──
	var econ: Dictionary = state.get("economy", {})
	# درآمد نفت: صادرات نفتی = سهم تولید × قیمت
	var oil_reserve := float(reserves.get("نفت", 90.0))
	var oil_income := oil_reserve * float(prices.get("نفت", 75.0)) * 0.004
	econ["oil_income"] = oil_income
	econ["foreign_reserves"] = float(econ.get("foreign_reserves", 0.0)) + oil_income
	# گندم گران → تورم خوراک
	var wheat_price := float(prices.get("گندم", 260.0))
	var food_inflation := (wheat_price - 260.0) / 260.0 * 0.03
	econ["inflation"] = clampf(float(econ.get("inflation", 0.08)) + food_inflation, 0.0, 1.5)
	# رشد طبیعی ذخایر (بازتولید)
	for cid in COMMODITIES:
		reserves[cid] = minf(200.0, float(reserves.get(cid, 0.0)) + float({"نفت": 1.2, "گاز": 0.8, "گندم": 3.0, "فلزات": 0.5}.get(cid, 0.0)))
	com["reserves"] = reserves
	state["commodities"] = com
	state["economy"] = econ

	# تاریخچه (محدود)
	var history: Array = com.get("history", [])
	history.append({"turn": turn, "prices": prices.duplicate(true)})
	while history.size() > MAX_HISTORY:
		history.pop_front()
	com["history"] = history
	state["commodities"] = com
	return {"state": state, "events": events}
