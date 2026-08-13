extends Node
# ── پست و لجستیک ملی (عمق ۲۱) ──
# شبکه توزیع سراسری، مراکز پردازش مکانیزه، تحویل آخرین مایل،
# تسهیل تجارت الکترونیک و رهگیری مرسولات. پستِ مدرن ستون
# فقرات فروش آنلاین SMEها و دسترسی روستایی است.
# پیوند: بنگاه‌های کوچک، توسعه روستایی، رفاه و GDP.

signal parcels_changed(count: int)

var network: float = 0.30
var sorting: float = 0.15
var lastmile: float = 0.20
var ecommerce: float = 0.25
var tracking: float = 0.10
var parcels_m: int = 500
var last_tick: int = 0

func reset():
	network = 0.30
	sorting = 0.15
	lastmile = 0.20
	ecommerce = 0.25
	tracking = 0.10
	parcels_m = 500

func _ensure(state: Dictionary):
	if not state.has("postal_policy"):
		state["postal_policy"] = {
			"network": network,
			"sorting": sorting,
			"lastmile": lastmile,
			"ecommerce": ecommerce,
			"tracking": tracking,
			"parcels_m": parcels_m,
			"last_tick": last_tick,
		}

func get_policy(state: Dictionary) -> Dictionary:
	_ensure(state)
	return state["postal_policy"]

func expand_network(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["postal_policy"]
	p["network"] = clampf(float(p.get("network", 0.0)) + 0.10, 0.0, 1.0)
	state["postal_policy"] = p
	return {"success": true}

func mechanize_sorting(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["postal_policy"]
	p["sorting"] = clampf(float(p.get("sorting", 0.0)) + 0.12, 0.0, 1.0)
	state["postal_policy"] = p
	return {"success": true}

func improve_lastmile(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["postal_policy"]
	p["lastmile"] = clampf(float(p.get("lastmile", 0.0)) + 0.12, 0.0, 1.0)
	state["postal_policy"] = p
	return {"success": true}

func boost_ecommerce(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["postal_policy"]
	# تجارت الکترونیک بدون زیرساخت تحویل مؤثر رشد نمی‌کند
	if float(p.get("lastmile", 0.0)) < 0.25:
		return {"success": false, "reason": "برای تسهیل تجارت الکترونیک ابتدا تحویل آخرین مایل را بسازید"}
	p["ecommerce"] = clampf(float(p.get("ecommerce", 0.0)) + 0.10, 0.0, 1.0)
	state["postal_policy"] = p
	return {"success": true}

func improve_tracking(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["postal_policy"]
	p["tracking"] = clampf(float(p.get("tracking", 0.0)) + 0.12, 0.0, 1.0)
	state["postal_policy"] = p
	return {"success": true}

func simulate(state: Dictionary, tick: int) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["postal_policy"]
	var economy: Dictionary = state.get("economy", {})
	var gdp: float = float(economy.get("gdp", 0.0))

	var net: float = float(p.get("network", 0.0))
	var srt: float = float(p.get("sorting", 0.0))
	var lm: float = float(p.get("lastmile", 0.0))
	var ec: float = float(p.get("ecommerce", 0.0))
	var tr: float = float(p.get("tracking", 0.0))

	# ظرفیت لجستیک = شبکه + پردازش + تحویل آخرین مایل
	var cap: float = clampf(net * 0.40 + srt * 0.25 + lm * 0.35, 0.0, 1.0)

	# حجم مرسولات سالانه (میلیون قطعه) - دترمینستیک از ظرفیت و تجارت الکترونیک
	p["parcels_m"] = int(round(200.0 + cap * 1800.0 + ec * 400.0))
	parcels_m = int(p["parcels_m"])
	p["last_tick"] = tick

	if gdp > 0.0:
		# تجارت الکترونیک و لجستیک کارآمد به GDP می‌افزایند
		economy["gdp"] = gdp + gdp * (ec * 0.0022 + cap * 0.0010)
		state["economy"] = economy

	# بازار آنلاین → بهره‌وری بنگاه‌های کوچک
	if state.has("sme_policy") and state["sme_policy"] is Dictionary:
		var sme: Dictionary = state["sme_policy"]
		sme["productivity"] = clampf(float(sme.get("productivity", 0.35)) + ec * 0.0008, 0.0, 1.0)
		state["sme_policy"] = sme

	# شبکه توزیع سراسری → درآمد روستایی و عدالت منطقه‌ای
	if state.has("rural_policy") and state["rural_policy"] is Dictionary:
		var rur: Dictionary = state["rural_policy"]
		rur["rural_income"] = clampf(float(rur.get("rural_income", 0.40)) + net * 0.0008, 0.0, 1.0)
		state["rural_policy"] = rur

	# رهگیری مرسولات → اعتماد عمومی و شادی اندک
	if state.has("population") and state["population"] is Dictionary:
		var pop: Dictionary = state["population"]
		pop["happiness"] = clampf(float(pop.get("happiness", 0.5)) + tr * 0.0005, 0.0, 1.0)
		state["population"] = pop

	emit_signal("parcels_changed", int(p["parcels_m"]))
	state["postal_policy"] = p
	return state

func simulate_month(state: Dictionary, tick: int) -> Dictionary:
	# قرارداد مشترک چرخه ماهانه موتور: خروجی همیشه {state, events} است.
	return {"state": simulate(state, tick), "events": []}

func get_summary(state: Dictionary) -> Dictionary:
	var p = get_policy(state)
	return {
		"network": p["network"],
		"sorting": p["sorting"],
		"lastmile": p["lastmile"],
		"ecommerce": p["ecommerce"],
		"tracking": p["tracking"],
		"parcels_m": p["parcels_m"],
	}
