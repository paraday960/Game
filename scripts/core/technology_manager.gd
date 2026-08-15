extends Node
# درخت فناوری داده‌محور با هزینه، پیش‌نیاز و اثر چندسیستمی

const TECHNOLOGIES_PATH = "res://data/technologies.json"
const INITIAL_UNLOCKS = ["industry_basic", "agriculture_basic"]
# ارتقاهای اصلی: هر شاخه فناوری ۳۰ سطح دارد (بالانس بازی ~۱ ساعته)؛
# ارتقاهای متفرقه (قوانین/پروژه‌ها/دکترین‌ها) بدون سطح یا سطح کم هستند.
const BRANCH_MAX_LEVEL := 30
const BRANCH_IDS := ["صنعت", "انرژی_پاک", "پزشکی", "نظامی", "دیجیتال", "فضا"]
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
	# سطوح شاخه‌ها (۰ تا ۳۰): از مقادیر قدیمی ۰..۱ مهاجرت می‌شود
	var levels: Dictionary = tech_state.get("branch_levels", {})
	if levels.is_empty():
		var branches: Dictionary = tech_state.get("branches", {})
		for branch in BRANCH_IDS:
			levels[branch] = clampi(int(round(float(branches.get(branch, 0.15)) * float(BRANCH_MAX_LEVEL))), 0, BRANCH_MAX_LEVEL)
	tech_state["branch_levels"] = levels
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
	if branch != "":
		var levels: Dictionary = tech_state.get("branch_levels", {})
		if not levels.has(branch):
			levels[branch] = 0
		levels[branch] = clampi(int(levels[branch]) + 1, 0, BRANCH_MAX_LEVEL)
		tech_state["branch_levels"] = levels
		_sync_branch_float(tech_state, branch)
	state["technology"] = tech_state
	for effect in technology.get("effects", []):
		_apply_effect(state, effect)
	return state

func progress_ratio(state: Dictionary) -> float:
	var current = state.get("technology", {}).get("in_progress", null)
	if current == null:
		return 0.0
	return clamp(float(state["technology"].get("research_points", 0.0)) / max(get_cost(str(current)), 0.001), 0.0, 1.0)

# ── سیستم سطوح ۳۰: ارتقای دستی شاخه‌های اصلی با امتیاز پژوهش ──
func get_branch_level(state: Dictionary, branch: String) -> int:
	var levels: Dictionary = state.get("technology", {}).get("branch_levels", {})
	return clampi(int(levels.get(branch, 0)), 0, BRANCH_MAX_LEVEL)

func _sync_branch_float(tech_state: Dictionary, branch: String):
	# مقدار سازگاری ۰..۱ (سیستم‌های قدیمی از branches استفاده می‌کنند)
	var levels: Dictionary = tech_state.get("branch_levels", {})
	var branches: Dictionary = tech_state.get("branches", {})
	if not branches.has(branch):
		branches[branch] = 0.0
	branches[branch] = float(clampi(int(levels.get(branch, 0)), 0, BRANCH_MAX_LEVEL)) / float(BRANCH_MAX_LEVEL)
	tech_state["branches"] = branches

func branch_upgrade_cost(current_level: int) -> float:
	return float(clampi(current_level, 0, BRANCH_MAX_LEVEL - 1) + 1)

func can_upgrade_branch(state: Dictionary, branch: String) -> Dictionary:
	var tech_state: Dictionary = state.get("technology", {})
	var levels: Dictionary = tech_state.get("branch_levels", {})
	var level := clampi(int(levels.get(branch, 0)), 0, BRANCH_MAX_LEVEL)
	if level >= BRANCH_MAX_LEVEL:
		return {"valid": false, "reason": "این شاخه به حداکثر سطح ۳۰ رسیده است"}
	var cost := branch_upgrade_cost(level)
	var points := float(tech_state.get("research_points", 0.0))
	if points < cost:
		return {"valid": false, "reason": "امتیاز پژوهش کافی نیست (%s از %s)" % [PersianFormatter.to_persian_digits(str(int(points))), PersianFormatter.to_persian_digits(str(int(cost)))]}
	return {"valid": true, "reason": "", "cost": cost}

func upgrade_branch(state: Dictionary, branch: String) -> Dictionary:
	var tech_state: Dictionary = state.get("technology", {})
	var check := can_upgrade_branch(state, branch)
	if not check.valid:
		return {"state": state, "success": false, "reason": check.reason}
	var levels: Dictionary = tech_state.get("branch_levels", {})
	var level := clampi(int(levels.get(branch, 0)), 0, BRANCH_MAX_LEVEL)
	var cost := float(check.cost)
	tech_state["research_points"] = float(tech_state.get("research_points", 0.0)) - cost
	levels[branch] = level + 1
	tech_state["branch_levels"] = levels
	_sync_branch_float(tech_state, branch)
	state["technology"] = tech_state
	return {"state": state, "success": true, "level": level + 1, "cost": cost}

# پیروزی: سه شاخه اصلی در سطح ۳۰ → «عصر طلایی» (بازی در ~۱ ساعت قابل اتمام است)
func check_victory(state: Dictionary, turn: int) -> Dictionary:
	var tech_state: Dictionary = state.get("technology", {})
	if state.get("victory", {}).get("achieved", false):
		return {"state": state, "achieved": false}
	var levels: Dictionary = tech_state.get("branch_levels", {})
	var maxed: Array = []
	for branch in BRANCH_IDS:
		if clampi(int(levels.get(branch, 0)), 0, BRANCH_MAX_LEVEL) >= BRANCH_MAX_LEVEL:
			maxed.append(branch)
	if maxed.size() >= 3:
		state["victory"] = {"achieved": true, "turn": turn, "branches": maxed}
		return {"state": state, "achieved": true, "branches": maxed}
	return {"state": state, "achieved": false}

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
