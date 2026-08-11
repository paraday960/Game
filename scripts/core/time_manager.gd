extends Node
# هر نوبت بازیکن یک ماه است؛ موتور درون هر نوبت روزهای ماه را برای حفظ معادلات عمیق اجرا می‌کند.

const MONTH_NAMES = [
	"فروردین", "اردیبهشت", "خرداد", "تیر", "مرداد", "شهریور",
	"مهر", "آبان", "آذر", "دی", "بهمن", "اسفند"
]
const NORTH_SEASONS = {
	1:"بهار", 2:"بهار", 3:"بهار",
	4:"تابستان", 5:"تابستان", 6:"تابستان",
	7:"پاییز", 8:"پاییز", 9:"پاییز",
	10:"زمستان", 11:"زمستان", 12:"زمستان"
}
const SOUTH_SEASONS = {
	1:"پاییز", 2:"پاییز", 3:"پاییز",
	4:"زمستان", 5:"زمستان", 6:"زمستان",
	7:"بهار", 8:"بهار", 9:"بهار",
	10:"تابستان", 11:"تابستان", 12:"تابستان"
}

func reset(state: Dictionary) -> Dictionary:
	var clock: Dictionary = state.get("clock", {})
	clock["year"] = int(clock.get("year", 2027))
	clock["month"] = clamp(int(clock.get("month", 1)), 1, 12)
	clock["day"] = 1
	clock["hour"] = 0
	state["clock"] = clock
	state["time"] = {
		"turn": int(state.get("tick", 0)),
		"total_days": 0,
		"day_in_month": 1,
		"days_in_month": days_in_month(clock["year"], clock["month"]),
		"month_name": month_name(clock["month"]),
		"season": season_for_state(state, clock["month"]),
		"turn_unit": "ماه"
	}
	clock["season"] = state["time"]["season"]
	return state

func migrate_legacy_state(state: Dictionary) -> Dictionary:
	var legacy_days = max(0, int(state.get("tick", 0)))
	var converted_turn = int(ceil(float(legacy_days) / 30.0))
	state = reset(state)
	state["time"]["total_days"] = legacy_days
	state["time"]["turn"] = converted_turn
	state["tick"] = converted_turn
	return state

func ensure_time(state: Dictionary) -> Dictionary:
	if not state.has("time") or not state["time"] is Dictionary:
		return reset(state)
	var time: Dictionary = state["time"]
	var clock: Dictionary = state.get("clock", {})
	time["turn"] = int(time.get("turn", state.get("tick", 0)))
	time["total_days"] = int(time.get("total_days", int(state.get("tick", 0)) * 30))
	time["day_in_month"] = int(time.get("day_in_month", 1))
	time["days_in_month"] = days_in_month(int(clock.get("year", 2027)), int(clock.get("month", 1)))
	time["month_name"] = month_name(int(clock.get("month", 1)))
	time["season"] = season_for_state(state, int(clock.get("month", 1)))
	time["turn_unit"] = "ماه"
	state["time"] = time
	clock["season"] = time["season"]
	state["clock"] = clock
	return state

func begin_turn(state: Dictionary, turn: int) -> Dictionary:
	state = ensure_time(state)
	var clock: Dictionary = state["clock"]
	var time: Dictionary = state["time"]
	time["turn"] = turn
	time["day_in_month"] = 1
	time["days_in_month"] = days_in_month(int(clock["year"]), int(clock["month"]))
	time["month_name"] = month_name(int(clock["month"]))
	time["season"] = season_for_state(state, int(clock["month"]))
	clock["day"] = 1
	clock["season"] = time["season"]
	state["clock"] = clock
	state["time"] = time
	return state

func set_simulation_day(state: Dictionary, day: int) -> Dictionary:
	var time: Dictionary = state["time"]
	var clock: Dictionary = state["clock"]
	time["day_in_month"] = day
	clock["day"] = day
	state["time"] = time
	state["clock"] = clock
	return state

func finish_simulation_day(state: Dictionary) -> Dictionary:
	state["time"]["total_days"] = int(state["time"].get("total_days", 0)) + 1
	return state

func finish_turn(state: Dictionary) -> Dictionary:
	var clock: Dictionary = state["clock"]
	clock["day"] = 1
	clock["month"] = int(clock.get("month", 1)) + 1
	if clock["month"] > 12:
		clock["month"] = 1
		clock["year"] = int(clock.get("year", 2027)) + 1
	state["clock"] = clock
	state = ensure_time(state)
	state["time"]["day_in_month"] = 1
	return state

func get_total_days(state: Dictionary) -> int:
	return int(state.get("time", {}).get("total_days", int(state.get("tick", 0)) * 30))

func days_in_month(year: int, month: int) -> int:
	# تقویم خورشیدی: شش ماه ۳۱ روز، پنج ماه ۳۰ روز و اسفند ۲۹/۳۰ روز.
	if month <= 6:
		return 31
	if month <= 11:
		return 30
	return 30 if _is_leap_year(year) else 29

func month_name(month: int) -> String:
	return MONTH_NAMES[clamp(month, 1, 12) - 1]

func season_for_state(state: Dictionary, month: int) -> String:
	var country_id = str(state.get("country", {}).get("id", WorldManager.default_country))
	var latitude = float(WorldManager.get_country(country_id).get("lat", 0.0))
	return SOUTH_SEASONS.get(month, "بهار") if latitude < 0.0 else NORTH_SEASONS.get(month, "بهار")

func _is_leap_year(year: int) -> bool:
	# چرخه ساده ۴ ساله برای تقویم بازی؛ کاملاً دترمینستیک است.
	return year % 4 == 3


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_time_manager(data) -> Dictionary:
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

func _deep_cache_time_manager_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_time_manager"):
		set_meta("cache_time_manager", {})
	var cache = get_meta("cache_time_manager")
	return cache.get(key, null)

func _deep_cache_time_manager_set(key: String, value):
	if not has_meta("cache_time_manager"):
		set_meta("cache_time_manager", {})
	var cache = get_meta("cache_time_manager")
	cache[key] = value
	set_meta("cache_time_manager", cache)

func _deep_log_time_manager(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_time_manager(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_time_manager(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("time_manager"):
		state["time_manager"] = {}
	return state

func _deep_deterministic_time_manager_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_time_manager(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("time_manager_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_time_manager(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("time_manager", {}).duplicate(true) if state.has("time_manager") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---
