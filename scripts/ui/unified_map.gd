extends Control
# نقشه یکپارچه و پیوسته: جهان ← منطقه ← کشور ← استان و شهر

signal country_selected(code)
signal unit_selected(code, unit_id)
signal route_selected(route)
signal view_changed(center, zoom)
signal zoom_tier_changed(tier)

const PersianFont = preload("res://assets/fonts/Vazirmatn-Regular.ttf")
const MapFxLayerClass = preload("res://scripts/ui/map_fx_layer.gd")
const MIN_ZOOM := 1.0
const MAX_ZOOM := 80.0
const ADMIN_ZOOM := 3.6
const CITY_ZOOM := 5.2
const NETWORK_ZOOM := 6.5
const DETAIL_ZOOM := 10.0
const OCEAN_TOP := Color(0.018, 0.074, 0.108)
const OCEAN_BOTTOM := Color(0.008, 0.026, 0.052)
const ROUTE_COLORS := {
	"wars": Color(1.0, 0.22, 0.18, 0.96),
	"alliances": Color(0.26, 0.62, 1.0, 0.88),
	"trade": Color(0.24, 0.93, 0.55, 0.82),
	"trade_disrupted": Color(1.0, 0.18, 0.18, 0.95),
	"air": Color(0.22, 0.88, 1.0, 0.78),
	"sea": Color(0.20, 0.48, 1.0, 0.80),
	"land": Color(1.0, 0.67, 0.20, 0.78),
}

var countries: Dictionary = {}
var relations: Dictionary = {}
var world_state: Dictionary = {}
var full_state: Dictionary = {}
var player_country := ""
var selected_country := ""
var selected_unit := ""
var hovered_country := ""
var hovered_unit := ""
var hovered_city: Dictionary = {}
var hovered_route: Dictionary = {}
var base_layer := "political"
var overlays: Dictionary = {
	"wars": true, "alliances": true, "trade": true,
	"air": false, "sea": false, "land": false,
	"cities": true, "transport": true, "intelligence": false,
}
var camera_center := Vector2(0.5, 0.50)
var zoom_level := 1.0
var _base_scale := 1.0
var _viewport := Rect2()
var _unit_screen_records: Array = []
var _city_screen_records: Array = []
var _drawn_routes: Array = []
var _press_position := Vector2.ZERO
var _dragged := false
var _drag_active := false
var _pan_velocity := Vector2.ZERO
var _touch_points:Dictionary={}
var _pinch_distance:=0.0
var _pinch_center:=Vector2.ZERO
var _ignore_mouse_until_ms:=0
var _motion_until_ms:=0
var _settled_redraw_pending:=false
var _last_tier := ""
var fx_layer: Control

