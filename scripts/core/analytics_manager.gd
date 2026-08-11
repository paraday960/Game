extends Node
# تاریخچه ماهانه فشرده برای تحلیل روند، نمودار و تصمیم‌گیری بازیکن

const DEFAULT_INTERVAL = 1
const DEFAULT_MAX_SAMPLES = 120

func ensure_analytics(state: Dictionary) -> Dictionary:
	if state.has("analytics") and state["analytics"] is Dictionary:
		var analytics: Dictionary = state["analytics"]
		analytics["history"] = analytics.get("history", [])
		analytics["interval_turns"] = int(analytics.get("interval_turns", _interval()))
		analytics.erase("interval_days")
		analytics["max_samples"] = int(analytics.get("max_samples", _max_samples()))
		if analytics["history"].is_empty():
			analytics["history"].append(_sample(state, int(state.get("tick", 0)), float(state.get("economy", {}).get("gdp", 1.0))))
		analytics["last_sample_turn"] = int(analytics.get("last_sample_turn", analytics.get("last_sample_tick", state.get("tick", 0))))
		analytics.erase("last_sample_tick")
		state["analytics"] = analytics
		return state
	return reset(state)

func reset(state: Dictionary) -> Dictionary:
	var baseline_gdp = max(float(state.get("economy", {}).get("gdp", 1.0)), 1.0)
	var tick = int(state.get("tick", 0))
	state["analytics"] = {
		"version": 1,
		"interval_turns": _interval(),
		"max_samples": _max_samples(),
		"baseline_gdp": baseline_gdp,
		"last_sample_turn": tick,
		"history": [_sample(state, tick, baseline_gdp)]
	}
	return state

func update(state: Dictionary, tick: int) -> Dictionary:
	state = ensure_analytics(state)
	var analytics: Dictionary = state["analytics"]
	var interval = max(1, int(analytics.get("interval_turns", _interval())))
	var last_tick = int(analytics.get("last_sample_turn", -interval))
	if tick - last_tick < interval:
		return state
	var history: Array = analytics.get("history", [])
	history.append(_sample(state, tick, float(analytics.get("baseline_gdp", 1.0))))
	while history.size() > int(analytics.get("max_samples", _max_samples())):
		history.pop_front()
	analytics["history"] = history
	analytics["last_sample_turn"] = tick
	state["analytics"] = analytics
	return state

func get_history(state: Dictionary, limit: int = 52) -> Array:
	var history: Array = state.get("analytics", {}).get("history", [])
	var start = max(0, history.size() - max(1, limit))
	return history.slice(start, history.size()).duplicate(true)

func get_change(state: Dictionary, key: String, relative: bool = false) -> float:
	var history: Array = state.get("analytics", {}).get("history", [])
	if history.size() < 2:
		return 0.0
	var previous = float(history[-2].get(key, 0.0))
	var current = float(history[-1].get(key, 0.0))
	if relative:
		return (current - previous) / max(abs(previous), 0.000001)
	return current - previous

func _sample(state: Dictionary, tick: int, baseline_gdp: float) -> Dictionary:
	var economy: Dictionary = state.get("economy", {})
	var clock: Dictionary = state.get("clock", {})
	var gdp = float(economy.get("gdp", 0.0))
	return {
		"tick": tick,
		"year": int(clock.get("year", 2027)),
		"month": int(clock.get("month", 1)),
		"day": int(clock.get("day", 1)),
		"gdp": gdp,
		"gdp_index": gdp / max(baseline_gdp, 1.0),
		"gdp_per_capita": float(economy.get("gdp_per_capita", 0.0)),
		"population": float(state.get("population", {}).get("total", 0.0)),
		"happiness": float(state.get("population", {}).get("happiness", 0.0)),
		"stability": float(state.get("politics", {}).get("stability", 0.0)),
		"inflation": float(economy.get("inflation", 0.0)),
		"unemployment": float(economy.get("unemployment", 0.0)),
		"debt_to_gdp": float(economy.get("debt_to_gdp", 0.0)),
		"power": float(state.get("indicators", {}).get("power_score", 0.0)) / 100.0,
		"score": float(state.get("score", 0.0)),
		"research_rate": float(state.get("technology", {}).get("research_rate", 0.0)),
		"carbon": float(state.get("environment", {}).get("carbon_emission", state.get("environment", {}).get("carbon", 0.0)))
	}

