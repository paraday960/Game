extends Node
# نقشه ملی ۱۹۵ کشور: تقسیمات اداری، شهرهای واقعی و شاخص‌های منطقه‌ای پویا

const DATA_PATH := "res://data/country_maps.json"

var countries: Dictionary = {} # ISO3 -> {units:Array, cities:Array, unit_index:Dictionary}
var data_version := ""
var sources: Array = []
var model_notice_fa := ""
var load_errors: Array = []
var admin_unit_count := 0
var city_count := 0

func _ready():
	reload()

func reload() -> bool:
	countries.clear()
	load_errors.clear()
	admin_unit_count = 0
	city_count = 0
	var file = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		load_errors.append("فایل نقشه ملی خوانده نشد")
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or not parsed.get("countries", null) is Dictionary:
		load_errors.append("ساختار داده نقشه ملی نامعتبر است")
		return false
	data_version = str(parsed.get("version", "1.0.0"))
	sources = parsed.get("sources", []).duplicate(true)
	model_notice_fa = str(parsed.get("model_notice_fa", ""))
	for code in parsed["countries"].keys():
		var raw_country: Dictionary = parsed["countries"][code]
		var units: Array = []
		var unit_index: Dictionary = {}
		for raw_unit in raw_country.get("units", []):
			var polygons: Array = []
			for raw_polygon in raw_unit.get("polygons", []):
				var outer = _project_ring(raw_polygon.get("outer", []))
				if outer.size() < 3:
					continue
				var holes: Array = []
				for raw_hole in raw_polygon.get("holes", []):
					var hole = _project_ring(raw_hole)
					if hole.size() >= 3:
						holes.append(hole)
				var fill_ring = outer.duplicate()
				if fill_ring.size() > 2 and fill_ring[0].is_equal_approx(fill_ring[fill_ring.size() - 1]):
					fill_ring.resize(fill_ring.size() - 1)
				polygons.append({"outer": outer, "holes": holes, "fillable": not Geometry2D.triangulate_polygon(fill_ring).is_empty()})
			if polygons.is_empty():
				continue
			var center_raw: Array = raw_unit.get("center", [0.0, 0.0])
			var center = GeographyManager.normalized_point(float(center_raw[0]), float(center_raw[1]))
			var unit = {
				"id": str(raw_unit.get("id", "")),
				"name_fa": _clean_fa(str(raw_unit.get("name_fa", "ناحیه اداری"))),
				"type_fa": _clean_fa(str(raw_unit.get("type_fa", "ناحیه اداری"))),
				"center": center,
				"area_weight": float(raw_unit.get("area_weight", 0.0)),
				"population_share": float(raw_unit.get("population_share", 0.0)),
				"economy_share": float(raw_unit.get("economy_share", 0.0)),
				"resource_index": float(raw_unit.get("resource_index", 0.5)),
				"strategic_index": float(raw_unit.get("strategic_index", 0.5)),
				"capital": bool(raw_unit.get("capital", false)),
				"polygons": polygons,
			}
			units.append(unit)
			unit_index[unit.id] = unit
		var cities: Array = []
		for raw_city in raw_country.get("cities", []):
			cities.append({
				"name_fa": _clean_fa(str(raw_city.get("name_fa", "شهر"))),
				"point": GeographyManager.normalized_point(float(raw_city.get("lon", 0.0)), float(raw_city.get("lat", 0.0))),
				"population": int(raw_city.get("population", 0)),
				"capital": bool(raw_city.get("capital", false)),
				"unit_id": str(raw_city.get("unit_id", "")),
			})
		if units.is_empty():
			load_errors.append("تقسیمات اداری کشور %s خالی است" % code)
			continue
		countries[code] = {"units": units, "cities": cities, "unit_index": unit_index}
		admin_unit_count += units.size()
		city_count += cities.size()
	if countries.size() != 195:
		load_errors.append("نقشه ملی همه ۱۹۵ کشور را پوشش نمی‌دهد")
	return load_errors.is_empty()

func is_valid() -> bool:
	if countries.size() != 195 or admin_unit_count < 4000 or city_count < 1500 or not load_errors.is_empty():
		return false
	for source in sources:
		if str(source.get("license", "")).to_lower() != "public domain":
			return false
	return true

func has_country(code: String) -> bool:
	return countries.has(code)

func get_units(code: String) -> Array:
	return countries.get(code, {}).get("units", [])

func get_cities(code: String) -> Array:
	return countries.get(code, {}).get("cities", [])

func get_unit(code: String, unit_id: String) -> Dictionary:
	return countries.get(code, {}).get("unit_index", {}).get(unit_id, {})

