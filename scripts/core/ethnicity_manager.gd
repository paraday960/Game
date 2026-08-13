extends Node
# ────────────────────────────────────────────────────────────────────────────
# همبستگی قومی — عمق انسجام ملی و حقوق اقوام
# تنش قومی با نابرابری، تبعیض و ضعف ادغام می‌بالد؛ فرصت‌های برابر، خودمختاری
# فرهنگی و گفت‌وگوی ملی آن را فرو می‌نشاند. بی‌توجهی → بحران هویتی و تجزیه‌طلبی.
# پیوند: سیاست، آموزش، رفاه، فرهنگ، رسانه، فراکسیون‌ها.
#
# state["ethnicity_policy"] = { "equal_programs":0..1, "autonomy":0..1,
#   "dialogues":0, "last_festival":turn, "representation":0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("ethnicity_policy"):
		state["ethnicity_policy"] = {"equal_programs": 0.4, "autonomy": 0.4, "dialogues": 0, "last_festival": -99, "representation": 0.4}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var eth: Dictionary = state.get("ethnicity", {})
	var ep: Dictionary = state["ethnicity_policy"]
	var pol: Dictionary = state.get("politics", {})
	var pop: Dictionary = state.get("population", {})

	var tension := float(eth.get("tension", 0.3))
	var integration := float(eth.get("integration", 0.55))
	var discrimination := float(eth.get("discrimination", 0.2))
	var cultural_rights := float(eth.get("cultural_rights", 0.6))
	var equal_programs := float(ep.get("equal_programs", 0.4))
	var autonomy := float(ep.get("autonomy", 0.4))
	var representation := float(ep.get("representation", 0.4))

	# سیاست‌های دولت تنش را می‌خوابانند
	var policy_effect := equal_programs * 0.004 + autonomy * 0.003 + representation * 0.002
	tension = clampf(tension - policy_effect + (1.0 - integration) * 0.001, 0.02, 0.95)

	# نمایندگی اقوام در دولت
	representation = clampf(representation + equal_programs * 0.001, 0.05, 1.0)
	ep["representation"] = representation
	eth["discrimination"] = clampf(discrimination * 0.99 - equal_programs * 0.004, 0.0, 0.85)
	eth["cultural_rights"] = clampf(cultural_rights * 0.99 + autonomy * 0.006, 0.1, 0.95)
	eth["integration"] = clampf(integration * 0.995 + (equal_programs * 0.004 + representation * 0.003), 0.1, 0.95)
	eth["tension"] = tension

	# بحران هویتی
	if tension > 0.70 and Deterministic.chance(0.06):
		pol["stability"] = clampf(float(pol.get("stability", 0.6)) - 0.02, 0.05, 1.0)
		state["media"]["groups"]["جوانان"]["approval"] = clampf(float(state["media"]["groups"]["جوانان"].get("approval", 45.0)) - 1.5, 5.0, 100.0)
		events.append({"type": "ethnic_crisis", "message": "🚨 بحران هویتی در مناطق قومی‌نشین! اعتراضات و درخواست‌های جدایی‌طلبی بالا گرفت"})
	elif tension < 0.35 and Deterministic.chance(0.04):
		pol["stability"] = clampf(float(pol.get("stability", 0.6)) + 0.004, 0.05, 1.0)
		events.append({"type": "ethnic_harmony", "message": "🕊️ همبستگی ملی درخشان شد؛ اقوام در کنار هم زندگی مسالمت‌آمیزی دارند"})

	# رضایت گروه‌های قومی به سمت شادی کلان می‌گراید
	var happiness := float(pop.get("happiness", 0.6))
	var groups: Array = eth.get("groups", [])
	for g in groups:
		if g is Dictionary:
			var g_happy := float(g.get("happiness", 0.6)) + (happiness - float(g.get("happiness", 0.6))) * 0.05 + (1.0 - discrimination) * 0.004 - tension * 0.002
			g["happiness"] = clampf(g_happy, 0.1, 0.95)
	eth["groups"] = groups

	state["ethnicity"] = eth
	state["ethnicity_policy"] = ep
	state["politics"] = pol
	return {"state": state, "events": events}

