extends Control
# پس‌زمینه اورجینال اتاق فرمان؛ بدون تصویر یا منبع خارجی

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()

func _draw():
	for index in range(36):
		var ratio = float(index) / 35.0
		var color = Color(0.025, 0.061, 0.092).lerp(Color(0.006, 0.018, 0.035), ratio)
		draw_rect(Rect2(0, size.y * ratio, size.x, size.y / 35.0 + 1.0), color, true)
	var grid_color = Color(0.17, 0.50, 0.60, 0.055)
	for x in range(0, int(size.x) + 1, 48):
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid_color, 1.0)
	for y in range(0, int(size.y) + 1, 48):
		draw_line(Vector2(0, y), Vector2(size.x, y), grid_color, 1.0)
	for radius in range(420, 40, -36):
		var alpha = (420.0 - float(radius)) / 420.0 * 0.006
		draw_circle(Vector2(size.x * 0.13, size.y * 0.18), float(radius), Color(0.08, 0.72, 0.78, alpha))
	draw_line(Vector2(0, 2), Vector2(size.x, 2), Color(0.28, 0.85, 0.92, 0.42), 2.0)