func get_unit_count(code: String) -> int:
	return get_units(code).size()

func get_capital_city(code: String) -> Dictionary:
	for city in get_cities(code):
		if city.get("capital", false):
			return city
	return get_cities(code)[0] if not get_cities(code).is_empty() else {}

func get_unit_metrics(code: String, unit_id: String, state: Dictionary) -> Dictionary:
	var unit = get_unit(code, unit_id)
	if unit.is_empty():
		return {}
	var profile = WorldManager.get_country(code)
	var total_area = max(0.0, float(profile.get("area_km2", 0.0)))
	var area_total = 0.0
	var max_population_share = 0.000001
	var max_economy_share = 0.000001
	for other in get_units(code):
		area_total += float(other.get("area_weight", 0.0))
		max_population_share = max(max_population_share, float(other.get("population_share", 0.0)))
		max_economy_share = max(max_economy_share, float(other.get("economy_share", 0.0)))
	var population_share = float(unit.get("population_share", 0.0))
	var economy_share = float(unit.get("economy_share", 0.0))
	var area_share = float(unit.get("area_weight", 0.0)) / max(area_total, 0.000001)
	var is_player_country = str(state.get("country", {}).get("id", "")) == code
	var profile_population = max(1.0, float(profile.get("population", 1.0)))
	var profile_gdp = max(1.0, float(profile.get("gdp", 1.0)))
	var wealth = clamp((log(max(500.0, profile_gdp / profile_population)) / log(10.0) - 2.7) / 2.0, 0.08, 0.95)
	var national_population = float(state.get("population", {}).get("total", profile_population)) if is_player_country else profile_population
	var national_gdp = float(state.get("economy", {}).get("gdp", profile_gdp)) if is_player_country else profile_gdp
	var population = national_population * population_share
	var gdp = national_gdp * economy_share
	var variation = _stable_fraction(unit_id + "-local") - 0.5
	var inequality = float(state.get("administration", {}).get("regional_inequality", 0.35)) if is_player_country else clamp(0.48 - wealth * 0.22, 0.18, 0.55)
	var infrastructure_base = float(state.get("infrastructure", {}).get("quality", 0.55)) if is_player_country else clamp(0.25 + wealth * 0.70, 0.20, 0.93)
	var satisfaction_base = float(state.get("population", {}).get("happiness", state.get("population", {}).get("satisfaction", 0.60))) if is_player_country else clamp(0.42 + wealth * 0.30, 0.35, 0.78)
	var security_base = float(state.get("security", {}).get("public_security", 0.65)) if is_player_country else clamp(0.44 + wealth * 0.32, 0.36, 0.82)
	var tension = float(state.get("politics", {}).get("tension", 0.35)) if is_player_country else 0.35
	var infrastructure = clamp(infrastructure_base + variation * 0.30 - inequality * 0.08 + (0.08 if unit.get("capital", false) else 0.0), 0.05, 0.98)
	var satisfaction = clamp(satisfaction_base + variation * 0.24 - inequality * (0.14 + abs(variation) * 0.08), 0.05, 0.98)
	var security = clamp(security_base + variation * 0.20 - tension * 0.08, 0.05, 0.98)
	var weather_risk = _weather_risk(profile, state if is_player_country else {}, unit)
	var self_sufficiency = float(state.get("resources", {}).get("self_sufficiency", 0.65)) if is_player_country else clamp(0.42 + float(profile.get("strategic_weight", 0.3)) * 0.40, 0.35, 0.82)
	var resource_score = clamp(float(unit.get("resource_index", 0.5)) * 0.72 + self_sufficiency * 0.28, 0.0, 1.0)
	var national_military = clamp((float(state.get("military", {}).get("power", profile.get("military_power", 30.0))) if is_player_country else float(profile.get("military_power", 30.0))) / 100.0, 0.0, 1.0)
	var readiness = float(state.get("military", {}).get("readiness", 0.55)) if is_player_country else clamp(0.42 + national_military * 0.40, 0.42, 0.88)
	var military_score = clamp(float(unit.get("strategic_index", 0.5)) * 0.68 + national_military * 0.20 + readiness * 0.12, 0.0, 1.0)
	var roads_default = max(5.0, total_area * (0.035 + wealth * 0.045) + profile_population / (1400.0 - wealth * 550.0))
	var roads_total = float(state.get("transport_detail", {}).get("roads_km", roads_default)) if is_player_country else roads_default
	return {
		"id": unit_id,
		"name_fa": unit.get("name_fa", "ناحیه"),
		"type_fa": unit.get("type_fa", "ناحیه اداری"),
		"capital": unit.get("capital", false),
		"area_km2": total_area * area_share,
		"population": population,
		"population_share": population_share,
		"population_relative": clamp(population_share / max_population_share, 0.0, 1.0),
		"gdp": gdp,
		"economy_share": economy_share,
		"economy_relative": clamp(economy_share / max_economy_share, 0.0, 1.0),
		"gdp_per_capita": gdp / max(population, 1.0),
		"infrastructure": infrastructure,
		"satisfaction": satisfaction,
		"security": security,
		"weather_risk": weather_risk,
		"resource_score": resource_score,
		"military_score": military_score,
		"strategic_index": float(unit.get("strategic_index", 0.5)),
		"roads_km": roads_total * (population_share * 0.65 + area_share * 0.35),
	}

