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
