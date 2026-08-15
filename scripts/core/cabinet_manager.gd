extends Node
# کابینه و وزیران: شایستگی، پاکدستی، وفاداری، تجربه، انسجام و رسوایی

const DATA_PATH = "res://data/cabinet.json"
var ministries: Dictionary = {}
var ordered_ids: Array = []
var candidates: Dictionary = {}
var data_version := ""
var appointment_cost := 0.5
var load_errors: Array = []

func _ready():
	reload()

func reload() -> bool:
	ministries.clear()
	ordered_ids.clear()
	candidates.clear()
	load_errors.clear()
	var file = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		load_errors.append("فایل کابینه خوانده نشد")
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or not parsed.get("ministries", null) is Array:
		load_errors.append("ساختار کابینه نامعتبر است")
		return false
	data_version = str(parsed.get("version", "1.0.0"))
	appointment_cost = float(parsed.get("appointment_cost", 0.5))
	for raw in parsed["ministries"]:
		if not raw is Dictionary:
			continue
		var id = str(raw.get("id", ""))
		if id.is_empty() or ministries.has(id):
			load_errors.append("شناسه وزارتخانه خالی یا تکراری است")
			continue
		ministries[id] = raw.duplicate(true)
		ordered_ids.append(id)
		for candidate in raw.get("candidates", []):
			if candidate is Dictionary:
				candidates[str(candidate.get("id", ""))] = candidate.duplicate(true)
	return load_errors.is_empty()

func is_valid() -> bool:
	return ministries.size() >= 10 and candidates.size() >= 30 and load_errors.is_empty()

func get_ministry_ids() -> Array:
	return ordered_ids.duplicate()

func get_ministry(id: String) -> Dictionary:
	return ministries.get(id, {}).duplicate(true)

func get_candidate(id: String) -> Dictionary:
	return candidates.get(id, {}).duplicate(true)

func get_candidate_name(id: String) -> String:
	return str(candidates.get(id, {}).get("name_fa", id))

func reset(state: Dictionary) -> Dictionary:
	var active: Dictionary = {}
	for ministry_id in ordered_ids:
		var pool: Array = ministries[ministry_id].get("candidates", [])
		if not pool.is_empty():
			active[ministry_id] = {"candidate_id":str(pool[0].get("id", "")),"appointed_turn":0,"tenure_months":0,"scandals":0}
	state["cabinet"] = {
		"data_version":data_version,
		"active":active,
		"performance":{},
		"cohesion":0.65,
		"history":[],
		"scandal_count":0,
		"missions":{},
		"disputes":[],
		"next_mission_turn":0
	}
	return state

func ensure_state(state: Dictionary) -> Dictionary:
	if not state.has("cabinet") or not state["cabinet"] is Dictionary:
		return reset(state)
	var cabinet: Dictionary = state["cabinet"]
	cabinet["active"] = cabinet.get("active", {})
	cabinet["performance"] = cabinet.get("performance", {})
	cabinet["history"] = cabinet.get("history", [])
	cabinet["cohesion"] = float(cabinet.get("cohesion", 0.65))
	cabinet["scandal_count"] = int(cabinet.get("scandal_count", 0))
	cabinet["missions"] = cabinet.get("missions", {})
	cabinet["disputes"] = cabinet.get("disputes", [])
	cabinet["next_mission_turn"] = int(cabinet.get("next_mission_turn", 0))
	state["cabinet"] = cabinet
	return state

func can_appoint(state: Dictionary, ministry_id: String, candidate_id: String) -> Dictionary:
	if not ministries.has(ministry_id):
		return {"valid":false,"reason":"وزارتخانه معتبر نیست"}
	var belongs = false
	for candidate in ministries[ministry_id].get("candidates", []):
		if str(candidate.get("id", "")) == candidate_id:
			belongs = true
			break
	if not belongs:
		return {"valid":false,"reason":"نامزد برای این وزارتخانه معرفی نشده است"}
	state = ensure_state(state.duplicate(true))
	if str(state["cabinet"]["active"].get(ministry_id, {}).get("candidate_id", "")) == candidate_id:
		return {"valid":false,"reason":"این وزیر هم‌اکنون منصوب است"}
	if float(state.get("policies", {}).get("political_capital", 0.0)) < appointment_cost:
		return {"valid":false,"reason":"سرمایه سیاسی کافی برای تغییر وزیر وجود ندارد"}
	return {"valid":true,"reason":""}

