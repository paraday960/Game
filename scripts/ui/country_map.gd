extends Control
# نمای ملی: مرز واقعی، تقسیمات اداری، شهرها و لایه‌های زنده کشور بازیکن

signal unit_selected(unit_id)

const PersianFont = preload("res://assets/fonts/Vazirmatn-Regular.ttf")
const OCEAN := Color(0.018, 0.075, 0.115)
const LAND_BASE := Color(0.12, 0.20, 0.23)

var country_code := ""
var full_state: Dictionary = {}
var active_layer := "administrative"
var show_cities := true
var show_transport := true
var selected_unit := ""
var hovered_unit := ""
var hovered_city: Dictionary = {}
var _map_rect := Rect2()
var _view_bounds := Rect2()
var _center_x := 0.5
var _unit_screen_records: Array = []
var _city_screen_records: Array = []

func _ready():
	custom_minimum_size = Vector2(0, 650)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	resized.connect(queue_redraw)
	queue_redraw()

func set_country_data(code: String, state: Dictionary, layer: String = "administrative", cities_visible: bool = true, transport_visible: bool = true):
	country_code = code
	full_state = state
	active_layer = layer
	show_cities = cities_visible
	show_transport = transport_visible
	var profile = WorldManager.get_country(country_code)
	_center_x = GeographyManager.normalized_point(float(profile.get("lon", 0.0)), float(profile.get("lat", 0.0))).x
	_view_bounds = _calculate_view_bounds()
	var units = CountryGeographyManager.get_units(country_code)
	if selected_unit == "" or CountryGeographyManager.get_unit(country_code, selected_unit).is_empty():
		for unit in units:
			if unit.get("capital", false):
				selected_unit = str(unit.get("id", ""))
				break
		if selected_unit == "" and not units.is_empty():
			selected_unit = str(units[0].get("id", ""))
	queue_redraw()

func _draw():
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.008, 0.025, 0.045), true)
	if country_code == "" or _view_bounds.size.x <= 0.0 or _view_bounds.size.y <= 0.0:
		_draw_centered_message("داده نقشه ملی در دسترس نیست")
		return
	var logical_size = Vector2(max(0.02, _view_bounds.size.x), max(0.02, _view_bounds.size.y))
	_map_rect = _fit_rect(logical_size, size - Vector2(24, 62))
	_map_rect.position += Vector2(12, 10)
	draw_rect(_map_rect, OCEAN, true)
	_draw_national_outline(true)
	_unit_screen_records.clear()
	_draw_admin_units()
	if show_transport:
		_draw_transport_network()
	if active_layer in ["resources", "military"]:
		_draw_special_markers()
	_city_screen_records.clear()
	if show_cities:
		_draw_cities()
	_draw_national_outline(false)
	_draw_legend()
	if not hovered_city.is_empty() or hovered_unit != "":
		_draw_tooltip()

func _draw_national_outline(fill: bool):
	for polygon in GeographyManager.get_polygons(country_code):
		var outer = _screen_ring(polygon.outer)
		if outer.size() < 3:
			continue
		if fill and not Geometry2D.triangulate_polygon(outer).is_empty():
			draw_colored_polygon(outer, LAND_BASE)
			for hole in polygon.holes:
				var screen_hole = _screen_ring(hole)
				if screen_hole.size() >= 3 and not Geometry2D.triangulate_polygon(screen_hole).is_empty():
					draw_colored_polygon(screen_hole, OCEAN)
		if not fill:
			var border = outer.duplicate()
			border.append(outer[0])
			draw_polyline(border, Color(0.72, 0.90, 0.98), 2.4, true)

