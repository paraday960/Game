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

func _init(p_type: String, p_payload: Dictionary = {}, p_player_id: String = "player1"):
	type = p_type
	payload = p_payload
	player_id = p_player_id
	tick = 0
	version = 0
	timestamp = Time.get_unix_time_from_system()
	id = "%s_%d_%d" % [type, tick, randi() % 1000000]

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

static func from_dict(d: Dictionary) -> GameCommand:
	var cmd = GameCommand.new(d.get("type", "unknown"), d.get("payload", {}), d.get("player_id", "player1"))
	cmd.id = d.get("id", "")
	cmd.tick = d.get("tick", 0)
	cmd.version = d.get("version", 0)
	cmd.timestamp = d.get("timestamp", 0.0)
	return cmd

# انواع فرمان‌های بازی
static func create_budget_allocate(allocations: Dictionary) -> GameCommand:
	return GameCommand.new("budget_allocate", {"allocations": allocations})

static func create_tax_set(rate: float) -> GameCommand:
	return GameCommand.new("tax_set", {"rate": rate})

static func create_research_start(tech_id: String) -> GameCommand:
	return GameCommand.new("research_start", {"tech_id": tech_id})

static func create_diplomacy_action(target: String, action: String) -> GameCommand:
	return GameCommand.new("diplomacy", {"target": target, "action": action})

static func create_next_tick() -> GameCommand:
	return GameCommand.new("next_tick", {})