func appoint(state: Dictionary, ministry_id: String, candidate_id: String, turn: int) -> Dictionary:
	var check = can_appoint(state, ministry_id, candidate_id)
	if not check.valid:
		return {"success":false,"reason":check.reason,"state":state,"events":[]}
	state = ensure_state(state)
	var cabinet: Dictionary = state["cabinet"]
	var previous = str(cabinet["active"].get(ministry_id, {}).get("candidate_id", ""))
	cabinet["active"][ministry_id] = {"candidate_id":candidate_id,"appointed_turn":turn,"tenure_months":0,"scandals":0}
	cabinet["history"].append({"type":"appointed","ministry":ministry_id,"candidate":candidate_id,"previous":previous,"turn":turn})
	state["policies"]["political_capital"] = max(0.0, float(state["policies"].get("political_capital", 0.0)) - appointment_cost)
	state["politics"]["trust"] = clamp(float(state["politics"].get("trust", 0.5)) + (float(candidates[candidate_id].get("integrity", 0.5)) - 0.5) * 0.01, 0.0, 1.0)
	state["cabinet"] = cabinet
	return {"success":true,"state":state,"events":[{
		"type":"minister_appointed","ministry":ministry_id,"candidate":candidate_id,
		"message":"%s به‌عنوان مسئول %s منصوب شد" % [get_candidate_name(candidate_id), ministries[ministry_id].get("name_fa", "وزارتخانه")]
	}]}

func dismiss(state: Dictionary, ministry_id: String, turn: int) -> Dictionary:
	state = ensure_state(state)
	if not state["cabinet"]["active"].has(ministry_id):
		return {"success":false,"reason":"این وزارتخانه وزیر فعال ندارد","state":state,"events":[]}
	var candidate_id = str(state["cabinet"]["active"][ministry_id].get("candidate_id", ""))
	state["cabinet"]["active"].erase(ministry_id)
	state["cabinet"]["history"].append({"type":"dismissed","ministry":ministry_id,"candidate":candidate_id,"turn":turn})
	state["politics"]["trust"] = clamp(float(state["politics"].get("trust", 0.5)) - 0.01, 0.0, 1.0)
	return {"success":true,"state":state,"events":[{
		"type":"minister_dismissed","message":"%s از %s برکنار شد" % [get_candidate_name(candidate_id), ministries[ministry_id].get("name_fa", "وزارتخانه")]
	}]}

# ── کابینهٔ زنده (عمق‌بخشی ۴۴) ──
# مأموریت ویژه در بحران: وزیرِ مرتبط با حوزهٔ بحران مأموریت می‌گیرد؛
# موفقیت به شایستگی/پاکدستی/انسجام بستگی دارد؛ شکست، اعتماد می‌سوزاند.

func can_mission(state: Dictionary, ministry_id: String) -> Dictionary:
	if not ministries.has(ministry_id):
		return {"valid":false,"reason":"وزارتخانه معتبر نیست"}
	state = ensure_state(state.duplicate(true))
	var cabinet: Dictionary = state["cabinet"]
	if not cabinet["active"].has(ministry_id):
		return {"valid":false,"reason":"این وزارتخانه وزیر فعال ندارد"}
	if int(cabinet.get("next_mission_turn", 0)) > int(state.get("tick", 0)):
		return {"valid":false,"reason":"کابینه در دورهٔ استراحت مأموریت است"}
	if float(state.get("policies", {}).get("political_capital", 0.0)) < 0.5:
		return {"valid":false,"reason":"سرمایه سیاسی کافی نیست"}
	return {"valid":true,"reason":""}