func _draw_admin_units():
	for unit in CountryGeographyManager.get_units(country_code):
		var unit_id = str(unit.get("id", ""))
		var fill = _unit_fill(unit)
		var border = Color(0.36, 0.54, 0.59, 0.82)
		var width = 0.85
		if unit_id == selected_unit:
			fill = fill.lightened(0.14)
			border = Color(1.0, 0.84, 0.24)
			width = 2.2
		elif unit_id == hovered_unit:
			fill = fill.lightened(0.10)
			border = Color.WHITE
			width = 1.8
		for polygon in unit.get("polygons", []):
			var outer = _screen_ring(polygon.outer)
			if outer.size() < 3:
				continue
			if not Geometry2D.triangulate_polygon(outer).is_empty():
				draw_colored_polygon(outer, fill)
				_unit_screen_records.append({"id": unit_id, "outer": outer})
			for hole in polygon.holes:
				var screen_hole = _screen_ring(hole)
				if screen_hole.size() >= 3 and not Geometry2D.triangulate_polygon(screen_hole).is_empty():
					draw_colored_polygon(screen_hole, OCEAN)
			var ring = outer.duplicate()
			ring.append(outer[0])
			draw_polyline(ring, border, width, true)

func _unit_fill(unit: Dictionary) -> Color:
	var unit_id = str(unit.get("id", ""))
	if active_layer == "administrative":
		var tone = _stable_fraction(unit_id)
		return Color(0.12 + tone * 0.14, 0.27 + tone * 0.12, 0.31 + tone * 0.10, 0.97)
	var value = CountryGeographyManager.get_layer_value(country_code, unit_id, full_state, active_layer)
	match active_layer:
		"population": return _gradient(Color(0.08, 0.18, 0.25), Color(0.12, 0.86, 1.0), value)
		"economy": return _gradient(Color(0.10, 0.20, 0.18), Color(0.25, 0.95, 0.46), value)
		"infrastructure": return _status_color(value)
		"satisfaction": return _status_color(value)
		"security": return _gradient(Color(0.55, 0.12, 0.16), Color(0.20, 0.72, 0.95), value)
		"weather": return _gradient(Color(0.12, 0.45, 0.62), Color(0.95, 0.20, 0.13), value)
		"resources": return _gradient(Color(0.19, 0.16, 0.24), Color(0.96, 0.69, 0.16), value)
		"military": return _gradient(Color(0.15, 0.17, 0.23), Color(0.88, 0.20, 0.26), value)
	return LAND_BASE

func _draw_transport_network():
	var cities = CountryGeographyManager.get_cities(country_code)
	if cities.is_empty():
		return
	var capital = CountryGeographyManager.get_capital_city(country_code)
	if capital.is_empty():
		capital = cities[0]
	var start = _normalized_to_screen(capital.point)
	var transport = full_state.get("transport_detail", {})
	var road_quality = float(transport.get("roads_quality", full_state.get("infrastructure", {}).get("quality", 0.55)))
	var rail_quality = float(transport.get("rail_quality", 0.45))
	var road_color = _gradient(Color(0.72, 0.30, 0.16, 0.72), Color(0.98, 0.84, 0.34, 0.84), road_quality)
	for index in range(1, min(9, cities.size())):
		var destination = _normalized_to_screen(cities[index].point)
		if not _map_rect.has_point(destination):
			continue
		var route = _curve_points(start, destination, (index % 2) * 2.0 - 1.0)
		draw_polyline(route, Color(0.01, 0.03, 0.04, 0.72), 4.2, true)
		draw_polyline(route, road_color, 1.8, true)
		if index <= 5:
			_draw_dashed(route, Color(0.82, 0.92, 1.0, 0.72), 0.9 + rail_quality)
	# مراکز راهبردی واقعی Natural Earth/داده بازی؛ در نبود هاب، پایتخت فرودگاه ملی است.
	var air_hubs = MapLayerManager.get_hubs("air", [country_code])
	if air_hubs.is_empty():
		_draw_hub(start, Color(0.16, 0.88, 1.0), "هوایی")
	else:
		for hub in air_hubs:
			_draw_hub(_geo_point(float(hub.get("lon", 0.0)), float(hub.get("lat", 0.0))), Color(0.16, 0.88, 1.0), "هوایی")
	var sea_hubs = MapLayerManager.get_hubs("sea", [country_code])
	for hub in sea_hubs:
		_draw_hub(_geo_point(float(hub.get("lon", 0.0)), float(hub.get("lat", 0.0))), Color(0.22, 0.52, 1.0), "دریایی")
	if sea_hubs.is_empty() and not WorldManager.get_country(country_code).get("landlocked", false):
		var coast = _nearest_coast_point(capital.point)
		if coast != Vector2.ZERO:
			_draw_hub(_normalized_to_screen(coast), Color(0.22, 0.52, 1.0), "دسترسی دریایی")

