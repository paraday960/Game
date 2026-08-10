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
			country_polygons.append({"outer": outer, "holes": holes})
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
