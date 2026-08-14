extends Node
# ── استاندارد و زیرساخت کیفیت (عمق ۲۱) ──
# مترولوژی و کالیبراسیون، آزمایشگاه‌های معتمد، اعتباردهی و
# صدور گواهی، بازرسی بازار و دروازه کیفیت صادرات. زیرساخت
# کیفیت کلید پذیرش کالای داخلی در بازارهای جهانی است.
# پیوند: تجارت خارجی، صادرات، اعتماد مصرف‌کننده.

signal certified_firms_changed(count: int)

var metrology: float = 0.20
var labs: float = 0.15
var accreditation: float = 0.10
var surveillance: float = 0.25
var export_gate: float = 0.15
var certified_firms: int = 1200
var last_tick: int = 0

func reset():
	metrology = 0.20
	labs = 0.15
	accreditation = 0.10
	surveillance = 0.25
	export_gate = 0.15
	certified_firms = 1200

func _ensure(state: Dictionary):
	if not state.has("standards_policy"):
		state["standards_policy"] = {
			"metrology": metrology,
			"labs": labs,
			"accreditation": accreditation,
			"surveillance": surveillance,
			"export_gate": export_gate,
			"certified_firms": certified_firms,
			"last_tick": last_tick,
		}

func get_policy(state: Dictionary) -> Dictionary:
	_ensure(state)
	return state["standards_policy"]

func invest_metrology(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["standards_policy"]
	p["metrology"] = clampf(float(p.get("metrology", 0.0)) + 0.10, 0.0, 1.0)
	state["standards_policy"] = p
	return {"success": true}

func accredit_labs(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["standards_policy"]
	p["labs"] = clampf(float(p.get("labs", 0.0)) + 0.12, 0.0, 1.0)
	state["standards_policy"] = p
	return {"success": true}

func expand_accreditation(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["standards_policy"]
	# اعتباردهی بدون زیرساخت آزمایشگاهی اعتباری ندارد
	if float(p.get("labs", 0.0)) < 0.25:
		return {"success": false, "reason": "برای گسترش اعتباردهی ابتدا آزمایشگاه‌های معتمد بسازید"}
	p["accreditation"] = clampf(float(p.get("accreditation", 0.0)) + 0.10, 0.0, 1.0)
	state["standards_policy"] = p
	return {"success": true}

func improve_surveillance(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["standards_policy"]
	p["surveillance"] = clampf(float(p.get("surveillance", 0.0)) + 0.12, 0.0, 1.0)
	state["standards_policy"] = p
	return {"success": true}

func strengthen_export_gate(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["standards_policy"]
	p["export_gate"] = clampf(float(p.get("export_gate", 0.0)) + 0.12, 0.0, 1.0)
	state["standards_policy"] = p
	return {"success": true}

func simulate(state: Dictionary, tick: int) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["standards_policy"]
	var economy: Dictionary = state.get("economy", {})
	var gdp: float = float(economy.get("gdp", 0.0))

	var met: float = float(p.get("metrology", 0.0))
	var lb: float = float(p.get("labs", 0.0))
	var acr: float = float(p.get("accreditation", 0.0))
	var srv: float = float(p.get("surveillance", 0.0))
	var eg: float = float(p.get("export_gate", 0.0))

	# شاخص زیرساخت کیفیت ملی
	var qi: float = clampf(met * 0.35 + lb * 0.25 + acr * 0.25 + eg * 0.15, 0.0, 1.0)

	# بنگاه‌های دارای گواهی کیفیت - دترمینستیک از شاخص
	p["certified_firms"] = int(round(500.0 + qi * 20000.0))
	certified_firms = int(p["certified_firms"])
	p["last_tick"] = tick

	if gdp > 0.0:
		# صادراتِ مطابق استاندارد: حق‌بیمه کیفی + دسترسی بازار
		# واقع‌گرایی: اثر سطحی همگرا (هر ماه ۲۰٪ از فاصله تا هدف) به‌جای جمعِ بی‌پایان روی GDP
		var boost_target: float = gdp * (qi * 0.0018 + eg * 0.0012)
		var boost_prev: float = float(p.get("_gdp_boost", 0.0))
		var boost_delta: float = (boost_target - boost_prev) * 0.20
		economy["gdp"] = gdp + boost_delta
		p["_gdp_boost"] = boost_prev + boost_delta
		# ممیزی ذخایر (۱۴۰۵): ورودی ماهانه به کانال reserve_inflows (مالک: بانک مرکزی)
		var st_infl: Dictionary = economy.get("reserve_inflows", {})
		st_infl["صادرات استاندارد"] = gdp * eg * 0.0006
		economy["reserve_inflows"] = st_infl
		state["economy"] = economy

	# بازرسی بازار → اعتماد مصرف‌کننده و شادی اندک
	if state.has("population") and state["population"] is Dictionary:
		var pop: Dictionary = state["population"]
		pop["happiness"] = clampf(float(pop.get("happiness", 0.5)) + srv * 0.0006, 0.0, 1.0)
		state["population"] = pop

	emit_signal("certified_firms_changed", int(p["certified_firms"]))
	state["standards_policy"] = p
	return state

func simulate_month(state: Dictionary, tick: int) -> Dictionary:
	# قرارداد مشترک چرخه ماهانه موتور: خروجی همیشه {state, events} است.
	return {"state": simulate(state, tick), "events": []}

func get_summary(state: Dictionary) -> Dictionary:
	var p = get_policy(state)
	return {
		"metrology": p["metrology"],
		"labs": p["labs"],
		"accreditation": p["accreditation"],
		"surveillance": p["surveillance"],
		"export_gate": p["export_gate"],
		"certified_firms": p["certified_firms"],
	}
