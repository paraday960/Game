extends RefCounted
class_name BaseSystem
# کلاس پایه برای تمام ۳۳ سیستم - ۲.۲.۶ و ۲.۲.۷

func compute(state: Dictionary, tick: int) -> Dictionary:
	# باید در کلاس‌های فرزند override شود
	return {"success": true, "state": state, "events": []}

func log_event(state: Dictionary, event_type: String, data: Dictionary):
	return {
		"type": event_type,
		"data": data,
		"tick": state.get("tick", 0)
	}

func clamp01(v: float) -> float:
	return clamp(v, 0.0, 1.0)