func _interval() -> int:
	return int(BalanceConfig.get_value("simulation.analytics_interval_turns", DEFAULT_INTERVAL))

func _max_samples() -> int:
	return int(BalanceConfig.get_value("simulation.analytics_max_samples", DEFAULT_MAX_SAMPLES))


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_analytics_manager(data) -> Dictionary:
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

func _deep_cache_analytics_manager_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_analytics_manager"):
		set_meta("cache_analytics_manager", {})
	var cache = get_meta("cache_analytics_manager")
	return cache.get(key, null)

func _deep_cache_analytics_manager_set(key: String, value):
	if not has_meta("cache_analytics_manager"):
		set_meta("cache_analytics_manager", {})
	var cache = get_meta("cache_analytics_manager")
	cache[key] = value
	set_meta("cache_analytics_manager", cache)

func _deep_log_analytics_manager(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_analytics_manager(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_analytics_manager(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("analytics_manager"):
		state["analytics_manager"] = {}
	return state

func _deep_deterministic_analytics_manager_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_analytics_manager(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("analytics_manager_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_analytics_manager(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("analytics_manager", {}).duplicate(true) if state.has("analytics_manager") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_analytics_manager(data) -> Dictionary:
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

func _deep_cache_analytics_manager_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_analytics_manager"):
		set_meta("cache_analytics_manager", {})
	var cache = get_meta("cache_analytics_manager")
	return cache.get(key, null)

func _deep_cache_analytics_manager_set(key: String, value):
	if not has_meta("cache_analytics_manager"):
		set_meta("cache_analytics_manager", {})
	var cache = get_meta("cache_analytics_manager")
	cache[key] = value
	set_meta("cache_analytics_manager", cache)

func _deep_log_analytics_manager(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_analytics_manager(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_analytics_manager(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("analytics_manager"):
		state["analytics_manager"] = {}
	return state

func _deep_deterministic_analytics_manager_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_analytics_manager(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("analytics_manager_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_analytics_manager(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("analytics_manager", {}).duplicate(true) if state.has("analytics_manager") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data



# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_analytics_manager(data) -> Dictionary:
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

func _deep_cache_analytics_manager_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_analytics_manager"):
		set_meta("cache_analytics_manager", {})
	var cache = get_meta("cache_analytics_manager")
	return cache.get(key, null)

func _deep_cache_analytics_manager_set(key: String, value):
	if not has_meta("cache_analytics_manager"):
		set_meta("cache_analytics_manager", {})
	var cache = get_meta("cache_analytics_manager")
	cache[key] = value
	set_meta("cache_analytics_manager", cache)

func _deep_log_analytics_manager(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_analytics_manager(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_analytics_manager(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("analytics_manager"):
		state["analytics_manager"] = {}
	return state

func _deep_deterministic_analytics_manager_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_analytics_manager(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("analytics_manager_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_analytics_manager(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("analytics_manager", {}).duplicate(true) if state.has("analytics_manager") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data



# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_analytics_manager(data) -> Dictionary:
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

func _deep_cache_analytics_manager_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_analytics_manager"):
		set_meta("cache_analytics_manager", {})
	var cache = get_meta("cache_analytics_manager")
	return cache.get(key, null)

func _deep_cache_analytics_manager_set(key: String, value):
	if not has_meta("cache_analytics_manager"):
		set_meta("cache_analytics_manager", {})
	var cache = get_meta("cache_analytics_manager")
	cache[key] = value
	set_meta("cache_analytics_manager", cache)

func _deep_log_analytics_manager(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_analytics_manager(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_analytics_manager(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("analytics_manager"):
		state["analytics_manager"] = {}
	return state

func _deep_deterministic_analytics_manager_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_analytics_manager(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("analytics_manager_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_analytics_manager(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("analytics_manager", {}).duplicate(true) if state.has("analytics_manager") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data


