extends Node
# خلاصه مدیریتی ماه: هزاران محاسبه روزانه را به گزارش قابل فهم و اولویت‌دار تبدیل می‌کند.

const CRITICAL_WORDS = ["crisis", "protest", "war_", "disaster", "collapse", "epidemic", "snow_", "flood", "heatwave", "shortage", "attack", "unrest"]
const POSITIVE_WORDS = ["success", "unlocked", "victory", "agreement", "cleared", "breakthrough", "completed", "saved_lives"]

func build(state: Dictionary, events: Array, turn: int) -> Dictionary:
	var grouped: Dictionary = {}
	var category_counts: Dictionary = {}
	for wrapped in events:
		if not wrapped is Dictionary:
			continue
		var system = str(wrapped.get("system", "other"))
		category_counts[system] = int(category_counts.get(system, 0)) + 1
		var event: Dictionary = wrapped.get("event", {})
		var type = str(event.get("type", "event"))
		var message = str(event.get("message", ""))
		if message.is_empty():
			continue
		var key = "%s:%s" % [system, type]
		if not grouped.has(key):
			grouped[key] = {
				"type":type, "system":system, "message":message,
				"count":0, "priority":_priority(type, float(event.get("severity", 0.0)))
			}
		grouped[key]["count"] = int(grouped[key]["count"]) + 1
	var ranked: Array = grouped.values()
	ranked.sort_custom(func(a, b): return int(a.get("priority", 0)) > int(b.get("priority", 0)))
	var important: Array = []
	for item in ranked:
		if important.size() >= 8:
			break
		important.append(item.duplicate(true))
	var clock: Dictionary = state.get("clock", {})
	var report = {
		"turn":turn,
		"year":int(clock.get("year", 2027)),
		"month":int(clock.get("month", 1)),
		"month_name":TimeManager.month_name(int(clock.get("month", 1))),
		"season":str(state.get("time", {}).get("season", "")),
		"total_events":events.size(),
		"important":important,
		"category_counts":category_counts,
		"gdp_change":AnalyticsManager.get_change(state, "gdp", true),
		"happiness_change":AnalyticsManager.get_change(state, "happiness"),
		"stability_change":AnalyticsManager.get_change(state, "stability"),
		"weather":state.get("weather", {}).get("current", {}).duplicate(true)
	}
	state["monthly_report"] = report
	return state

func summary_message(report: Dictionary) -> String:
	var critical = 0
	for item in report.get("important", []):
		if int(item.get("priority", 0)) >= 3:
			critical += 1
	return "گزارش %s: %s رویداد ثبت شد؛ %s مورد نیازمند توجه فوری است" % [
		report.get("month_name", "ماه"), str(report.get("total_events", 0)), str(critical)]

func _priority(type: String, severity: float) -> int:
	for word in CRITICAL_WORDS:
		if type.contains(word):
			return 4 if severity >= 0.5 else 3
	for word in POSITIVE_WORDS:
		if type.contains(word):
			return 2
	return 1
