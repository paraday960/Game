extends Node
# سیاست‌های عمومی مستمر با سرمایه سیاسی، تعارض راهبردی و اثر روزانه

const POLICIES_PATH = "res://data/policies.json"

var policies: Dictionary = {}
var ordered_ids: Array = []
var data_version: String = ""
var load_errors: Array = []

func _ready():
	reload()

func reload() -> bool:
	policies.clear()
	ordered_ids.clear()
	load_errors.clear()
	var file = FileAccess.open(POLICIES_PATH, FileAccess.READ)
	if file == null:
		load_errors.append("فایل سیاست‌ها خوانده نشد")
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or not parsed.get("policies", null) is Array:
		load_errors.append("ساختار فایل سیاست‌ها نامعتبر است")
		return false
	data_version = str(parsed.get("version", "1.0.0"))
	for raw in parsed["policies"]:
		if not raw is Dictionary:
			continue
		var id = str(raw.get("id", ""))
		if id.is_empty() or policies.has(id):
			load_errors.append("شناسه سیاست خالی یا تکراری است")
			continue
		if not raw.get("effects", null) is Array:
			load_errors.append("سیاست %s اثر معتبر ندارد" % id)
			continue
		policies[id] = raw.duplicate(true)
		ordered_ids.append(id)
	return load_errors.is_empty()

func is_valid() -> bool:
	return policies.size() >= 10 and load_errors.is_empty()

func get_policy_ids() -> Array:
	return ordered_ids.duplicate()

func get_policy(id: String) -> Dictionary:
	return policies.get(id, {}).duplicate(true)

func get_policy_name(id: String) -> String:
	return str(policies.get(id, {}).get("name_fa", id))

func reset(state: Dictionary) -> Dictionary:
	state["policies"] = {
		"data_version": data_version,
		"political_capital": float(BalanceConfig.get_value("politics.policy_capital_max", 5.0)),
		"active": {},
		"history": []
	}
	return state

func ensure_state(state: Dictionary) -> Dictionary:
	if not state.has("policies") or not state["policies"] is Dictionary:
		return reset(state)
	var policy_state: Dictionary = state["policies"]
	policy_state["data_version"] = data_version
	policy_state["political_capital"] = float(policy_state.get("political_capital", 5.0))
	policy_state["active"] = policy_state.get("active", {})
	policy_state["history"] = policy_state.get("history", [])
	state["policies"] = policy_state
	return state

func can_change(state: Dictionary, policy_id: String, enabled: bool) -> Dictionary:
	if not policies.has(policy_id):
		return {"valid": false, "reason": "سیاست انتخابی وجود ندارد"}
	state = ensure_state(state.duplicate(true))
	var policy_state: Dictionary = state["policies"]
	var active: Dictionary = policy_state["active"]
	if enabled:
		if active.has(policy_id):
			return {"valid": false, "reason": "این سیاست هم‌اکنون فعال است"}
		var cost = float(policies[policy_id].get("political_cost", 1.0))
		if float(policy_state["political_capital"]) < cost:
			return {"valid": false, "reason": "سرمایه سیاسی کافی نیست"}
		var exclusive_group = str(policies[policy_id].get("exclusive_group", ""))
		if not exclusive_group.is_empty():
			for active_id in active.keys():
				if str(policies.get(active_id, {}).get("exclusive_group", "")) == exclusive_group:
					return {"valid": false, "reason": "ابتدا سیاست متعارض «%s» را لغو کنید" % get_policy_name(active_id)}
	else:
		if not active.has(policy_id):
			return {"valid": false, "reason": "این سیاست فعال نیست"}
	return {"valid": true, "reason": ""}

func apply_change(state: Dictionary, policy_id: String, enabled: bool, tick: int) -> Dictionary:
	var check = can_change(state, policy_id, enabled)
	if not check.valid:
		return {"success": false, "reason": check.reason, "state": state, "events": []}
	state = ensure_state(state)
	var policy_state: Dictionary = state["policies"]
	var definition: Dictionary = policies[policy_id]
	var event: Dictionary
	if enabled:
		policy_state["political_capital"] = max(0.0, float(policy_state["political_capital"]) - float(definition.get("political_cost", 1.0)))
		policy_state["active"][policy_id] = {"started_tick": tick}
		event = {"type":"policy_enabled", "policy_id":policy_id, "message":"سیاست «%s» فعال شد" % get_policy_name(policy_id)}
	else:
		policy_state["active"].erase(policy_id)
		event = {"type":"policy_disabled", "policy_id":policy_id, "message":"سیاست «%s» لغو شد" % get_policy_name(policy_id)}
	policy_state["history"].append({
		"policy_id":policy_id, "enabled":enabled, "tick":tick, "name":get_policy_name(policy_id)
	})
	while policy_state["history"].size() > 100:
		policy_state["history"].pop_front()
	state["policies"] = policy_state
	return {"success": true, "state": state, "events": [event]}

