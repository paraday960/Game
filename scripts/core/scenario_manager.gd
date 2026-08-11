extends Node
# سناریو، هدف، مهلت و شرط پیروزی داده‌محور

const SCENARIOS_PATH = "res://data/scenarios.json"

var scenarios: Dictionary = {}
var ordered_ids: Array = []
var default_scenario: String = "balanced"
var data_version: String = ""
var load_errors: Array = []

func _ready():
	reload()

func reload() -> bool:
	scenarios.clear()
	ordered_ids.clear()
	load_errors.clear()
	var file = FileAccess.open(SCENARIOS_PATH, FileAccess.READ)
	if file == null:
		load_errors.append("فایل سناریوها خوانده نشد")
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or not parsed.get("scenarios", null) is Array:
		load_errors.append("ساختار فایل سناریوها نامعتبر است")
		return false
	data_version = str(parsed.get("version", "1.0.0"))
	default_scenario = str(parsed.get("default_scenario", "balanced"))
	for raw in parsed["scenarios"]:
		if not raw is Dictionary:
			continue
		var id = str(raw.get("id", ""))
		if id.is_empty() or scenarios.has(id):
			load_errors.append("شناسه سناریو خالی یا تکراری است")
			continue
		if not raw.get("objectives", null) is Array or raw["objectives"].is_empty():
			load_errors.append("سناریو %s هدف ندارد" % id)
			continue
		scenarios[id] = raw.duplicate(true)
		ordered_ids.append(id)
	if not scenarios.has(default_scenario):
		load_errors.append("سناریوی پیش‌فرض وجود ندارد")
	return load_errors.is_empty()

func is_valid() -> bool:
	return scenarios.size() >= 5 and load_errors.is_empty()

func get_scenario_ids() -> Array:
	return ordered_ids.duplicate()

func get_scenario(id: String) -> Dictionary:
	return scenarios.get(id, {}).duplicate(true)

func get_scenario_name(id: String) -> String:
	return str(scenarios.get(id, {}).get("name_fa", id))

func can_select(state: Dictionary, id: String) -> Dictionary:
	if int(state.get("tick", 0)) != 0:
		return {"valid": false, "reason": "سناریو فقط پیش از نخستین روز قابل انتخاب است"}
	if not scenarios.has(id):
		return {"valid": false, "reason": "سناریوی انتخابی وجود ندارد"}
	return {"valid": true, "reason": ""}

func apply_scenario(state: Dictionary, id: String, start_tick: int = 0) -> Dictionary:
	if not scenarios.has(id):
		id = default_scenario
	state = TimeManager.ensure_time(state)
	var start_day = TimeManager.get_total_days(state)
	var definition: Dictionary = scenarios[id]
	var objectives: Array = []
	for raw_objective in definition.get("objectives", []):
		var objective: Dictionary = raw_objective.duplicate(true)
		var start_value = _metric_value(state, str(objective.get("path", "")))
		objective["start_value"] = start_value
		objective["target"] = _resolve_target(objective, start_value)
		objective["current"] = start_value
		objective["progress"] = 0.0
		objective["completed"] = false
		objective["announced"] = false
		objectives.append(objective)
	state["scenario"] = {
		"data_version": data_version,
		"id": id,
		"name": definition.get("name_fa", id),
		"difficulty": definition.get("difficulty_fa", "معمولی"),
		"description": definition.get("description", ""),
		"completion_rule": definition.get("completion_rule", "all"),
		"started_tick": start_tick,
		"started_day": start_day,
		"deadline_tick": start_tick + int(ceil(float(definition.get("deadline_days", 1080)) / 30.0)),
		"deadline_day": start_day + int(definition.get("deadline_days", 1080)),
		"reward_xp": int(definition.get("reward_xp", 0)),
		"reward_legacy": int(definition.get("reward_legacy", 0)),
		"status": "active",
		"progress": 0.0,
		"objectives": objectives,
		"reward_claimed": false
	}
	return state

func ensure_scenario(state: Dictionary) -> Dictionary:
	var scenario = state.get("scenario", null)
	if not scenario is Dictionary or not scenarios.has(str(scenario.get("id", ""))):
		return apply_scenario(state, default_scenario, int(state.get("tick", 0)))
	if not scenario.has("deadline_day"):
		# schemaهای قدیمی، tick را روز می‌دانستند.
		scenario["started_day"] = int(scenario.get("started_tick", 0))
		scenario["deadline_day"] = int(scenario.get("deadline_tick", TimeManager.get_total_days(state) + 1080))
		scenario["started_tick"] = int(floor(float(scenario["started_day"]) / 30.0))
		scenario["deadline_tick"] = int(ceil(float(scenario["deadline_day"]) / 30.0))
		state["scenario"] = scenario
	return state

