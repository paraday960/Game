extends Node
# توسعه نظامی ماهانه: پروژه، دکترین، هزینه، پیش‌نیاز و اثر پایدار

const DATA_PATH = "res://data/military_programs.json"
const DOCTRINES = {
	"defensive":{"name_fa":"دفاع سرزمینی","power_multiplier":0.97,"readiness_bonus":0.03,"deterrence_bonus":6.0,"casualty_reduction":0.10},
	"balanced":{"name_fa":"دکترین متوازن","power_multiplier":1.0,"readiness_bonus":0.0,"deterrence_bonus":0.0,"casualty_reduction":0.0},
	"expeditionary":{"name_fa":"عملیات برون‌مرزی","power_multiplier":1.08,"readiness_bonus":-0.02,"deterrence_bonus":2.0,"casualty_reduction":-0.05}
}
var programs: Dictionary = {}
var ordered_ids: Array = []
var data_version := ""
var load_errors: Array = []

func _ready(): reload()

func reload() -> bool:
	programs.clear(); ordered_ids.clear(); load_errors.clear()
	var file = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null: load_errors.append("فایل برنامه‌های نظامی خوانده نشد"); return false
	var parsed = JSON.parse_string(file.get_as_text()); file.close()
	if not parsed is Dictionary or not parsed.get("programs", null) is Array:
		load_errors.append("ساختار برنامه‌های نظامی نامعتبر است"); return false
	data_version = str(parsed.get("version", "1.0.0"))
	for raw in parsed["programs"]:
		if not raw is Dictionary: continue
		var id = str(raw.get("id", ""))
		if id.is_empty() or programs.has(id): load_errors.append("شناسه برنامه نظامی تکراری است"); continue
		programs[id] = raw.duplicate(true); ordered_ids.append(id)
	return load_errors.is_empty()

func is_valid() -> bool: return programs.size() >= 8 and load_errors.is_empty()
func get_program_ids() -> Array: return ordered_ids.duplicate()
func get_program(id: String) -> Dictionary: return programs.get(id, {}).duplicate(true)
func get_program_name(id: String) -> String: return str(programs.get(id, {}).get("name_fa", id))
func get_doctrine_name(id: String) -> String: return str(DOCTRINES.get(id, {}).get("name_fa", id))

func reset(state: Dictionary) -> Dictionary:
	state["military_development"] = {
		"data_version":data_version, "doctrine":"balanced", "active":{}, "completed":[],
		"modifiers":{"power_multiplier":1.0,"readiness_bonus":0.0,"logistics_bonus":0.0,"deterrence_bonus":0.0,"casualty_reduction":0.0},
		"history":[]
	}
	return state

func ensure_state(state: Dictionary) -> Dictionary:
	if not state.has("military_development") or not state["military_development"] is Dictionary: return reset(state)
	var dev: Dictionary = state["military_development"]
	dev["active"] = dev.get("active", {}); dev["completed"] = dev.get("completed", [])
	dev["doctrine"] = dev.get("doctrine", "balanced"); dev["history"] = dev.get("history", [])
	dev["modifiers"] = dev.get("modifiers", {"power_multiplier":1.0,"readiness_bonus":0.0,"logistics_bonus":0.0,"deterrence_bonus":0.0,"casualty_reduction":0.0})
	state["military_development"] = dev
	return state

func can_start(state: Dictionary, id: String) -> Dictionary:
	if not programs.has(id): return {"valid":false,"reason":"برنامه نظامی وجود ندارد"}
	state = ensure_state(state.duplicate(true)); var dev: Dictionary = state["military_development"]
	if dev["completed"].has(id): return {"valid":false,"reason":"این برنامه قبلاً تکمیل شده است"}
	if dev["active"].has(id): return {"valid":false,"reason":"این برنامه در حال اجراست"}
	if dev["active"].size() >= 2: return {"valid":false,"reason":"حداکثر دو برنامه نظامی هم‌زمان قابل اجراست"}
	for prerequisite in programs[id].get("prerequisites", []):
		if not state.get("technology", {}).get("unlocked", []).has(prerequisite):
			return {"valid":false,"reason":"فناوری پیش‌نیاز «%s» باز نشده است" % TechnologyManager.get_technology_name(prerequisite)}
	return {"valid":true,"reason":""}