func _ready():
	custom_minimum_size = Vector2(0, 820)
	set_meta("block_parent_touch_scroll",true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	resized.connect(queue_redraw)
	# لایه افکت‌های زنده (موج، جنگ، تجارت، ابر) بالای نقشه ثابت
	fx_layer = MapFxLayerClass.new()
	fx_layer.map = self
	add_child(fx_layer)
	queue_redraw()

# آیا افکت زنده‌ای برای نمایش هست؟ (باتری: بازترسیم فقط با نرخ ~۱۲ فریم)
func _fx_active() -> bool:
	if bool(SettingsManager.get_value("reduce_motion", false)):
		return false
	if not visible:
		return false
	if base_layer == "weather":
		return true
	if overlays.get("trade", false):
		return true
	if not world_state.get("wars", {}).is_empty() or not world_state.get("npc_wars", {}).is_empty():
		return true
	if zoom_level <= 2.3:
		return true
	if player_country != "":
		return true
	return false

func configure(new_countries: Dictionary, new_relations: Dictionary, new_player: String, new_world: Dictionary, state: Dictionary, layer: String, new_overlays: Dictionary, initial_center: Vector2 = Vector2(0.5, 0.5), initial_zoom: float = 1.0):
	countries = new_countries.duplicate(true)
	relations = new_relations.duplicate(true)
	player_country = new_player
	world_state = new_world.duplicate(true)
	full_state = state
	base_layer = layer
	overlays.merge(new_overlays, true)
	camera_center = initial_center
	zoom_level = clamp(initial_zoom, MIN_ZOOM, MAX_ZOOM)
	if selected_country == "" or not countries.has(selected_country):
		selected_country = player_country
	_clamp_camera()
	queue_redraw()

func set_base_layer(layer: String):
	base_layer = layer
	queue_redraw()

func set_overlay(layer: String, enabled: bool):
	overlays[layer] = enabled
	queue_redraw()

func zoom_in():
	_zoom_at(size * 0.5, zoom_level * 1.55)

func zoom_out():
	_zoom_at(size * 0.5, zoom_level / 1.55)

func focus_world():
	camera_center = Vector2(0.5, 0.50)
	zoom_level = MIN_ZOOM
	selected_unit = ""
	_emit_view()
	queue_redraw()

func focus_player():
	focus_country(player_country)

func focus_selected():
	focus_country(selected_country if selected_country != "" else player_country)

func focus_country(code: String):
	if not countries.has(code):
		return
	selected_country = code
	selected_unit = ""
	var profile = countries.get(code, WorldManager.get_country(code))
	var reference = GeographyManager.normalized_point(float(profile.get("lon", 0.0)), float(profile.get("lat", 0.0)))
	var minimum = Vector2(INF, INF)
	var maximum = Vector2(-INF, -INF)
	for polygon in GeographyManager.get_polygons(code):
		for point in polygon.outer:
			var local = _unwrap_around(point, reference.x)
			minimum.x = min(minimum.x, local.x); minimum.y = min(minimum.y, local.y)
			maximum.x = max(maximum.x, local.x); maximum.y = max(maximum.y, local.y)
	if not is_finite(minimum.x):
		camera_center = reference
		zoom_level = 5.0
	else:
		var span = maximum - minimum
		camera_center = (minimum + maximum) * 0.5
		camera_center.x = fposmod(camera_center.x, 1.0)
		_update_projection()
		var x_zoom = (_viewport.size.x * 0.80) / max(span.x * 2.0 * _base_scale, 1.0)
		var y_zoom = (_viewport.size.y * 0.76) / max(span.y * _base_scale, 1.0)
		zoom_level = clamp(min(x_zoom, y_zoom), 2.0, MAX_ZOOM * 0.82)
	_clamp_camera()
	_emit_view()
	queue_redraw()

func get_view_state() -> Dictionary:
	return {"center": camera_center, "zoom": zoom_level}

func _draw():
	_update_projection()
	var low_detail=_motion_active()
	_draw_ocean()
	if not low_detail:_draw_graticule()
	_draw_countries(low_detail)
	_unit_screen_records.clear();_drawn_routes.clear();_city_screen_records.clear()
	if not low_detail:
		if zoom_level>=ADMIN_ZOOM and selected_country!="":_draw_admin_detail(selected_country)
		_draw_routes()
		_draw_war_fronts() # جبهه‌های جنگ - نقشه‌محور
		_draw_supply_lines() # خطوط تدارکات - نقشه‌محور
		if zoom_level>=NETWORK_ZOOM and overlays.get("transport",true) and selected_country!="":_draw_national_network(selected_country)
		_draw_hubs();_draw_country_labels()
		if zoom_level>=CITY_ZOOM and overlays.get("cities",true) and selected_country!="":_draw_cities(selected_country)
	_draw_selected_outline();_draw_map_hud()
	if not low_detail and bool(SettingsManager.get_value("tooltips_enabled",true)) and (hovered_country!="" or hovered_unit!="" or not hovered_city.is_empty() or not hovered_route.is_empty()):_draw_tooltip()

func _update_projection():
	_viewport = Rect2(Vector2(6, 6), Vector2(max(1.0, size.x - 12.0), max(1.0, size.y - 12.0)))
	_base_scale = min(_viewport.size.x / 2.0, _viewport.size.y)

func _draw_ocean():
	for index in range(24):
		var ratio = float(index) / 23.0
		var band = Rect2(0, size.y * ratio, size.x, size.y / 23.0 + 1.0)
		draw_rect(band, OCEAN_TOP.lerp(OCEAN_BOTTOM, ratio), true)
	var world_top_left = _normalized_to_screen(Vector2(0.0, 0.0), false)
	var world_bottom_right = _normalized_to_screen(Vector2(1.0, 1.0), false)
	var world_rect = Rect2(world_top_left, world_bottom_right - world_top_left)
	draw_rect(world_rect, Color(0.015, 0.068, 0.102, 0.86), true)
	# استخر نور ملایم مرکزی — عمق سینمایی ثابت بدون هزینه فریم.
	for ring_index in range(5):
		draw_circle(Vector2(size.x * 0.5, size.y * 0.32), 250.0 + float(ring_index) * 95.0, Color(0.10, 0.34, 0.46, 0.022))

func _draw_graticule():
	var alpha = clamp(0.10 + log(zoom_level) * 0.035, 0.10, 0.24)
	var step = 30 if zoom_level < 3.0 else (10 if zoom_level < 10.0 else 5)
	for longitude in range(-180, 181, step):
		var points := PackedVector2Array()
		for latitude in range(-80, 81, 4):
			points.append(_geo_point(float(longitude), float(latitude)))
		_draw_visible_polyline(points, Color(0.36, 0.68, 0.78, alpha), 0.7)
	for latitude in range(-75, 76, step):
		var points := PackedVector2Array()
		for longitude in range(-180, 181, 5):
			points.append(_geo_point(float(longitude), float(latitude)))
		_draw_visible_polyline(points, Color(0.36, 0.68, 0.78, alpha), 0.7)

func _draw_countries(low_detail:bool=false):
	for code in countries.keys():
		var code_string = str(code)
		var fill = _country_fill(code_string)
		var border = Color(0.36, 0.57, 0.65, 0.72)
		var width = clamp(0.7 + log(zoom_level) * 0.20, 0.7, 1.8)
		if code_string == player_country:
			border = Color(0.22, 0.82, 1.0, 0.98); width += 0.9
		if code_string == hovered_country:
			fill = fill.lightened(0.12); border = Color.WHITE; width += 1.1
		if code_string == selected_country:
			fill = fill.lightened(0.08); border = Color(1.0, 0.79, 0.22); width += 1.3
		for polygon in GeographyManager.get_polygons(code_string):
			var outer = _screen_ring(polygon.outer)
			if outer.size() < 3 or not _polygon_visible(outer):
				continue
			if not low_detail and polygon.get("fillable",true) and not Geometry2D.triangulate_polygon(outer).is_empty():draw_colored_polygon(outer,fill)
			if not low_detail:
				for hole in polygon.holes:
					var screen_hole=_screen_ring(hole)
					if screen_hole.size()>=3 and _polygon_visible(screen_hole) and not Geometry2D.triangulate_polygon(screen_hole).is_empty():draw_colored_polygon(screen_hole,OCEAN_TOP)
			var ring = outer.duplicate(); ring.append(outer[0])
			# سایه ساحلی: خشکی از اقیانوس بلند می‌شود (سبک نقشه سینمایی).
			if not low_detail:
				draw_polyline(ring, Color(0.0, 0.008, 0.016, 0.32), width + 4.0, true)
				# هاله اختصاصی کشور بازیکن — هویت بصری HOI4.
				if code_string == player_country:
					draw_polyline(ring, Color(0.35, 0.85, 1.0, 0.20), width + 6.5, true)
			draw_polyline(ring, border, width, true)

func _draw_admin_detail(code: String):
	for unit in CountryGeographyManager.get_units(code):
		var unit_id = str(unit.get("id", ""))
		var fill = _admin_fill(code, unit)
		var border = Color(0.48, 0.68, 0.71, 0.76)
		var width = clamp(0.75 + log(zoom_level) * 0.18, 0.8, 1.8)
		if unit_id == hovered_unit:
			fill = fill.lightened(0.13); border = Color.WHITE; width += 1.0
		if unit_id == selected_unit:
			fill = fill.lightened(0.17); border = Color(1.0, 0.84, 0.24); width += 1.4
		for polygon in unit.get("polygons", []):
			var outer = _screen_ring(polygon.outer)
			if outer.size() < 3 or not _polygon_visible(outer):
				continue
			if polygon.get("fillable", true) and not Geometry2D.triangulate_polygon(outer).is_empty():
				draw_colored_polygon(outer, fill)
				_unit_screen_records.append({"id": unit_id, "outer": outer})
			var ring = outer.duplicate(); ring.append(outer[0])
			draw_polyline(ring, border, width, true)
	if zoom_level >= DETAIL_ZOOM:
		_draw_admin_labels(code)

func _country_fill(code: String) -> Color:
	var profile = countries.get(code, WorldManager.get_country(code))
	var value = _country_layer_value(code, profile)
	match base_layer:
		"relations": return _status_gradient(value).darkened(0.18)
		"population": return Color(0.06, 0.15, 0.22).lerp(Color(0.12, 0.82, 0.96), value)
		"economy": return Color(0.08, 0.17, 0.15).lerp(Color(0.25, 0.88, 0.45), value)
		"infrastructure": return _status_gradient(value).darkened(0.10)
		"satisfaction": return _status_gradient(value).darkened(0.10)
		"security": return Color(0.50, 0.11, 0.15).lerp(Color(0.15, 0.64, 0.88), value)
		"weather": return Color(0.10, 0.39, 0.60).lerp(Color(0.90, 0.20, 0.14), value)
		"resources": return Color(0.16, 0.14, 0.21).lerp(Color(0.91, 0.64, 0.17), value)
		"military": return Color(0.13, 0.16, 0.21).lerp(Color(0.82, 0.18, 0.22), value)
	var palette = {
		"Asia": Color(0.15, 0.34, 0.38), "Europe": Color(0.20, 0.30, 0.47),
		"Africa": Color(0.39, 0.29, 0.18), "Americas": Color(0.13, 0.38, 0.29),
		"Oceania": Color(0.34, 0.23, 0.42),
	}
	return palette.get(str(profile.get("region", "")), Color(0.25, 0.31, 0.33))

func _country_layer_value(code: String, profile: Dictionary) -> float:
	var population = max(1.0, float(profile.get("population", 1.0)))
	var gdp = max(1.0, float(profile.get("gdp", 1.0)))
	var wealth = clamp((log(max(500.0, gdp / population)) / log(10.0) - 2.7) / 2.0, 0.05, 1.0)
	if code == player_country:
		population = max(1.0, float(full_state.get("population", {}).get("total", population)))
		gdp = max(1.0, float(full_state.get("economy", {}).get("gdp", gdp)))
	match base_layer:
		"relations": return clamp(float(relations.get(code, 100.0 if code == player_country else 50.0)) / 100.0, 0.0, 1.0)
		"population": return clamp((log(population) / log(10.0) - 4.0) / 5.3, 0.0, 1.0)
		"economy": return clamp((log(gdp) / log(10.0) - 8.0) / 6.0, 0.0, 1.0)
		"infrastructure": return float(full_state.get("infrastructure", {}).get("quality", 0.55)) if code == player_country else clamp(0.22 + wealth * 0.72, 0.15, 0.95)
		"satisfaction": return float(full_state.get("population", {}).get("happiness", 0.60)) if code == player_country else clamp(0.40 + wealth * 0.33, 0.32, 0.80)
		"security": return float(full_state.get("security", {}).get("public_security", 0.65)) if code == player_country else clamp(0.42 + wealth * 0.36, 0.34, 0.83)
		"weather": return clamp(max(float(profile.get("snow_factor", 0.2)), max(float(profile.get("flood_factor", 0.3)), float(profile.get("heat_factor", 0.4)))), 0.0, 1.0)
		"resources": return clamp(0.25 + float(profile.get("strategic_weight", 0.3)) * 0.65, 0.0, 1.0)
		"military", "military_power": return clamp(float(profile.get("military_power", 20.0)) / 100.0, 0.0, 1.0)
		# گروه اقتصادی
		"agriculture": return float(full_state.get("agriculture", {}).get("food_security", 0.85)) if code == player_country else clamp(0.30 + wealth*0.50, 0.10, 0.95)
		"industry": return float(full_state.get("industry", {}).get("output", 100.0))/150.0 if code == player_country else clamp(0.20+wealth*0.60,0.10,0.90)
		"trade_layer", "trade": return float(full_state.get("trade", {}).get("export_diversity", 0.60)) if code == player_country else clamp(0.30+wealth*0.50,0.10,0.90)
		"tourism": return float(full_state.get("tourism", {}).get("service_quality", 0.60)) if code == player_country else clamp(0.25+wealth*0.50,0.10,0.85)
		"central_bank": return 1.0 - float(full_state.get("central_bank", {}).get("inflation", 0.08))/0.30 if code == player_country else clamp(wealth,0.10,0.90)
		"stock_market": return float(full_state.get("stock_market", {}).get("investor_confidence", 0.60)) if code == player_country else clamp(wealth*0.8,0.10,0.90)
		"retail": return float(full_state.get("retail", {}).get("competition", 0.60)) if code == player_country else clamp(0.30+wealth*0.50,0.10,0.90)
		"fuel_stations": return float(full_state.get("fuel_stations", {}).get("coverage", 0.75)) if code == player_country else clamp(0.30+wealth*0.50,0.10,0.90)
		# اجتماعی
		"health": return float(full_state.get("health", {}).get("quality", 0.60)) if code == player_country else clamp(0.30+wealth*0.50,0.10,0.90)
		"education": return float(full_state.get("education", {}).get("quality", 0.55)) if code == player_country else clamp(0.30+wealth*0.50,0.10,0.90)
		"welfare": return 1.0 - float(full_state.get("welfare", {}).get("poverty", 0.15))*2.0 if code == player_country else clamp(1.0-wealth*0.3,0.10,0.90)
		"family": return float(full_state.get("family", {}).get("child_welfare", 0.65)) if code == player_country else clamp(0.40+wealth*0.40,0.10,0.90)
		"sports_youth": return float(full_state.get("sports_youth", {}).get("youth_happiness", 0.60)) if code == player_country else clamp(0.30+wealth*0.50,0.10,0.90)
		"ethnicity": return 1.0 - float(full_state.get("ethnicity", {}).get("tension", 0.30)) if code == player_country else clamp(0.60,0.10,0.90)
		"culture": return float(full_state.get("culture", {}).get("cohesion", 0.65)) if code == player_country else clamp(0.40+wealth*0.40,0.10,0.90)
		# سیاسی
		"judicial": return float(full_state.get("judicial", {}).get("rule_of_law", 0.60)) if code == player_country else clamp(0.30+wealth*0.50,0.10,0.90)
		"intelligence": return float(full_state.get("intelligence", {}).get("cyber_readiness", 0.50)) if code == player_country else clamp(0.30+wealth*0.50,0.10,0.90)
		"administration": return float(full_state.get("administration", {}).get("efficiency", 0.60)) if code == player_country else clamp(0.30+wealth*0.50,0.10,0.90)
		"elections": return float(full_state.get("elections", {}).get("transparency", 0.55)) if code == player_country else clamp(0.30+wealth*0.50,0.10,0.90)
		"politics": return float(full_state.get("politics", {}).get("stability", 0.60)) if code == player_country else clamp(0.30+wealth*0.50,0.10,0.90)
		"statistics": return float(full_state.get("statistics", {}).get("accuracy", 0.75)) if code == player_country else clamp(0.40+wealth*0.40,0.10,0.90)
		"emergency": return float(full_state.get("emergency", {}).get("preparedness", 0.50)) if code == player_country else clamp(0.30+wealth*0.50,0.10,0.90)
		# زیرساخت
		"environment": return float(full_state.get("environment", {}).get("air_quality", 0.60)) if code == player_country else clamp(0.30+wealth*0.50,0.10,0.90)
		"urban_facilities": return float(full_state.get("urban_facilities", {}).get("water_network", 0.75)) if code == player_country else clamp(0.30+wealth*0.50,0.10,0.90)
		"public_services": return float(full_state.get("public_services_detail", {}).get("coverage_health", 0.75)) if code == player_country else clamp(0.30+wealth*0.50,0.10,0.90)
		"transport_roads": return 1.0 - float(full_state.get("transport_detail", {}).get("traffic_congestion", 0.40)) if code == player_country else clamp(0.40+wealth*0.40,0.10,0.90)
		"settlements": return float(full_state.get("settlements_detail", {}).get("housing_quality", 0.60)) if code == player_country else clamp(0.30+wealth*0.50,0.10,0.90)
		# نظامی پیشرفته
		"trade_route_warfare": return 1.0 - float(full_state.get("trade_route_warfare", {}).get("piracy_level", 0.10))*2.0
	return 0.5

func _admin_fill(code: String, unit: Dictionary) -> Color:
	if base_layer in ["political", "relations"]:
		var tone = _stable_fraction(str(unit.get("id", "")))
		return Color(0.12 + tone * 0.12, 0.29 + tone * 0.11, 0.32 + tone * 0.10, 0.98)
	var value = CountryGeographyManager.get_layer_value(code, str(unit.get("id", "")), full_state, base_layer)
	match base_layer:
		"population": return Color(0.05, 0.15, 0.22).lerp(Color(0.10, 0.88, 1.0), value)
		"economy": return Color(0.07, 0.17, 0.14).lerp(Color(0.22, 0.94, 0.43), value)
		"infrastructure", "satisfaction": return _status_gradient(value)
		"security": return Color(0.54, 0.11, 0.15).lerp(Color(0.17, 0.72, 0.96), value)
		"weather": return Color(0.11, 0.44, 0.66).lerp(Color(0.96, 0.22, 0.13), value)
		"resources": return Color(0.17, 0.14, 0.22).lerp(Color(0.98, 0.70, 0.16), value)
		"military": return Color(0.14, 0.16, 0.22).lerp(Color(0.91, 0.18, 0.23), value)
	return Color(0.21, 0.31, 0.32)

func _draw_routes():
	# لایه‌های عادی + لایه ویژه مسیرهای مختل (همیشه اگر حمله فعال باشد نمایش داده می‌شود)
	var layers_to_draw = ["trade", "alliances", "wars", "land", "air", "sea", "trade_disrupted"]
	for layer in layers_to_draw:
		# لایه trade_disrupted حتی اگر trade خاموش باشد هم اگر حمله باشد نمایش داده شود
		if layer == "trade_disrupted":
			var warfare = full_state.get("trade_route_warfare", {})
			if warfare.get("attacks", []).is_empty() and warfare.get("chokepoints", {}).is_empty():
				continue
		elif not overlays.get(layer if layer != "trade_disrupted" else "trade", false) and layer != "trade_disrupted":
			# برای trade_disrupted از overlay trade استفاده می‌کنیم اما اگر حمله باشد حتی بدون overlay هم نشان داده می‌شود
			if layer != "trade_disrupted" and not overlays.get(layer, false):
				continue
		var route_list = MapLayerManager.get_dynamic_routes(full_state, layer if layer != "trade_disrupted" else "trade_disrupted")
		if layer in ["air", "sea"]:
			route_list.append_array(MapLayerManager.get_static_routes(layer))
		elif layer == "trade_disrupted":
			# مسیرهای تجاری عادی هم به عنوان پس‌زمینه برای مقایسه
			route_list.append_array(MapLayerManager.get_dynamic_routes(full_state, "trade_disrupted"))
		for route in route_list:
			var start = _geo_point(float(route.get("from_lon", 0.0)), float(route.get("from_lat", 0.0)))
			var finish = _geo_point(float(route.get("to_lon", 0.0)), float(route.get("to_lat", 0.0)))
			if not _segment_near_view(start, finish):
				continue
			var points = _curve_points(start, finish, layer)
			var color: Color = _route_color(layer)
			var width = clamp(1.2 + abs(float(route.get("volume", 0.5))) * 1.8 + log(zoom_level) * 0.12, 1.2, 4.5)
			# مسیرهای مختل = قرمز چشمک‌زن + نقطه‌چین ضخیم + سایه
			if layer == "trade_disrupted" or float(route.get("volume", 0.5)) < 0:
				color = Color(1.0, 0.25, 0.25, 0.92) # قرمز هشدار
				if route.get("chokepoint", false):
					color = Color(1.0, 0.15, 0.15, 0.98)
					width = clamp(width + 2.0, 2.5, 6.0)
				# سایه تیره برای تاکید
				draw_polyline(points, Color(0.0,0.0,0.0,0.45), width+2.5, true)
				_draw_dashed(points, color, width)
				# نقطه انفجار در وسط مسیر برای حمله
				if points.size() > 2:
					var mid = points[points.size()/2]
					draw_circle(mid, 5.0 + sin(Time.get_ticks_msec()*0.005)*2.0, Color(1.0,0.30,0.10,0.85))
					draw_circle(mid, 2.5, Color(1.0,0.85,0.2,0.95))
			elif layer == "wars":
				_draw_dashed(points, color, width)
			else:
				draw_polyline(points, color, width, true)
			var record = route.duplicate(true); record["points"] = points; record["type"] = layer
			_drawn_routes.append(record)

func _draw_hubs():
	for layer in ["air", "sea"]:
		if not overlays.get(layer, false): continue
		for hub in MapLayerManager.get_hubs(layer):
			var point = _geo_point(float(hub.get("lon", 0.0)), float(hub.get("lat", 0.0)))
			if not _viewport.grow(10).has_point(point): continue
			var color: Color = _route_color(layer)
			var radius = 3.0 + min(3.0, log(zoom_level + 1.0))
			draw_circle(point, radius + 2.0, Color(0.01, 0.03, 0.05, 0.92)); draw_circle(point, radius, color)
			if zoom_level >= 4.0:
				draw_string(PersianFont, point + Vector2(8, 4), str(hub.get("name_fa", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(0.84, 0.91, 0.97))
	if overlays.get("sea", false) or true: # گلوگاه‌ها همیشه مهم‌اند - حتی بدون لایه دریا نمایش هشدار
		var warfare = full_state.get("trade_route_warfare", {})
		var chokepoints_state = warfare.get("chokepoints", {})
		for choke in MapLayerManager.get_chokepoints():
			var point = _geo_point(float(choke.get("lon", 0.0)), float(choke.get("lat", 0.0)))
			if not _viewport.grow(20).has_point(point):
				continue
			var choke_id = str(choke.get("id",""))
			var is_blocked = chokepoints_state.has(choke_id)
			var is_critical = bool(choke.get("critical",false))
			if is_blocked:
				var action = str(chokepoints_state[choke_id].get("action","blockade"))
				var blocked_color = Color(1.0, 0.18, 0.18, 0.95) if action == "blockade" else Color(1.0, 0.45, 0.05, 0.90) if action == "mine" else Color(0.25, 0.85, 0.35, 0.85)
				# انیمیشن ضربان برای مسدود
				var pulse = 1.0 + sin(Time.get_ticks_msec()*0.004)*0.3
				draw_circle(point, (8.0 + (3.0 if is_critical else 0.0))*pulse, Color(0.0,0.0,0.0,0.55))
				draw_circle(point, (6.0 + (2.0 if is_critical else 0.0))*pulse, blocked_color)
				draw_circle(point, 2.5, Color(1.0,1.0,1.0,0.90))
				# علامت ممنوع
				if zoom_level >= 1.5:
					draw_string(PersianFont, point + Vector2(12, 4), "🚫 %s (%s)" % [str(choke.get("name_fa","")), action], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, blocked_color)
			else:
				var normal_color = Color(1.0, 0.78, 0.18, 0.85) if is_critical else Color(0.85, 0.65, 0.25, 0.70)
				draw_rect(Rect2(point - Vector2(4, 4), Vector2(8, 8)), normal_color, true)
				draw_rect(Rect2(point - Vector2(5, 5), Vector2(10, 10)), Color(0.0,0.0,0.0,0.35), false, 1.2)

func _draw_country_labels():
	var occupied: Array = []
	for code in countries.keys():
		var profile = countries[code]
		var strategic = float(profile.get("strategic_weight", 0.2))
		if zoom_level < 1.55 and strategic < 0.72 and code != player_country and code != selected_country: continue
		if zoom_level < 2.7 and strategic < 0.42 and code != player_country and code != selected_country: continue
		var point = _geo_point(float(profile.get("lon", 0.0)), float(profile.get("lat", 0.0)))
		if not _viewport.grow(-10).has_point(point): continue
		var label = str(profile.get("name_fa", code))
		var font_size = int(clamp(20.0 + log(zoom_level) * 2.0 + strategic * 3.0, 20.0, 30.0)*float(SettingsManager.get_value("text_scale",1.0)))
		var rect = Rect2(point - Vector2(label.length() * font_size * 0.28, font_size), Vector2(max(42.0, label.length() * font_size * 0.58), font_size + 7.0))
		if _overlaps_any(rect, occupied) and code != player_country and code != selected_country: continue
		occupied.append(rect)
		var color = Color(1.0, 0.86, 0.35) if code == selected_country else (Color(0.42, 0.90, 1.0) if code == player_country else Color(0.86, 0.91, 0.94))
		draw_string(PersianFont, point, label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.01, 0.03, 0.05), 2)
		draw_string(PersianFont, point, label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)

func _draw_admin_labels(code: String):
	var occupied: Array = []
	for unit in CountryGeographyManager.get_units(code):
		var point = _normalized_to_screen(unit.center)
		if not _viewport.grow(-8).has_point(point): continue
		var name = str(unit.get("name_fa", ""))
		var font_size = int(clamp(18.0 + log(zoom_level)*1.4, 18.0, 26.0)*float(SettingsManager.get_value("text_scale",1.0)))
		var rect = Rect2(point - Vector2(name.length() * 3.1, 12), Vector2(max(34.0, name.length() * 6.2), 21))
		if _overlaps_any(rect, occupied) and not unit.get("capital", false) and str(unit.id) != selected_unit: continue
		occupied.append(rect)
		var color = Color(1.0, 0.84, 0.30) if str(unit.id) == selected_unit else Color(0.82, 0.90, 0.91)
		draw_string(PersianFont, point, name, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.01, 0.025, 0.04), 2)
		draw_string(PersianFont, point, name, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)

func _draw_cities(code: String):
	var cities = CountryGeographyManager.get_cities(code)
	for index in range(cities.size()):
		var city: Dictionary = cities[index]
		var point = _normalized_to_screen(city.point)
		if not _viewport.grow(-6).has_point(point): continue
		var capital = bool(city.get("capital", false))
		var population = max(10.0, float(city.get("population", 0)))
		var radius = clamp(3.0 + log(population) / log(10.0) - 4.0 + log(zoom_level) * 0.25, 3.0, 8.0)
		draw_circle(point, radius + 2.0, Color(0.01, 0.025, 0.04, 0.94))
		draw_circle(point, radius, Color(1.0, 0.79, 0.20) if capital else Color(0.88, 0.95, 1.0))
		_city_screen_records.append({"city": city, "point": point, "radius": radius + 8.0})
		if capital or zoom_level >= DETAIL_ZOOM or index < 4:
			var label = ("پایتخت · " if capital else "") + str(city.get("name_fa", "شهر"))
			draw_string(PersianFont, point + Vector2(9, -7), label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(clamp(19+log(zoom_level)*1.5,19,27)*float(SettingsManager.get_value("text_scale",1.0))), Color(1.0, 0.91, 0.58) if capital else Color(0.86, 0.92, 0.96))

func _draw_national_network(code: String):
	var cities = CountryGeographyManager.get_cities(code)
	if cities.size() < 2: return
	var capital = CountryGeographyManager.get_capital_city(code)
	if capital.is_empty(): capital = cities[0]
	var start = _normalized_to_screen(capital.point)
	var is_player = code == player_country
	var transport = full_state.get("transport_detail", {}) if is_player else {}
	var road_quality = float(transport.get("roads_quality", _country_layer_value(code, countries[code])))
	var rail_quality = float(transport.get("rail_quality", road_quality * 0.85))
	var road_color = Color(0.74, 0.34, 0.15).lerp(Color(1.0, 0.81, 0.26), road_quality)
	for index in range(1, min(11, cities.size())):
		var finish = _normalized_to_screen(cities[index].point)
		if not _segment_near_view(start, finish): continue
		var points = _curve_points(start, finish, "land")
		draw_polyline(points, Color(0.01, 0.025, 0.04, 0.80), 4.2, true)
		draw_polyline(points, road_color, 1.7, true)
		if index <= 6: _draw_dashed(points, Color(0.77, 0.90, 0.96, 0.78), 0.8 + rail_quality)

func _draw_war_fronts():
	# رسم جبهه‌های جنگ - خط مقدم بین کشورها با پیشرفت و عرض
	var mil = full_state.get("military", {})
	var fronts = mil.get("fronts_detail", {}).get("active_fronts", []) if mil.has("fronts_detail") else []
	var world = full_state.get("world", {})
	var wars = world.get("wars", {})
	if fronts.is_empty() and wars.is_empty():
		return

	# اگر fronts خالی ولی wars داریم - از wars بساز
	if fronts.is_empty():
		for target in wars.keys():
			var player_id = str(world.get("player_country",""))
			var player_profile = countries.get(player_id, {})
			var enemy_profile = countries.get(str(target), {})
			if player_profile.is_empty() or enemy_profile.is_empty():
				continue
			var start = _geo_point(float(player_profile.get("lon",0.0)), float(player_profile.get("lat",0.0)))
			var finish = _geo_point(float(enemy_profile.get("lon",0.0)), float(enemy_profile.get("lat",0.0)))
			if not _segment_near_view(start, finish):
				continue
			var war = wars[target]
			var progress = float(war.get("progress",0.0)) # -100 تا +100
			# رنگ بر اساس پیشرفت: سبز اگر در حال پیروزی، قرمز اگر شکست
			var front_color = Color(0.20, 0.85, 0.40, 0.85) if progress > 0 else Color(0.95, 0.25, 0.25, 0.85) if progress < -20 else Color(0.85, 0.75, 0.20, 0.80)
			var width = clamp(2.5 + abs(progress)/30.0, 2.5, 6.0)
			var mid = (start + finish) * 0.5 + Vector2(0, -20).rotated((finish-start).angle())
			var points1 = _curve_points(start, mid, "wars")
			var points2 = _curve_points(mid, finish, "wars")
			draw_polyline(points1, Color(0.0,0.0,0.0,0.40), width+2.0, true)
			draw_polyline(points2, Color(0.0,0.0,0.0,0.40), width+2.0, true)
			_draw_dashed(points1, front_color, width)
			_draw_dashed(points2, front_color, width)
			# فلش پیشرفت
			if points1.size() > 5:
				var arrow_pos = points1[points1.size()/2]
				var dir = (finish - start).normalized()
				var arrow_size = 8.0
				var perp = Vector2(-dir.y, dir.x)
				if progress > 0:
					# فلش به سمت دشمن
					draw_line(arrow_pos, arrow_pos + dir*arrow_size + perp*arrow_size*0.5, front_color, 2.5)
					draw_line(arrow_pos, arrow_pos + dir*arrow_size - perp*arrow_size*0.5, front_color, 2.5)
				else:
					# فلش عقب‌نشینی
					draw_line(arrow_pos, arrow_pos - dir*arrow_size + perp*arrow_size*0.5, Color(0.95,0.25,0.25,0.85), 2.5)
					draw_line(arrow_pos, arrow_pos - dir*arrow_size - perp*arrow_size*0.5, Color(0.95,0.25,0.25,0.85), 2.5)
			# متن پیشرفت
			if zoom_level >= 2.0:
				var label = "جبهه %s: %+.0f" % [WorldManager.get_country_name(str(target)), progress]
				draw_string(PersianFont, mid + Vector2(10, -10), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, front_color)
	else:
		for front in fronts:
			var target = str(front.get("target",""))
			var player_id = str(full_state.get("world",{}).get("player_country",""))
			var player_profile = countries.get(player_id, {})
			var enemy_profile = countries.get(target, {})
			if player_profile.is_empty() or enemy_profile.is_empty():
				continue
			var start = _geo_point(float(player_profile.get("lon",0.0)), float(player_profile.get("lat",0.0)))
			var finish = _geo_point(float(enemy_profile.get("lon",0.0)), float(enemy_profile.get("lat",0.0)))
			if not _segment_near_view(start, finish):
				continue
			var progress = float(front.get("progress",0.0))
			var width_km = float(front.get("width_km",300.0))
			var terrain = str(front.get("terrain","دشت"))
			var supply = float(front.get("supply_status",0.5))
			var air_sup = float(front.get("air_superiority",0.5))
			var front_color = Color(0.20, 0.85, 0.40, 0.85) if progress > 20 else Color(0.95, 0.25, 0.25, 0.85) if progress < -20 else Color(0.85, 0.75, 0.20, 0.80)
			var width = clamp(3.0 + width_km/200.0, 3.0, 8.0)
			var mid = (start + finish) * 0.5
			var points = _curve_points(start, finish, "wars")
			draw_polyline(points, Color(0.0,0.0,0.0,0.45), width+2.5, true)
			_draw_dashed(points, front_color, width)
			# اطلاعات جبهه
			if zoom_level >= 2.5 and points.size() > 2:
				var mid_point = points[points.size()/2]
				var info = "%s | %s | تدارکات %.0f٪ | هوایی %.0f٪" % [terrain, ("پیشروی" if progress>0 else "عقب‌نشینی"), supply*100.0, air_sup*100.0]
				draw_string(PersianFont, mid_point + Vector2(10, -15), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.90,0.92,0.95))

