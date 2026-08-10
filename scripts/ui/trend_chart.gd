extends Control
# نمودار آفلاین روند هفتگی شاخص‌های اصلی

const PersianFont = preload("res://assets/fonts/Vazirmatn-Regular.ttf")
const SERIES = [
	{"key":"happiness", "name":"شادی", "color":Color(0.30, 0.95, 0.52)},
	{"key":"stability", "name":"ثبات", "color":Color(0.30, 0.70, 1.00)},
	{"key":"power", "name":"قدرت", "color":Color(1.00, 0.72, 0.24)},
	{"key":"gdp_index", "name":"رشد اقتصاد", "color":Color(0.82, 0.45, 1.00)}
]

var history: Array = []

func _ready():
	custom_minimum_size = Vector2(0, 300)
	resized.connect(queue_redraw)

func set_history(value: Array):
	history = value.duplicate(true)
	queue_redraw()

func _draw():
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.055, 0.11), true)
	var plot = Rect2(Vector2(52, 38), Vector2(max(10.0, size.x - 76), max(10.0, size.y - 88)))
	for i in range(5):
		var y = plot.position.y + plot.size.y * float(i) / 4.0
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(0.35, 0.5, 0.65, 0.22), 1.0)
		var label = "%s٪" % _fa(str(100 - i * 25))
		draw_string(PersianFont, Vector2(8, y + 5), label, HORIZONTAL_ALIGNMENT_LEFT, 42, 13, Color(0.65, 0.72, 0.82))
	draw_rect(plot, Color(0.35, 0.62, 0.82, 0.65), false, 1.5)
	if history.size() < 2:
		draw_string(PersianFont, plot.get_center() + Vector2(-135, 4), "نمودار پس از هفت روز شکل می‌گیرد", HORIZONTAL_ALIGNMENT_CENTER, 270, 16, Color(0.78, 0.82, 0.9))
	else:
		for definition in SERIES:
			var points := PackedVector2Array()
			for i in range(history.size()):
				var x = plot.position.x + plot.size.x * float(i) / float(history.size() - 1)
				var normalized = _normalized_value(str(definition["key"]), history[i].get(definition["key"], 0.0))
				var y = plot.end.y - normalized * plot.size.y
				points.append(Vector2(x, y))
			if points.size() >= 2:
				draw_polyline(points, definition["color"], 2.5, true)
				draw_circle(points[-1], 4.0, definition["color"])
	var legend_x = plot.position.x
	for definition in SERIES:
		draw_circle(Vector2(legend_x + 6, size.y - 23), 5.0, definition["color"])
		draw_string(PersianFont, Vector2(legend_x + 16, size.y - 17), str(definition["name"]), HORIZONTAL_ALIGNMENT_LEFT, 100, 14, Color.WHITE)
		legend_x += 125

func _normalized_value(key: String, raw) -> float:
	var value = float(raw)
	if key == "gdp_index":
		# بازه ۸۰٪ تا ۱۳۰٪ خط پایه روی ارتفاع کامل نمودار
		return clamp((value - 0.80) / 0.50, 0.0, 1.0)
	return clamp(value, 0.0, 1.0)

func _fa(text: String) -> String:
	var result = text
	var en = "0123456789"
	var fa = "۰۱۲۳۴۵۶۷۸۹"
	for i in range(10):
		result = result.replace(en[i], fa[i])
	return result
