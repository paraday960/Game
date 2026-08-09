extends Node
# Event Sourcing + CQRS - بخش ۳.۷ لایه ۵
# گزارش تغییرناپذیر برای ممیزی، بازپخش، ضدتقلب

var events: Array = []
var max_events: int = 10000

signal event_added(event)

func _ready():
	events = []

func log_event(type: String, data: Dictionary, tick: int = -1, version: int = -1):
	var evt = {
		"id": events.size(),
		"type": type,
		"data": data,
		"tick": tick,
		"version": version,
		"timestamp": Time.get_unix_time_from_system(),
		"seed": Deterministic.get_state() if Deterministic else 0
	}
	events.append(evt)
	if events.size() > max_events:
		events.pop_front()
	emit_signal("event_added", evt)
	return evt

func get_events(filter_type: String = "") -> Array:
	if filter_type == "":
		return events
	var filtered = []
	for e in events:
		if e.type == filter_type:
			filtered.append(e)
	return filtered

func get_last(n: int = 10) -> Array:
	var start = max(0, events.size() - n)
	return events.slice(start, events.size())

func replay(from_tick: int = 0):
	# بازسازی وضعیت از روی گزارش - برای ذخیره/بارگذاری
	var replay_events = []
	for e in events:
		if e.tick >= from_tick:
			replay_events.append(e)
	return replay_events

func export_json() -> String:
	return JSON.stringify(events)

func clear():
	events = []

func count() -> int:
	return events.size()
