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
		"scandal_count":0
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
		cabinet["performance"][ministry_id] = performance
		_apply_ministry_effects(state, ministries[ministry_id].get("effects", []), performance)
		record["tenure_months"] = int(record.get("tenure_months", 0)) + 1
		if integrity < 0.50 and Deterministic.chance((0.50 - integrity) * 0.18):
			record["scandals"] = int(record.get("scandals", 0)) + 1
			cabinet["scandal_count"] = int(cabinet.get("scandal_count", 0)) + 1
			state["politics"]["corruption"] = clamp(float(state["politics"].get("corruption", 0.3)) + 0.015, 0.0, 0.95)
			state["politics"]["trust"] = clamp(float(state["politics"].get("trust", 0.5)) - 0.025, 0.0, 1.0)
			events.append({"type":"minister_scandal","ministry":ministry_id,"candidate":candidate_id,"message":"رسوایی مالی %s در %s افشا شد" % [get_candidate_name(candidate_id), ministries[ministry_id].get("name_fa", "وزارتخانه")]})
		cabinet["active"][ministry_id] = record
		loyalty_total += loyalty
		active_count += 1
	cabinet["cohesion"] = clamp(loyalty_total / max(active_count, 1) * (1.0 - polarization * 0.25), 0.0, 1.0)
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


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_cabinet_manager(data) -> Dictionary:
	if not data is Dictionary:
		return {"valid": false, "reason": "داده دیکشنری نیست"}
	if data.is_empty():
		return {"valid": false, "reason": "داده خالی"}
	# بررسی NaN/Inf
	for k in data.keys():
		var v = data[k]
		if v is float and (is_nan(v) or is_inf(v)):
			return {"valid": false, "reason": "عدد نامتناهی در %s" % str(k)}
	return {"valid": true, "reason": ""}

func _deep_cache_cabinet_manager_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_cabinet_manager"):
		set_meta("cache_cabinet_manager", {})
	var cache = get_meta("cache_cabinet_manager")
	return cache.get(key, null)

func _deep_cache_cabinet_manager_set(key: String, value):
	if not has_meta("cache_cabinet_manager"):
		set_meta("cache_cabinet_manager", {})
	var cache = get_meta("cache_cabinet_manager")
	cache[key] = value
	set_meta("cache_cabinet_manager", cache)

func _deep_log_cabinet_manager(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_cabinet_manager(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_cabinet_manager(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("cabinet_manager"):
		state["cabinet_manager"] = {}
	return state

func _deep_deterministic_cabinet_manager_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_cabinet_manager(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("cabinet_manager_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_cabinet_manager(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("cabinet_manager", {}).duplicate(true) if state.has("cabinet_manager") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---
