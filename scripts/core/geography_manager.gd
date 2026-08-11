extends Node
# هندسه اختصاصی نقشه بازی: چندضلعی واقعی، مرز، Hit-test و نمای منطقه‌ای

const DATA_PATH = "res://data/world_polygons.json"
var polygons: Dictionary = {} # ISO3 -> [{outer:PackedVector2Array, holes:Array}]
var bounds: Dictionary = {}   # ISO3 -> Rect2 in normalized Web Mercator
var data_version := ""
var source_info: Dictionary = {}
var load_errors: Array = []

func _ready():
	reload()

func reload() -> bool:
	polygons.clear()
	bounds.clear()
	load_errors.clear()
	var file = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		load_errors.append("فایل چندضلعی نقشه خوانده نشد")
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or not parsed.get("countries", null) is Dictionary:
		load_errors.append("ساختار چندضلعی نقشه نامعتبر است")
		return false
	data_version = str(parsed.get("version", "1.0.0"))
	source_info = parsed.get("source", {}).duplicate(true)
	for code in parsed["countries"].keys():
		var country_polygons: Array = []
		var minp = Vector2(1, 1)
		var maxp = Vector2(0, 0)
		for raw_polygon in parsed["countries"][code]:
			var outer = _project_ring(raw_polygon.get("outer", []))
			if outer.size() < 3:
				continue
			var holes: Array = []
			for raw_hole in raw_polygon.get("holes", []):
				var hole = _project_ring(raw_hole)
				if hole.size() >= 3:
					holes.append(hole)
			for point in outer:
				minp.x = min(minp.x, point.x); minp.y = min(minp.y, point.y)
				maxp.x = max(maxp.x, point.x); maxp.y = max(maxp.y, point.y)
			var fill_ring = outer.duplicate()
			if fill_ring.size() > 2 and fill_ring[0].is_equal_approx(fill_ring[fill_ring.size() - 1]):
				fill_ring.resize(fill_ring.size() - 1)
			country_polygons.append({"outer": outer, "holes": holes, "fillable": not Geometry2D.triangulate_polygon(fill_ring).is_empty()})
		if country_polygons.is_empty():
			load_errors.append("چندضلعی کشور %s خالی است" % code)
			continue
		polygons[code] = country_polygons
		bounds[code] = Rect2(minp, maxp - minp)
	return load_errors.is_empty()

func is_valid() -> bool:
	return polygons.size() == 195 and load_errors.is_empty()

func get_polygons(code: String) -> Array:
	return polygons.get(code, [])

func get_bounds(code: String) -> Rect2:
	return bounds.get(code, Rect2())

func country_at_normalized(point: Vector2, allowed: Array = []) -> String:
	var ids = allowed if not allowed.is_empty() else polygons.keys()
	# کشورهای کوچک‌تر ابتدا بررسی می‌شوند تا زیر چندضلعی کشورهای بزرگ گم نشوند.
	var candidates: Array = []
	for code in ids:
		var box: Rect2 = bounds.get(code, Rect2())
		if box.has_point(point):
			candidates.append({"code": code, "area": box.size.x * box.size.y})
	candidates.sort_custom(func(a, b): return float(a.area) < float(b.area))
	for candidate in candidates:
		for polygon in polygons.get(candidate.code, []):
			if not Geometry2D.is_point_in_polygon(point, polygon.outer):
				continue
			var inside_hole = false
			for hole in polygon.holes:
				if Geometry2D.is_point_in_polygon(point, hole):
					inside_hole = true
					break
			if not inside_hole:
				return str(candidate.code)
	return ""

func normalized_point(lon: float, lat: float) -> Vector2:
	lon = clamp(lon, -180.0, 180.0)
	lat = clamp(lat, -80.0, 80.0)
	var mercator = log(tan(PI / 4.0 + deg_to_rad(lat) / 2.0))
	return Vector2((lon + 180.0) / 360.0, clamp(0.5 - mercator / (2.0 * PI), 0.02, 0.98))

func _project_ring(raw: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for coordinate in raw:
		if coordinate is Array and coordinate.size() >= 2:
			result.append(normalized_point(float(coordinate[0]), float(coordinate[1])))
	return result


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_geography_manager(data) -> Dictionary:
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

func _deep_cache_geography_manager_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_geography_manager"):
		set_meta("cache_geography_manager", {})
	var cache = get_meta("cache_geography_manager")
	return cache.get(key, null)

func _deep_cache_geography_manager_set(key: String, value):
	if not has_meta("cache_geography_manager"):
		set_meta("cache_geography_manager", {})
	var cache = get_meta("cache_geography_manager")
	cache[key] = value
	set_meta("cache_geography_manager", cache)

func _deep_log_geography_manager(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_geography_manager(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_geography_manager(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("geography_manager"):
		state["geography_manager"] = {}
	return state

func _deep_deterministic_geography_manager_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_geography_manager(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("geography_manager_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_geography_manager(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("geography_manager", {}).duplicate(true) if state.has("geography_manager") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---
