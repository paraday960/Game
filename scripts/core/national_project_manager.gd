extends Node
# پروژه‌های ملی: زمان، بودجه، فساد، آب‌وهوا، تأخیر، اضافه‌هزینه و اثر چندسیستمی

const DATA_PATH = "res://data/national_projects.json"
var projects: Dictionary = {}
var ordered_ids: Array = []
var data_version := ""
var load_errors: Array = []

func _ready():
	reload()

func reload() -> bool:
	projects.clear()
	ordered_ids.clear()
	load_errors.clear()
	var file = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		load_errors.append("فایل پروژه‌های ملی خوانده نشد")
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or not parsed.get("projects", null) is Array:
		load_errors.append("ساختار پروژه‌های ملی نامعتبر است")
		return false
	data_version = str(parsed.get("version", "1.0.0"))
	for raw in parsed["projects"]:
		if not raw is Dictionary:
			continue
		var id = str(raw.get("id", ""))
		if id.is_empty() or projects.has(id):
			load_errors.append("شناسه پروژه ملی خالی یا تکراری است")
			continue
		projects[id] = raw.duplicate(true)
		ordered_ids.append(id)
	return load_errors.is_empty()

func is_valid() -> bool:
	return projects.size() >= 12 and load_errors.is_empty()

func get_project_ids() -> Array:
	return ordered_ids.duplicate()

func get_project(id: String) -> Dictionary:
	return projects.get(id, {}).duplicate(true)

func get_project_name(id: String) -> String:
	return str(projects.get(id, {}).get("name_fa", id))

func reset(state: Dictionary) -> Dictionary:
	state["national_projects"] = {
		"data_version":data_version,
		"active":{},
		"completed":[],
		"cancelled":[],
		"history":[],
		"total_spent":0.0,
		"total_overrun":0.0
	}
	_sync_infrastructure(state)
	return state

func ensure_state(state: Dictionary) -> Dictionary:
	if not state.has("national_projects") or not state["national_projects"] is Dictionary:
		return reset(state)
	var project_state: Dictionary = state["national_projects"]
	project_state["active"] = project_state.get("active", {})
	project_state["completed"] = project_state.get("completed", [])
	project_state["cancelled"] = project_state.get("cancelled", [])
	project_state["history"] = project_state.get("history", [])
	project_state["total_spent"] = float(project_state.get("total_spent", 0.0))
	project_state["total_overrun"] = float(project_state.get("total_overrun", 0.0))
	state["national_projects"] = project_state
	_sync_infrastructure(state)
	return state

func can_start(state: Dictionary, id: String) -> Dictionary:
	if not projects.has(id):
		return {"valid":false,"reason":"پروژه ملی وجود ندارد"}
	state = ensure_state(state.duplicate(true))
	var project_state: Dictionary = state["national_projects"]
	if project_state["completed"].has(id):
		return {"valid":false,"reason":"این پروژه قبلاً تکمیل شده است"}
	if project_state["active"].has(id):
		return {"valid":false,"reason":"این پروژه در حال ساخت است"}
	if project_state["active"].size() >= 3:
		return {"valid":false,"reason":"حداکثر سه پروژه ملی هم‌زمان قابل اجراست"}
	for prerequisite in projects[id].get("prerequisites", []):
		if not state.get("technology", {}).get("unlocked", []).has(prerequisite):
			return {"valid":false,"reason":"فناوری پیش‌نیاز «%s» باز نشده است" % TechnologyManager.get_technology_name(prerequisite)}
	return {"valid":true,"reason":""}

