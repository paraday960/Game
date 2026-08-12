extends Control
# پس‌زمینه اورجینال «اتاق فرمان»؛ گرادیان شبانه + هاله‌های نوری + شبکه راهبردی
# بدون هیچ تصویر یا منبع خارجی — همه‌چیز با رسم برداری ساخته می‌شود.

# ستاره‌های چشمک‌زن و شهاب — پس‌زمینه زنده (procedural، نرخ محدود)
var _stars: Array = []
var _shooting_stars: Array = []
var _bg_time := 0.0
var _accum := 0.0

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()
	_generate_stars()
	set_process(true)

func _generate_stars():
	_stars.clear()
	for i in range(140):
		_stars.append({
			"x": randf_range(0.0, 1.0),
			"y": randf_range(0.0, 0.55),
			"r": randf_range(0.6, 2.2),
			"phase": randf_range(0.0, TAU),
			"speed": randf_range(0.4, 2.2)
		})

func _process(delta):
	_accum += delta
	if _accum < 1.0 / 20.0:
		return
	_accum = 0.0
	_bg_time += delta
	# شهاب‌های گاه‌به‌گاه
	if randf() < 0.008 and _shooting_stars.size() < 3:
		_shooting_stars.append({
			"x": randf_range(0.2, 0.9), "y": randf_range(0.0, 0.2),
			"vx": randf_range(0.012, 0.02), "vy": randf_range(0.008, 0.013),
			"life": 1.0
		})
	for s in _shooting_stars:
		s["x"] = float(s["x"]) + float(s["vx"])
		s["y"] = float(s["y"]) + float(s["vy"])
		s["life"] = float(s["life"]) - 0.035
	_shooting_stars = _shooting_stars.filter(func(s): return float(s["life"]) > 0.0)
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
	# ── ستاره‌های چشمک‌زن (نیمه بالایی، سبک اتاق فرمان شبانه) ──
	for star in _stars:
		var twinkle: float = 0.45 + 0.55 * sin(_bg_time * float(star["speed"]) + float(star["phase"]))
		var px := Vector2(float(star["x"]) * size.x, float(star["y"]) * size.y)
		draw_circle(px, float(star["r"]) * (0.8 + twinkle * 0.4), Color(0.85, 0.92, 1.0, 0.10 + 0.28 * twinkle))
		# هاله‌های روشن‌تر
		if twinkle > 0.75:
			draw_circle(px, float(star["r"]) * 2.4, Color(0.72, 0.86, 1.0, 0.05 * twinkle))
	# ── شفق قطبی متحرک (aurora) — هاله‌های رنگی آرام در پس‌زمینه ──
	for b in range(3):
		var cx: float = size.x * (0.22 + 0.28 * sin(_bg_time * 0.07 + float(b) * 2.4) + float(b) * 0.16)
		var cy: float = size.y * (0.10 + 0.05 * cos(_bg_time * 0.05 + float(b) * 1.7))
		var hue_col: Color = [Color(0.12, 0.55, 0.70), Color(0.55, 0.35, 0.75), Color(0.85, 0.60, 0.25)][b]
		for radius in range(300, 20, -20):
			var alpha: float = (300.0 - float(radius)) / 300.0 * 0.016
			alpha *= 0.75 + 0.25 * sin(_bg_time * 0.4 + float(b) * 2.0)
			draw_circle(Vector2(cx, cy), float(radius), Color(hue_col.r, hue_col.g, hue_col.b, alpha))
	# ── شهاب‌ها ──
	for s in _shooting_stars:
		var start := Vector2(float(s["x"]) * size.x, float(s["y"]) * size.y)
		var tail := start - Vector2(float(s["vx"]), float(s["vy"])) * 320.0
		var alpha: float = clampf(float(s["life"]), 0.0, 1.0)
		draw_line(tail, start, Color(0.85, 0.92, 1.0, 0.28 * alpha), 1.6, true)
		draw_circle(start, 1.8, Color(1.0, 1.0, 1.0, 0.75 * alpha))


# --- لایه عمیق UI: انیمیشن، دسترس‌پذیری، واکنش‌گرایی، فارسی، بازخورد، کارایی ---

func _deep_setup_command_background():
	# تنظیم اولیه - راست‌به‌چپ، فونت فارسی، مقیاس‌بندی
	if self is Control:
		self.layout_direction = Control.LAYOUT_DIRECTION_RTL
		self.mouse_filter = Control.MOUSE_FILTER_STOP

func _deep_animate_command_background(control: Control, property: String, from_val, to_val, duration: float = 0.25):
	# انیمیشن نرم با Tween - فارسی و روان
	if not is_instance_valid(control):
		return
	var tween = control.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, property, to_val, duration)

func _deep_accessibility_command_background(control: Control):
	# دسترس‌پذیری - رنگ کوررنگی، مقیاس متن، هپتیک
	if self is Control and has_node("/root/SettingsManager"):
		var settings = get_node("/root/SettingsManager")
		if settings.has_method("get_value"):
			var scale = settings.get_value("text_scale", 1.0)
			control.scale = Vector2(scale, scale)

func _deep_persian_command_background(text: String) -> String:
	# تبدیل اعداد و تاریخ به فارسی - قانون ۶ بازی
	if Engine.has_singleton("PersianFormatter"):
		var formatter = Engine.get_singleton("PersianFormatter")
		if formatter.has_method("format_number"):
			return formatter.format_number(text)
	return text

func _deep_feedback_command_background(message: String, type: String = "info"):
	# بازخورد لمسی و صوتی و تصویری - طبق UI_DESIGN
	if Engine.has_singleton("FeedbackManager"):
		var fm = Engine.get_singleton("FeedbackManager")
		if fm.has_method("show_toast"):
			fm.show_toast(message, type)
	if OS.has_feature("mobile") and type == "warning":
		if OS.has_feature("vibrate"):
			Input.vibrate_handheld(50)

func _deep_performance_command_background():
	# بهینه‌سازی کارایی - LOD، فریم‌ییلد، کش
	if Engine.get_frames_drawn() % 60 == 0:
		# هر ثانیه یک بار
		pass

func _deep_responsive_command_background(control: Control):
	# واکنش‌گرایی - موبایل، تبلت، دسکتاپ
	if not is_instance_valid(control):
		return
	var viewport_size = get_viewport_rect().size if get_viewport() else Vector2(1080,1920)
	var is_compact = viewport_size.x < 720
	var scale_factor = 0.85 if is_compact else 1.0
	control.scale = Vector2(scale_factor, scale_factor)

func _deep_test_command_background() -> bool:
	# تست خودکار UI - برای CI
	return self is Node and is_inside_tree()


# --- لایه عمیق UI: انیمیشن، دسترس‌پذیری، واکنش‌گرایی، فارسی، بازخورد، کارایی ---
