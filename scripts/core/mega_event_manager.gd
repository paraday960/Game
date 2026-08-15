extends Node
# ── میزبانی رویداد بزرگ جهانی (عمق‌بخشی ۴۳) ──
# کاندیداتوری، میزبانی و میراث: بازیکن برای رویدادهای بزرگ (جام جهانی،
# المپیک، اکسپو، گرندپری) نامزد می‌شود؛ موفقیت به زیرساخت/ثبات/قدرت نرم
# بستگی دارد؛ در حین میزبانی گردشگری و قدرت نرم جهش می‌کند و پس از آن
# «میراث» ماندگار می‌ماند — یا اگر زیرساخت ضعیف بود، «فیل سفید» می‌شود.
#
# state["mega_event"] = {
#   "status": "none" | "hosting" | "legacy",
#   "event_id": "", "started_turn": 0, "ends_turn": 0,
#   "legacy_until_turn": 0, "white_elephant": false, "bid_count": 0
# }

const EVENTS_PATH := "res://data/mega_events.json"
var events: Dictionary = {}
var load_errors: Array = []

func _ready() -> void:
	reload()

func reload() -> bool:
	events.clear()
	load_errors.clear()
	var file := FileAccess.open(EVENTS_PATH, FileAccess.READ)
	if file == null:
		load_errors.append("فایل رویدادهای جهانی خوانده نشد")
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.get("events", null) is Array:
		load_errors.append("ساختار mega_events.json نامعتبر است")
		return false
	for raw in parsed["events"]:
		var id := str(raw.get("id", ""))
		if id.is_empty() or events.has(id):
			load_errors.append("شناسه رویداد خالی یا تکراری است: %s" % id)
			continue
		events[id] = raw.duplicate(true)
	return events.size() >= 3 and load_errors.is_empty()

func get_errors() -> Array:
	return load_errors

func get_event_ids() -> Array:
	return events.keys()

func get_event(id: String) -> Dictionary:
	return events.get(id, {}).duplicate(true)

func get_event_name(id: String) -> String:
	return str(events.get(id, {}).get("name_fa", id))

# ── وضعیت ──
func _ensure(state: Dictionary) -> Dictionary:
	if not state.has("mega_event"):
		state["mega_event"] = {"status": "none", "event_id": "", "started_turn": 0,
			"ends_turn": 0, "legacy_until_turn": 0, "white_elephant": false, "bid_count": 0}
	return state

func get_status(state: Dictionary) -> Dictionary:
	state = _ensure(state)
	return state["mega_event"].duplicate(true)

# ── نامزدی ──
func can_bid(state: Dictionary, event_id: String) -> Dictionary:
	state = _ensure(state)
	var me: Dictionary = state["mega_event"]
	if str(me.get("status", "none")) != "none":
		return {"valid": false, "reason": "کشور درگیر یک رویداد یا دوره‌ی میراث است"}
	if not events.has(event_id):
		return {"valid": false, "reason": "رویداد موردنظر وجود ندارد"}
	return {"valid": true, "reason": ""}

func bid(state: Dictionary, event_id: String, turn: int) -> Dictionary:
	state = _ensure(state)
	var check := can_bid(state, event_id)
	if not check.valid:
		return {"success": false, "reason": check.reason, "state": state, "events": []}
	var definition: Dictionary = events[event_id]
	var econ: Dictionary = state.get("economy", {})
	var gdp := float(econ.get("gdp", 500_000_000_000.0))
	var cost := gdp * float(definition.get("bid_cost_gdp_ratio", 0.015))
	# هزینه‌ی نامزدی → بدهی (هزینه‌ی واقعی دولت)
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + cost
	state["economy"] = econ

	var me: Dictionary = state["mega_event"]
	me["bid_count"] = int(me.get("bid_count", 0)) + 1

	# شانس موفقیت: زیرساخت + ثبات + قدرت نرم + گردشگری
	var infra := float(state.get("infrastructure", {}).get("quality", 0.55))
	var sport_infra := float(state.get("pro_sports_policy", {}).get("infrastructure", 0.2))
	var stability := float(state.get("politics", {}).get("stability", 0.6))
	var soft := float(state.get("culture_policy", {}).get("soft_power", 40.0)) / 100.0
	var tourism_infra := float(state.get("tourism", {}).get("infrastructure", 0.55))
	var score := infra * 0.30 + sport_infra * 0.20 + stability * 0.15 + soft * 0.20 + tourism_infra * 0.15
	var chance := clampf(score * 0.9 - 0.15, 0.10, 0.85)

	var events_out: Array = []
	if Deterministic.chance(chance):
		me["status"] = "hosting"
		me["event_id"] = event_id
		me["started_turn"] = turn
		me["ends_turn"] = turn + int(definition.get("duration_months", 3))
		me["legacy_until_turn"] = 0
		me["white_elephant"] = infra < 0.35 or sport_infra < 0.20
		events_out.append({"type": "mega_event_won", "event_id": event_id,
			"message": "🎉 %s به کشور شما رسید! جهان به تماشای شما می‌آید." % get_event_name(event_id)})
	else:
		me["status"] = "legacy"
		me["event_id"] = event_id
		me["started_turn"] = turn
		me["ends_turn"] = 0
		me["legacy_until_turn"] = turn + int(definition.get("legacy_months", 12))
		me["white_elephant"] = true
		events_out.append({"type": "mega_event_lost", "event_id": event_id,
			"message": "😔 نامزدی %s ناموفق بود؛ هزینه‌ی تبلیغات و زیرساخت بر باد رفت." % get_event_name(event_id)})

	state["mega_event"] = me
	return {"success": true, "state": state, "events": events_out}