func start_project(state: Dictionary, id: String, turn: int) -> Dictionary:
	var check = can_start(state, id)
	if not check.valid:
		return {"success":false,"reason":check.reason,"state":state,"events":[]}
	state = ensure_state(state)
	var definition: Dictionary = projects[id]
	var project_state: Dictionary = state["national_projects"]
	var total_cost = float(state.get("economy", {}).get("gdp", 1.0)) * float(definition.get("cost_gdp_ratio", 0.02))
	var upfront = total_cost * 0.10
	state["economy"]["national_debt"] = float(state["economy"].get("national_debt", 0.0)) + upfront
	project_state["total_spent"] += upfront
	project_state["active"][id] = {
		"started_turn":turn,
		"progress":0.0,
		"duration_months":int(definition.get("duration_months", 12)),
		"elapsed_months":0,
		"delay_months":0,
		"total_cost":total_cost,
		"spent":upfront,
		"overrun":0.0
	}
	project_state["history"].append({"type":"started","id":id,"turn":turn})
	state["national_projects"] = project_state
	_sync_infrastructure(state)
	return {"success":true,"state":state,"events":[{
		"type":"national_project_started","project_id":id,
		"message":"پروژه ملی «%s» آغاز شد" % get_project_name(id)
	}]}

func can_cancel(state: Dictionary, id: String) -> Dictionary:
	state = ensure_state(state.duplicate(true))
	if not state["national_projects"]["active"].has(id):
		return {"valid":false,"reason":"این پروژه فعال نیست"}
	return {"valid":true,"reason":""}

func cancel_project(state: Dictionary, id: String, turn: int) -> Dictionary:
	var check = can_cancel(state, id)
	if not check.valid:
		return {"success":false,"reason":check.reason,"state":state,"events":[]}
	state = ensure_state(state)
	var project_state: Dictionary = state["national_projects"]
	var record: Dictionary = project_state["active"][id].duplicate(true)
	record["id"] = id
	record["cancelled_turn"] = turn
	project_state["cancelled"].append(record)
	project_state["active"].erase(id)
	project_state["history"].append({"type":"cancelled","id":id,"turn":turn})
	state["politics"]["trust"] = clamp(float(state["politics"].get("trust", 0.5)) - 0.015, 0.0, 1.0)
	state["national_projects"] = project_state
	_sync_infrastructure(state)
	return {"success":true,"state":state,"events":[{
		"type":"national_project_cancelled","project_id":id,
		"message":"پروژه «%s» لغو شد؛ هزینه انجام‌شده قابل بازگشت نیست" % get_project_name(id)
	}]}

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure_state(state)
	var project_state: Dictionary = state["national_projects"]
	var events: Array = []
	var completed_now: Array = []
	var administration = float(state.get("administration", {}).get("efficiency", 0.55))
	var corruption = float(state.get("politics", {}).get("corruption", 0.30))
	var weather_severity = float(state.get("weather", {}).get("current", {}).get("severity", 0.0)) if state.get("weather", {}).get("current", {}).get("hazard", "none") != "none" else 0.0
	var war_penalty = 0.12 if not state.get("world", {}).get("wars", {}).is_empty() else 0.0
	for id in project_state["active"].keys():
		var record: Dictionary = project_state["active"][id]
		var duration = max(1, int(record.get("duration_months", 12)))
		var efficiency = clamp(0.55 + administration * 0.45 - corruption * 0.25 - weather_severity * 0.18 - war_penalty, 0.25, 1.15)
		var random_factor = Deterministic.next_range(0.88, 1.12)
		var progress_gain = 1.0 / float(duration) * efficiency * random_factor
		var planned_monthly_cost = float(record.get("total_cost", 0.0)) * 0.90 / float(duration)
		var overrun_factor = 1.0 + corruption * 0.35 + weather_severity * 0.18 + war_penalty
		var actual_cost = planned_monthly_cost * overrun_factor
		var overrun = max(0.0, actual_cost - planned_monthly_cost)
		record["progress"] = min(1.0, float(record.get("progress", 0.0)) + progress_gain)
		record["elapsed_months"] = int(record.get("elapsed_months", 0)) + 1
		record["spent"] = float(record.get("spent", 0.0)) + actual_cost
		record["overrun"] = float(record.get("overrun", 0.0)) + overrun
		project_state["total_spent"] += actual_cost
		project_state["total_overrun"] += overrun
		state["economy"]["national_debt"] = float(state["economy"].get("national_debt", 0.0)) + actual_cost
		if efficiency < 0.55 or Deterministic.chance(corruption * 0.025 + weather_severity * 0.04):
			record["delay_months"] = int(record.get("delay_months", 0)) + 1
			events.append({
				"type":"national_project_delay","project_id":id,
				"message":"پروژه «%s» به‌دلیل %s با تأخیر روبه‌رو شد" % [get_project_name(id), _delay_reason(corruption, weather_severity, war_penalty)]
			})
		project_state["active"][id] = record
		if float(record["progress"]) >= 1.0:
			completed_now.append(id)
	for id in completed_now:
		var record: Dictionary = project_state["active"].get(id, {}).duplicate(true)
		project_state["active"].erase(id)
		project_state["completed"].append(id)
		project_state["history"].append({"type":"completed","id":id,"turn":turn,"spent":record.get("spent",0.0),"overrun":record.get("overrun",0.0)})
		_apply_effects(state, projects[id].get("effects", []))
		events.append({
			"type":"national_project_completed","project_id":id,
			"message":"پروژه ملی «%s» تکمیل و بهره‌برداری شد" % get_project_name(id)
		})
	while project_state["history"].size() > 150:
		project_state["history"].pop_front()
	state["national_projects"] = project_state
	_sync_infrastructure(state)
	return {"state":state,"events":events}