func _draw_hub(point: Vector2, color: Color, _kind: String):
	if not _map_rect.grow(5).has_point(point):
		return
	draw_circle(point, 6.5, Color(0.01, 0.025, 0.04, 0.92))
	draw_circle(point, 4.0, color)
	draw_arc(point, 7.5, 0.0, TAU, 16, Color(color.r, color.g, color.b, 0.55), 1.2)

func _draw_special_markers():
	var ranked: Array = []
	for unit in CountryGeographyManager.get_units(country_code):
		var value = CountryGeographyManager.get_layer_value(country_code, str(unit.id), full_state, active_layer)
		ranked.append({"unit": unit, "value": value})
	ranked.sort_custom(func(a, b): return float(a.value) > float(b.value))
	for index in range(min(5, ranked.size())):
		var point = _normalized_to_screen(ranked[index].unit.center)
		if not _map_rect.has_point(point):
			continue
		var color = Color(1.0, 0.76, 0.22) if active_layer == "resources" else Color(1.0, 0.28, 0.26)
		draw_circle(point, 7.0, Color(0.02, 0.03, 0.05, 0.9))
		draw_arc(point, 5.0, 0.0, TAU, 6 if active_layer == "resources" else 4, color, 2.3)

func _draw_cities():
	var cities = CountryGeographyManager.get_cities(country_code)
	for index in range(cities.size()):
		var city: Dictionary = cities[index]
		var point = _normalized_to_screen(city.point)
		if not _map_rect.has_point(point):
			continue
		var capital = bool(city.get("capital", false))
		var population = float(city.get("population", 0))
		var radius = 4.0 + clamp(log(max(population, 10.0)) / log(10.0) - 4.0, 0.0, 3.0)
		if capital:
			radius = max(radius, 7.0)
		draw_circle(point, radius + 2.2, Color(0.01, 0.025, 0.04, 0.92))
		draw_circle(point, radius, Color(1.0, 0.83, 0.24) if capital else Color(0.92, 0.96, 1.0))
		_city_screen_records.append({"city": city, "point": point, "radius": radius + 5.0})
		if capital or index < 5:
			var label = ("پایتخت: " if capital else "") + str(city.get("name_fa", "شهر"))
			var label_pos = point + Vector2(9, -8 if index % 2 == 0 else 15)
			draw_string(PersianFont, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.94, 0.72) if capital else Color(0.88, 0.93, 0.98))

func _draw_legend():
	var title = _layer_name(active_layer)
	var y = size.y - 19.0
	draw_string(PersianFont, Vector2(14, y), title, HORIZONTAL_ALIGNMENT_LEFT, 175, 14, Color.WHITE)
	if active_layer != "administrative":
		var left = 190.0
		for index in range(8):
			var value = float(index) / 7.0
			var fake_unit = {"id": "legend-%d" % index}
			var color: Color
			match active_layer:
				"population": color = _gradient(Color(0.08, 0.18, 0.25), Color(0.12, 0.86, 1.0), value)
				"economy": color = _gradient(Color(0.10, 0.20, 0.18), Color(0.25, 0.95, 0.46), value)
				"infrastructure", "satisfaction": color = _status_color(value)
				"security": color = _gradient(Color(0.55, 0.12, 0.16), Color(0.20, 0.72, 0.95), value)
				"weather": color = _gradient(Color(0.12, 0.45, 0.62), Color(0.95, 0.20, 0.13), value)
				"resources": color = _gradient(Color(0.19, 0.16, 0.24), Color(0.96, 0.69, 0.16), value)
				_: color = _gradient(Color(0.15, 0.17, 0.23), Color(0.88, 0.20, 0.26), value)
			draw_rect(Rect2(left + index * 24, y - 13, 25, 9), color, true)
		draw_string(PersianFont, Vector2(left + 205, y), "زیاد", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.90, 0.95))
		draw_string(PersianFont, Vector2(left - 35, y), "کم", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.90, 0.95))
	if show_transport:
		draw_line(Vector2(size.x - 205, y - 6), Vector2(size.x - 175, y - 6), Color(0.98, 0.84, 0.34), 2.0)
		draw_string(PersianFont, Vector2(size.x - 168, y), "راه/ریل مدل‌شده", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.90, 0.95))

