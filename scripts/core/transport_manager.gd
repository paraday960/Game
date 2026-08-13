extends Node
# ────────────────────────────────────────────────────────────────────────────
# حمل‌ونقل عمومی — عمق تحرک شهری و کیفیت زندگی
# مترو، اتوبوس و BRT ستون فقرات شهرها هستند؛ یارانه کرایه، نوسازی ناوگان و
# برقی‌سازی آلودگی را کم و رضایت را زیاد می‌کند. بی‌توجهی → اعتصاب و اعتراض.
# پیوند: زیرساخت، محیط‌زیست، انرژی، رفاه، شادی.
#
# state["transport_policy"] = { "subsidy_level":0..1, "last_metro":turn,
#   "last_fleet":turn, "metro_built":0, "brt_built":0 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("transport_policy"):
		state["transport_policy"] = {"subsidy_level": 0.5, "last_metro": -99, "last_fleet": -99, "metro_built": 0, "brt_built": 0}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var pt: Dictionary = state.get("public_transport", {})
	var tp: Dictionary = state["transport_policy"]
	var econ: Dictionary = state.get("economy", {})
	var pol: Dictionary = state.get("politics", {})
	var env: Dictionary = state.get("environment", {})

	var coverage := float(pt.get("coverage", 0.6))
	var affordability := float(pt.get("affordability", 0.7))
	var punctuality := float(pt.get("punctuality", 0.75))
	var fleet_age := float(pt.get("fleet_age", 7.0))
	var electrification := float(pt.get("electrification", 0.15))
	var subsidy_level := float(tp.get("subsidy_level", 0.5))

	# رضایت از حمل‌ونقل عمومی
	var satisfaction := clampf(0.15 + coverage * 0.30 + affordability * 0.25 + punctuality * 0.20 + (1.0 - fleet_age / 15.0) * 0.10, 0.05, 1.0)
	pt["satisfaction"] = satisfaction

	# هزینه ماهانه یارانه کرایه
	var gdp := float(econ.get("gdp", 1.0))
	var cost := gdp * 0.001 * subsidy_level
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + cost
	var revenue := float(econ.get("government_revenue", 0.0))
	if cost > revenue * 0.05:
		econ["national_debt"] = float(econ.get("national_debt", 0.0)) + (cost - revenue * 0.05) * 0.5

	# آلودگی شهری: ناوگان فرسوده و دیزلی
	var emission_factor := (fleet_age / 12.0) * (1.0 - electrification * 0.7)
	env["pollution"] = clampf(float(env.get("pollution", 0.4)) + emission_factor * 0.004, 0.05, 1.0)
	state["environment"] = env

	# اعتصاب کارگران حمل‌ونقل
	if satisfaction < 0.40 and Deterministic.chance(0.05):
		pol["stability"] = clampf(float(pol.get("stability", 0.6)) - 0.015, 0.05, 1.0)
		state["population"]["happiness"] = clampf(float(state["population"].get("happiness", 0.6)) - 0.006, 0.05, 1.0)
		events.append({"type": "transit_strike", "message": "🚏 اعتصاب سراسری حمل‌ونقل! شهر فلج شد و شهروندان خشمگین‌اند"})
	elif satisfaction > 0.75 and Deterministic.chance(0.04):
		state["population"]["happiness"] = clampf(float(state["population"].get("happiness", 0.6)) + 0.004, 0.05, 1.0)
		events.append({"type": "transit_success", "message": "🚇 حمل‌ونقل عمومی درخشان شد؛ شهروندان راحت‌تر و شادتر زندگی می‌کنند"})

	# بازگشت رضایت به سیستم روزانه
	pt["satisfaction"] = satisfaction
	state["public_transport"] = pt
	state["transport_policy"] = tp
	state["economy"] = econ
	state["politics"] = pol
	return {"state": state, "events": events}

