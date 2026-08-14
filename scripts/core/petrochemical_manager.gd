extends Node
# ── صنعت پتروشیمی و زنجیره ارزش ──
# تولید محصولات پتروشیمی، زنجیره پایین‌دست و صادرات.
# نفت خام به محصولات با ارزش افزوده بالا تبدیل می‌شود؛
# کاهش خام‌فروشی و افزایش درآمد ارزی. پیوند: انرژی، صنعت، تجارت.

signal petrochemical_output_changed(output: float)

var feedstock: float = 0.40        # تأمین خوراک
var plants: float = 0.20           # مجتمع‌های پتروشیمی
var downstream: float = 0.15       # صنایع پایین‌دست
var catalyst_rnd: float = 0.10
var exports: float = 0.10
var total_output: float = 0.0
var last_tick: int = 0

func reset():
	feedstock = 0.40
	plants = 0.20
	downstream = 0.15
	catalyst_rnd = 0.10
	exports = 0.10
	total_output = 0.0

func _ensure(state: Dictionary):
	if not state.has("petrochemical_policy"):
		state["petrochemical_policy"] = {
			"feedstock": feedstock,
			"plants": plants,
			"downstream": downstream,
			"rnd": catalyst_rnd,
			"exports": exports,
			"output": total_output,
			"last_tick": last_tick,
		}

func get_policy(state: Dictionary) -> Dictionary:
	_ensure(state)
	return state["petrochemical_policy"]

func secure_feedstock(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["petrochemical_policy"]
	p["feedstock"] = clampf(float(p.get("feedstock", 0.0)) + 0.10, 0.0, 1.0)
	state["petrochemical_policy"] = p
	return {"success": true}

func build_plants(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["petrochemical_policy"]
	var energy_sec: float = float(state.get("energy_policy", {}).get("energy_security", 0.4))
	if energy_sec < 0.3:
		return {"success": false, "reason": "به امنیت انرژی بیشتری نیاز است"}
	p["plants"] = clampf(float(p.get("plants", 0.0)) + 0.12, 0.0, 1.0)
	state["petrochemical_policy"] = p
	return {"success": true}

func expand_downstream(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["petrochemical_policy"]
	p["downstream"] = clampf(float(p.get("downstream", 0.0)) + 0.12, 0.0, 1.0)
	state["petrochemical_policy"] = p
	return {"success": true}

func invest_catalyst(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["petrochemical_policy"]
	p["rnd"] = clampf(float(p.get("rnd", 0.0)) + 0.12, 0.0, 1.0)
	state["petrochemical_policy"] = p
	return {"success": true}

func boost_exports(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["petrochemical_policy"]
	if float(p.get("output", 0.0)) < 0.3:
		return {"success": false, "reason": "ابتدا تولید را افزایش دهید"}
	p["exports"] = clampf(float(p.get("exports", 0.0)) + 0.12, 0.0, 1.0)
	state["petrochemical_policy"] = p
	return {"success": true}

func simulate(state: Dictionary, tick: int) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["petrochemical_policy"]
	var economy: Dictionary = state.get("economy", {})
	var gdp: float = float(economy.get("gdp", 0.0))
	var energy: Dictionary = state.get("energy_policy", {})

	var feed: float = float(p.get("feedstock", 0.0))
	var pl: float = float(p.get("plants", 0.0))
	var down: float = float(p.get("downstream", 0.0))
	var rnd: float = float(p.get("rnd", 0.0))
	var exp: float = float(p.get("exports", 0.0))

	var output: float = clampf(
		feed * 0.30 + pl * 0.35 + down * 0.20 + rnd * 0.15, 0.0, 1.0)
	# ارزش افزوده: پایین‌دست چند برابر می‌کند
	var value_added: float = output * (1.0 + down * 1.5)
	total_output = value_added
	p["output"] = total_output
	p["last_tick"] = tick

	if gdp > 0.0:
		# واقع‌گرایی: اثر سطحی همگرا (هر ماه ۲۰٪ از فاصله تا هدف) به‌جای جمعِ بی‌پایان روی GDP
		var boost_target: float = gdp * value_added * 0.006
		var boost_prev: float = float(p.get("_gdp_boost", 0.0))
		var boost_delta: float = (boost_target - boost_prev) * 0.20
		economy["gdp"] = gdp + boost_delta
		p["_gdp_boost"] = boost_prev + boost_delta
		# درآمد ارزی صادرات → کانال reserve_inflows (بازرسی ۱۴۰۵؛ مالک مخزن: بانک مرکزی)
		var pc_infl: Dictionary = economy.get("reserve_inflows", {})
		pc_infl["صادرات پتروشیمی"] = (gdp * exp * 0.004) if (exp > 0.0 and value_added > 0.2) else 0.0
		economy["reserve_inflows"] = pc_infl
		state["economy"] = economy

	# کاهش خام‌فروشی انرژی
	if not energy.is_empty():
		energy["raw_export_dep"] = clampf(float(energy.get("raw_export_dep", 0.6)) - output * 0.004, 0.0, 1.0)
		state["energy_policy"] = energy

	emit_signal("petrochemical_output_changed", total_output)
	state["petrochemical_policy"] = p
	return state

func simulate_month(state: Dictionary, tick: int) -> Dictionary:
	# قرارداد مشترک چرخه ماهانه موتور: خروجی همیشه {state, events} است؛
	# simulate خام state را برمی‌گرداند (سازگار با تست‌ها) پس اینجا بسته‌بندی می‌شود.
	return {"state": simulate(state, tick), "events": []}

func get_summary(state: Dictionary) -> Dictionary:
	var p = get_policy(state)
	return {
		"feedstock": p["feedstock"],
		"plants": p["plants"],
		"downstream": p["downstream"],
		"rnd": p["rnd"],
		"exports": p["exports"],
		"output": p["output"],
	}