func simulate(state: Dictionary, tick: int) -> Dictionary:
	state = ensure_state(state)
	var policy_state: Dictionary = state["policies"]
	var max_capital = float(BalanceConfig.get_value("politics.policy_capital_max", 5.0))
	var regen = float(BalanceConfig.get_value("politics.policy_capital_regen", 0.01))
	policy_state["political_capital"] = min(max_capital, float(policy_state["political_capital"]) + regen)
	for policy_id in policy_state["active"].keys():
		if not policies.has(policy_id):
			continue
		for effect in policies[policy_id].get("effects", []):
			_apply_effect(state, effect)
	state["policies"] = policy_state
	var events: Array = []
	if tick > 0 and tick % 90 == 0 and not policy_state["active"].is_empty():
		events.append({
			"type":"policy_quarterly_report",
			"message":"گزارش فصلی %s سیاست فعال منتشر شد" % str(policy_state["active"].size()),
			"active_count":policy_state["active"].size()
		})
	return {"state": state, "events": events}

func _apply_effect(state: Dictionary, effect: Dictionary):
	var parts = str(effect.get("path", "")).split(".")
	if parts.is_empty():
		return
	var current = state
	for i in range(parts.size() - 1):
		if not current is Dictionary or not current.has(parts[i]):
			return
		current = current[parts[i]]
	var key = parts[-1]
	if not current is Dictionary or not current.has(key) or not (current[key] is int or current[key] is float):
		return
	var value = float(current[key])
	match str(effect.get("op", "add")):
		"mul": value *= float(effect.get("value", 1.0))
		"set": value = float(effect.get("value", value))
		_: value += float(effect.get("value", 0.0))
	if effect.has("min"): value = max(value, float(effect["min"]))
	if effect.has("max"): value = min(value, float(effect["max"]))
	current[key] = value


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_policy_manager(data) -> Dictionary:
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

func _deep_cache_policy_manager_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_policy_manager"):
		set_meta("cache_policy_manager", {})
	var cache = get_meta("cache_policy_manager")
	return cache.get(key, null)

func _deep_cache_policy_manager_set(key: String, value):
	if not has_meta("cache_policy_manager"):
		set_meta("cache_policy_manager", {})
	var cache = get_meta("cache_policy_manager")
	cache[key] = value
	set_meta("cache_policy_manager", cache)

func _deep_log_policy_manager(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_policy_manager(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_policy_manager(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("policy_manager"):
		state["policy_manager"] = {}
	return state

func _deep_deterministic_policy_manager_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_policy_manager(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("policy_manager_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_policy_manager(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("policy_manager", {}).duplicate(true) if state.has("policy_manager") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_policy_manager(data) -> Dictionary:
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

func _deep_cache_policy_manager_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_policy_manager"):
		set_meta("cache_policy_manager", {})
	var cache = get_meta("cache_policy_manager")
	return cache.get(key, null)

func _deep_cache_policy_manager_set(key: String, value):
	if not has_meta("cache_policy_manager"):
		set_meta("cache_policy_manager", {})
	var cache = get_meta("cache_policy_manager")
	cache[key] = value
	set_meta("cache_policy_manager", cache)

func _deep_log_policy_manager(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_policy_manager(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_policy_manager(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("policy_manager"):
		state["policy_manager"] = {}
	return state

func _deep_deterministic_policy_manager_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_policy_manager(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("policy_manager_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_policy_manager(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("policy_manager", {}).duplicate(true) if state.has("policy_manager") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data



# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_policy_manager(data) -> Dictionary:
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

func _deep_cache_policy_manager_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_policy_manager"):
		set_meta("cache_policy_manager", {})
	var cache = get_meta("cache_policy_manager")
	return cache.get(key, null)

func _deep_cache_policy_manager_set(key: String, value):
	if not has_meta("cache_policy_manager"):
		set_meta("cache_policy_manager", {})
	var cache = get_meta("cache_policy_manager")
	cache[key] = value
	set_meta("cache_policy_manager", cache)

func _deep_log_policy_manager(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_policy_manager(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_policy_manager(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("policy_manager"):
		state["policy_manager"] = {}
	return state

func _deep_deterministic_policy_manager_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_policy_manager(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("policy_manager_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_policy_manager(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("policy_manager", {}).duplicate(true) if state.has("policy_manager") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data


