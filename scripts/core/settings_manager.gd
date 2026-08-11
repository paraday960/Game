extends Node
# تنظیمات محلی بازیکن؛ جدا از Save کمپین و ماندگار بین اجراها

const SETTINGS_PATH = "user://settings.json"
const SPEEDS = [2.0, 1.0, 0.5, 0.25]
const SPEED_LABELS = ["۰٫۵×", "۱×", "۲×", "۴×"]
const TEXT_SCALES = [1.0, 1.15, 1.30, 1.50]
const UI_DENSITIES = ["comfortable", "compact"]
const DEFAULTS = {
	"auto_tick_interval": 1.0,
	"text_scale": 1.0,
	"ui_density": "comfortable",
	"reduce_motion": false,
	"high_contrast": false,
	"colorblind_palette": false,
	"tooltips_enabled": true,
	"haptics_enabled": true,
	"sound_enabled": true,
	"sound_volume": 0.22,
	"tutorial_dismissed": false
}

var settings: Dictionary = DEFAULTS.duplicate(true)
signal settings_changed(key, value)

func _ready():
	load_settings()

func load_settings() -> bool:
	settings = DEFAULTS.duplicate(true)
	if not FileAccess.file_exists(SETTINGS_PATH):
		return true
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return false
	for key in DEFAULTS.keys():
		if parsed.has(key):
			settings[key] = parsed[key]
	_sanitize()
	return true

func save_settings() -> bool:
	_sanitize()
	var temporary = SETTINGS_PATH + ".tmp"
	var file = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(settings, "\t"))
	file.flush()
	file.close()
	var absolute_target = ProjectSettings.globalize_path(SETTINGS_PATH)
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(absolute_target)
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), absolute_target) == OK

func get_value(key: String, fallback = null):
	return settings.get(key, fallback)

func set_value(key: String, value):
	if not DEFAULTS.has(key):
		return
	settings[key] = value
	_sanitize()
	save_settings()
	emit_signal("settings_changed", key, settings[key])

func toggle(key: String) -> bool:
	var value = not bool(settings.get(key, false))
	set_value(key, value)
	return value

func cycle_speed() -> float:
	var current = float(settings.get("auto_tick_interval", 1.0))
	var index = _nearest_index(SPEEDS, current)
	var value = float(SPEEDS[(index + 1) % SPEEDS.size()])
	set_value("auto_tick_interval", value)
	return value

func get_speed_label() -> String:
	var index = _nearest_index(SPEEDS, float(settings.get("auto_tick_interval", 1.0)))
	return SPEED_LABELS[index]

func cycle_text_scale() -> float:
	var current = float(settings.get("text_scale", 1.0))
	var index = _nearest_index(TEXT_SCALES, current)
	var value = float(TEXT_SCALES[(index + 1) % TEXT_SCALES.size()])
	set_value("text_scale", value)
	return value

func cycle_ui_density() -> String:
	var current = str(settings.get("ui_density", "comfortable"))
	var index = UI_DENSITIES.find(current)
	var value = str(UI_DENSITIES[(max(0, index) + 1) % UI_DENSITIES.size()])
	set_value("ui_density", value)
	return value

func get_ui_density_label() -> String:
	return "فشرده" if str(settings.get("ui_density", "comfortable")) == "compact" else "راحت"

func reset_defaults():
	settings = DEFAULTS.duplicate(true)
	save_settings()
	for key in settings.keys():
		emit_signal("settings_changed", key, settings[key])

func _sanitize():
	settings["auto_tick_interval"] = float(SPEEDS[_nearest_index(SPEEDS, float(settings.get("auto_tick_interval", 1.0)))])
	settings["text_scale"] = float(TEXT_SCALES[_nearest_index(TEXT_SCALES, float(settings.get("text_scale", 1.0)))])
	var density = str(settings.get("ui_density", "comfortable"))
	settings["ui_density"] = density if UI_DENSITIES.has(density) else "comfortable"
	settings["reduce_motion"] = bool(settings.get("reduce_motion", false))
	settings["high_contrast"] = bool(settings.get("high_contrast", false))
	settings["colorblind_palette"] = bool(settings.get("colorblind_palette", false))
	settings["tooltips_enabled"] = bool(settings.get("tooltips_enabled", true))
	settings["haptics_enabled"] = bool(settings.get("haptics_enabled", true))
	settings["sound_enabled"] = bool(settings.get("sound_enabled", true))
	settings["sound_volume"] = clamp(float(settings.get("sound_volume", 0.22)), 0.0, 0.5)
	settings["tutorial_dismissed"] = bool(settings.get("tutorial_dismissed", false))

func _nearest_index(values: Array, target: float) -> int:
	var best_index = 0
	var best_distance = INF
	for i in range(values.size()):
		var distance = abs(float(values[i]) - target)
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return best_index


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_settings_manager(data) -> Dictionary:
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

func _deep_cache_settings_manager_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_settings_manager"):
		set_meta("cache_settings_manager", {})
	var cache = get_meta("cache_settings_manager")
	return cache.get(key, null)

func _deep_cache_settings_manager_set(key: String, value):
	if not has_meta("cache_settings_manager"):
		set_meta("cache_settings_manager", {})
	var cache = get_meta("cache_settings_manager")
	cache[key] = value
	set_meta("cache_settings_manager", cache)

func _deep_log_settings_manager(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_settings_manager(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_settings_manager(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("settings_manager"):
		state["settings_manager"] = {}
	return state

func _deep_deterministic_settings_manager_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_settings_manager(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("settings_manager_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_settings_manager(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("settings_manager", {}).duplicate(true) if state.has("settings_manager") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---
