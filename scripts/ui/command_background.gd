extends Control
# پس‌زمینه اورجینال «اتاق فرمان»؛ گرادیان شبانه + هاله‌های نوری + شبکه راهبردی
# بدون هیچ تصویر یا منبع خارجی — همه‌چیز با رسم برداری ساخته می‌شود.

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()

func _draw():
	# گرادیان عمودی: نیلی عمیق بالا → تقریباً مشکی پایین
	for index in range(40):
		var ratio = float(index) / 39.0
		var color = Color(0.032, 0.070, 0.115).lerp(Color(0.006, 0.016, 0.032), ratio)
		draw_rect(Rect2(0, size.y * ratio, size.x, size.y / 39.0 + 1.0), color, true)
	# شبکه راهبردی کم‌رنگ
	var grid_color = Color(0.20, 0.46, 0.58, 0.05)
	for x in range(0, int(size.x) + 1, 52):
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid_color, 1.0)
	for y in range(0, int(size.y) + 1, 52):
		draw_line(Vector2(0, y), Vector2(size.x, y), grid_color, 1.0)
	# هاله فیروزه‌ای بالا-راست (رادار)
	for radius in range(560, 40, -40):
		var alpha = (560.0 - float(radius)) / 560.0 * 0.007
		draw_circle(Vector2(size.x * 0.86, size.y * 0.10), float(radius), Color(0.14, 0.80, 0.76, alpha))
	# هاله طلایی پایین-چپ (قلب حکمرانی)
	for radius in range(500, 40, -40):
		var alpha = (500.0 - float(radius)) / 500.0 * 0.005
		draw_circle(Vector2(size.x * 0.10, size.y * 0.92), float(radius), Color(0.93, 0.74, 0.33, alpha))
	# وینەت لبه‌ها برای عمق (سبک HOI4)
	for index in range(10):
		var thickness = size.x * 0.012 * (index + 1)
		var alpha = 0.05 * (1.0 - float(index) / 10.0)
		var vc = Color(0.0, 0.0, 0.0, alpha)
		draw_rect(Rect2(0, 0, thickness, size.y), vc, true)
		draw_rect(Rect2(size.x - thickness, 0, thickness, size.y), vc, true)
		draw_rect(Rect2(0, 0, size.x, thickness), vc, true)
		draw_rect(Rect2(0, size.y - thickness, size.x, thickness), vc, true)
	# خط افقی طلایی زیر نوار بالایی
	draw_line(Vector2(0, 2), Vector2(size.x, 2), Color(0.93, 0.74, 0.33, 0.30), 2.0)
