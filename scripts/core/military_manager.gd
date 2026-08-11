extends Node
# توسعه نظامی ماهانه: پروژه، دکترین، هزینه، پیش‌نیاز و اثر پایدار - نسخه عمیق واقعی
# ۸ دکترین واقعی + ۲۰ برنامه نظامی برای جنگ تمام‌عیار مدرن

const DATA_PATH = "res://data/military_programs.json"
const DOCTRINES = {
	"defensive":{
		"name_fa":"دفاع سرزمینی",
		"desc":"دفاع در عمق، استحکامات، ضد حمله محدود، تاب‌آوری بالا",
		"power_multiplier":0.92,"readiness_bonus":0.06,"defense_bonus":0.35,"offense_penalty":-0.25,"deterrence_bonus":8.0,"casualty_reduction":0.18,"logistics_bonus":0.05,
		"doctrine_type":"defensive","terrain_bonus":{"کوهستان":0.20,"شهری":0.15}
	},
	"balanced":{
		"name_fa":"دکترین متوازن",
		"desc":"ترکیب دفاع و حمله منعطف، عملیات مشترک",
		"power_multiplier":1.0,"readiness_bonus":0.0,"defense_bonus":0.10,"offense_bonus":0.10,"deterrence_bonus":0.0,"casualty_reduction":0.0,"logistics_bonus":0.0,
		"doctrine_type":"balanced"
	},
	"maneuver":{
		"name_fa":"مانور / بلیتزکریگ",
		"desc":"نفوذ سریع زرهی، محاصره، جنگ برق‌آسا، غافلگیری، Schwerpunkt",
		"power_multiplier":1.18,"readiness_bonus":-0.03,"defense_bonus":-0.15,"offense_bonus":0.40,"deterrence_bonus":5.0,"casualty_reduction":-0.08,"logistics_bonus":-0.10,
		"doctrine_type":"offensive","terrain_bonus":{"دشت":0.25,"بیابان":0.15}
	},
	"attrition":{
		"name_fa":"فرسایشی / آتش سنگین",
		"desc":"آتش توپخانه انبوه، نابودی تدریجی، جنگ خندق، تحمل تلفات",
		"power_multiplier":1.05,"readiness_bonus":0.02,"defense_bonus":0.15,"offense_bonus":0.15,"deterrence_bonus":2.0,"casualty_reduction":-0.05,"logistics_bonus":-0.15,
		"doctrine_type":"offensive"
	},
	"guerrilla":{
		"name_fa":"چریکی / نامتقارن",
		"desc":"کمین، تله، جنگ فرسایشی طولانی، عدم تقارن، مردم‌پایه",
		"power_multiplier":0.75,"readiness_bonus":0.08,"defense_bonus":0.40,"offense_bonus":-0.20,"deterrence_bonus":-5.0,"casualty_reduction":0.20,"logistics_bonus":0.20,
		"doctrine_type":"defensive","terrain_bonus":{"جنگل":0.25,"کوهستان":0.20,"شهری":0.15}
	},
	"expeditionary":{
		"name_fa":"برون‌مرزی / اعزامی",
		"desc":"قدرت‌نمایی دوربرد، آبی-خاکی، هوابرد، لجستیک قوی",
		"power_multiplier":1.08,"readiness_bonus":-0.02,"defense_bonus":-0.10,"offense_bonus":0.25,"deterrence_bonus":4.0,"casualty_reduction":-0.05,"logistics_bonus":-0.12,
		"doctrine_type":"offensive"
	},
	"hybrid":{
		"name_fa":"هیبریدی مدرن",
		"desc":"ترکیب متعارف + سایبری + اطلاعاتی + نیابتی + پهپاد swarm + جنگ الکترونیک - دکترین ۲۰۲۰s",
		"power_multiplier":1.12,"readiness_bonus":0.04,"defense_bonus":0.10,"offense_bonus":0.20,"deterrence_bonus":6.0,"casualty_reduction":0.08,"logistics_bonus":0.05,
		"doctrine_type":"hybrid","requires_tech":["cyber_defense","defense_drones"]
	},
	"deterrence":{
		"name_fa":"بازدارندگی راهبردی",
		"desc":"حداکثر بازدارندگی با حداقل درگیری - هسته‌ای، موشکی، سایبری، فضایی",
		"power_multiplier":0.95,"readiness_bonus":0.05,"defense_bonus":0.30,"offense_bonus":-0.30,"deterrence_bonus":25.0,"casualty_reduction":0.15,"logistics_bonus":0.10,
		"doctrine_type":"deterrence","requires_tech":["missile_defense"]
	}
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
		if id.is_empty() or programs.has(id): load_errors.append("شناسه تکراری نظامی"); continue
		programs[id] = raw.duplicate(true); ordered_ids.append(id)
	return load_errors.is_empty()

func is_valid() -> bool: return programs.size() >= 10 and load_errors.is_empty()
func get_program_ids() -> Array: return ordered_ids.duplicate()
func get_program(id: String) -> Dictionary: return programs.get(id, {}).duplicate(true)
func get_program_name(id: String) -> String: return str(programs.get(id, {}).get("name_fa", id))
func get_doctrine_name(id: String) -> String: return str(DOCTRINES.get(id, {}).get("name_fa", id))
func get_doctrine_description(id: String) -> String: return str(DOCTRINES.get(id, {}).get("desc", ""))

func reset(state: Dictionary) -> Dictionary:
	state["military_development"] = {
		"data_version":data_version, "doctrine":"balanced", "active":{}, "completed":[],
		"modifiers":{"power_multiplier":1.0,"readiness_bonus":0.0,"logistics_bonus":0.0,"deterrence_bonus":0.0,"casualty_reduction":0.0,"defense_bonus":0.0,"offense_bonus":0.0},
		"history":[]
	}
	return state

func ensure_state(state: Dictionary) -> Dictionary:
	if not state.has("military_development") or not state["military_development"] is Dictionary: return reset(state)
	var dev: Dictionary = state["military_development"]
	dev["active"] = dev.get("active", {}); dev["completed"] = dev.get("completed", [])
	dev["doctrine"] = dev.get("doctrine", "balanced"); dev["history"] = dev.get("history", [])
	dev["modifiers"] = dev.get("modifiers", {"power_multiplier":1.0,"readiness_bonus":0.0,"logistics_bonus":0.0,"deterrence_bonus":0.0,"casualty_reduction":0.0,"defense_bonus":0.0,"offense_bonus":0.0})
	# مهاجرت از ۳ دکترین قدیم به ۸ جدید
	if not DOCTRINES.has(dev["doctrine"]):
		dev["doctrine"] = "balanced"
	state["military_development"] = dev
	return state

func can_start(state: Dictionary, id: String) -> Dictionary:
	if not programs.has(id): return {"valid":false,"reason":"برنامه نظامی وجود ندارد"}
	state = ensure_state(state.duplicate(true)); var dev: Dictionary = state["military_development"]
	if dev["completed"].has(id): return {"valid":false,"reason":"این برنامه قبلاً تکمیل شده"}
	if dev["active"].has(id): return {"valid":false,"reason":"این برنامه در حال اجراست"}
	if dev["active"].size() >= 2: return {"valid":false,"reason":"حداکثر دو برنامه هم‌زمان"}
	for prerequisite in programs[id].get("prerequisites", []):
		if not state.get("technology", {}).get("unlocked", []).has(prerequisite):
			return {"valid":false,"reason":"فناوری پیش‌نیاز «%s» باز نشده" % TechnologyManager.get_technology_name(prerequisite)}
	# بررسی پیش‌نیاز دکترین برای برخی برنامه‌ها
	var required_doctrine = programs[id].get("required_doctrine", "")
	if not required_doctrine.is_empty() and dev["doctrine"] != required_doctrine:
		return {"valid":false,"reason":"این برنامه نیازمند دکترین «%s» است" % get_doctrine_name(required_doctrine)}
	return {"valid":true,"reason":""}

func start_program(state: Dictionary, id: String, turn: int) -> Dictionary:
	var check = can_start(state, id)
	if not check.valid: return {"success":false,"reason":check.reason,"state":state,"events":[]}
	state = ensure_state(state); var dev: Dictionary = state["military_development"]; var definition: Dictionary = programs[id]
	var cost = float(state.get("economy", {}).get("gdp", 1.0)) * float(definition.get("cost_gdp_ratio", 0.002))
	state["economy"]["national_debt"] = float(state["economy"].get("national_debt", 0.0)) + cost
	dev["active"][id] = {"started_turn":turn,"remaining_months":int(definition.get("duration_months", 1)),"cost":cost}
	dev["history"].append({"type":"started","id":id,"turn":turn}); state["military_development"] = dev
	return {"success":true,"state":state,"events":[{"type":"military_program_started","message":"برنامه «%s» آغاز شد - %s" % [get_program_name(id), definition.get("description","")],"program_id":id}]}

func set_doctrine(state: Dictionary, doctrine: String, turn: int) -> Dictionary:
	if not DOCTRINES.has(doctrine): return {"success":false,"reason":"دکترین نظامی معتبر نیست - ۸ دکترین موجود: %s" % ",".join(DOCTRINES.keys()),"state":state,"events":[]}
	state = ensure_state(state); var dev: Dictionary = state["military_development"]
	if dev["doctrine"] == doctrine: return {"success":false,"reason":"این دکترین از قبل فعال است","state":state,"events":[]}
	var old = dev["doctrine"]
	dev["doctrine"] = doctrine; dev["history"].append({"type":"doctrine","id":doctrine,"turn":turn,"from":old}); state["military_development"] = dev
	# اثر دکترین بر سیاست
	var tension_change = 0.0
	match doctrine:
		"expeditionary": tension_change = 0.03
		"maneuver": tension_change = 0.02
		"attrition": tension_change = 0.015
		"defensive": tension_change = -0.01
		"deterrence": tension_change = 0.025
		"hybrid": tension_change = 0.02
		_: tension_change = 0.0
	state["politics"]["tension"] = clamp(float(state["politics"].get("tension", 0.3)) + tension_change, 0.0, 1.0)
	return {"success":true,"state":state,"events":[{"type":"military_doctrine_changed","message":"دکترین به «%s» تغییر کرد - %s" % [get_doctrine_name(doctrine), get_doctrine_description(doctrine)]}]}

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure_state(state); var dev: Dictionary = state["military_development"]; var events: Array = []; var finished: Array = []
	for id in dev["active"].keys():
		dev["active"][id]["remaining_months"] = int(dev["active"][id].get("remaining_months", 1)) - 1
		if int(dev["active"][id]["remaining_months"]) <= 0: finished.append(id)
	for id in finished:
		dev["active"].erase(id); dev["completed"].append(id); _apply_program_effects(dev, programs[id].get("effects", {}))
		dev["history"].append({"type":"completed","id":id,"turn":turn})
		events.append({"type":"military_program_completed","message":"برنامه «%s» تکمیل و عملیاتی شد" % get_program_name(id),"program_id":id})
	while dev["history"].size() > 150: dev["history"].pop_front()
	state["military_development"] = dev
	return {"state":state,"events":events}

func get_effective_modifiers(state: Dictionary) -> Dictionary:
	state = ensure_state(state); var dev: Dictionary = state["military_development"]; var result: Dictionary = dev["modifiers"].duplicate(true)
	var doctrine: Dictionary = DOCTRINES.get(str(dev.get("doctrine", "balanced")), DOCTRINES["balanced"])
	result["power_multiplier"] = float(result.get("power_multiplier", 1.0)) * float(doctrine.get("power_multiplier", 1.0))
	result["readiness_bonus"] = float(result.get("readiness_bonus", 0.0)) + float(doctrine.get("readiness_bonus", 0.0))
	result["deterrence_bonus"] = float(result.get("deterrence_bonus", 0.0)) + float(doctrine.get("deterrence_bonus", 0.0))
	result["casualty_reduction"] = clamp(float(result.get("casualty_reduction", 0.0)) + float(doctrine.get("casualty_reduction", 0.0)), -0.15, 0.70)
	result["defense_bonus"] = float(result.get("defense_bonus", 0.0)) + float(doctrine.get("defense_bonus", 0.0))
	result["offense_bonus"] = float(result.get("offense_bonus", 0.0)) + float(doctrine.get("offense_bonus", 0.0))
	result["logistics_bonus"] = float(result.get("logistics_bonus", 0.0)) + float(doctrine.get("logistics_bonus", 0.0))
	return result

func get_doctrine_bonus_for_terrain(doctrine_id: String, terrain: String) -> float:
	var doc = DOCTRINES.get(doctrine_id, {})
	var terrain_bonus = doc.get("terrain_bonus", {})
	return float(terrain_bonus.get(terrain, 0.0))

func _apply_program_effects(dev: Dictionary, effects: Dictionary):
	var mods: Dictionary = dev["modifiers"]
	mods["power_multiplier"] = float(mods.get("power_multiplier", 1.0)) + float(effects.get("power_multiplier", 0.0))
	for key in ["readiness_bonus","logistics_bonus","deterrence_bonus","casualty_reduction","defense_bonus","offense_bonus"]:
		mods[key] = float(mods.get(key, 0.0)) + float(effects.get(key, 0.0))
	dev["modifiers"] = mods


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_military_manager(data) -> Dictionary:
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

func _deep_cache_military_manager_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_military_manager"):
		set_meta("cache_military_manager", {})
	var cache = get_meta("cache_military_manager")
	return cache.get(key, null)

func _deep_cache_military_manager_set(key: String, value):
	if not has_meta("cache_military_manager"):
		set_meta("cache_military_manager", {})
	var cache = get_meta("cache_military_manager")
	cache[key] = value
	set_meta("cache_military_manager", cache)

func _deep_log_military_manager(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_military_manager(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_military_manager(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("military_manager"):
		state["military_manager"] = {}
	return state

func _deep_deterministic_military_manager_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_military_manager(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("military_manager_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_military_manager(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("military_manager", {}).duplicate(true) if state.has("military_manager") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_military_manager(data) -> Dictionary:
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

func _deep_cache_military_manager_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_military_manager"):
		set_meta("cache_military_manager", {})
	var cache = get_meta("cache_military_manager")
	return cache.get(key, null)

func _deep_cache_military_manager_set(key: String, value):
	if not has_meta("cache_military_manager"):
		set_meta("cache_military_manager", {})
	var cache = get_meta("cache_military_manager")
	cache[key] = value
	set_meta("cache_military_manager", cache)

func _deep_log_military_manager(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_military_manager(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_military_manager(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("military_manager"):
		state["military_manager"] = {}
	return state

func _deep_deterministic_military_manager_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_military_manager(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("military_manager_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_military_manager(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("military_manager", {}).duplicate(true) if state.has("military_manager") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data


