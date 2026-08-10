extends Node
# Event Sourcing + CQRS - بخش ۳.۷ لایه ۵
# گزارش تغییرناپذیر برای ممیزی، بازپخش، ضدتقلب
# رویدادهای هر تیک ابتدا در تراکنش نگه داشته می‌شوند و فقط پس از Commit منتشر می‌شوند.

var events: Array = []
var max_events: int = 10000
var _transaction_events: Array = []
var _transaction_active: bool = false

signal event_added(event)

func _ready():
	events = []
	_transaction_events = []
	_transaction_active = false

func begin_transaction() -> bool:
	if _transaction_active:
		return false
	_transaction_events = []
	_transaction_active = true
	return true

func commit_transaction() -> Array:
	if not _transaction_active:
		return []
	var committed: Array = []
	for pending in _transaction_events:
		var evt = pending.duplicate(true)
		evt["id"] = _next_event_id()
		events.append(evt)
		committed.append(evt)
		_trim_to_limit()
		emit_signal("event_added", evt)
	_transaction_events = []
	_transaction_active = false
	return committed

func rollback_transaction():
	_transaction_events = []
	_transaction_active = false

func is_transaction_active() -> bool:
	return _transaction_active

func log_event(type: String, data: Dictionary, tick: int = -1, version: int = -1):
	var evt = {
		"id": -1 if _transaction_active else _next_event_id(),
		"type": type,
		"data": data.duplicate(true),
		"tick": tick,
		"version": version,
		"timestamp": Time.get_unix_time_from_system(),
		"seed": Deterministic.get_state() if Deterministic else 0
	}
	if _transaction_active:
		_transaction_events.append(evt)
	else:
		events.append(evt)
		_trim_to_limit()
		emit_signal("event_added", evt)
	return evt

func _next_event_id() -> int:
	if events.is_empty():
		return 0
	return int(events[-1].get("id", events.size() - 1)) + 1

func _trim_to_limit():
	while events.size() > max_events:
		events.pop_front()

func get_events(filter_type: String = "") -> Array:
	if filter_type == "":
		return events.duplicate(true)
	var filtered = []
	for e in events:
		if e.get("type", "") == filter_type:
			filtered.append(e.duplicate(true))
	return filtered

func get_last(n: int = 10) -> Array:
	var start = max(0, events.size() - n)
	return events.slice(start, events.size()).duplicate(true)

func replay(from_tick: int = 0) -> Array:
	# خروجی مرتب برای بازپخش ممیزی؛ بازسازی Snapshot در SaveManager انجام می‌شود.
	var replay_events = []
	for e in events:
		if int(e.get("tick", -1)) >= from_tick:
			replay_events.append(e.duplicate(true))
	return replay_events

func export_json() -> String:
	return JSON.stringify(events)

func import_events(imported: Array) -> bool:
	var clean: Array = []
	for raw in imported:
		if not raw is Dictionary:
			return false
		if not raw.has("type") or not raw.has("data"):
			return false
		var evt = raw.duplicate(true)
		evt["id"] = clean.size()
		clean.append(evt)
	events = clean
	_trim_to_limit()
	return true

func clear():
	events = []
	rollback_transaction()

func count() -> int:
	return events.size()