# ── برنامه فرصت‌های برابر ──
func equal_opportunities(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var ep: Dictionary = state["ethnicity_policy"]
	if float(ep.get("equal_programs", 0.4)) >= 0.98:
		return {"success": false, "reason": "برنامه فرصت‌های برابر حداکثری است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["government_spending"] = float(econ.get("government_spending", 0.0)) + float(econ.get("gdp", 1.0)) * 0.003
	ep["equal_programs"] = clampf(float(ep.get("equal_programs", 0.4)) + 0.3, 0.0, 1.0)
	state["ethnicity"]["discrimination"] = clampf(float(state["ethnicity"].get("discrimination", 0.2)) - 0.03, 0.0, 0.85)
	state["education"]["quality"] = clampf(float(state["education"].get("quality", 0.55)) + 0.008, 0.1, 1.0)
	state["ethnicity_policy"] = ep
	state["economy"] = econ
	return {"success": true, "state": state,
		"events": [{"type": "equal_opp", "message": "⚖️ برنامه فرصت‌های برابر اقوام اجرا شد؛ سهمیه آموزشی و استخدامی عادلانه شد"}]}

# ── خودمختاری فرهنگی مناطق ──
func cultural_autonomy(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var ep: Dictionary = state["ethnicity_policy"]
	if float(ep.get("autonomy", 0.4)) >= 0.98:
		return {"success": false, "reason": "خودمختاری فرهنگی حداکثری است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["government_spending"] = float(econ.get("government_spending", 0.0)) + float(econ.get("gdp", 1.0)) * 0.004
	ep["autonomy"] = clampf(float(ep.get("autonomy", 0.4)) + 0.3, 0.0, 1.0)
	state["ethnicity"]["cultural_rights"] = clampf(float(state["ethnicity"].get("cultural_rights", 0.6)) + 0.05, 0.1, 0.95)
	state["ethnicity"]["tension"] = clampf(float(state["ethnicity"].get("tension", 0.3)) - 0.02, 0.02, 0.95)
	# پوپولیست‌ها ناراضی می‌شوند
	var pop_fac: Dictionary = state.get("factions", {}).get("پوپولیست‌ها", {})
	if not pop_fac.is_empty():
		pop_fac["loyalty"] = clampf(float(pop_fac.get("loyalty", 55.0)) - 2.0, 5.0, 100.0)
		state["factions"]["پوپولیست‌ها"] = pop_fac
	state["ethnicity_policy"] = ep
	state["economy"] = econ
	return {"success": true, "state": state,
		"events": [{"type": "autonomy", "message": "🏳️ خودمختاری فرهنگی مناطق قومی تصویب شد؛ زبان و آیین‌های محلی رسمیت یافت"}]}

# ── گفت‌وگوی ملی اقوام ──
func national_dialogue(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var ep: Dictionary = state["ethnicity_policy"]
	if turn - int(ep.get("last_dialogue", -99)) < 4:
		return {"success": false, "reason": "گفت‌وگوی ملی هر ۴ نوبت یک بار ممکن است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["government_spending"] = float(econ.get("government_spending", 0.0)) + float(econ.get("gdp", 1.0)) * 0.001
	ep["last_dialogue"] = turn
	ep["dialogues"] = int(ep.get("dialogues", 0)) + 1
	state["ethnicity"]["tension"] = clampf(float(state["ethnicity"].get("tension", 0.3)) - 0.04, 0.02, 0.95)
	state["media"]["trust"] = clampf(float(state["media"].get("trust", 0.55)) + 0.01, 0.05, 1.0)
	state["ethnicity_policy"] = ep
	state["economy"] = econ
	return {"success": true, "state": state,
		"events": [{"type": "dialogue", "message": "🤝 گفت‌وگوی ملی اقوام برگزار شد؛ نمایندگان همه قومیت‌ها دور یک میز نشستند"}]}

# ── جشنواره فرهنگ اقوام ──
func ethnic_festival(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var ep: Dictionary = state["ethnicity_policy"]
	if turn - int(ep.get("last_festival", -99)) < 12:
		return {"success": false, "reason": "جشنواره فرهنگ اقوام هر ۱۲ نوبت یک بار ممکن است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["government_spending"] = float(econ.get("government_spending", 0.0)) + float(econ.get("gdp", 1.0)) * 0.006
	ep["last_festival"] = turn
	state["population"]["happiness"] = clampf(float(state["population"].get("happiness", 0.6)) + 0.012, 0.05, 1.0)
	state["culture_policy"]["soft_power"] = clampf(float(state["culture_policy"].get("soft_power", 40.0)) + 2.0, 5.0, 100.0)
	state["tourism"]["revenue"] = float(state["tourism"].get("revenue", 0.0)) * 1.02
	state["media"]["groups"]["جوانان"]["approval"] = clampf(float(state["media"]["groups"]["جوانان"].get("approval", 45.0)) + 2.0, 5.0, 100.0)
	state["ethnicity_policy"] = ep
	state["economy"] = econ
	return {"success": true, "state": state,
		"events": [{"type": "ethnic_festival", "message": "🎊 جشنواره فرهنگ اقوام: موسیقی، رقص و آیین‌های رنگارنگ؛ ملت در شادی یکی شد"}]}
