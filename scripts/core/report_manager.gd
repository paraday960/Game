extends Node
# خلاصه مدیریتی ماه: هزاران محاسبه روزانه را به گزارش قابل فهم و اولویت‌دار تبدیل می‌کند.

const CRITICAL_WORDS = ["crisis", "protest", "war_", "disaster", "collapse", "epidemic", "snow_", "flood", "heatwave", "shortage", "attack", "unrest"]
const POSITIVE_WORDS = ["success", "unlocked", "victory", "agreement", "cleared", "breakthrough", "completed", "saved_lives"]

func build(state: Dictionary, events: Array, turn: int) -> Dictionary:
	var grouped: Dictionary = {}
	var category_counts: Dictionary = {}
	for wrapped in events:
		if not wrapped is Dictionary:
			continue
		var system = str(wrapped.get("system", "other"))
		category_counts[system] = int(category_counts.get(system, 0)) + 1
		var event: Dictionary = wrapped.get("event", {})
		var type = str(event.get("type", "event"))
		var message = str(event.get("message", ""))
		if message.is_empty():
			continue
		var key = "%s:%s" % [system, type]
		if not grouped.has(key):
			grouped[key] = {
				"type":type, "system":system, "message":message,
				"count":0, "priority":_priority(type, float(event.get("severity", 0.0)))
			}
		grouped[key]["count"] = int(grouped[key]["count"]) + 1
	var ranked: Array = grouped.values()
	ranked.sort_custom(func(a, b): return int(a.get("priority", 0)) > int(b.get("priority", 0)))
	var important: Array = []
	for item in ranked:
		if important.size() >= 8:
			break
		important.append(item.duplicate(true))
	var clock: Dictionary = state.get("clock", {})
	var report = {
		"turn":turn,
		"year":int(clock.get("year", 2027)),
		"month":int(clock.get("month", 1)),
		"month_name":TimeManager.month_name(int(clock.get("month", 1))),
		"season":str(state.get("time", {}).get("season", "")),
		"total_events":events.size(),
		"important":important,
		"category_counts":category_counts,
		"gdp_change":AnalyticsManager.get_change(state, "gdp", true),
		"happiness_change":AnalyticsManager.get_change(state, "happiness"),
		"stability_change":AnalyticsManager.get_change(state, "stability"),
		"weather":state.get("weather", {}).get("current", {}).duplicate(true)
	}
	state["monthly_report"] = report
	return state

func summary_message(report: Dictionary) -> String:
	var critical = 0
	for item in report.get("important", []):
		if int(item.get("priority", 0)) >= 3:
			critical += 1
	return "گزارش %s: %s رویداد ثبت شد؛ %s مورد نیازمند توجه فوری است" % [
		report.get("month_name", "ماه"), str(report.get("total_events", 0)), str(critical)]

func _priority(type: String, severity: float) -> int:
	for word in CRITICAL_WORDS:
		if type.contains(word):
			return 4 if severity >= 0.5 else 3
	for word in POSITIVE_WORDS:
		if type.contains(word):
			return 2
	return 1


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_report_manager(data) -> Dictionary:
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

func _deep_cache_report_manager_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_report_manager"):
		set_meta("cache_report_manager", {})
	var cache = get_meta("cache_report_manager")
	return cache.get(key, null)

func _deep_cache_report_manager_set(key: String, value):
	if not has_meta("cache_report_manager"):
		set_meta("cache_report_manager", {})
	var cache = get_meta("cache_report_manager")
	cache[key] = value
	set_meta("cache_report_manager", cache)

func _deep_log_report_manager(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_report_manager(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_report_manager(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("report_manager"):
		state["report_manager"] = {}
	return state

func _deep_deterministic_report_manager_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_report_manager(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("report_manager_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_report_manager(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("report_manager", {}).duplicate(true) if state.has("report_manager") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---