func _draw_supply_lines():
	# رسم خطوط تدارکات از پایتخت به جبهه - رنگ بر اساس آسیب‌پذیری
	var mil = full_state.get("military", {})
	var logi = mil.get("logistics_detail", {})
	if logi.is_empty():
		return
	var supply_vuln = float(logi.get("supply_line_vulnerability",0.30))
	var fuel_days = float(logi.get("fuel_stock_days",25.0))
	var ammo_days = float(logi.get("ammo_stock_days",20.0))
	var player_id = str(full_state.get("world",{}).get("player_country",""))
	var player_profile = countries.get(player_id, {})
	if player_profile.is_empty():
		return
	var capital = CountryGeographyManager.get_capital_city(player_id)
	if capital.is_empty():
		return
	var start = _normalized_to_screen(capital.point)
	var world = full_state.get("world", {})
	var wars = world.get("wars", {})
	for target in wars.keys():
		var enemy_profile = countries.get(str(target), {})
		if enemy_profile.is_empty():
			continue
		var finish = _geo_point(float(enemy_profile.get("lon",0.0)), float(enemy_profile.get("lat",0.0)))
		# نقطه میانی جبهه ۷۰٪ به سمت دشمن
		var front_point = start.lerp(finish, 0.70)
		if not _segment_near_view(start, front_point):
			continue
		# رنگ بر اساس آسیب‌پذیری و ذخایر
		var supply_color = Color(0.25, 0.85, 0.45, 0.75) # سبز = امن
		if supply_vuln > 0.60 or fuel_days < 5.0 or ammo_days < 3.0:
			supply_color = Color(0.95, 0.25, 0.25, 0.85) # قرمز = بحرانی
		elif supply_vuln > 0.40 or fuel_days < 15.0:
			supply_color = Color(0.95, 0.75, 0.20, 0.80) # زرد = پرخطر
		var points = _curve_points(start, front_point, "land")
		# خط تدارکات نقطه‌چین ظریف
		_draw_dashed(points, supply_color, 1.8)
		# کامیون‌های کوچک متحرک روی مسیر
		if not bool(SettingsManager.get_value("reduce_motion",false)):
			var t = fmod(Time.get_ticks_msec()*0.0003, 1.0)
			var idx = int(t * (points.size()-1))
			if idx < points.size():
				var truck_pos = points[idx]
				draw_circle(truck_pos, 3.0, Color(0.15,0.15,0.15,0.85))
				draw_circle(truck_pos, 1.8, supply_color)

