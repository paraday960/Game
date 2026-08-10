extends Node
# تنظیمات محلی بازیکن؛ جدا از Save کمپین و ماندگار بین اجراها

const SETTINGS_PATH = "user://settings.json"
const SPEEDS = [2.0, 1.0, 0.5, 0.25]
const SPEED_LABELS = ["۰٫۵×", "۱×", "۲×", "۴×"]
const TEXT_SCALES = [0.90, 1.0, 1.15, 1.30]
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
