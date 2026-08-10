extends Control
# نقشه جهان آفلاین Natural Earth با کشورها و روابط پویا

signal country_selected(code)

const WORLD_TEXTURE = preload("res://assets/maps/world_natural_earth.svg")

var countries: Dictionary = {}
var relations: Dictionary = {}
var player_country: String = ""
var selected_code: String = ""
var hovered_code: String = ""
var _map_rect := Rect2()

func _ready():
	custom_minimum_size = Vector2(0, 440)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	resized.connect(queue_redraw)
	queue_redraw()

func set_world(new_countries: Dictionary, new_relations: Dictionary, new_player_country: String):
	countries = new_countries.duplicate(true)
	relations = new_relations.duplicate(true)
	player_country = new_player_country
	if selected_code == "" and not relations.is_empty():
		selected_code = str(relations.keys()[0])
	queue_redraw()

# سازگاری با فراخوان قدیمی
func set_relations(new_relations: Dictionary):
	relations = new_relations.duplicate(true)
	queue_redraw()

func _draw():
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.055, 0.11), true)
	_map_rect = _fit_rect(Vector2(WORLD_TEXTURE.get_width(), WORLD_TEXTURE.get_height()), size - Vector2(20, 20))
	_map_rect.position += Vector2(10, 10)
	draw_texture_rect(WORLD_TEXTURE, _map_rect, false, Color(0.62, 0.75, 0.84, 0.72))
	draw_rect(_map_rect, Color(0.25, 0.55, 0.75, 0.8), false, 2.0)
	for code in countries.keys():
		if code == player_country:
			continue
		var point = _country_point(code)
		var relation = float(relations.get(code, 50.0))
		var color = _relation_color(relation)
		var radius = 4.0 + float(countries[code].get("strategic_weight",0.3)) * 4.0
		if code == hovered_code:
			radius = 12.0
		if code == selected_code:
			draw_circle(point, 17.0, Color(1.0, 0.86, 0.3, 0.32))
			radius = 10.0
		draw_circle(point, radius + 3.0, Color(0.02, 0.05, 0.10, 0.92))
		draw_circle(point, radius, color)
		draw_arc(point, radius + 2.0, 0, TAU, 24, Color(1, 1, 1, 0.75), 1.5)
		if code == hovered_code or code == selected_code:
			_draw_country_label(code, point, relation)
	if countries.has(player_country):
		var home = _country_point(player_country)
		draw_circle(home, 14.0, Color(0.15, 0.65, 1.0))
		draw_arc(home, 18.0, 0, TAU, 32, Color.WHITE, 2.5)
		draw_string(ThemeDB.fallback_font, home + Vector2(22, 6), "کشور شما: " + _country_name(player_country), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.72, 0.9, 1.0))

func _draw_country_label(code: String, point: Vector2, relation: float):
	var runtime = countries.get(code, {})
	var war_label = " | در جنگ" if runtime.get("at_war", false) else ""
	var label = "%s  رابطه %s%s" % [_country_name(code), _persian_number(int(relation)), war_label]
	var estimated_width = min(320.0, 90.0 + label.length() * 7.0)
	var pos = point + Vector2(17, -22)
	if pos.x + estimated_width > _map_rect.end.x:
		pos.x = point.x - estimated_width - 17
	draw_rect(Rect2(pos - Vector2(6, 19), Vector2(estimated_width, 28)), Color(0.02, 0.05, 0.10, 0.88), true)
	draw_string(ThemeDB.fallback_font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

func _gui_input(event):
	if event is InputEventMouseMotion:
		var next_hover = _nearest_country(event.position)
		if next_hover != hovered_code:
			hovered_code = next_hover
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovered_code != "" else Control.CURSOR_ARROW
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var code = _nearest_country(event.position)
		if code != "":
			selected_code = code
			queue_redraw()
			emit_signal("country_selected", code)
	elif event is InputEventKey and event.pressed and event.is_action("ui_accept"):
		var codes = relations.keys()
		if codes.is_empty():
			return
		if selected_code == "":
			selected_code = codes[0]
		else:
			selected_code = codes[(codes.find(selected_code) + 1) % codes.size()]
		queue_redraw()
		emit_signal("country_selected", selected_code)

func _nearest_country(position: Vector2) -> String:
	var best = ""
	var best_distance = 18.0
	for code in countries.keys():
		if code == player_country:
			continue
		var distance = position.distance_to(_country_point(code))
		if distance < best_distance:
			best_distance = distance
			best = code
	return best

func _country_point(code: String) -> Vector2:
	var country = countries.get(code, {})
	var lon = clamp(float(country.get("lon", 0.0)), -180.0, 180.0)
	var lat = clamp(float(country.get("lat", 0.0)), -80.0, 80.0)
	var x = (lon + 180.0) / 360.0
	var lat_rad = deg_to_rad(lat)
	var mercator = log(tan(PI / 4.0 + lat_rad / 2.0))
	var y = clamp(0.5 - mercator / (2.0 * PI), 0.06, 0.94)
	return _map_rect.position + Vector2(x, y) * _map_rect.size

func _fit_rect(texture_size: Vector2, available: Vector2) -> Rect2:
	if texture_size.x <= 0 or texture_size.y <= 0:
		return Rect2(Vector2.ZERO, available)
	var scale_factor = min(available.x / texture_size.x, available.y / texture_size.y)
	var fitted = texture_size * scale_factor
	return Rect2((available - fitted) * 0.5, fitted)

func _relation_color(value: float) -> Color:
	var normalized = clamp(value / 100.0, 0.0, 1.0)
	if normalized >= 0.65:
		return Color(0.25, 0.9, 0.45)
	if normalized >= 0.40:
		return Color(1.0, 0.78, 0.22)
	return Color(1.0, 0.3, 0.32)

func _country_name(code: String) -> String:
	return str(countries.get(code, {}).get("name_fa", code))

func _persian_number(value: int) -> String:
	var result = str(value)
	var en = "0123456789"
	var fa = "۰۱۲۳۴۵۶۷۸۹"
	for i in range(en.length()):
		result = result.replace(en[i], fa[i])
	return result
