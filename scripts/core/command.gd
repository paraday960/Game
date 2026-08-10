extends RefCounted
class_name GameCommand
# فرمان‌محور - بخش ۳.۷ لایه ۶ - فقط فرمان ارسال می‌شود نه وضعیت

var id: String
var type: String
var player_id: String
var tick: int
var version: int
var payload: Dictionary
var timestamp: float

# شمارنده دترمینستیک - بدون randi() تا قفل دترمینستیک نشکند (بخش ۳.۶)
static var _counter: int = 0

func _init(p_type: String, p_payload: Dictionary = {}, p_player_id: String = "player1"):
	type = p_type
	payload = p_payload
	player_id = p_player_id
	tick = 0
	version = 0
	timestamp = Time.get_unix_time_from_system()
	_counter += 1
	id = "%s_%s_%d" % [type, player_id, _counter]

func to_dict() -> Dictionary:
	return {
		"id": id,
		"type": type,
		"player_id": player_id,
		"tick": tick,
		"version": version,
		"payload": payload,
		"timestamp": timestamp
	}

static func from_dict(d: Dictionary):
	var cmd = _self_script().new(d.get("type", "unknown"), d.get("payload", {}), d.get("player_id", "player1"))
	cmd.id = d.get("id", "")
	cmd.tick = d.get("tick", 0)
	cmd.version = d.get("version", 0)
	cmd.timestamp = d.get("timestamp", 0.0)
	return cmd

# لود خودارجاع - سازگار با import سرد
static func _self_script():
	return load("res://scripts/core/command.gd")

# انواع فرمان‌های بازی
static func create_budget_allocate(allocations: Dictionary):
	return _self_script().new("budget_allocate", {"allocations": allocations})

static func create_tax_set(rate: float):
	return _self_script().new("tax_set", {"rate": rate})

static func create_monetary_policy(mode: String, value: float = 0.0):
	return _self_script().new("monetary_policy", {"mode": mode, "value": value})

static func create_tariff_set(rate: float):
	return _self_script().new("tariff_set", {"rate": rate})

static func create_research_start(tech_id: String):
	return _self_script().new("research_start", {"tech_id": tech_id})

static func create_diplomacy_action(target: String, action: String):
	return _self_script().new("diplomacy", {"target": target, "action": action})

static func create_country_select(country_id: String, scenario_id: String = "balanced"):
	return _self_script().new("country_select", {"country_id": country_id, "scenario_id": scenario_id})

static func create_policy_change(policy_id: String, enabled: bool):
	return _self_script().new("policy_change", {"policy_id": policy_id, "enabled": enabled})

static func create_municipal_action(action: String):
	return _self_script().new("municipal_action", {"action": action})

static func create_military_program(program_id: String):
	return _self_script().new("military_program", {"program_id": program_id})

static func create_military_doctrine(doctrine: String):
	return _self_script().new("military_doctrine", {"doctrine": doctrine})

static func create_national_project(project_id: String):
	return _self_script().new("national_project", {"project_id": project_id, "action": "start"})

static func create_project_cancel(project_id: String):
	return _self_script().new("national_project", {"project_id": project_id, "action": "cancel"})

static func create_cabinet_appointment(ministry_id: String, candidate_id: String):
	return _self_script().new("cabinet_change", {"ministry_id": ministry_id, "candidate_id": candidate_id, "action": "appoint"})

static func create_cabinet_dismissal(ministry_id: String):
	return _self_script().new("cabinet_change", {"ministry_id": ministry_id, "candidate_id": "", "action": "dismiss"})

static func create_law_change(law_id: String, action: String):
	return _self_script().new("law_change", {"law_id": law_id, "action": action})

static func create_decision_resolve(decision_id: String, choice_id: String):
	return _self_script().new("decision_resolve", {"decision_id": decision_id, "choice_id": choice_id})

static func create_next_tick():
	return _self_script().new("next_tick", {})
