extends Node
# ────────────────────────────────────────────────────────────────────────────
# سیاست ارزی — عمق اقتصاد کلان
# نرخ ارز قابل مشاهده است و بازیکن سه اهرم دارد:
#  - مداخله (خرید ارز با ذخایر → تقویت)
#  - کاهش ارزش (تضعیف → صادرات بیشتر ولی تورم و هزینه واردات)
#  - کنترل سرمایه (جلوگیری از فرار ارز ولی کاهش سرمایه‌گذاری خارجی)
# هر اقدام هزینه واقعی دارد و شوک‌های ارزی (بحران ذخایر) رویداد می‌سازند.
#
# state["forex"] = { "intervention":0..1, "capital_control":bool, "black_premium":0..1, "history":[...] }
# ────────────────────────────────────────────────────────────────────────────

func ensure(state: Dictionary) -> Dictionary:
	if not state.has("forex"):
		state["forex"] = {
			"intervention": 0.0,
			"capital_control": false,
			"black_premium": 0.05,
			"history": []
		}
	return state

func get_rate(state: Dictionary) -> float:
	return float(state.get("central_bank", {}).get("exchange_rate", 1.0))

# ── مداخله ارزی: هزینه ذخایر، تقویت نرخ ──
func can_intervene(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var reserves := float(state.get("economy", {}).get("foreign_reserves", 0.0))
	if reserves < 2.0e9:
		return {"valid": false, "reason": "ذخایر ارزی برای مداخله کافی نیست"}
	return {"valid": true, "reason": ""}

func intervene(state: Dictionary, amount_billion: float) -> Dictionary:
	state = ensure(state)
	var check := can_intervene(state)
	if not check.valid:
		return {"success": false, "reason": check.reason, "state": state, "events": []}
	var amount := amount_billion * 1.0e9
	var econ: Dictionary = state.get("economy", {})
	var reserves := float(econ.get("foreign_reserves", 0.0))
	if amount > reserves:
		return {"success": false, "reason": "ذخایر کافی نیست", "state": state, "events": []}
	econ["foreign_reserves"] = reserves - amount
	state["economy"] = econ
	var cb: Dictionary = state.get("central_bank", {})
	# قدرت تقویت نرخ با مبلغ مداخله مقیاس می‌گیرد: از ۱٪ تا ۵٪ (در ۲۰ میلیارد به اوج می‌رسد)
	var strength := clampf(amount / 20.0e9, 0.0, 1.0)
	cb["exchange_rate"] = clampf(float(cb.get("exchange_rate", 1.0)) * (1.0 - 0.01 - strength * 0.04), 0.2, 5.0)
	state["central_bank"] = cb
	var forex: Dictionary = state["forex"]
	forex["intervention"] = clampf(float(forex.get("intervention", 0.0)) + 0.3, 0.0, 1.0)
	state["forex"] = forex
	return {"success": true, "state": state,
		"events": [{"type": "forex_intervention", "message": "💱 بانک مرکزی با %s میلیارد از ذخایر، نرخ ارز را تقویت کرد" % PersianFormatter.to_persian_digits(str(int(amount_billion)))}]}

# ── کاهش ارزش پول ──
func devalue(state: Dictionary, percent: float) -> Dictionary:
	state = ensure(state)
	if percent <= 0.0 or percent > 20.0:
		return {"success": false, "reason": "درصد نامعتبر (۱ تا ۲۰)", "state": state, "events": []}
	var cb: Dictionary = state.get("central_bank", {})
	cb["exchange_rate"] = clampf(float(cb.get("exchange_rate", 1.0)) * (1.0 + percent / 100.0), 0.2, 5.0)
	state["central_bank"] = cb
	var econ: Dictionary = state.get("economy", {})
	# صادرات ارزان‌تر → رشد صادرات؛ تورم وارداتی → تورم
	econ["exports"] = float(econ.get("exports", 1.0)) * (1.0 + percent / 100.0 * 0.6)
	econ["imports"] = float(econ.get("imports", 1.0)) * (1.0 + percent / 100.0 * 0.4)
	econ["inflation"] = clampf(float(econ.get("inflation", 0.08)) + percent / 100.0 * 0.3, 0.0, 1.5)
	var forex: Dictionary = state["forex"]
	forex["black_premium"] = clampf(float(forex.get("black_premium", 0.05)) + percent / 100.0 * 0.4, 0.0, 0.6)
	state["forex"] = forex
	state["economy"] = econ
	return {"success": true, "state": state,
		"events": [{"type": "forex_devalue", "message": "💱 پول ملی %s٪ کاهش ارزش یافت؛ صادرات رونق گرفت ولی تورم بالا رفت" % PersianFormatter.to_persian_digits(str(int(percent)))}]}

# ── کنترل سرمایه ──
func toggle_capital_control(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var forex: Dictionary = state["forex"]
	var control := not bool(forex.get("capital_control", false))
	forex["capital_control"] = control
	state["forex"] = forex
	var econ: Dictionary = state.get("economy", {})
	if control:
		econ["foreign_investment"] = float(econ.get("foreign_investment", 1.0)) * 0.92
		forex["black_premium"] = clampf(float(forex.get("black_premium", 0.05)) + 0.06, 0.0, 0.6)
	else:
		econ["foreign_investment"] = float(econ.get("foreign_investment", 1.0)) * 1.04
	state["economy"] = econ
	state["forex"] = forex
	return {"success": true, "state": state,
		"events": [{"type": "capital_control", "message": "🔒 کنترل سرمایه %s شد؛ فرار ارز مهار شد ولی سرمایه‌گذاری خارجی کاهش یافت" % ("فعال" if control else "لغو")}]}

# ── شبیه‌سازی ماهانه ──
func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var forex: Dictionary = state["forex"]
	var econ: Dictionary = state.get("economy", {})
	var cb: Dictionary = state.get("central_bank", {})
	var rate := float(cb.get("exchange_rate", 1.0))
	var reserves := float(econ.get("foreign_reserves", 0.0))
	var inflation := float(econ.get("inflation", 0.08))

	# صافی: اثر مداخله قبلی محو می‌شود
	forex["intervention"] = clampf(float(forex.get("intervention", 0.0)) - 0.1, 0.0, 1.0)
	# بازار سیاه: با تورم و کنترل سرمایه رشد می‌کند
	var premium := float(forex.get("black_premium", 0.05))
	premium += inflation * 0.02
	if bool(forex.get("capital_control", false)):
		premium += 0.01
	forex["black_premium"] = clampf(premium, 0.0, 0.6)

	# بحران ذخایر: فشار بر نرخ
	if reserves < float(econ.get("gdp", 1.0)) * 0.02 and Deterministic.chance(0.15):
		cb["exchange_rate"] = clampf(rate * 1.04, 0.2, 5.0)
		events.append({"type": "forex_crisis", "message": "🚨 بحران ارزی: ذخایر اندک، فشار سنگین بر پول ملی"})
	# نرخ با مداخله‌های قبلی تعدیل می‌شود
	var inter := float(forex.get("intervention", 0.0))
	cb["exchange_rate"] = clampf(rate * (1.0 - inter * 0.01), 0.2, 5.0)
	state["central_bank"] = cb
	state["forex"] = forex
	state["economy"] = econ

	# تاریخچه (محدود)
	var history: Array = forex.get("history", [])
	history.append({"turn": turn, "rate": float(cb.get("exchange_rate", 1.0)), "premium": float(forex.get("black_premium", 0.05))})
	while history.size() > 48:
		history.pop_front()
	forex["history"] = history
	state["forex"] = forex
	return {"state": state, "events": events}