# ── ساخت خط مترو جدید ──
func build_metro(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var tp: Dictionary = state["transport_policy"]
	if turn - int(tp.get("last_metro", -99)) < 8:
		return {"success": false, "reason": "ساخت هر خط مترو ۸ نوبت طول می‌کشد", "state": state, "events": []}
	var pt: Dictionary = state.get("public_transport", {})
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.012
	tp["last_metro"] = turn
	tp["metro_built"] = int(tp.get("metro_built", 0)) + 1
	pt["metro_lines"] = int(pt.get("metro_lines", 4)) + 1
	pt["metro_stations"] = int(pt.get("metro_stations", 200)) + 40
	pt["metro_length_km"] = float(pt.get("metro_length_km", 220.0)) + 25.0
	pt["coverage"] = clampf(float(pt.get("coverage", 0.6)) + 0.05, 0.15, 0.98)
	econ["unemployment"] = clampf(float(econ.get("unemployment", 0.08)) - 0.0005, 0.02, 0.30)
	state["public_transport"] = pt
	state["transport_policy"] = tp
	state["economy"] = econ
	return {"success": true, "state": state,
		"events": [{"type": "metro", "message": "🚇 خط متروی جدید افتتاح شد؛ پوشش شبکه و اشتغال عمرانی رشد کرد"}]}

# ── توسعه خطوط BRT ──
func build_brt(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var tp: Dictionary = state["transport_policy"]
	if turn - int(tp.get("last_brt", -99)) < 4:
		return {"success": false, "reason": "توسعه BRT هر ۴ نوبت یک بار ممکن است", "state": state, "events": []}
	var pt: Dictionary = state.get("public_transport", {})
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.005
	tp["last_brt"] = turn
	tp["brt_built"] = int(tp.get("brt_built", 0)) + 1
	pt["brt_lines"] = int(pt.get("brt_lines", 8)) + 1
	pt["coverage"] = clampf(float(pt.get("coverage", 0.6)) + 0.03, 0.15, 0.98)
	pt["punctuality"] = clampf(float(pt.get("punctuality", 0.75)) + 0.02, 0.2, 0.98)
	state["public_transport"] = pt
	state["transport_policy"] = tp
	state["economy"] = econ
	return {"success": true, "state": state,
		"events": [{"type": "brt", "message": "🚌 خطوط BRT گسترش یافت؛ اتوبوس‌ها سریع‌تر و منظم‌تر شدند"}]}

# ── افزایش یارانه کرایه ──
func raise_subsidy(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var tp: Dictionary = state["transport_policy"]
	if float(tp.get("subsidy_level", 0.5)) >= 0.98:
		return {"success": false, "reason": "یارانه کرایه در سقف ممکن است", "state": state, "events": []}
	tp["subsidy_level"] = clampf(float(tp.get("subsidy_level", 0.5)) + 0.2, 0.0, 1.0)
	var pt: Dictionary = state.get("public_transport", {})
	pt["affordability"] = clampf(float(pt.get("affordability", 0.7)) + 0.04, 0.1, 0.95)
	state["public_transport"] = pt
	state["transport_policy"] = tp
	return {"success": true, "state": state,
		"events": [{"type": "transit_subsidy", "message": "💸 یارانه کرایه حمل‌ونقل افزایش یافت؛ خانواده‌های کم‌درآمد نفس راحت کشیدند"}]}

# ── نوسازی ناوگان برقی ──
func modernize_fleet(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var tp: Dictionary = state["transport_policy"]
	if turn - int(tp.get("last_fleet", -99)) < 6:
		return {"success": false, "reason": "نوسازی ناوگان هر ۶ نوبت یک بار ممکن است", "state": state, "events": []}
	var pt: Dictionary = state.get("public_transport", {})
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.008
	tp["last_fleet"] = turn
	pt["fleet_age"] = maxf(float(pt.get("fleet_age", 7.0)) - 2.0, 2.0)
	pt["electrification"] = clampf(float(pt.get("electrification", 0.15)) + 0.1, 0.02, 0.85)
	pt["punctuality"] = clampf(float(pt.get("punctuality", 0.75)) + 0.02, 0.2, 0.98)
	state["public_transport"] = pt
	state["transport_policy"] = tp
	state["economy"] = econ
	return {"success": true, "state": state,
		"events": [{"type": "fleet", "message": "🔋 ناوگان اتوبوس‌های برقی نو خریداری شد؛ هوا پاک‌تر و سفرها روان‌تر شد"}]}