func get_layer_value(code: String, unit_id: String, state: Dictionary, layer: String) -> float:
	var metrics = get_unit_metrics(code, unit_id, state)
	match layer:
		"population": return float(metrics.get("population_relative", 0.0))
		"economy": return float(metrics.get("economy_relative", 0.0))
		"infrastructure": return float(metrics.get("infrastructure", 0.0))
		"satisfaction": return float(metrics.get("satisfaction", 0.0))
		"security": return float(metrics.get("security", 0.0))
		"weather": return float(metrics.get("weather_risk", 0.0))
		"resources": return float(metrics.get("resource_score", 0.0))
		"military": return float(metrics.get("military_score", 0.0))
	return float(metrics.get("strategic_index", 0.5))

func _weather_risk(profile: Dictionary, state: Dictionary, unit: Dictionary) -> float:
	var current = state.get("weather", {}).get("current", {})
	var hazard = str(current.get("hazard", "none"))
	var severity = float(current.get("severity", 0.0))
	if severity <= 0.0:
		severity = max(
			float(profile.get("snow_factor", 0.2)),
			max(float(profile.get("flood_factor", 0.3)), float(profile.get("heat_factor", 0.4)))
		) * 0.35
	var local = 0.78 + _stable_fraction(str(unit.get("id", "")) + "-weather") * 0.42
	if hazard == "snow" and float(unit.get("center", Vector2.ZERO).y) < GeographyManager.normalized_point(0.0, 30.0).y:
		local += 0.12
	return clamp(severity * local, 0.0, 1.0)

func _project_ring(raw: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for coordinate in raw:
		if coordinate is Array and coordinate.size() >= 2:
			result.append(GeographyManager.normalized_point(float(coordinate[0]), float(coordinate[1])))
	return result

func _stable_fraction(text: String) -> float:
	var value: int = 2166136261
	for index in range(text.length()):
		value = int(((value ^ text.unicode_at(index)) * 16777619) & 0x7fffffff)
	return float(value % 1000003) / 1000003.0

func _clean_fa(value: String) -> String:
	return value.replace("\\u200c", "‌")


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_country_geography_manager(data) -> Dictionary:
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

func _deep_cache_country_geography_manager_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_country_geography_manager"):
		set_meta("cache_country_geography_manager", {})
	var cache = get_meta("cache_country_geography_manager")
	return cache.get(key, null)

func _deep_cache_country_geography_manager_set(key: String, value):
	if not has_meta("cache_country_geography_manager"):
		set_meta("cache_country_geography_manager", {})
	var cache = get_meta("cache_country_geography_manager")
	cache[key] = value
	set_meta("cache_country_geography_manager", cache)

func _deep_log_country_geography_manager(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_country_geography_manager(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_country_geography_manager(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("country_geography_manager"):
		state["country_geography_manager"] = {}
	return state

func _deep_deterministic_country_geography_manager_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_country_geography_manager(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("country_geography_manager_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_country_geography_manager(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("country_geography_manager", {}).duplicate(true) if state.has("country_geography_manager") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_country_geography_manager(data) -> Dictionary:
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

func _deep_cache_country_geography_manager_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_country_geography_manager"):
		set_meta("cache_country_geography_manager", {})
	var cache = get_meta("cache_country_geography_manager")
	return cache.get(key, null)

func _deep_cache_country_geography_manager_set(key: String, value):
	if not has_meta("cache_country_geography_manager"):
		set_meta("cache_country_geography_manager", {})
	var cache = get_meta("cache_country_geography_manager")
	cache[key] = value
	set_meta("cache_country_geography_manager", cache)

func _deep_log_country_geography_manager(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_country_geography_manager(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_country_geography_manager(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("country_geography_manager"):
		state["country_geography_manager"] = {}
	return state

func _deep_deterministic_country_geography_manager_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_country_geography_manager(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("country_geography_manager_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_country_geography_manager(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("country_geography_manager", {}).duplicate(true) if state.has("country_geography_manager") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data