func _draw_selected_outline():
	if selected_country == "": return
	for polygon in GeographyManager.get_polygons(selected_country):
		var outer = _screen_ring(polygon.outer)
		if outer.size() < 3 or not _polygon_visible(outer): continue
		var ring = outer.duplicate(); ring.append(outer[0])
		# هاله طلایی نرم پشت خط انتخاب — خوانایی در نمای شلوغ.
		draw_polyline(ring, Color(1.0, 0.79, 0.22, 0.18), clamp(7.0 + log(zoom_level), 7.0, 10.0), true)
		draw_polyline(ring, Color(1.0, 0.76, 0.18, 0.96), clamp(2.0 + log(zoom_level) * 0.35, 2.0, 4.5), true)

func _draw_map_hud():
	var tier = _zoom_tier()
	if tier != _last_tier:
		_last_tier = tier; emit_signal("zoom_tier_changed", tier)
	var panel = Rect2(14, 14, 320, 92)
	draw_rect(panel, Color(0.006, 0.022, 0.039, 0.92), true)
	draw_rect(panel, Color(0.25, 0.69, 0.78, 0.62), false, 1.5)
	draw_string(PersianFont, Vector2(28, 50), tier, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color(0.90, 0.96, 0.98))
	draw_string(PersianFont, Vector2(28, 80), "بزرگ‌نمایی ×" + PersianFormatter.to_persian_digits("%.1f" % zoom_level), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.64, 0.80, 0.86))
	var scale_km = _nice_scale_km()
	var scale_pixels = float(scale_km) / 40075.0 * 2.0 * _base_scale * zoom_level
	var scale_y = size.y - 26.0
	draw_line(Vector2(20, scale_y), Vector2(20 + scale_pixels, scale_y), Color.WHITE, 2.0)
	draw_line(Vector2(20, scale_y - 5), Vector2(20, scale_y + 2), Color.WHITE, 1.5)
	draw_line(Vector2(20 + scale_pixels, scale_y - 5), Vector2(20 + scale_pixels, scale_y + 2), Color.WHITE, 1.5)
	draw_string(PersianFont, Vector2(22, scale_y - 10), PersianFormatter.to_persian_digits(str(scale_km)) + " کیلومتر", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.84, 0.91, 0.95))
	var layer_label = _layer_name(base_layer)
	var width = max(205.0, layer_label.length() * 13.0 + 42.0)
	var layer_panel = Rect2(size.x - width - 14, 14, width, 52)
	draw_rect(layer_panel, Color(0.006, 0.022, 0.039, 0.92), true)
	draw_string(PersianFont, layer_panel.position + Vector2(16, 35), "لایه · " + layer_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(1.0, 0.81, 0.30))

