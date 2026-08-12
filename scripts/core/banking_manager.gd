extends Node
# ────────────────────────────────────────────────────────────────────────────
# بانکداری و بازار سرمایه — عمق نظام مالی
# ذخیره قانونی بانک‌ها، بازار سهام (شاخص با اعتماد/ارز/چرخه)، نظارت بانکی،
# و بحران بانکی (فرار سپرده). پیوند: بانک مرکزی، ارز، اقتصاد سایه، چرخه،
# نخبگان اقتصادی.
#
# state["banking"] = { "reserve_ratio":0.08..0.2, "supervision":0..1,
#   "stock_index":0..100, "bank_health":0..1, "crisis":{..}|{}, "bailouts":0 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("banking"):
		state["banking"] = {"reserve_ratio": 0.12, "supervision": 0.5, "stock_index": 55.0, "bank_health": 0.7, "crisis": {}, "bailouts": 0}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var bk: Dictionary = state["banking"]
	var econ: Dictionary = state.get("economy", {})
	var cb: Dictionary = state.get("central_bank", {})
	var forex: Dictionary = state.get("forex", {})
	var shadow: Dictionary = state.get("shadow", {})
	var cycle: Dictionary = econ.get("cycle", {})
	var reserve := float(bk.get("reserve_ratio", 0.12))
	var supervision := float(bk.get("supervision", 0.5))
	var stock_index := float(bk.get("stock_index", 55.0))
	var bank_health := float(bk.get("bank_health", 0.7))
	var inflation := float(econ.get("inflation", 0.08))
	var rate := float(cb.get("interest_rate", cb.get("policy_rate", 0.15)))
	var black_premium := float(forex.get("black_premium", 0.05))
	var shadow_size := float(shadow.get("size", 0.18))
	var phase := str(cycle.get("phase", "growth"))

	# سلامت بانک‌ها: ذخیره + نظارت − تورم − بازار سیاه − اقتصاد سایه
	bank_health = clampf(bank_health + (reserve - 0.12) * 0.5 + (supervision - 0.5) * 0.2 - inflation * 0.3 - black_premium * 0.4 - shadow_size * 0.3, 0.05, 0.98)
	bk["bank_health"] = bank_health

	# شاخص سهام: اعتماد + چرخه + سلامت بانک + نرخ بهره (بالا = منفی)
	var confidence: float = float(econ.get("investment_confidence", 0.5))
	var phase_effect: float = float({"boom": 2.5, "growth": 0.8, "stagnation": -1.0, "recession": -3.0}.get(phase, 0.0))
	stock_index = clampf(stock_index + (confidence - 0.5) * 3.0 + phase_effect + (bank_health - 0.7) * 2.0 - (rate - 0.12) * 8.0 + Deterministic.next_range(-1.0, 1.0), 5.0, 100.0)
	bk["stock_index"] = stock_index

	# بحران بانکی: سلامت پایین + شوک
	if bk.get("crisis", {}).is_empty() and bank_health < 0.35 and Deterministic.chance(0.10):
		bk["crisis"] = {"turn": turn, "banks": "چند بانک بزرگ"}
		events.append({"type": "banking_crisis", "message": "🏦 بحران بانکی! سپرده‌گذاران به صف فرار افتادند و شاخص سهام سقوط کرد"})
	elif not bk.get("crisis", {}).is_empty():
		var crisis: Dictionary = bk["crisis"]
		var age := turn - int(crisis.get("turn", turn))
		stock_index = clampf(stock_index - 3.0, 5.0, 100.0)
		bk["stock_index"] = stock_index
		if age >= 3:
			# بحران خودبه‌خود فروکش می‌کند ولی با آسیب
			econ["gdp"] = float(econ.get("gdp", 1.0)) * 0.995
			events.append({"type": "banking_crisis_end", "message": "🏦 بحران بانکی فروکش کرد؛ اقتصاد زخمی شد"})
			bk["crisis"] = {}

	# اعتبار بانکی به اقتصاد: سلامت بانک → رشد
	econ["credit_available"] = bank_health
	econ["gdp"] = float(econ.get("gdp", 1.0)) * (1.0 + (bank_health - 0.6) * 0.001)
	state["banking"] = bk
	state["economy"] = econ
	return {"state": state, "events": events}

func set_reserve(state: Dictionary, ratio: float) -> Dictionary:
	state = ensure(state)
	if ratio < 0.05 or ratio > 0.25:
		return {"success": false, "reason": "ذخیره قانونی باید ۵٪ تا ۲۵٪ باشد", "state": state, "events": []}
	var bk: Dictionary = state["banking"]
	bk["reserve_ratio"] = ratio
	state["banking"] = bk
	return {"success": true, "state": state,
		"events": [{"type": "reserve_ratio", "message": "🏦 ذخیره قانونی بانک‌ها به %s٪ تغییر کرد؛ اعتبار یا احتیاط" % PersianFormatter.to_persian_digits(str(int(ratio * 100.0)))}]}

func strengthen_supervision(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var bk: Dictionary = state["banking"]
	if float(bk.get("supervision", 0.5)) >= 0.95:
		return {"success": false, "reason": "نظارت بانکی حداکثری است", "state": state, "events": []}
	state["economy"]["national_debt"] = float(state["economy"].get("national_debt", 0.0)) + float(state["economy"].get("gdp", 1.0)) * 0.001
	bk["supervision"] = clampf(float(bk.get("supervision", 0.5)) + 0.15, 0.0, 1.0)
	state["banking"] = bk
	return {"success": true, "state": state,
		"events": [{"type": "supervision", "message": "🔍 نظارت بانکی تقویت شد؛ بانک‌های پرریسک مهار شدند"}]}

func bailout(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var bk: Dictionary = state["banking"]
	if bk.get("crisis", {}).is_empty():
		return {"success": false, "reason": "بحران بانکی فعالی نیست", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	var gdp := float(econ.get("gdp", 1.0))
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + gdp * 0.03
	econ["gdp"] = gdp * 1.005
	bk["bank_health"] = clampf(float(bk.get("bank_health", 0.7)) + 0.3, 0.05, 0.98)
	bk["bailouts"] = int(bk.get("bailouts", 0)) + 1
	bk["crisis"] = {}
	state["banking"] = bk
	state["economy"] = econ
	# نخبگان خوشحال، افکار عمومی خشمگین
	state["media"]["groups"]["شهرنشینان"]["approval"] = clampf(float(state["media"]["groups"]["شهرنشینان"].get("approval", 55.0)) - 3.0, 5.0, 100.0)
	return {"success": true, "state": state,
		"events": [{"type": "bailout", "message": "💸 نجات بانک‌ها با پول دولت! بازار نفس کشید ولی مردم عصبانی‌اند"}]}

func support_market(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var bk: Dictionary = state["banking"]
	var econ: Dictionary = state.get("economy", {})
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * 0.002
	bk["stock_index"] = clampf(float(bk.get("stock_index", 55.0)) + 6.0, 5.0, 100.0)
	state["banking"] = bk
	state["economy"] = econ
	return {"success": true, "state": state,
		"events": [{"type": "market_support", "message": "📈 صندوق تثبیت بازار سهام وارد شد؛ شاخص جهش کرد"}]}