func _draw_tooltip():
	var label := ""
	if not hovered_city.is_empty():
		label = ("پایتخت — " if hovered_city.get("capital", false) else "شهر — ") + str(hovered_city.get("name_fa", ""))
		if int(hovered_city.get("population", 0)) > 0:
			label += " | جمعیت جغرافیایی: " + PersianFormatter.format_large(float(hovered_city.population))
	elif hovered_unit != "":
		var metrics = CountryGeographyManager.get_unit_metrics(country_code, hovered_unit, full_state)
		label = "%s %s | %s: %s" % [metrics.get("type_fa", "ناحیه"), metrics.get("name_fa", ""), _layer_name(active_layer), _layer_metric_text(metrics)]
	if label == "":
		return
	var point = get_local_mouse_position() + Vector2(14, -14)
	var width = min(520.0, 110.0 + label.length() * 7.0)
	if point.x + width > size.x:
		point.x -= width + 24.0
	if point.y < 30.0:
		point.y += 45.0
	draw_rect(Rect2(point - Vector2(6, 20), Vector2(width, 32)), Color(0.005, 0.018, 0.035, 0.96), true)
	draw_string(PersianFont, point, label, HORIZONTAL_ALIGNMENT_LEFT, width - 8, 14, Color.WHITE)

func _layer_metric_text(metrics: Dictionary) -> String:
	match active_layer:
		"population": return PersianFormatter.format_large(float(metrics.get("population", 0))) + " نفر"
		"economy": return PersianFormatter.format_money(float(metrics.get("gdp", 0)))
		"infrastructure": return _percent(float(metrics.get("infrastructure", 0)))
		"satisfaction": return _percent(float(metrics.get("satisfaction", 0)))
		"security": return _percent(float(metrics.get("security", 0)))
		"weather": return _percent(float(metrics.get("weather_risk", 0))) + " ریسک"
		"resources": return _percent(float(metrics.get("resource_score", 0)))
		"military": return _percent(float(metrics.get("military_score", metrics.get("strategic_index", 0))))
	return str(metrics.get("name_fa", ""))

func _gui_input(event):
	if event is InputEventMouseMotion:
		var next_city = _city_at(event.position)
		var next_unit = "" if not next_city.is_empty() else _unit_at(event.position)
		if next_unit != hovered_unit or next_city != hovered_city:
			hovered_unit = next_unit
			hovered_city = next_city
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovered_unit != "" or not hovered_city.is_empty() else Control.CURSOR_ARROW
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var unit_id = _unit_at(event.position)
		if unit_id == "" and not _city_at(event.position).is_empty():
			unit_id = str(_city_at(event.position).get("unit_id", ""))
		if unit_id != "":
			selected_unit = unit_id
			queue_redraw()
			emit_signal("unit_selected", unit_id)
	elif event is InputEventKey and event.pressed and event.is_action("ui_accept"):
		var units = CountryGeographyManager.get_units(country_code)
		if units.is_empty():
			return
		var current_index = -1
		for index in range(units.size()):
			if str(units[index].id) == selected_unit:
				current_index = index
				break
		selected_unit = str(units[(current_index + 1) % units.size()].id)
		queue_redraw()
		emit_signal("unit_selected", selected_unit)

func _unit_at(position: Vector2) -> String:
	for index in range(_unit_screen_records.size() - 1, -1, -1):
		var record: Dictionary = _unit_screen_records[index]
		if Geometry2D.is_point_in_polygon(position, record.outer):
			return str(record.id)
	return ""

func _city_at(position: Vector2) -> Dictionary:
	for record in _city_screen_records:
		if position.distance_to(record.point) <= float(record.radius):
			return record.city
	return {}