func assign_mission(state: Dictionary, ministry_id: String, turn: int) -> Dictionary:
	var check = can_mission(state, ministry_id)
	if not check.valid:
		return {"success":false,"reason":check.reason,"state":state,"events":[]}
	state = ensure_state(state)
	var cabinet: Dictionary = state["cabinet"]
	cabinet["missions"] = cabinet.get("missions", {})
	cabinet["missions"][ministry_id] = {"assigned_turn":turn}
	cabinet["next_mission_turn"] = turn + 6  # کولداون ۶ ماه پس از هر مأموریت
	state["cabinet"] = cabinet
	state["policies"]["political_capital"] = max(0.0, float(state["policies"].get("political_capital", 0.0)) - 0.5)
	var candidate_id = str(state["cabinet"]["active"].get(ministry_id, {}).get("candidate_id", ""))
	return {"success":true,"state":state,"events":[{
		"type":"minister_mission","ministry":ministry_id,
		"message":"🎯 به %s مأموریت ویژه برای مدیریت %s داده شد" % [get_candidate_name(candidate_id), ministries[ministry_id].get("name_fa", "وزارتخانه")]
	}]}

func mediate_dispute(state: Dictionary, turn: int) -> Dictionary:
	state = ensure_state(state)
	var cabinet: Dictionary = state["cabinet"]
	var disputes: Array = cabinet.get("disputes", [])
	if disputes.is_empty():
		return {"success":false,"reason":"درگیری فعالی در کابینه نیست","state":state,"events":[]}
	if float(state.get("policies", {}).get("political_capital", 0.0)) < 1.0:
		return {"success":false,"reason":"سرمایه سیاسی کافی برای میانجیگری نیست","state":state,"events":[]}
	state["policies"]["political_capital"] = max(0.0, float(state["policies"].get("political_capital", 0.0)) - 1.0)
	cabinet["cohesion"] = clampf(float(cabinet.get("cohesion", 0.65)) + 0.10, 0.0, 1.0)
	var names: Array = []
	for d in disputes:
		names.append("%s و %s" % [get_candidate_name(str(d.get("a", ""))), get_candidate_name(str(d.get("b", "")))])
	cabinet["disputes"] = []
	state["cabinet"] = cabinet
	return {"success":true,"state":state,"events":[{
		"type":"cabinet_mediation","message":"🤝 رهبر میان %s میانجیگری کرد؛ انسجام کابینه بهبود یافت" % "، ".join(names)
	}]}

