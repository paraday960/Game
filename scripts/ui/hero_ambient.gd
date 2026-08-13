extends Control
# ✨ غبار طلایی شناور برای صفحه شروع — حس سینمایی پشت کارت قهرمان
# کاملاً نمایشی، سبک (۲۰ ذره) و بدون اثر روی دترمینیسم.

var _dust: Array = []
var _t := 0.0
var _accum := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for i in range(22):
		_dust.append({
			"x": randf_range(0.0, 1.0),
			"y": randf_range(0.0, 1.0),
			"r": randf_range(1.2, 3.4),
			"speed": randf_range(0.002, 0.006),
			"drift": randf_range(0.0, TAU),
			"phase": randf_range(0.0, TAU),
			"warm": randf() < 0.6
		})
	set_process(true)

func _process(delta: float) -> void:
	# باتری: وقتی این لایه پشت تب‌های دیگر پنهان است هیچ پردازشی نمی‌شود
	if not is_visible_in_tree():
		return
	_accum += delta
	if _accum < 1.0 / 24.0:
		return
	_accum = 0.0
	_t += delta
	queue_redraw()

func _draw() -> void:
	for i in range(_dust.size()):
		var p: Dictionary = _dust[i]
		var x: float = fposmod(float(p["x"]) + _t * float(p["speed"]) + sin(_t * 0.3 + float(p["drift"])) * 0.02, 1.0)
		var y: float = float(p["y"]) + sin(_t * 0.22 + float(p["drift"]) * 2.0) * 0.015
		var tw: float = 0.5 + 0.5 * sin(_t * 1.4 + float(p["phase"]))
		var col: Color = Color(1.0, 0.84, 0.45) if bool(p["warm"]) else Color(0.55, 0.90, 0.95)
		draw_circle(Vector2(x * size.x, y * size.y), float(p["r"]) * (0.7 + tw * 0.5), Color(col.r, col.g, col.b, 0.08 + 0.30 * tw))