# ── شبیه‌سازی ماهانه ──
func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = _ensure(state)
	var me: Dictionary = state["mega_event"]
	var events_out: Array = []
	var status := str(me.get("status", "none"))
	if status == "none":
		return {"state": state, "events": events_out}
	var event_id := str(me.get("event_id", ""))
	var definition: Dictionary = events.get(event_id, {})
	var econ: Dictionary = state.get("economy", {})

	if status == "hosting":
		# درآمد گردشگری → کانال ذخایر ارزی
		var gdp := float(econ.get("gdp", 500_000_000_000.0))
		var tourism_income := gdp * float(definition.get("monthly_tourism_gdp_ratio", 0.003))
		var infl: Dictionary = econ.get("reserve_inflows", {})
		infl[get_event_name(event_id)] = tourism_income
		econ["reserve_inflows"] = infl
		# رشد بخش گردشگری از کانال sector_boosts
		var boosts: Dictionary = econ.get("sector_boosts", {})
		boosts["میزبانی رویداد جهانی"] = float(definition.get("monthly_tourism_gdp_ratio", 0.003)) * 12.0
		econ["sector_boosts"] = boosts
		state["economy"] = econ
		# قدرت نرم و رضایت
		var culture: Dictionary = state.get("culture_policy", {})
		culture["soft_power"] = clampf(float(culture.get("soft_power", 40.0)) + float(definition.get("soft_power_gain", 1.0)), 5.0, 100.0)
		state["culture_policy"] = culture
		var pop: Dictionary = state.get("population", {})
		pop["happiness"] = clampf(float(pop.get("happiness", 0.6)) + float(definition.get("happiness_gain", 0.004)), 0.05, 1.0)
		state["population"] = pop
		# پایان میزبانی → میراث
		if turn >= int(me.get("ends_turn", turn)):
			me["status"] = "legacy"
			me["legacy_until_turn"] = turn + int(definition.get("legacy_months", 12))
			me["ends_turn"] = 0
			if bool(me.get("white_elephant", false)):
				events_out.append({"type": "white_elephant", "event_id": event_id,
					"message": "🏗️ پس از %s، ورزشگاه‌ها و زیرساخت‌های گران نیمه‌کاره ماندند — «فیل سفید»؛ نگهداری‌شان بدهی می‌آورد." % get_event_name(event_id)})
			else:
				events_out.append({"type": "mega_event_legacy", "event_id": event_id,
					"message": "🌟 میراث %s: گردشگری و جایگاه جهانی کشور ماندگار شد." % get_event_name(event_id)})

	elif status == "legacy":
		# میراث: گردشگری پایه و قدرت نرم ماندگار
		var tourism: Dictionary = state.get("tourism", {})
		tourism["infrastructure"] = clampf(float(tourism.get("infrastructure", 0.55)) + float(definition.get("legacy_tourism_base", 0.02)) / 12.0, 0.1, 1.0)
		state["tourism"] = tourism
		var culture: Dictionary = state.get("culture_policy", {})
		culture["soft_power"] = clampf(float(culture.get("soft_power", 40.0)) + float(definition.get("legacy_soft_power", 1.0)) / 12.0, 5.0, 100.0)
		state["culture_policy"] = culture
		# فیل سفید: فشار بدهی و نارضایتی خفیف
		if bool(me.get("white_elephant", false)):
			var gdp := float(econ.get("gdp", 500_000_000_000.0))
			econ["national_debt"] = float(econ.get("national_debt", 0.0)) + gdp * 0.0008
			state["economy"] = econ
			var pop: Dictionary = state.get("population", {})
			pop["happiness"] = clampf(float(pop.get("happiness", 0.6)) - 0.001, 0.05, 1.0)
			state["population"] = pop
		# پایان میراث
		if turn >= int(me.get("legacy_until_turn", turn)):
			me["status"] = "none"
			me["event_id"] = ""
			me["legacy_until_turn"] = 0
			me["white_elephant"] = false

	state["mega_event"] = me
	return {"state": state, "events": events_out}