func _draw_tooltip():
	var text := ""
	if not hovered_city.is_empty():
		text = ("پایتخت" if hovered_city.get("capital", false) else "شهر") + " · " + str(hovered_city.get("name_fa", ""))
		if int(hovered_city.get("population", 0)) > 0: text += " | جمعیت " + PersianFormatter.format_large(float(hovered_city.population))
	elif hovered_unit != "":
		var metrics = CountryGeographyManager.get_unit_metrics(selected_country, hovered_unit, full_state)
		text = "%s %s | %s" % [metrics.get("type_fa", "ناحیه"), metrics.get("name_fa", ""), _metric_text(metrics)]
	elif not hovered_route.is_empty():
		text = str(hovered_route.get("label", _overlay_name(str(hovered_route.get("type", "")))))
	elif hovered_country != "":
		var profile = countries.get(hovered_country, {})
		text = "%s | پایتخت %s | جمعیت %s | GDP %s" % [profile.get("name_fa", hovered_country), profile.get("capital_fa", ""), PersianFormatter.format_large(float(profile.get("population", 0))), PersianFormatter.format_money(float(profile.get("gdp", 0)))]
	if text == "": return
	var mouse = get_local_mouse_position() + Vector2(14, -14)
	var width = min(820.0, max(300.0, 90.0 + text.length() * 10.5))
	if mouse.x + width > size.x: mouse.x -= width + 28.0
	if mouse.y < 58: mouse.y += 72
	var rect = Rect2(mouse - Vector2(10, 32), Vector2(width, 52))
	draw_rect(rect, Color(0.004, 0.017, 0.030, 0.98), true)
	draw_rect(rect, Color(0.29, 0.76, 0.84, 0.68), false, 1.5)
	draw_string(PersianFont, mouse, text, HORIZONTAL_ALIGNMENT_LEFT, width - 18, 21, Color.WHITE)

