extends Node
# ────────────────────────────────────────────────────────────────────────────
# گردشگری — عمق اقتصاد خدمات
# سیاست ویزا (تسهیل/سختگیرانه)، سرمایه‌گذاری مهمان‌پذیری، کمپین مقصد و
# گردشگری سلامت. پیوند: قدرت نرم، امنیت، قیمت ارز (ارز ارزان = جذاب‌تر).
#
# state["tourism_policy"] = { "visa":"open"|"moderate"|"strict", "hospitality":0..1,
#   "destination_campaign":0..1, "health_tourism":0..1, "visitors":0 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("tourism_policy"):
		state["tourism_policy"] = {"visa": "moderate", "hospitality": 0.4, "destination_campaign": 0.2, "health_tourism": 0.2, "visitors": 0}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var tp: Dictionary = state["tourism_policy"]
	var econ: Dictionary = state.get("economy", {})
	var tourism: Dictionary = state.get("tourism", {})
	var cul: Dictionary = state.get("culture_policy", {})
	var sec: Dictionary = state.get("security", {})
	var forex: Dictionary = state.get("forex", {})
	var soft := float(cul.get("soft_power", 40.0)) / 100.0
	var safety := float(sec.get("public_security", 0.7))
	var exchange := float(state.get("central_bank", {}).get("exchange_rate", 1.0))
	var visa := str(tp.get("visa", "moderate"))
	var hospitality := float(tp.get("hospitality", 0.4))
	var campaign := float(tp.get("destination_campaign", 0.2))
	var health := float(tp.get("health_tourism", 0.2))

	# جاذبه: قدرت نرم + امنیت + مهمان‌پذیری + ارز ارزان + کمپین
	var attractiveness: float = soft * 0.3 + safety * 0.25 + hospitality * 0.2 + campaign * 0.1 + health * 0.08
	var visa_factor: float = float({"open": 1.0, "moderate": 0.7, "strict": 0.4}.get(visa, 0.7))
	var exchange_factor: float = clampf(1.3 / exchange, 0.6, 1.3)
	var visitors: float = 5_000_000.0 * attractiveness * visa_factor * exchange_factor
	tourism["visitors"] = int(visitors)
	tourism["revenue"] = visitors * 1200.0 * (0.8 + hospitality * 0.4)
	tourism["infrastructure"] = clampf(float(tourism.get("infrastructure", 0.55)) + hospitality * 0.1, 0.1, 1.0)
	state["tourism"] = tourism
	# درآمد گردشگری به ذخایر ارزی
	var income := float(tourism.get("revenue", 0.0)) / 12.0
	econ["foreign_reserves"] = float(econ.get("foreign_reserves", 0.0)) + income * 0.01
	state["economy"] = econ
	# رویداد: رونق/رکود گردشگری
	if visitors > 12_000_000.0 and Deterministic.chance(0.08):
		events.append({"type": "tourism_boom", "message": "✈️ رونق گردشگری! تعداد بازدیدکنندگان به رکورد جدید رسید"})
	elif visitors < 2_000_000.0 and Deterministic.chance(0.06):
		events.append({"type": "tourism_slump", "message": "📉 گردشگری در رکود؛ درآمد ارزی کاهش یافت"})
	state["tourism_policy"] = tp
	return {"state": state, "events": events}

func visa_policy(state: Dictionary, policy: String) -> Dictionary:
	state = ensure(state)
	if not ["open", "moderate", "strict"].has(policy):
		return {"success": false, "reason": "سیاست ویزا نامعتبر", "state": state, "events": []}
	var tp: Dictionary = state["tourism_policy"]
	tp["visa"] = policy
	state["tourism_policy"] = tp
	var names := {"open": "تسهیل کامل", "moderate": "متوسط", "strict": "سختگیرانه"}
	return {"success": true, "state": state,
		"events": [{"type": "visa_policy", "message": "🛂 سیاست ویزا به «%s» تغییر کرد" % names[policy]}]}

func invest_hospitality(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var tp: Dictionary = state["tourism_policy"]
	if float(tp.get("hospitality", 0.4)) >= 0.95:
		return {"success": false, "reason": "ظرفیت مهمان‌پذیری کامل است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * 0.003
	state["economy"] = econ
	tp["hospitality"] = clampf(float(tp.get("hospitality", 0.4)) + 0.15, 0.0, 1.0)
	state["tourism_policy"] = tp
	return {"success": true, "state": state,
		"events": [{"type": "hospitality", "message": "🏨 هتل‌ها و زیرساخت گردشگری توسعه یافت؛ ظرفیت پذیرش بالا رفت"}]}

func destination_campaign(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var tp: Dictionary = state["tourism_policy"]
	if float(tp.get("destination_campaign", 0.2)) >= 0.95:
		return {"success": false, "reason": "کمپین مقصد فعال است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * 0.002
	state["economy"] = econ
	tp["destination_campaign"] = clampf(float(tp.get("destination_campaign", 0.2)) + 0.3, 0.0, 1.0)
	state["tourism_policy"] = tp
	return {"success": true, "state": state,
		"events": [{"type": "destination_campaign", "message": "📣 کمپین جهانی «مقصد کشور» آغاز شد؛ جاذبه گردشگری در جهان شناخته‌تر شد"}]}

func health_tourism(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var tp: Dictionary = state["tourism_policy"]
	if float(tp.get("health_tourism", 0.2)) >= 0.9:
		return {"success": false, "reason": "ظرفیت گردشگری سلامت کامل است", "state": state, "events": []}
	var health: Dictionary = state.get("health", {})
	if float(health.get("quality", 0.6)) < 0.7:
		return {"success": false, "reason": "کیفیت درمان کافی نیست (بهداشت ۷۰٪+)", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * 0.003
	state["economy"] = econ
	tp["health_tourism"] = clampf(float(tp.get("health_tourism", 0.2)) + 0.25, 0.0, 1.0)
	state["tourism_policy"] = tp
	return {"success": true, "state": state,
		"events": [{"type": "health_tourism", "message": "🏥 مراکز درمانی بین‌المللی برای جذب بیماران خارجی تجهیز شد؛ درآمد ارزی پزشکی آغاز شد"}]}
