extends Node
# ============================================================
# 🛒 بازار جهانی منابع (الهام از World Empire)
# خرید/فروش منابع (نفت، غذا، آهن، مس، مواد صنعتی، گاز) با قیمت‌های پویای جهانی.
# قیمت‌ها هر ماه بر اساس عرضه/تقاضا و ذخایر تغییر می‌کنند.
# ============================================================

const TRADABLE = ["نفت", "گاز", "غذا", "آهن", "مس", "مواد_صنعتی"]

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	var market: Dictionary = state.get("market", {})
	var prices: Dictionary = market.get("prices", {})
	if prices.is_empty():
		prices = {"نفت": 75.0, "گاز": 3.5, "غذا": 0.9, "آهن": 110.0, "مس": 8500.0, "مواد_صنعتی": 2200.0}
	# پویایی قیمت بر اساس ذخایر داخلی و شوک‌های جهانی
	var res: Dictionary = state.get("resources", {}).get("inventory", {})
	for r in TRADABLE:
		var inv = float(res.get(r, 60.0))
		var supply_pressure = (60.0 - inv) * 0.002  # کمبود → گرانی
		var shock = Deterministic.next_range(-0.03, 0.035)
		prices[r] = max(0.1, float(prices.get(r, 1.0)) * (1.0 + supply_pressure + shock))
	market["prices"] = prices
	market["history"] = market.get("history", [])
	market["history"].append(prices.duplicate(true))
	while market["history"].size() > 24:
		market["history"].pop_front()
	state["market"] = market
	return {"state": state, "events": []}

# خرید: هزینه از ذخایر ارزی (foreign_reserves) کم می‌شود
func buy(state: Dictionary, resource: String, amount: float) -> Dictionary:
	if resource not in TRADABLE:
		return {"success": false, "reason": "منبع قابل معامله نیست"}
	var prices: Dictionary = state.get("market", {}).get("prices", {})
	var price = float(prices.get(resource, 1.0))
	var cost = price * amount
	var econ: Dictionary = state.get("economy", {})
	var reserves = float(econ.get("foreign_reserves", 50e9))
	if cost > reserves:
		return {"success": false, "reason": "ذخایر ارزی کافی نیست"}
	econ["foreign_reserves"] = reserves - cost
	state["economy"] = econ
	var inv: Dictionary = state.get("resources", {}).get("inventory", {})
	var capacity: Dictionary = state.get("resources", {}).get("capacity", {})
	var cap = float(capacity.get(resource, 150.0))
	inv[resource] = min(cap, float(inv.get(resource, 0.0)) + amount)
	state["resources"]["inventory"] = inv
	return {"success": true, "cost": cost, "state": state, "message": "خرید %s واحد %s با هزینه %s میلیارد" % [PersianFormatter.to_persian_digits(str(int(amount))), resource, PersianFormatter.to_persian_digits("%.1f" % (cost / 1e9))]}

# فروش: درآمد به ذخایر ارزی اضافه می‌شود
func sell(state: Dictionary, resource: String, amount: float) -> Dictionary:
	if resource not in TRADABLE:
		return {"success": false, "reason": "منبع قابل معامله نیست"}
	var inv: Dictionary = state.get("resources", {}).get("inventory", {})
	var have = float(inv.get(resource, 0.0))
	if have < amount:
		return {"success": false, "reason": "ذخیره کافی برای فروش نیست"}
	var prices: Dictionary = state.get("market", {}).get("prices", {})
	var price = float(prices.get(resource, 1.0))
	var revenue = price * amount
	inv[resource] = have - amount
	state["resources"]["inventory"] = inv
	var econ: Dictionary = state.get("economy", {})
	econ["foreign_reserves"] = float(econ.get("foreign_reserves", 50e9)) + revenue
	state["economy"] = econ
	return {"success": true, "revenue": revenue, "state": state, "message": "فروش %s واحد %s با درآمد %s میلیارد" % [PersianFormatter.to_persian_digits(str(int(amount))), resource, PersianFormatter.to_persian_digits("%.1f" % (revenue / 1e9))]}