func _gui_input(event):
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and Time.get_ticks_msec()<_ignore_mouse_until_ms:return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(event.position, zoom_level * 1.32); accept_event(); return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(event.position, zoom_level / 1.32); accept_event(); return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press_position = event.position; _dragged = false; _drag_active=true;_pan_velocity=Vector2.ZERO;grab_focus()
			else:
				_drag_active=false
				if not _dragged:_handle_selection(event.position, event.double_click)
			accept_event()
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			if event.position.distance_to(_press_position) > 5.0: _dragged = true
			if _dragged:_pan_velocity=event.relative*45.0;_pan_pixels(event.relative)
		else:
			_update_hover(event.position)
	elif event is InputEventScreenTouch:
		_ignore_mouse_until_ms=Time.get_ticks_msec()+350
		if event.pressed:
			_touch_points[event.index]=event.position;_pan_velocity=Vector2.ZERO
			if _touch_points.size()==1:_press_position=event.position;_dragged=false;_drag_active=true
			elif _touch_points.size()>=2:_dragged=true;_drag_active=true;_reset_pinch_reference()
		else:
			var was_pinching=_touch_points.size()>=2
			_touch_points.erase(event.index)
			if _touch_points.is_empty():
				_drag_active=false
				if not _dragged and not was_pinching:_handle_selection(event.position,event.double_tap)
			elif _touch_points.size()==1:
				var remaining:Vector2=_touch_points.values()[0];_press_position=remaining;_pinch_distance=0.0;_dragged=true
	elif event is InputEventScreenDrag:
		_ignore_mouse_until_ms=Time.get_ticks_msec()+350
		if not _touch_points.has(event.index):return
		_touch_points[event.index]=event.position
		if _touch_points.size()>=2:
			_handle_manual_pinch()
		else:
			if event.position.distance_to(_press_position)>8.0:_dragged=true
			_pan_velocity=event.relative*42.0;_pan_pixels(event.relative)
	elif event is InputEventMagnifyGesture:
		if _touch_points.size()<2:_zoom_at(event.position,zoom_level*event.factor)
	elif event is InputEventPanGesture:
		_pan_pixels(-event.delta * 18.0)
	elif event is InputEventKey and event.pressed:
		if event.keycode in [KEY_PLUS, KEY_EQUAL]: zoom_in()
		elif event.keycode == KEY_MINUS: zoom_out()
		elif event.keycode == KEY_HOME: focus_player()
		elif event.keycode == KEY_0: focus_world()

