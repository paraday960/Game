extends Node
# قوانین ملی: تصویب، لغو، اجرای اداری، حمایت عمومی، تعارض و نظارت قضایی

const DATA_PATH = "res://data/laws.json"
var laws: Dictionary = {}
var ordered_ids: Array = []
var data_version := ""
var load_errors: Array = []

func _ready():
	reload()

func reload() -> bool:
	laws.clear()
	ordered_ids.clear()
	load_errors.clear()
	var file = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		load_errors.append("فایل قوانین خوانده نشد")
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or not parsed.get("laws", null) is Array:
		load_errors.append("ساختار قوانین نامعتبر است")
		return false
	data_version = str(parsed.get("version", "1.0.0"))
	for raw in parsed["laws"]:
		if not raw is Dictionary:
			continue
		var id = str(raw.get("id", ""))
		if id.is_empty() or laws.has(id):
			load_errors.append("شناسه قانون خالی یا تکراری است")
			continue
		laws[id] = raw.duplicate(true)
		ordered_ids.append(id)
	return load_errors.is_empty()

func is_valid() -> bool:
	return laws.size() >= 12 and load_errors.is_empty()

func get_law_ids() -> Array:
	return ordered_ids.duplicate()

func get_law(id: String) -> Dictionary:
	return laws.get(id, {}).duplicate(true)

func get_law_name(id: String) -> String:
	return str(laws.get(id, {}).get("name_fa", id))

func reset(state: Dictionary) -> Dictionary:
	state["legislation"] = {
		"data_version":data_version,
		"enacted":{},
		"repealed":[],
		"history":[],
		"average_support":0.60,
		"legal_challenges":0
	}
	return state

func ensure_state(state: Dictionary) -> Dictionary:
	if not state.has("legislation") or not state["legislation"] is Dictionary:
		return reset(state)
	var legislation: Dictionary = state["legislation"]
	legislation["enacted"] = legislation.get("enacted", {})
	legislation["repealed"] = legislation.get("repealed", [])
	legislation["history"] = legislation.get("history", [])
	legislation["average_support"] = float(legislation.get("average_support", 0.60))
	legislation["legal_challenges"] = int(legislation.get("legal_challenges", 0))
	state["legislation"] = legislation
	return state

func can_enact(state: Dictionary, id: String) -> Dictionary:
	if not laws.has(id):
		return {"valid":false,"reason":"قانون انتخابی وجود ندارد"}
	state = ensure_state(state.duplicate(true))
	var legislation: Dictionary = state["legislation"]
	if legislation["enacted"].has(id):
		return {"valid":false,"reason":"این قانون هم‌اکنون برقرار است"}
	var cost = float(laws[id].get("political_cost", 1.0))
	if float(state.get("policies", {}).get("political_capital", 0.0)) < cost:
		return {"valid":false,"reason":"سرمایه سیاسی کافی برای تصویب وجود ندارد"}
	for prerequisite in laws[id].get("prerequisites", []):
		if not state.get("technology", {}).get("unlocked", []).has(prerequisite):
			return {"valid":false,"reason":"فناوری پیش‌نیاز «%s» باز نشده است" % TechnologyManager.get_technology_name(prerequisite)}
	var group = str(laws[id].get("exclusive_group", ""))
	if not group.is_empty():
		for active_id in legislation["enacted"].keys():
			if str(laws.get(active_id, {}).get("exclusive_group", "")) == group:
				return {"valid":false,"reason":"قانون متعارض «%s» ابتدا باید لغو شود" % get_law_name(active_id)}
	return {"valid":true,"reason":""}

func enact(state: Dictionary, id: String, turn: int) -> Dictionary:
	var check = can_enact(state, id)
	if not check.valid:
		return {"success":false,"reason":check.reason,"state":state,"events":[]}
	state = ensure_state(state)
	var legislation: Dictionary = state["legislation"]
	legislation["enacted"][id] = {
		"enacted_turn":turn,"implementation":0.0,"support":float(laws[id].get("public_support",0.6)),
		"challenges":0,"fully_implemented":false
	}
	legislation["history"].append({"type":"enacted","id":id,"turn":turn})
	state["policies"]["political_capital"] = max(0.0, float(state["policies"].get("political_capital", 0.0)) - float(laws[id].get("political_cost", 1.0)))
	state["legislation"] = legislation
	return {"success":true,"state":state,"events":[{"type":"law_enacted","law_id":id,"message":"قانون «%s» تصویب شد و وارد مرحله اجرا گردید" % get_law_name(id)}]}

