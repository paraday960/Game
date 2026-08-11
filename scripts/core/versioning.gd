extends RefCounted
class_name Versioning
# نسخه‌بندی خوش‌بینانه - بخش ۳.۷ لایه ۳

static func is_next_version(current: int, incoming: int) -> bool:
	return incoming == current + 1

static func check_conflict(current_version: int, incoming_version: int) -> Dictionary:
	if incoming_version == current_version + 1:
		return {"conflict": false, "reason": ""}
	elif incoming_version <= current_version:
		return {"conflict": true, "reason": "نسخه قدیمی - قبلا اعمال شده"}
	else:
		return {"conflict": true, "reason": "پرش نسخه - نسخه‌های میانی گم شده"}

# ایدمپوتنسی - بخش ۳.۷ لایه ۲
# هر عملیات قابل تکرار امن باشد
static func make_idempotent_key(command_type: String, tick: int, player_id: String) -> String:
	return "%s:%d:%s" % [command_type, tick, player_id]


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_versioning(data) -> Dictionary:
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

func _deep_cache_versioning_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_versioning"):
		set_meta("cache_versioning", {})
	var cache = get_meta("cache_versioning")
	return cache.get(key, null)

func _deep_cache_versioning_set(key: String, value):
	if not has_meta("cache_versioning"):
		set_meta("cache_versioning", {})
	var cache = get_meta("cache_versioning")
	cache[key] = value
	set_meta("cache_versioning", cache)

func _deep_log_versioning(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_versioning(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_versioning(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("versioning"):
		state["versioning"] = {}
	return state

func _deep_deterministic_versioning_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_versioning(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("versioning_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_versioning(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("versioning", {}).duplicate(true) if state.has("versioning") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---