func _handle_selection(position: Vector2, double_click: bool):
	var city = _city_at(position)
	if not city.is_empty():
		FeedbackManager.play_click()
		var unit_id = str(city.get("unit_id", ""))
		if unit_id != "": selected_unit = unit_id; emit_signal("unit_selected", selected_country, unit_id)
		queue_redraw(); return
	if zoom_level >= ADMIN_ZOOM and selected_country != "":
		var unit_id = _unit_at(position)
		if unit_id != "":
			FeedbackManager.play_click();selected_unit = unit_id; emit_signal("unit_selected", selected_country, unit_id); queue_redraw(); return
	var route = _route_at(position)
	if not route.is_empty():
		FeedbackManager.play_click();emit_signal("route_selected", route); return
	var code = _country_at(position)
	if code != "":
		FeedbackManager.play_click();selected_country = code; selected_unit = ""; emit_signal("country_selected", code)
		if double_click: focus_country(code)
		else: queue_redraw()

func _update_hover(position: Vector2):
	var next_city = _city_at(position)
	var next_unit = "" if not next_city.is_empty() else _unit_at(position)
	var next_route: Dictionary = {} if not next_city.is_empty() or next_unit != "" else _route_at(position)
	var next_country = ""
	if next_city.is_empty() and next_unit == "" and next_route.is_empty():
		next_country = _country_at(position)
	if next_city != hovered_city or next_unit != hovered_unit or next_route != hovered_route or next_country != hovered_country:
		hovered_city = next_city; hovered_unit = next_unit; hovered_route = next_route; hovered_country = next_country
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not next_city.is_empty() or next_unit != "" or not next_route.is_empty() or next_country != "" else Control.CURSOR_ARROW
		queue_redraw()

func _reset_pinch_reference():
	if _touch_points.size()<2:return
	var points:Array=_touch_points.values();var a:Vector2=points[0];var b:Vector2=points[1]
	_pinch_distance=max(1.0,a.distance_to(b));_pinch_center=(a+b)*0.5

func _handle_manual_pinch():
	var points:Array=_touch_points.values();if points.size()<2:return
	var a:Vector2=points[0];var b:Vector2=points[1];var new_distance=max(1.0,a.distance_to(b));var new_center=(a+b)*0.5
	if _pinch_distance>0.0:
		var factor=clamp(new_distance/_pinch_distance,0.72,1.38)
		if abs(factor-1.0)>0.002:_zoom_at(new_center,zoom_level*factor)
		var center_delta=new_center-_pinch_center
		if center_delta.length()>0.1:_pan_pixels(center_delta)
	_pinch_distance=new_distance;_pinch_center=new_center;_dragged=true;_pan_velocity=Vector2.ZERO

func _mark_motion():
	_motion_until_ms=Time.get_ticks_msec()+170;_settled_redraw_pending=true

func _motion_active()->bool:
	return Time.get_ticks_msec()<_motion_until_ms

func _process(delta:float):
	if _settled_redraw_pending and not _motion_active():_settled_redraw_pending=false;queue_redraw()
	if _drag_active or bool(SettingsManager.get_value("reduce_motion",false)) or _pan_velocity.length()<4.0:return
	var move=_pan_velocity*delta
	camera_center.x-=move.x/max(1.0,_base_scale*zoom_level*2.0);camera_center.y-=move.y/max(1.0,_base_scale*zoom_level)
	_pan_velocity*=exp(-6.5*delta);_mark_motion();_clamp_camera();_emit_view();queue_redraw()

func _pan_pixels(delta: Vector2):
	camera_center.x -= delta.x / max(1.0, _base_scale * zoom_level * 2.0)
	camera_center.y -= delta.y / max(1.0, _base_scale * zoom_level)
	_mark_motion();_clamp_camera();_emit_view();queue_redraw()

func _zoom_at(screen_point: Vector2, target_zoom: float):
	var before = _screen_to_normalized(screen_point)
	zoom_level = clamp(target_zoom, MIN_ZOOM, MAX_ZOOM)
	var after = _screen_to_normalized(screen_point)
	var dx = before.x - after.x
	if dx > 0.5: dx -= 1.0
	elif dx < -0.5: dx += 1.0
	camera_center += Vector2(dx, before.y - after.y)
	_mark_motion();_clamp_camera();_emit_view();queue_redraw()

func _clamp_camera():
	camera_center.x = fposmod(camera_center.x, 1.0)
	var margin = 0.46 / zoom_level
	camera_center.y = clamp(camera_center.y, margin, 1.0 - margin)

func _emit_view():
	emit_signal("view_changed", camera_center, zoom_level)

func _normalized_to_screen(point: Vector2, wrap: bool = true) -> Vector2:
	var dx = point.x - camera_center.x
	if wrap:
		if dx > 0.5: dx -= 1.0
		elif dx < -0.5: dx += 1.0
	return _viewport.get_center() + Vector2(dx * 2.0, point.y - camera_center.y) * _base_scale * zoom_level

func _screen_to_normalized(point: Vector2) -> Vector2:
	var delta = (point - _viewport.get_center()) / max(1.0, _base_scale * zoom_level)
	return Vector2(fposmod(camera_center.x + delta.x * 0.5, 1.0), clamp(camera_center.y + delta.y, 0.0, 1.0))

func _geo_point(longitude: float, latitude: float) -> Vector2:
	return _normalized_to_screen(GeographyManager.normalized_point(longitude, latitude))

