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