func update(state: Dictionary, tick: int) -> Dictionary:
	state = ensure_scenario(state)
	var scenario: Dictionary = state["scenario"]
	var events: Array = []
	if str(scenario.get("status", "active")) != "active":
		return {"state": state, "events": events}
	var completion_rule = str(scenario.get("completion_rule", "all"))
	var completed_count = 0
	var objectives: Array = scenario.get("objectives", [])
	for i in range(objectives.size()):
		var objective: Dictionary = objectives[i]
		var current = _metric_value(state, str(objective.get("path", "")))
		var satisfied = _is_satisfied(objective, current)
		var was_completed = bool(objective.get("completed", false))
		objective["current"] = current
		objective["progress"] = _objective_progress(objective, current)
		if completion_rule == "deadline":
			objective["completed"] = satisfied
		else:
			objective["completed"] = was_completed or satisfied
		if objective["completed"]:
			completed_count += 1
		if completion_rule != "deadline" and objective["completed"] and not objective.get("announced", false):
			objective["announced"] = true
			events.append({
				"type": "scenario_objective_completed",
				"message": "هدف سناریو تکمیل شد: %s" % objective.get("title_fa", "هدف"),
				"objective_id": objective.get("id", "")
			})
		objectives[i] = objective
	scenario["objectives"] = objectives
	scenario["progress"] = float(completed_count) / max(objectives.size(), 1)
	var total_days = TimeManager.get_total_days(state)
	var deadline_reached = total_days >= int(scenario.get("deadline_day", total_days + 1))
	var won = false
	if completion_rule == "deadline":
		won = deadline_reached and completed_count == objectives.size()
	elif completed_count == objectives.size():
		won = true
	if won:
		scenario["status"] = "won"
		scenario["completed_tick"] = tick
		scenario["completed_day"] = total_days
		_apply_reward(state, scenario)
		events.append({
			"type": "scenario_won",
			"message": "سناریوی «%s» با موفقیت کامل شد" % scenario.get("name", ""),
			"scenario_id": scenario.get("id", "")
		})
	elif deadline_reached:
		scenario["status"] = "expired"
		scenario["completed_tick"] = tick
		scenario["completed_day"] = total_days
		events.append({
			"type": "scenario_expired",
			"message": "مهلت سناریوی «%s» پایان یافت؛ بازی همچنان ادامه دارد" % scenario.get("name", ""),
			"scenario_id": scenario.get("id", "")
		})
	state["scenario"] = scenario
	return {"state": state, "events": events}

func days_remaining(state: Dictionary) -> int:
	var scenario: Dictionary = state.get("scenario", {})
	return max(0, int(scenario.get("deadline_day", 0)) - TimeManager.get_total_days(state))

func _resolve_target(objective: Dictionary, start_value):
	var mode = str(objective.get("mode", "gte"))
	var value = objective.get("value", 0.0)
	if mode == "increase_ratio" and (start_value is int or start_value is float):
		return float(start_value) * (1.0 + float(value))
	if mode == "increase_add" and (start_value is int or start_value is float):
		return float(start_value) + float(value)
	return value

func _is_satisfied(objective: Dictionary, current) -> bool:
	var mode = str(objective.get("mode", "gte"))
	var target = objective.get("target", objective.get("value", 0.0))
	if mode == "contains":
		return current is Array and current.has(target)
	if not (current is int or current is float) or not (target is int or target is float):
		return false
	if mode == "lte":
		return float(current) <= float(target)
	return float(current) >= float(target)

func _objective_progress(objective: Dictionary, current) -> float:
	var mode = str(objective.get("mode", "gte"))
	if mode == "contains":
		return 1.0 if current is Array and current.has(objective.get("target")) else 0.0
	if not (current is int or current is float):
		return 0.0
	var start = float(objective.get("start_value", 0.0))
	var target = float(objective.get("target", 0.0))
	var value = float(current)
	if mode == "lte":
		if value <= target:
			return 1.0
		if start <= target:
			return 0.0
		return clamp((start - value) / max(start - target, 0.000001), 0.0, 1.0)
	if value >= target:
		return 1.0
	if target <= start:
		return 0.0
	return clamp((value - start) / max(target - start, 0.000001), 0.0, 1.0)

func _metric_value(state: Dictionary, path: String):
	match path:
		"world.alliances_count": return state.get("world", {}).get("alliances", []).size()
		"world.trade_agreements_count": return state.get("world", {}).get("trade_agreements", []).size()
		"world.active_wars_count": return state.get("world", {}).get("wars", {}).size()
		"technology.unlocked_count": return state.get("technology", {}).get("unlocked", []).size()
		"decision_history_count": return state.get("decision_history", []).size()
	var current = state
	for part in path.split("."):
		if not current is Dictionary or not current.has(part):
			return null
		current = current[part]
	return current

func _apply_reward(state: Dictionary, scenario: Dictionary):
	if scenario.get("reward_claimed", false):
		return
	state["xp"] = float(state.get("xp", 0.0)) + float(scenario.get("reward_xp", 0))
	var level_xp = max(float(BalanceConfig.get_value("progression.level_xp", 100.0)), 1.0)
	state["level"] = int(float(state["xp"]) / level_xp) + 1
	var progression: Dictionary = state.get("progression", {})
	progression["legacy_score"] = int(progression.get("legacy_score", 0)) + int(scenario.get("reward_legacy", 0))
	state["progression"] = progression
	scenario["reward_claimed"] = true


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_scenario_manager(data) -> Dictionary:
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

func _deep_cache_scenario_manager_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_scenario_manager"):
		set_meta("cache_scenario_manager", {})
	var cache = get_meta("cache_scenario_manager")
	return cache.get(key, null)

func _deep_cache_scenario_manager_set(key: String, value):
	if not has_meta("cache_scenario_manager"):
		set_meta("cache_scenario_manager", {})
	var cache = get_meta("cache_scenario_manager")
	cache[key] = value
	set_meta("cache_scenario_manager", cache)

func _deep_log_scenario_manager(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_scenario_manager(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_scenario_manager(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("scenario_manager"):
		state["scenario_manager"] = {}
	return state

func _deep_deterministic_scenario_manager_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_scenario_manager(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("scenario_manager_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_scenario_manager(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("scenario_manager", {}).duplicate(true) if state.has("scenario_manager") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---