func get_disputes(state: Dictionary) -> Array:
	state = ensure_state(state)
	return state["cabinet"].get("disputes", []).duplicate(true)

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure_state(state)
	var cabinet: Dictionary = state["cabinet"]
	var events: Array = []
	var loyalty_total = 0.0
	var active_count = 0
	var polarization = float(state.get("politicians_detail", {}).get("polarization", 0.4))
	for ministry_id in ordered_ids:
		if not cabinet["active"].has(ministry_id):
			cabinet["performance"][ministry_id] = 0.20
			_apply_vacancy_penalty(state, ministry_id)
			continue
		var record: Dictionary = cabinet["active"][ministry_id]
		var candidate_id = str(record.get("candidate_id", ""))
		var candidate: Dictionary = candidates.get(candidate_id, {})
		var competence = float(candidate.get("competence", 0.5))
		var integrity = float(candidate.get("integrity", 0.5))
		var loyalty = float(candidate.get("loyalty", 0.5))
		var experience = min(1.0, float(candidate.get("experience", 0.5)) + int(record.get("tenure_months", 0)) * 0.002)
		var cohesion_factor = clamp(1.0 - polarization * 0.35, 0.55, 1.0)
		var performance = clamp((competence * 0.45 + integrity * 0.25 + experience * 0.20 + loyalty * 0.10) * cohesion_factor, 0.15, 0.95)
		# مأموریت ویژه: عملکرد موقتاً تقویت/تضعیف می‌شود تا نتیجهٔ مأموریت در همین ماه مشخص شود
		var missions: Dictionary = cabinet.get("missions", {})
		if missions.has(ministry_id):
			var mission_chance := clampf(competence * 0.45 + integrity * 0.25 + float(cabinet.get("cohesion", 0.6)) * 0.30, 0.15, 0.90)
			missions.erase(ministry_id)
			if Deterministic.chance(mission_chance):
				performance = clamp(performance + 0.20, 0.15, 0.95)
				state["politics"]["trust"] = clamp(float(state["politics"].get("trust", 0.5)) + 0.015, 0.0, 1.0)
				events.append({"type":"minister_mission_success","ministry":ministry_id,"candidate":candidate_id,
					"message":"✅ مأموریت ویژهٔ %s در %s موفق بود؛ اعتماد عمومی افزایش یافت" % [get_candidate_name(candidate_id), ministries[ministry_id].get("name_fa", "وزارتخانه")]})
			else:
				performance = clamp(performance - 0.15, 0.15, 0.95)
				state["politics"]["trust"] = clamp(float(state["politics"].get("trust", 0.5)) - 0.02, 0.0, 1.0)
				state["politics"]["stability"] = clamp(float(state["politics"].get("stability", 0.5)) - 0.01, 0.05, 0.95)
				record["scandals"] = int(record.get("scandals", 0)) + 1
				events.append({"type":"minister_mission_failed","ministry":ministry_id,"candidate":candidate_id,
					"message":"❌ مأموریت ویژهٔ %s در %s شکست خورد؛ اعتماد عمومی آسیب دید" % [get_candidate_name(candidate_id), ministries[ministry_id].get("name_fa", "وزارتخانه")]})
			cabinet["missions"] = missions
		cabinet["performance"][ministry_id] = performance
		_apply_ministry_effects(state, ministries[ministry_id].get("effects", []), performance)
		record["tenure_months"] = int(record.get("tenure_months", 0)) + 1
		if integrity < 0.50 and Deterministic.chance((0.50 - integrity) * 0.18):
			record["scandals"] = int(record.get("scandals", 0)) + 1
			cabinet["scandal_count"] = int(cabinet.get("scandal_count", 0)) + 1
			state["politics"]["corruption"] = clamp(float(state["politics"].get("corruption", 0.3)) + 0.015, 0.0, 0.95)
			state["politics"]["trust"] = clamp(float(state["politics"].get("trust", 0.5)) - 0.025, 0.0, 1.0)
			events.append({"type":"minister_scandal","ministry":ministry_id,"candidate":candidate_id,"message":"رسوایی مالی %s در %s افشا شد" % [get_candidate_name(candidate_id), ministries[ministry_id].get("name_fa", "وزارتخانه")]})
		# ── چرخهٔ عمر وزیر (عمق‌بخشی ۴۴) ──
		var tenure := int(record.get("tenure_months", 0))
		var age := int(candidate.get("age", 55))
		var resilience := float(candidate.get("resilience", 0.6))
		var ambition := float(candidate.get("ambition", 0.4))
		var resigned := false
		var left_reason := ""
		if tenure > 36 and resilience < 0.55 and Deterministic.chance(0.03):
			resigned = true; left_reason = "فرسودگی پس از سه سال خدمت"
		elif ambition > 0.70 and tenure > 24 and Deterministic.chance(0.02):
			resigned = true; left_reason = "پذیرش فرصت بهتر در بخش خصوصی"
		elif age >= 70 and Deterministic.chance(0.004):
			resigned = true; left_reason = "درگذشت"
		elif age >= 62 and age < 70 and Deterministic.chance(0.001):
			resigned = true; left_reason = "درگذشت"
		if resigned:
			cabinet["active"].erase(ministry_id)
			cabinet["history"].append({"type":"left","ministry":ministry_id,"candidate":candidate_id,"turn":turn,"reason":left_reason})
			if left_reason == "درگذشت":
				events.append({"type":"minister_died","ministry":ministry_id,"candidate":candidate_id,
					"message":"🕊️ %s، وزیر %s، درگذشت؛ جایگاه او خالی مانده است" % [get_candidate_name(candidate_id), ministries[ministry_id].get("name_fa", "وزارتخانه")]})
			else:
				events.append({"type":"minister_resigned","ministry":ministry_id,"candidate":candidate_id,
					"message":"🚪 %s از وزارت %s کناره‌گیری کرد (%s)" % [get_candidate_name(candidate_id), ministries[ministry_id].get("name_fa", "وزارتخانه"), left_reason]})
			continue
		cabinet["active"][ministry_id] = record
		loyalty_total += loyalty
		active_count += 1
	# ── درگیری وزرا (ایدئولوژی متضاد) ──
	var disputes: Array = cabinet.get("disputes", [])
	if disputes.is_empty():
		var ideology_active := {}
		for ministry_id in ordered_ids:
			if not cabinet["active"].has(ministry_id):
				continue
			var cid := str(cabinet["active"][ministry_id].get("candidate_id", ""))
			var cand: Dictionary = candidates.get(cid, {})
			ideology_active[ministry_id] = str(cand.get("ideology", ""))
		var clash_pairs := {"محافظه‌کار":"اصلاح‌طلب", "اصلاح‌طلب":"محافظه‌کار", "پوپولیست":"تکنوکرات", "تکنوکرات":"پوپولیست"}
		for mid_a in ideology_active.keys():
			for mid_b in ideology_active.keys():
				if str(mid_a) >= str(mid_b):
					continue
				if str(clash_pairs.get(str(ideology_active[mid_a]), "")) == str(ideology_active[mid_b]) and Deterministic.chance(0.06):
					disputes.append({"a":str(cabinet["active"][mid_a].get("candidate_id","")),"b":str(cabinet["active"][mid_b].get("candidate_id","")),"since_turn":turn})
					events.append({"type":"cabinet_dispute","message":"⚡ اختلاف شدید میان %s و %s در کابینه؛ انسجام آسیب دید" % [get_candidate_name(str(cabinet["active"][mid_a].get("candidate_id",""))), get_candidate_name(str(cabinet["active"][mid_b].get("candidate_id","")))]})
					break
			if not disputes.is_empty():
				break
	else:
		# درگیری ادامه دارد: هر ماه انسجام کم‌تر
		cabinet["cohesion"] = clampf(float(cabinet.get("cohesion", 0.6)) - 0.03, 0.0, 1.0)
	cabinet["disputes"] = disputes
	cabinet["cohesion"] = clamp(loyalty_total / max(active_count, 1) * (1.0 - polarization * 0.25) - disputes.size() * 0.08, 0.0, 1.0)
	if cabinet["cohesion"] < 0.35:
		state["politics"]["stability"] = clamp(float(state["politics"].get("stability", 0.5)) - 0.01, 0.05, 0.95)
		if turn % 3 == 0:
			events.append({"type":"cabinet_disunity","message":"اختلاف شدید در کابینه اجرای سیاست‌ها را کند کرده است"})
	if turn % 3 == 0:
		events.append({"type":"cabinet_report","message":"گزارش فصلی عملکرد کابینه با انسجام %s٪ منتشر شد" % str(int(float(cabinet["cohesion"]) * 100.0))})
	while cabinet["history"].size() > 150:
		cabinet["history"].pop_front()
	state["cabinet"] = cabinet
	return {"state":state,"events":events}

func _apply_ministry_effects(state: Dictionary, effects: Array, performance: float):
	var factor = (performance - 0.50) * 2.0
	for effect in effects:
		_apply_path_delta(state, str(effect.get("path", "")), float(effect.get("value", 0.0)) * factor, effect)

func _apply_vacancy_penalty(state: Dictionary, ministry_id: String):
	for effect in ministries.get(ministry_id, {}).get("effects", []):
		_apply_path_delta(state, str(effect.get("path", "")), -abs(float(effect.get("value", 0.0))) * 0.35, effect)

func _apply_path_delta(state: Dictionary, path: String, delta: float, effect: Dictionary):
	var parts = path.split(".")
	var current = state
	for i in range(parts.size() - 1):
		if not current is Dictionary or not current.has(parts[i]):
			return
		current = current[parts[i]]
	var key = parts[-1]
	if not current is Dictionary or not current.has(key) or not (current[key] is int or current[key] is float):
		return
	var value = float(current[key]) + delta
	if effect.has("min"): value = max(value, float(effect["min"]))
	if effect.has("max"): value = min(value, float(effect["max"]))
	current[key] = value
