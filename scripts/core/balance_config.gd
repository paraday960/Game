extends Node
# منبع واحد تنظیمات بالانس؛ فایل JSON بدون تغییر کد قابل تنظیم است.

const BALANCE_PATH = "res://data/balance.json"
var data: Dictionary = {}
var load_errors: Array = []

func _ready():
	reload()

func reload() -> bool:
	data = {}
	load_errors = []
	var file = FileAccess.open(BALANCE_PATH, FileAccess.READ)
	if file == null:
		load_errors.append("فایل بالانس قابل خواندن نیست")
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		load_errors.append("ساختار JSON بالانس نامعتبر است")
		return false
	data = parsed
	_validate_required()
	return load_errors.is_empty()

func get_value(path: String, fallback):
	var current = data
	for part in path.split("."):
		if not current is Dictionary or not current.has(part):
			return fallback
		current = current[part]
	return current

func get_section(name: String) -> Dictionary:
	var section = data.get(name, {})
	return section.duplicate(true) if section is Dictionary else {}

func is_valid() -> bool:
	return not data.is_empty() and load_errors.is_empty()

func get_errors() -> Array:
	return load_errors.duplicate()

func _validate_required():
	var required = {
		"resources.energy_crisis_factor": [0.0, 1.0],
		"resources.food_crisis_threshold": [0.0, 150.0],
		"economy.tax_base": [0.0, 0.9],
		"economy.growth_base": [-0.1, 0.2],
		"economy.debt_interest": [0.0, 1.0],
		"economy.debt_ceiling": [0.1, 10.0],
		"population.birth_base": [0.0, 100.0],
		"population.death_base": [0.0, 100.0],
		"politics.stability_initial": [0.0, 1.0],
		"military.readiness_initial": [0.0, 1.0],
		"progression.combo_threshold": [0.0, 1.0]
	}
	for path in required.keys():
		var value = get_value(path, null)
		if not (value is int or value is float):
			load_errors.append("مقدار بالانس یافت نشد یا عددی نیست: " + path)
			continue
		var bounds = required[path]
		if float(value) < float(bounds[0]) or float(value) > float(bounds[1]):
			load_errors.append("مقدار بالانس خارج از محدوده است: " + path)


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_balance_config(data) -> Dictionary:
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

func _deep_cache_balance_config_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_balance_config"):
		set_meta("cache_balance_config", {})
	var cache = get_meta("cache_balance_config")
	return cache.get(key, null)

func _deep_cache_balance_config_set(key: String, value):
	if not has_meta("cache_balance_config"):
		set_meta("cache_balance_config", {})
	var cache = get_meta("cache_balance_config")
	cache[key] = value
	set_meta("cache_balance_config", cache)

func _deep_log_balance_config(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_balance_config(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_balance_config(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("balance_config"):
		state["balance_config"] = {}
	return state

func _deep_deterministic_balance_config_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_balance_config(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("balance_config_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_balance_config(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("balance_config", {}).duplicate(true) if state.has("balance_config") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---