func _screen_ring(ring: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	var count = ring.size()
	if count > 2 and ring[0].is_equal_approx(ring[count - 1]): count -= 1
	for index in range(count): result.append(_normalized_to_screen(ring[index]))
	return result

func _unwrap_around(point: Vector2, reference_x: float) -> Vector2:
	var result = point
	var delta = result.x - reference_x
	if delta > 0.5: result.x -= 1.0
	elif delta < -0.5: result.x += 1.0
	return result

func _polygon_visible(points: PackedVector2Array) -> bool:
	if points.is_empty(): return false
	var minimum = points[0]; var maximum = points[0]
	for point in points:
		minimum.x = min(minimum.x, point.x); minimum.y = min(minimum.y, point.y)
		maximum.x = max(maximum.x, point.x); maximum.y = max(maximum.y, point.y)
	return Rect2(minimum, maximum - minimum).intersects(_viewport.grow(12.0))

func _segment_near_view(start: Vector2, finish: Vector2) -> bool:
	var minimum = Vector2(min(start.x, finish.x), min(start.y, finish.y))
	var maximum = Vector2(max(start.x, finish.x), max(start.y, finish.y))
	return Rect2(minimum, maximum - minimum + Vector2.ONE).intersects(_viewport.grow(100.0))

func _draw_visible_polyline(points: PackedVector2Array, color: Color, width: float):
	for index in range(points.size() - 1):
		if _segment_near_view(points[index], points[index + 1]): draw_line(points[index], points[index + 1], color, width, true)

func _curve_points(start: Vector2, finish: Vector2, layer: String) -> PackedVector2Array:
	var points := PackedVector2Array(); var delta = finish - start
	var normal = Vector2(-delta.y, delta.x).normalized()
	var bend = min(80.0, delta.length() * 0.16) * (1.0 if layer in ["air", "alliances"] else 0.46)
	var control = (start + finish) * 0.5 + normal * bend
	for index in range(21):
		var ratio = float(index) / 20.0
		points.append((1.0-ratio)*(1.0-ratio)*start + 2.0*(1.0-ratio)*ratio*control + ratio*ratio*finish)
	return points

func _draw_dashed(points: PackedVector2Array, color: Color, width: float):
	for index in range(points.size() - 1):
		if index % 2 == 0: draw_line(points[index], points[index + 1], color, width, true)

func _country_at(position: Vector2) -> String:
	var code = GeographyManager.country_at_normalized(_screen_to_normalized(position))
	if code != "": return code
	var closest := ""; var best = 16.0
	for candidate in countries.keys():
		var profile = countries[candidate]
		var point = _geo_point(float(profile.get("lon",0.0)),float(profile.get("lat",0.0)))
		var distance = point.distance_to(position)
		if distance < best: best = distance; closest = str(candidate)
	return closest

func _unit_at(position: Vector2) -> String:
	for index in range(_unit_screen_records.size() - 1, -1, -1):
		var record: Dictionary = _unit_screen_records[index]
		if Geometry2D.is_point_in_polygon(position, record.outer): return str(record.id)
	return ""

func _city_at(position: Vector2) -> Dictionary:
	for record in _city_screen_records:
		if position.distance_to(record.point) <= float(record.radius): return record.city
	return {}

func _route_at(position: Vector2) -> Dictionary:
	var closest: Dictionary = {}; var best = 9.0
	for route in _drawn_routes:
		var points: PackedVector2Array = route.get("points", PackedVector2Array())
		for index in range(points.size() - 1):
			var distance = Geometry2D.get_closest_point_to_segment(position, points[index], points[index + 1]).distance_to(position)
			if distance < best: best = distance; closest = route
	return closest

func _metric_text(metrics: Dictionary) -> String:
	match base_layer:
		"population": return "جمعیت " + PersianFormatter.format_large(float(metrics.get("population", 0)))
		"economy": return "GDP " + PersianFormatter.format_money(float(metrics.get("gdp", 0)))
		"infrastructure": return "زیرساخت " + _percent(float(metrics.get("infrastructure", 0)))
		"satisfaction": return "رضایت " + _percent(float(metrics.get("satisfaction", 0)))
		"security": return "امنیت " + _percent(float(metrics.get("security", 0)))
		"weather": return "ریسک اقلیمی " + _percent(float(metrics.get("weather_risk", 0)))
		"resources": return "منابع " + _percent(float(metrics.get("resource_score", 0)))
		"military": return "اهمیت نظامی " + _percent(float(metrics.get("military_score", 0)))
	return "جمعیت " + PersianFormatter.format_large(float(metrics.get("population", 0)))

func _zoom_tier() -> String:
	if zoom_level < 1.7: return "نمای جهان"
	if zoom_level < ADMIN_ZOOM: return "نمای منطقه‌ای"
	if zoom_level < CITY_ZOOM: return "نمای کشور و استان‌ها"
	if zoom_level < DETAIL_ZOOM: return "نمای شهرها و شبکه‌ها"
	return "نمای جزئیات محلی"

func _nice_scale_km() -> int:
	var target = 125.0 / max(1.0, 2.0 * _base_scale * zoom_level) * 40075.0
	var values = [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000]
	var best = 1
	for value in values:
		if float(value) <= target: best = value
	return best

func _layer_name(layer: String) -> String:
	return {
		"political":"سیاسی","relations":"روابط","population":"جمعیت","economy":"اقتصاد","infrastructure":"زیرساخت","satisfaction":"رضایت","security":"امنیت","weather":"اقلیم","resources":"منابع","military":"نظامی",
		"agriculture":"کشاورزی","industry":"صنعت","trade_layer":"تجارت","tourism":"گردشگری","central_bank":"بانک مرکزی","stock_market":"بورس","retail":"خرده‌فروشی","fuel_stations":"سوخت",
		"health":"بهداشت","education":"آموزش","welfare":"رفاه","family":"خانواده","sports_youth":"ورزش","ethnicity":"قومیت","culture":"فرهنگ",
		"judicial":"قضایی","intelligence":"اطلاعات","administration":"اداره","elections":"انتخابات","politics":"سیاست","statistics":"آمار","emergency":"بحران",
		"environment":"محیط‌زیست","urban_facilities":"تاسیسات شهری","public_services":"خدمات عمومی","transport_roads":"راه‌ها","settlements":"سکونتگاه‌ها",
		"military_power":"قدرت نظامی","trade_route_warfare":"جنگ تجاری"
	}.get(layer, layer)

func _overlay_name(layer: String) -> String:
	return {"wars":"جنگ","alliances":"اتحاد","trade":"تجارت","trade_disrupted":"مسیر مختل 🚫","air":"پرواز","sea":"دریایی","land":"زمینی","cities":"شهرها","transport":"حمل‌ونقل","intelligence":"اطلاعات"}.get(layer, layer)

func _route_color(layer:String)->Color:
	if bool(SettingsManager.get_value("colorblind_palette",false)):
		return {"wars":Color(0.94,0.30,0.82,0.96),"alliances":Color(0.25,0.70,1.0,0.90),"trade":Color(0.20,0.91,0.86,0.86),"trade_disrupted":Color(1.0,0.25,0.25,0.95),"air":Color(0.72,0.82,1.0,0.82),"sea":Color(0.34,0.55,1.0,0.84),"land":Color(1.0,0.76,0.18,0.82)}.get(layer,Color.WHITE)
	if layer == "trade_disrupted":
		# چشمک زن قرمز - با زمان
		var blink = 0.75 + sin(Time.get_ticks_msec()*0.006)*0.25
		return Color(1.0, 0.20, 0.20, 0.80 + blink*0.15)
	return ROUTE_COLORS.get(layer,Color.WHITE)

func _percent(value: float) -> String:
	return PersianFormatter.to_persian_digits("%d٪" % int(clamp(value, 0.0, 1.0) * 100.0))

func _status_gradient(value: float) -> Color:
	if bool(SettingsManager.get_value("colorblind_palette",false)):
		if value<0.5:return Color(0.62,0.18,0.70).lerp(Color(0.92,0.66,0.16),value*2.0)
		return Color(0.92,0.66,0.16).lerp(Color(0.14,0.58,0.92),(value-0.5)*2.0)
	if value < 0.5: return Color(0.66, 0.12, 0.15).lerp(Color(0.88, 0.62, 0.15), value * 2.0)
	return Color(0.88, 0.62, 0.15).lerp(Color(0.13, 0.72, 0.40), (value - 0.5) * 2.0)

func _stable_fraction(text: String) -> float:
	var value: int = 5381
	for index in range(text.length()): value = int(((value * 33) ^ text.unicode_at(index)) & 0x7fffffff)
	return float(value % 1009) / 1009.0

func _overlaps_any(rect: Rect2, occupied: Array) -> bool:
	for other in occupied:
		if rect.intersects(other): return true
	return false