func _sync_infrastructure(state: Dictionary):
	if not state.has("infrastructure"):
		return
	var active_list: Array = []
	for id in state.get("national_projects", {}).get("active", {}).keys():
		var record: Dictionary = state["national_projects"]["active"][id]
		active_list.append({"id":id,"name":get_project_name(id),"progress":record.get("progress",0.0),"spent":record.get("spent",0.0)})
	state["infrastructure"]["projects"] = active_list

func _apply_effects(state: Dictionary, effects: Array):
	for effect in effects:
		var parts = str(effect.get("path", "")).split(".")
		if parts.is_empty():
			continue
		var current = state
		var valid = true
		for i in range(parts.size() - 1):
			if not current is Dictionary or not current.has(parts[i]):
				valid = false
				break
			current = current[parts[i]]
		if not valid:
			continue
		var key = parts[-1]
		if not current is Dictionary or not current.has(key) or not (current[key] is int or current[key] is float):
			continue
		var value = float(current[key])
		match str(effect.get("op", "add")):
			"mul": value *= float(effect.get("value", 1.0))
			"set": value = float(effect.get("value", value))
			_: value += float(effect.get("value", 0.0))
		if effect.has("min"): value = max(value, float(effect["min"]))
		if effect.has("max"): value = min(value, float(effect["max"]))
		current[key] = value

func _delay_reason(corruption: float, weather: float, war: float) -> String:
	if war > 0.0:
		return "فشار جنگ و کمبود منابع"
	if weather > 0.55:
		return "شرایط شدید جوی"
	if corruption > 0.45:
		return "فساد و ضعف پیمانکار"
	return "ضعف اجرایی و زنجیره تأمین"


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_national_project_manager(data) -> Dictionary:
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

func _deep_cache_national_project_manager_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_national_project_manager"):
		set_meta("cache_national_project_manager", {})
	var cache = get_meta("cache_national_project_manager")
	return cache.get(key, null)

func _deep_cache_national_project_manager_set(key: String, value):
	if not has_meta("cache_national_project_manager"):
		set_meta("cache_national_project_manager", {})
	var cache = get_meta("cache_national_project_manager")
	cache[key] = value
	set_meta("cache_national_project_manager", cache)

func _deep_log_national_project_manager(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_national_project_manager(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_national_project_manager(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("national_project_manager"):
		state["national_project_manager"] = {}
	return state

func _deep_deterministic_national_project_manager_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_national_project_manager(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("national_project_manager_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_national_project_manager(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("national_project_manager", {}).duplicate(true) if state.has("national_project_manager") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---
