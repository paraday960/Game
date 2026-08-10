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

static func create_research_start(tech_id: String):
	return _self_script().new("research_start", {"tech_id": tech_id})

static func create_diplomacy_action(target: String, action: String):
	return _self_script().new("diplomacy", {"target": target, "action": action})

static func create_next_tick():
	return _self_script().new("next_tick", {})