func repeal(state: Dictionary, id: String, turn: int) -> Dictionary:
	state = ensure_state(state)
	if not state["legislation"]["enacted"].has(id):
		return {"success":false,"reason":"این قانون برقرار نیست","state":state,"events":[]}
	if float(state.get("policies", {}).get("political_capital", 0.0)) < 0.25:
		return {"success":false,"reason":"سرمایه سیاسی کافی برای لغو وجود ندارد","state":state,"events":[]}
	var record = state["legislation"]["enacted"][id].duplicate(true)
	record["id"] = id
	record["repealed_turn"] = turn
	state["legislation"]["repealed"].append(record)
	state["legislation"]["enacted"].erase(id)
	state["legislation"]["history"].append({"type":"repealed","id":id,"turn":turn})
	state["policies"]["political_capital"] = max(0.0, float(state["policies"]["political_capital"]) - 0.25)
	state["politics"]["trust"] = clamp(float(state["politics"].get("trust",0.5)) - 0.005,0,1)
	return {"success":true,"state":state,"events":[{"type":"law_repealed","law_id":id,"message":"قانون «%s» لغو شد" % get_law_name(id)}]}

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure_state(state)
	var legislation: Dictionary = state["legislation"]
	var events: Array = []
	var admin = float(state.get("administration", {}).get("efficiency", 0.55))
	var judicial_efficiency = float(state.get("judicial", {}).get("efficiency", 0.55))
	var judicial_independence = float(state.get("judicial", {}).get("independence", 0.5))
	var corruption = float(state.get("politics", {}).get("corruption", 0.3))
	var happiness = float(state.get("population", {}).get("happiness", 0.5))
	var trust = float(state.get("politics", {}).get("trust", 0.5))
	var support_total = 0.0
	for id in legislation["enacted"].keys():
		if not laws.has(id):
			continue
		var record: Dictionary = legislation["enacted"][id]
		var definition: Dictionary = laws[id]
		var support = clamp(float(definition.get("public_support",0.6)) * 0.60 + happiness * 0.20 + trust * 0.20, 0.05, 0.95)
		record["support"] = support
		var implementation_gain = clamp(0.025 + admin * 0.045 + judicial_efficiency * 0.020 - corruption * 0.025, 0.01, 0.09)
		var controversy = float(definition.get("controversy",0.4))
		if Deterministic.chance(controversy * judicial_independence * 0.025):
			record["challenges"] = int(record.get("challenges",0)) + 1
			legislation["legal_challenges"] = int(legislation.get("legal_challenges",0)) + 1
			implementation_gain *= 0.40
			events.append({"type":"law_challenged","law_id":id,"message":"اجرای قانون «%s» با چالش قضایی و تأخیر روبه‌رو شد" % get_law_name(id)})
		record["implementation"] = clamp(float(record.get("implementation",0.0)) + implementation_gain, 0.0, 1.0)
		_apply_effects(state, definition.get("effects", []), float(record["implementation"]))
		if float(record["implementation"]) >= 1.0 and not record.get("fully_implemented",false):
			record["fully_implemented"] = true
			events.append({"type":"law_fully_implemented","law_id":id,"message":"قانون «%s» به اجرای کامل رسید" % get_law_name(id)})
		if support < 0.35:
			state["politics"]["tension"] = clamp(float(state["politics"].get("tension",0.3)) + 0.004,0,1)
			if turn % 3 == 0:
				events.append({"type":"law_public_opposition","law_id":id,"message":"مخالفت عمومی با قانون «%s» افزایش یافته است" % get_law_name(id)})
		legislation["enacted"][id] = record
		support_total += support
	legislation["average_support"] = support_total / max(legislation["enacted"].size(),1)
	while legislation["history"].size() > 150:
		legislation["history"].pop_front()
	state["legislation"] = legislation
	return {"state":state,"events":events}

func _apply_effects(state: Dictionary, effects: Array, implementation: float):
	for effect in effects:
		var parts = str(effect.get("path","")).split(".")
		var current = state
		var valid = true
		for i in range(parts.size()-1):
			if not current is Dictionary or not current.has(parts[i]): valid=false; break
			current=current[parts[i]]
		if not valid: continue
		var key=parts[-1]
		if not current is Dictionary or not current.has(key) or not (current[key] is int or current[key] is float): continue
		var value=float(current[key])+float(effect.get("value",0.0))*implementation
		if effect.has("min"): value=max(value,float(effect["min"]))
		if effect.has("max"): value=min(value,float(effect["max"]))
		current[key]=value


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_law_manager(data) -> Dictionary:
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

func _deep_cache_law_manager_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_law_manager"):
		set_meta("cache_law_manager", {})
	var cache = get_meta("cache_law_manager")
	return cache.get(key, null)

func _deep_cache_law_manager_set(key: String, value):
	if not has_meta("cache_law_manager"):
		set_meta("cache_law_manager", {})
	var cache = get_meta("cache_law_manager")
	cache[key] = value
	set_meta("cache_law_manager", cache)

func _deep_log_law_manager(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_law_manager(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_law_manager(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("law_manager"):
		state["law_manager"] = {}
	return state

func _deep_deterministic_law_manager_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_law_manager(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("law_manager_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_law_manager(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("law_manager", {}).duplicate(true) if state.has("law_manager") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_law_manager(data) -> Dictionary:
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

func _deep_cache_law_manager_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_law_manager"):
		set_meta("cache_law_manager", {})
	var cache = get_meta("cache_law_manager")
	return cache.get(key, null)

func _deep_cache_law_manager_set(key: String, value):
	if not has_meta("cache_law_manager"):
		set_meta("cache_law_manager", {})
	var cache = get_meta("cache_law_manager")
	cache[key] = value
	set_meta("cache_law_manager", cache)

func _deep_log_law_manager(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_law_manager(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_law_manager(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("law_manager"):
		state["law_manager"] = {}
	return state

func _deep_deterministic_law_manager_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_law_manager(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("law_manager_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_law_manager(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("law_manager", {}).duplicate(true) if state.has("law_manager") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data


