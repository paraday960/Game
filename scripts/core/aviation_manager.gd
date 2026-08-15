extends Node
# ── هوانوردی و خطوط هوایی (عمق ۲۱) ──
# توسعه فرودگاه‌ها، ناوگان هوایی ملی، ایمنی ناوبری، هاب ترانزیت
# مسافری و باری و لجستیک بار هوایی. هوانوردی شریان گردشگری،
# تجارت و اشتغال است و بر قدرت نرم کشور می‌افزاید.
# پیوند: اقتصاد، گردشگری، دیپلماسی.


var airports: float = 0.15
var fleet: float = 0.10
var safety: float = 0.40
var hub: float = 0.05
var cargo: float = 0.10
var passengers_m: int = 25
var last_tick: int = 0

func reset():
	airports = 0.15
	fleet = 0.10
	safety = 0.40
	hub = 0.05
	cargo = 0.10
	passengers_m = 25

func _ensure(state: Dictionary):
	if not state.has("aviation_policy"):
		state["aviation_policy"] = {
			"airports": airports,
			"fleet": fleet,
			"safety": safety,
			"hub": hub,
			"cargo": cargo,
			"passengers_m": passengers_m,
			"last_tick": last_tick,
		}

func get_policy(state: Dictionary) -> Dictionary:
	_ensure(state)
	return state["aviation_policy"]

func expand_airports(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["aviation_policy"]
	p["airports"] = clampf(float(p.get("airports", 0.0)) + 0.10, 0.0, 1.0)
	state["aviation_policy"] = p
	return {"success": true}

func expand_fleet(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["aviation_policy"]
	p["fleet"] = clampf(float(p.get("fleet", 0.0)) + 0.12, 0.0, 1.0)
	state["aviation_policy"] = p
	return {"success": true}

func improve_safety(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["aviation_policy"]
	p["safety"] = clampf(float(p.get("safety", 0.0)) + 0.12, 0.0, 1.0)
	state["aviation_policy"] = p
	return {"success": true}

func develop_hub(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["aviation_policy"]
	# هاب ترانزیت بدون ظرفیت فرودگاهی ممکن نیست
	if float(p.get("airports", 0.0)) < 0.30:
		return {"success": false, "reason": "برای هاب ترانزیت ابتدا باید فرودگاه‌ها توسعه یابند"}
	p["hub"] = clampf(float(p.get("hub", 0.0)) + 0.10, 0.0, 1.0)
	state["aviation_policy"] = p
	return {"success": true}

func develop_cargo(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["aviation_policy"]
	p["cargo"] = clampf(float(p.get("cargo", 0.0)) + 0.12, 0.0, 1.0)
	state["aviation_policy"] = p
	return {"success": true}

func simulate(state: Dictionary, tick: int) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["aviation_policy"]
	var economy: Dictionary = state.get("economy", {})
	var gdp: float = float(economy.get("gdp", 0.0))

	var air: float = float(p.get("airports", 0.0))
	var flt: float = float(p.get("fleet", 0.0))
	var sft: float = float(p.get("safety", 0.0))
	var hb: float = float(p.get("hub", 0.0))
	var crg: float = float(p.get("cargo", 0.0))

	# ظرفیت مؤثر: فرودگاه + ناوگان + هاب؛ ایمنی پایین ظرفیت را می‌کاهد
	var cap: float = clampf(air * 0.55 + flt * 0.30 + hb * 0.45, 0.0, 1.0)
	if sft < 0.30:
		cap *= 0.85

	# مسافران سالانه (میلیون نفر) - بازسازی دترمینستیک از ظرفیت
	p["passengers_m"] = int(round(6.0 + cap * 95.0))
	passengers_m = int(p["passengers_m"])
	p["last_tick"] = tick

	if gdp > 0.0:
		# سهم هوانوردی و بار هوایی در GDP + عوارض ترانزیت هاب به ارزها
		# واقع‌گرایی: اثر سطحی همگرا (هر ماه ۲۰٪ از فاصله تا هدف) به‌جای جمعِ بی‌پایان روی GDP
		var boost_target: float = gdp * (cap * 0.0035 + crg * 0.0020)
		var boost_prev: float = float(p.get("_gdp_boost", 0.0))
		var boost_delta: float = (boost_target - boost_prev) * 0.20
		economy["gdp"] = gdp + boost_delta
		p["_gdp_boost"] = boost_prev + boost_delta
		# ممیزی ذخایر (۱۴۰۵): ورودی ماهانه به کانال reserve_inflows (مالک: بانک مرکزی)
		var av_infl: Dictionary = economy.get("reserve_inflows", {})
		av_infl["هاب هوایی و بار"] = gdp * hb * 0.0008
		economy["reserve_inflows"] = av_infl
		state["economy"] = economy

	# اتصال هوایی جهانی → قدرت نرم
	if state.has("diplomacy") and state["diplomacy"] is Dictionary:
		var dip: Dictionary = state["diplomacy"]
		dip["soft_power"] = clampf(float(dip.get("soft_power", 35.0)) + cap * 0.03, 0.0, 100.0)
		state["diplomacy"] = dip

	state["aviation_policy"] = p
	return state

func simulate_month(state: Dictionary, tick: int) -> Dictionary:
	# قرارداد مشترک چرخه ماهانه موتور: خروجی همیشه {state, events} است.
	return {"state": simulate(state, tick), "events": []}

func get_summary(state: Dictionary) -> Dictionary:
	var p = get_policy(state)
	return {
		"airports": p["airports"],
		"fleet": p["fleet"],
		"safety": p["safety"],
		"hub": p["hub"],
		"cargo": p["cargo"],
		"passengers_m": p["passengers_m"],
	}
