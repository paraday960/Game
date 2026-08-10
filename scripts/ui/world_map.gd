extends Control
# نقشه جهان آفلاین بر پایه Natural Earth (Public Domain) با نقاط تعاملی روابط

signal country_selected(code)

const WORLD_TEXTURE = preload("res://assets/maps/world_natural_earth.svg")
const HOTSPOTS = {
	"همسایه_شرقی": Vector2(0.61, 0.43),
	"همسایه_غربی": Vector2(0.48, 0.43),
	"ابرقدرت_۱": Vector2(0.22, 0.34),
	"ابرقدرت_۲": Vector2(0.77, 0.38)
}
const COUNTRY_NAMES = {
	"همسایه_شرقی": "همسایه شرقی",
	"همسایه_غربی": "همسایه غربی",
	"ابرقدرت_۱": "ابرقدرت نخست",
	"ابرقدرت_۲": "ابرقدرت دوم"
}

var relations: Dictionary = {}
var selected_code: String = ""
var hovered_code: String = ""
var _map_rect := Rect2()

func _ready():
	custom_minimum_size = Vector2(0, 410)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	resized.connect(queue_redraw)
	queue_redraw()

func set_relations(new_relations: Dictionary):
	relations = new_relations.duplicate(true)
	queue_redraw()

func _draw():
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.055, 0.11), true)
	_map_rect = _fit_rect(Vector2(WORLD_TEXTURE.get_width(), WORLD_TEXTURE.get_height()), size - Vector2(20, 20))
	_map_rect.position += Vector2(10, 10)
	draw_texture_rect(WORLD_TEXTURE, _map_rect, false, Color(0.62, 0.75, 0.84, 0.72))
	draw_rect(_map_rect, Color(0.25, 0.55, 0.75, 0.8), false, 2.0)
	for code in HOTSPOTS.keys():
		var point = _map_rect.position + HOTSPOTS[code] * _map_rect.size
		var relation = float(relations.get(code, 0.0))
		var color = _relation_color(relation)
		var radius = 14.0
		if code == hovered_code:
			radius = 19.0
		if code == selected_code:
			draw_circle(point, 24.0, Color(1.0, 0.86, 0.3, 0.3))
		draw_circle(point, radius, Color(0.02, 0.05, 0.10, 0.9))
		draw_circle(point, radius - 4.0, color)
		draw_arc(point, radius, 0, TAU, 32, Color(1, 1, 1, 0.8), 2.0)
		var label = "%s  %s" % [COUNTRY_NAMES.get(code, code), _persian_number(int(relation))]
		var label_position = point + Vector2(20, -8)
		draw_string(ThemeDB.fallback_font, label_position, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

func _gui_input(event):
	if event is InputEventMouseMotion:
		var next_hover = _nearest_hotspot(event.position)
		if next_hover != hovered_code:
			hovered_code = next_hover
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovered_code != "" else Control.CURSOR_ARROW
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var code = _nearest_hotspot(event.position)
		if code != "":
			selected_code = code
			queue_redraw()
			emit_signal("country_selected", code)
	elif event is InputEventKey and event.pressed and event.is_action("ui_accept"):
		var codes = HOTSPOTS.keys()
		if selected_code == "":
			selected_code = codes[0]
		else:
			selected_code = codes[(codes.find(selected_code) + 1) % codes.size()]
		queue_redraw()
		emit_signal("country_selected", selected_code)

func _nearest_hotspot(position: Vector2) -> String:
	var best = ""
	var best_distance = 34.0
	for code in HOTSPOTS.keys():
		var point = _map_rect.position + HOTSPOTS[code] * _map_rect.size
		var distance = position.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = code
	return best

func _fit_rect(texture_size: Vector2, available: Vector2) -> Rect2:
	if texture_size.x <= 0 or texture_size.y <= 0:
		return Rect2(Vector2.ZERO, available)
	var scale_factor = min(available.x / texture_size.x, available.y / texture_size.y)
	var fitted = texture_size * scale_factor
	return Rect2((available - fitted) * 0.5, fitted)

func _relation_color(value: float) -> Color:
	var normalized = clamp((value + 100.0) / 200.0, 0.0, 1.0)
	if normalized >= 0.65:
		return Color(0.25, 0.9, 0.45)
	if normalized >= 0.40:
		return Color(1.0, 0.78, 0.22)
	return Color(1.0, 0.3, 0.32)

func _persian_number(value: int) -> String:
	var result = str(value)
	var en = "0123456789"
	var fa = "۰۱۲۳۴۵۶۷۸۹"
	for i in range(en.length()):
		result = result.replace(en[i], fa[i])
	return result