func start_program(state: Dictionary, id: String, turn: int) -> Dictionary:
	var check = can_start(state, id)
	if not check.valid: return {"success":false,"reason":check.reason,"state":state,"events":[]}
	state = ensure_state(state); var dev: Dictionary = state["military_development"]; var definition: Dictionary = programs[id]
	var cost = float(state.get("economy", {}).get("gdp", 1.0)) * float(definition.get("cost_gdp_ratio", 0.002))
	state["economy"]["national_debt"] = float(state["economy"].get("national_debt", 0.0)) + cost
	dev["active"][id] = {"started_turn":turn,"remaining_months":int(definition.get("duration_months", 1)),"cost":cost}
	dev["history"].append({"type":"started","id":id,"turn":turn}); state["military_development"] = dev
	return {"success":true,"state":state,"events":[{"type":"military_program_started","message":"برنامه «%s» آغاز شد" % get_program_name(id),"program_id":id}]}

func set_doctrine(state: Dictionary, doctrine: String, turn: int) -> Dictionary:
	if not DOCTRINES.has(doctrine): return {"success":false,"reason":"دکترین نظامی معتبر نیست","state":state,"events":[]}
	state = ensure_state(state); var dev: Dictionary = state["military_development"]
	if dev["doctrine"] == doctrine: return {"success":false,"reason":"این دکترین از قبل فعال است","state":state,"events":[]}
	dev["doctrine"] = doctrine; dev["history"].append({"type":"doctrine","id":doctrine,"turn":turn}); state["military_development"] = dev
	state["politics"]["tension"] = clamp(float(state["politics"].get("tension", 0.3)) + (0.02 if doctrine == "expeditionary" else -0.005), 0.0, 1.0)
	return {"success":true,"state":state,"events":[{"type":"military_doctrine_changed","message":"دکترین «%s» فعال شد" % get_doctrine_name(doctrine)}]}

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure_state(state); var dev: Dictionary = state["military_development"]; var events: Array = []; var finished: Array = []
	for id in dev["active"].keys():
		dev["active"][id]["remaining_months"] = int(dev["active"][id].get("remaining_months", 1)) - 1
		if int(dev["active"][id]["remaining_months"]) <= 0: finished.append(id)
	for id in finished:
		dev["active"].erase(id); dev["completed"].append(id); _apply_program_effects(dev, programs[id].get("effects", {}))
		dev["history"].append({"type":"completed","id":id,"turn":turn})
		events.append({"type":"military_program_completed","message":"برنامه «%s» تکمیل و وارد خدمت شد" % get_program_name(id),"program_id":id})
	while dev["history"].size() > 100: dev["history"].pop_front()
	state["military_development"] = dev
	return {"state":state,"events":events}

func get_effective_modifiers(state: Dictionary) -> Dictionary:
	state = ensure_state(state); var dev: Dictionary = state["military_development"]; var result: Dictionary = dev["modifiers"].duplicate(true)
	var doctrine: Dictionary = DOCTRINES.get(str(dev.get("doctrine", "balanced")), DOCTRINES["balanced"])
	result["power_multiplier"] = float(result.get("power_multiplier", 1.0)) * float(doctrine.get("power_multiplier", 1.0))
	result["readiness_bonus"] = float(result.get("readiness_bonus", 0.0)) + float(doctrine.get("readiness_bonus", 0.0))
	result["deterrence_bonus"] = float(result.get("deterrence_bonus", 0.0)) + float(doctrine.get("deterrence_bonus", 0.0))
	result["casualty_reduction"] = clamp(float(result.get("casualty_reduction", 0.0)) + float(doctrine.get("casualty_reduction", 0.0)), -0.10, 0.60)
	return result

func _apply_program_effects(dev: Dictionary, effects: Dictionary):
	var mods: Dictionary = dev["modifiers"]
	mods["power_multiplier"] = float(mods.get("power_multiplier", 1.0)) + float(effects.get("power_multiplier", 0.0))
	for key in ["readiness_bonus","logistics_bonus","deterrence_bonus","casualty_reduction"]:
		mods[key] = float(mods.get(key, 0.0)) + float(effects.get(key, 0.0))
	dev["modifiers"] = mods
