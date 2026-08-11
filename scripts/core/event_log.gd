extends Node
# Event Sourcing + CQRS - بخش ۳.۷ لایه ۵
# گزارش تغییرناپذیر برای ممیزی، بازپخش، ضدتقلب
# رویدادهای هر تیک ابتدا در تراکنش نگه داشته می‌شوند و فقط پس از Commit منتشر می‌شوند.

var events: Array = []
var max_events: int = 10000
var _transaction_events: Array = []
var _transaction_active: bool = false

signal event_added(event)

func _ready():
	events = []
	_transaction_events = []
	_transaction_active = false

func begin_transaction() -> bool:
	if _transaction_active:
		return false
	_transaction_events = []
	_transaction_active = true
	return true

func commit_transaction() -> Array:
	if not _transaction_active:
		return []
	var committed: Array = []
	for pending in _transaction_events:
		var evt = pending.duplicate(true)
		evt["id"] = _next_event_id()
		events.append(evt)
		committed.append(evt)
		_trim_to_limit()
		emit_signal("event_added", evt)
	_transaction_events = []
	_transaction_active = false
	return committed

func rollback_transaction():
	_transaction_events = []
	_transaction_active = false

func is_transaction_active() -> bool:
	return _transaction_active

func log_event(type: String, data: Dictionary, tick: int = -1, version: int = -1):
	var evt = {
		"id": -1 if _transaction_active else _next_event_id(),
		"type": type,
		"data": data.duplicate(true),
		"tick": tick,
		"version": version,
		"timestamp": Time.get_unix_time_from_system(),
		"seed": Deterministic.get_state() if Deterministic else 0
	}
	if _transaction_active:
		_transaction_events.append(evt)
	else:
		events.append(evt)
		_trim_to_limit()
		emit_signal("event_added", evt)
	return evt

func _next_event_id() -> int:
	if events.is_empty():
		return 0
	return int(events[-1].get("id", events.size() - 1)) + 1

func _trim_to_limit():
	while events.size() > max_events:
		events.pop_front()

func get_events(filter_type: String = "") -> Array:
	if filter_type == "":
		return events.duplicate(true)
	var filtered = []
	for e in events:
		if e.get("type", "") == filter_type:
			filtered.append(e.duplicate(true))
	return filtered

func get_last(n: int = 10) -> Array:
	var start = max(0, events.size() - n)
	return events.slice(start, events.size()).duplicate(true)

func replay(from_tick: int = 0) -> Array:
	# خروجی مرتب برای بازپخش ممیزی؛ بازسازی Snapshot در SaveManager انجام می‌شود.
	var replay_events = []
	for e in events:
		if int(e.get("tick", -1)) >= from_tick:
			replay_events.append(e.duplicate(true))
	return replay_events

func export_json() -> String:
	return JSON.stringify(events)

func import_events(imported: Array) -> bool:
	var clean: Array = []
	for raw in imported:
		if not raw is Dictionary:
			return false
		if not raw.has("type") or not raw.has("data"):
			return false
		var evt = raw.duplicate(true)
		evt["id"] = clean.size()
		clean.append(evt)
	events = clean
	_trim_to_limit()
	return true

func truncate_after_tick(tick: int):
	var kept: Array = []
	for event in events:
		if int(event.get("tick", -1)) <= tick:
			kept.append(event)
	events = kept
	rollback_transaction()

func clear():
	events = []
	rollback_transaction()

func count() -> int:
	return events.size()


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_event_log(data) -> Dictionary:
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

func _deep_cache_event_log_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_event_log"):
		set_meta("cache_event_log", {})
	var cache = get_meta("cache_event_log")
	return cache.get(key, null)

func _deep_cache_event_log_set(key: String, value):
	if not has_meta("cache_event_log"):
		set_meta("cache_event_log", {})
	var cache = get_meta("cache_event_log")
	cache[key] = value
	set_meta("cache_event_log", cache)

func _deep_log_event_log(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_event_log(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_event_log(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("event_log"):
		state["event_log"] = {}
	return state

func _deep_deterministic_event_log_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_event_log(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("event_log_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_event_log(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("event_log", {}).duplicate(true) if state.has("event_log") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_event_log(data) -> Dictionary:
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

func _deep_cache_event_log_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_event_log"):
		set_meta("cache_event_log", {})
	var cache = get_meta("cache_event_log")
	return cache.get(key, null)

func _deep_cache_event_log_set(key: String, value):
	if not has_meta("cache_event_log"):
		set_meta("cache_event_log", {})
	var cache = get_meta("cache_event_log")
	cache[key] = value
	set_meta("cache_event_log", cache)

func _deep_log_event_log(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_event_log(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_event_log(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("event_log"):
		state["event_log"] = {}
	return state

func _deep_deterministic_event_log_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_event_log(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("event_log_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_event_log(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("event_log", {}).duplicate(true) if state.has("event_log") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data



# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_event_log(data) -> Dictionary:
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

func _deep_cache_event_log_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_event_log"):
		set_meta("cache_event_log", {})
	var cache = get_meta("cache_event_log")
	return cache.get(key, null)

func _deep_cache_event_log_set(key: String, value):
	if not has_meta("cache_event_log"):
		set_meta("cache_event_log", {})
	var cache = get_meta("cache_event_log")
	cache[key] = value
	set_meta("cache_event_log", cache)

func _deep_log_event_log(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_event_log(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_event_log(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("event_log"):
		state["event_log"] = {}
	return state

func _deep_deterministic_event_log_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_event_log(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("event_log_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_event_log(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("event_log", {}).duplicate(true) if state.has("event_log") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data


