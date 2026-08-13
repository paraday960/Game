extends Node
# ────────────────────────────────────────────────────────────────────────────
# میراث فرهنگی — عمق هویت و گردشگری تاریخی
# محوطه‌های تاریخی درآمد گردشگری می‌آورند و قدرت نرم می‌سازند؛ اما فرسایش،
# بلایای طبیعی و قاچاق آثار، میراث را تهدید می‌کند. دولت می‌تواند مرمت کند،
# پرونده ثبت جهانی بفرستد، جشنواره برگزار کند یا با قاچاقچیان بجنگد.
# پیوند: فرهنگ، گردشگری، آموزش، رهبر، رسانه.
#
# state["heritage_policy"] = { "restored": 0, "registered": 0,
#   "festivals": 0, "last_festival": turn, "last_disaster": turn,
#   "last_antiq": turn }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("heritage_policy"):
		state["heritage_policy"] = {"restored": 0, "registered": 0, "festivals": 0, "last_festival": -99, "last_disaster": -99, "last_antiq": -99}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var hr: Dictionary = state.get("heritage", {})
	var hp: Dictionary = state["heritage_policy"]
	var tour: Dictionary = state.get("tourism", {})
	var cult: Dictionary = state.get("culture_policy", {})

	var preservation := float(hr.get("preservation", 0.6))
	var unesco := int(hr.get("unesco_sites", 0))
	var sites := int(hr.get("sites", 20))
	var restored := int(hp.get("restored", 0))

	# مرمت‌های انجام‌شده، فرسایش روزانه را جبران می‌کنند
	if restored > 0:
		preservation = clampf(preservation + 0.004 * minf(float(restored), 3.0), 0.05, 1.0)

	# بلایای طبیعی و فرسودگی خطرناک
	var disaster_chance := 0.02
	if preservation < 0.35:
		disaster_chance = 0.06
	if Deterministic.chance(disaster_chance) and turn - int(hp.get("last_disaster", -99)) > 12:
		preservation = clampf(preservation - 0.15, 0.05, 1.0)
		hr["sites"] = maxi(int(hr.get("sites", 20)) - 1, 1)
		hp["last_disaster"] = turn
		events.append({"type": "heritage_disaster", "message": "🏚️ زمین‌لرزه/سیل به محوطه‌های تاریخی آسیب زد! مرمت فوری ضروری است"})

	# درآمد گردشگری میراثی و قدرت نرم
	var base_rev := float(tour.get("revenue", 0.0))
	tour["revenue"] = base_rev * (1.0 + preservation * 0.008 + float(unesco) * 0.006)
	cult["soft_power"] = clampf(float(cult.get("soft_power", 40.0)) + float(unesco) * 0.12 + preservation * 0.05, 5.0, 100.0)

	hr["preservation"] = preservation
	state["heritage"] = hr
	state["heritage_policy"] = hp
	state["tourism"] = tour
	state["culture_policy"] = cult
	return {"state": state, "events": events}

# ── مرمت محوطه‌های تاریخی ──
func restore_sites(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var hr: Dictionary = state.get("heritage", {})
	var hp: Dictionary = state["heritage_policy"]
	var econ: Dictionary = state.get("economy", {})
	econ["government_spending"] = float(econ.get("government_spending", 0.0)) + float(econ.get("gdp", 1.0)) * 0.005
	hr["preservation"] = clampf(float(hr.get("preservation", 0.6)) + 0.1, 0.05, 1.0)
	hr["restoration"] = clampf(float(hr.get("restoration", 0.55)) + 0.1, 0.05, 1.0)
	hp["restored"] = int(hp.get("restored", 0)) + 1
	state["heritage"] = hr
	state["heritage_policy"] = hp
	state["economy"] = econ
	return {"success": true, "state": state,
		"events": [{"type": "restore", "message": "🧱 مرمتگران به محوطه‌های تاریخی رفتند؛ بناها جان دوباره گرفتند و گردشگران بازگشتند"}]}

# ── پرونده ثبت جهانی ──
func register_unesco(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var hr: Dictionary = state.get("heritage", {})
	var hp: Dictionary = state["heritage_policy"]
	if int(hr.get("unesco_sites", 0)) >= 6:
		return {"success": false, "reason": "ظرفیت ثبت جهانی در این بازه تکمیل است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["government_spending"] = float(econ.get("government_spending", 0.0)) + float(econ.get("gdp", 1.0)) * 0.015
	hr["unesco_sites"] = int(hr.get("unesco_sites", 0)) + 1
	hp["registered"] = int(hp.get("registered", 0)) + 1
	state["culture_policy"]["soft_power"] = clampf(float(state["culture_policy"].get("soft_power", 40.0)) + 4.0, 5.0, 100.0)
	state["heritage"] = hr
	state["heritage_policy"] = hp
	state["economy"] = econ
	return {"success": true, "state": state,
		"events": [{"type": "unesco", "message": "🌍 ثبت جهانی جدید! نام کشور در فهرست میراث بشریت جاودانه شد؛ جهان به تماشا آمد"}]}

# ── جشنواره بین‌المللی ──
func heritage_festival(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var hp: Dictionary = state["heritage_policy"]
	if turn - int(hp.get("last_festival", -99)) < 12:
		return {"success": false, "reason": "جشنواره بین‌المللی هر ۱۲ نوبت یک بار ممکن است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	var tour: Dictionary = state.get("tourism", {})
	econ["government_spending"] = float(econ.get("government_spending", 0.0)) + float(econ.get("gdp", 1.0)) * 0.008
	tour["revenue"] = float(tour.get("revenue", 0.0)) * 1.05
	hp["last_festival"] = turn
	hp["festivals"] = int(hp.get("festivals", 0)) + 1
	state["population"]["happiness"] = clampf(float(state["population"].get("happiness", 0.6)) + 0.01, 0.05, 1.0)
	state["culture_policy"]["soft_power"] = clampf(float(state["culture_policy"].get("soft_power", 40.0)) + 2.0, 5.0, 100.0)
	state["economy"] = econ
	state["tourism"] = tour
	state["heritage_policy"] = hp
	return {"success": true, "state": state,
		"events": [{"type": "heritage_festival", "message": "🎭 جشنواره بین‌المللی میراث: موسیقی، نمایش و آیین‌های کهن؛ گردشگران شگفت‌زده شدند"}]}

# ── مبارزه با قاچاق آثار ──
func antiquities_crackdown(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var hp: Dictionary = state["heritage_policy"]
	if turn - int(hp.get("last_antiq", -99)) < 6:
		return {"success": false, "reason": "عملیات ضدقاچاق هر ۶ نوبت یک بار ممکن است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	var gdp := float(econ.get("gdp", 1.0))
	econ["government_revenue"] = float(econ.get("government_revenue", 0.0)) + gdp * 0.002
	hp["last_antiq"] = turn
	state["politics"]["corruption"] = clampf(float(state["politics"].get("corruption", 0.3)) - 0.012, 0.01, 1.0)
	state["heritage"]["digital_archives"] = clampf(float(state["heritage"].get("digital_archives", 0.4)) + 0.05, 0.05, 1.0)
	state["economy"] = econ
	state["heritage_policy"] = hp
	return {"success": true, "state": state,
		"events": [{"type": "antiquities", "message": "🚔 باند قاچاق آثار تاریخی متلاشی شد؛ اشیای باستانی به موزه‌ها بازگشت و خزانه سود کرد"}]}
