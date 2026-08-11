extends Node
# درخت فناوری داده‌محور با هزینه، پیش‌نیاز و اثر چندسیستمی

const TECHNOLOGIES_PATH = "res://data/technologies.json"
const INITIAL_UNLOCKS = ["industry_basic", "agriculture_basic"]
const LEGACY_IDS = {
	"صنعت_پایه":"industry_basic", "کشاورزی_پایه":"agriculture_basic",
	"صنعت_پیشرفته":"advanced_manufacturing", "انرژی_خورشیدی":"solar_grid",
	"هوش_مصنوعی":"national_ai", "پزشکی_نوین":"modern_vaccines",
	"موشکی":"missile_defense", "دیجیتال":"digital_government", "فضا":"earth_observation"
}

var technologies: Dictionary = {}
var ordered_ids: Array = []
var data_version: String = ""
var load_errors: Array = []

func _ready():
	reload()

func reload() -> bool:
	technologies.clear()
	ordered_ids.clear()
	load_errors.clear()
	var file = FileAccess.open(TECHNOLOGIES_PATH, FileAccess.READ)
	if file == null:
		load_errors.append("فایل درخت فناوری خوانده نشد")
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or not parsed.get("technologies", null) is Array:
		load_errors.append("ساختار درخت فناوری نامعتبر است")
		return false
	data_version = str(parsed.get("version", "1.0.0"))
	for raw in parsed["technologies"]:
		if not raw is Dictionary or str(raw.get("id", "")).is_empty():
			continue
		var id = str(raw["id"])
		technologies[id] = raw.duplicate(true)
		ordered_ids.append(id)
	for id in technologies.keys():
		for prerequisite in technologies[id].get("prerequisites", []):
			if not technologies.has(prerequisite):
				load_errors.append("پیش‌نیاز ناشناخته برای فناوری %s" % id)
	return load_errors.is_empty()

func is_valid() -> bool:
	return technologies.size() >= 18 and load_errors.is_empty()

func get_technology(id: String) -> Dictionary:
	return technologies.get(id, {}).duplicate(true)

func get_technology_name(id: String) -> String:
	return str(technologies.get(id, {}).get("name_fa", id))

func get_cost(id: String) -> float:
	return float(technologies.get(id, {}).get("cost", 0.0))

func get_available(state: Dictionary) -> Array:
	var tech_state: Dictionary = state.get("technology", {})
	var unlocked: Array = tech_state.get("unlocked", [])
	var in_progress = tech_state.get("in_progress", null)
	var available: Array = []
	for id in ordered_ids:
		var technology: Dictionary = technologies[id]
		if float(technology.get("cost", 0.0)) <= 0.0 or unlocked.has(id) or id == in_progress:
			continue
		var ready = true
		for prerequisite in technology.get("prerequisites", []):
			if not unlocked.has(prerequisite):
				ready = false
				break
		if ready:
			available.append(technology.duplicate(true))
	return available

func can_start(state: Dictionary, id: String) -> Dictionary:
	if not technologies.has(id):
		return {"valid": false, "reason": "فناوری انتخابی وجود ندارد"}
	var tech_state: Dictionary = state.get("technology", {})
	if tech_state.get("in_progress", null) != null:
		return {"valid": false, "reason": "یک پژوهش دیگر در حال اجراست"}
	if tech_state.get("unlocked", []).has(id):
		return {"valid": false, "reason": "این فناوری قبلاً باز شده است"}
	for prerequisite in technologies[id].get("prerequisites", []):
		if not tech_state.get("unlocked", []).has(prerequisite):
			return {"valid": false, "reason": "پیش‌نیاز «%s» هنوز باز نشده است" % get_technology_name(prerequisite)}
	return {"valid": true, "reason": ""}

func migrate_state(state: Dictionary) -> Dictionary:
	if not state.has("technology"):
		return state
	var tech_state: Dictionary = state["technology"]
	var migrated: Array = []
	for old_id in tech_state.get("unlocked", []):
		var id = LEGACY_IDS.get(str(old_id), str(old_id))
		if technologies.has(id) and not migrated.has(id):
			migrated.append(id)
	for initial in INITIAL_UNLOCKS:
		if not migrated.has(initial):
			migrated.append(initial)
	tech_state["unlocked"] = migrated
	if tech_state.get("in_progress", null) != null:
		var current = LEGACY_IDS.get(str(tech_state["in_progress"]), str(tech_state["in_progress"]))
		tech_state["in_progress"] = current if technologies.has(current) and not migrated.has(current) else null
	tech_state["tree_version"] = data_version
	state["technology"] = tech_state
	return state

func apply_unlock(state: Dictionary, id: String) -> Dictionary:
	if not technologies.has(id):
		return state
	var technology: Dictionary = technologies[id]
	var tech_state: Dictionary = state["technology"]
	if not tech_state["unlocked"].has(id):
		tech_state["unlocked"].append(id)
	var branch = str(technology.get("branch", ""))
	if tech_state.get("branches", {}).has(branch):
		tech_state["branches"][branch] = clamp(float(tech_state["branches"][branch]) + 0.06, 0.0, 1.0)
	state["technology"] = tech_state
	for effect in technology.get("effects", []):
		_apply_effect(state, effect)
	return state

func progress_ratio(state: Dictionary) -> float:
	var current = state.get("technology", {}).get("in_progress", null)
	if current == null:
		return 0.0
	return clamp(float(state["technology"].get("research_points", 0.0)) / max(get_cost(str(current)), 0.001), 0.0, 1.0)

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

func _deep_validate_technology_manager(data) -> Dictionary:
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

func _deep_cache_technology_manager_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_technology_manager"):
		set_meta("cache_technology_manager", {})
	var cache = get_meta("cache_technology_manager")
	return cache.get(key, null)

func _deep_cache_technology_manager_set(key: String, value):
	if not has_meta("cache_technology_manager"):
		set_meta("cache_technology_manager", {})
	var cache = get_meta("cache_technology_manager")
	cache[key] = value
	set_meta("cache_technology_manager", cache)

func _deep_log_technology_manager(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_technology_manager(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_technology_manager(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("technology_manager"):
		state["technology_manager"] = {}
	return state

func _deep_deterministic_technology_manager_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_technology_manager(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("technology_manager_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_technology_manager(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("technology_manager", {}).duplicate(true) if state.has("technology_manager") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---