func _calculate_view_bounds() -> Rect2:
	var min_point = Vector2(INF, INF)
	var max_point = Vector2(-INF, -INF)
	for polygon in GeographyManager.get_polygons(country_code):
		for point in polygon.outer:
			var local = _unwrap(point)
			min_point.x = min(min_point.x, local.x)
			min_point.y = min(min_point.y, local.y)
			max_point.x = max(max_point.x, local.x)
			max_point.y = max(max_point.y, local.y)
	if not is_finite(min_point.x) or not is_finite(max_point.x):
		return Rect2()
	var span = max_point - min_point
	var padding = Vector2(max(span.x * 0.06, 0.0008), max(span.y * 0.08, 0.0008))
	return Rect2(min_point - padding, span + padding * 2.0)

func _screen_ring(ring: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	var count = ring.size()
	if count > 2 and ring[0].is_equal_approx(ring[count - 1]):
		count -= 1
	for index in range(count):
		result.append(_normalized_to_screen(ring[index]))
	return result

func _normalized_to_screen(point: Vector2) -> Vector2:
	var local = _unwrap(point)
	return _map_rect.position + Vector2((local.x - _view_bounds.position.x) / _view_bounds.size.x, (local.y - _view_bounds.position.y) / _view_bounds.size.y) * _map_rect.size

func _unwrap(point: Vector2) -> Vector2:
	var result = point
	var delta = result.x - _center_x
	if delta > 0.5:
		result.x -= 1.0
	elif delta < -0.5:
		result.x += 1.0
	return result

func _geo_point(lon: float, lat: float) -> Vector2:
	return _normalized_to_screen(GeographyManager.normalized_point(lon, lat))

func _nearest_coast_point(origin: Vector2) -> Vector2:
	var best = Vector2.ZERO
	var best_distance = INF
	var local_origin = _unwrap(origin)
	for polygon in GeographyManager.get_polygons(country_code):
		for point in polygon.outer:
			var distance = local_origin.distance_to(_unwrap(point))
			if distance < best_distance:
				best_distance = distance
				best = point
	return best

func _curve_points(start: Vector2, finish: Vector2, direction: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var delta = finish - start
	var normal = Vector2(-delta.y, delta.x).normalized()
	var control = (start + finish) * 0.5 + normal * min(28.0, delta.length() * 0.10) * direction
	for index in range(17):
		var ratio = float(index) / 16.0
		points.append((1.0 - ratio) * (1.0 - ratio) * start + 2.0 * (1.0 - ratio) * ratio * control + ratio * ratio * finish)
	return points

func _draw_dashed(points: PackedVector2Array, color: Color, width: float):
	for index in range(points.size() - 1):
		if index % 2 == 0:
			draw_line(points[index], points[index + 1], color, width, true)

func _fit_rect(logical_size: Vector2, available: Vector2) -> Rect2:
	var scale = min(available.x / logical_size.x, available.y / logical_size.y)
	var fitted = logical_size * scale
	return Rect2((available - fitted) * 0.5, fitted)

func _gradient(low: Color, high: Color, value: float) -> Color:
	return low.lerp(high, clamp(value, 0.0, 1.0))

func _status_color(value: float) -> Color:
	if value < 0.5:
		return _gradient(Color(0.66, 0.13, 0.15), Color(0.88, 0.63, 0.15), value * 2.0)
	return _gradient(Color(0.88, 0.63, 0.15), Color(0.16, 0.76, 0.42), (value - 0.5) * 2.0)

func _stable_fraction(text: String) -> float:
	var value: int = 5381
	for index in range(text.length()):
		value = int(((value * 33) ^ text.unicode_at(index)) & 0x7fffffff)
	return float(value % 1009) / 1009.0

func _layer_name(layer: String) -> String:
	return {
		"administrative": "تقسیمات اداری", "population": "تراکم جمعیت",
		"economy": "فعالیت اقتصادی", "infrastructure": "کیفیت زیرساخت",
		"satisfaction": "رضایت منطقه‌ای", "security": "امنیت داخلی",
		"weather": "ریسک اقلیمی", "resources": "ظرفیت منابع", "military": "اهمیت نظامی",
	}.get(layer, "اطلاعات ملی")

func _percent(value: float) -> String:
	return PersianFormatter.to_persian_digits("%d٪" % int(clamp(value, 0.0, 1.0) * 100.0))

func _draw_centered_message(message: String):
	draw_string(PersianFont, size * 0.5, message, HORIZONTAL_ALIGNMENT_CENTER, 400, 18, Color(0.82, 0.88, 0.94))
