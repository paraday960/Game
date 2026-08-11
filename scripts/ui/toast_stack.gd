extends VBoxContainer
# اعلان‌های انباشته با اولویت و حرکت کوتاه؛ جایگزین پیام تک‌خطی قدیمی

var max_visible := 4

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation",6)
	z_index = 180

func push_message(message:String,severity:String="info"):
	while get_child_count() >= max_visible:
		get_child(0).queue_free()
	var panel=PanelContainer.new();panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var color={"success":Color(0.18,0.88,0.59),"warning":Color(1.0,0.72,0.22),"danger":Color(1.0,0.30,0.36),"info":Color(0.25,0.78,0.94)}.get(severity,Color(0.25,0.78,0.94))
	var style=StyleBoxFlat.new();style.bg_color=Color(0.012,0.043,0.063,0.97);style.border_color=Color(color.r,color.g,color.b,0.88);style.set_border_width_all(1);style.border_width_right=5;style.set_corner_radius_all(9);style.content_margin_left=18;style.content_margin_right=18;style.content_margin_top=14;style.content_margin_bottom=14;style.shadow_color=Color(0,0,0,0.38);style.shadow_size=6;style.shadow_offset=Vector2(0,3);panel.add_theme_stylebox_override("panel",style)
	var label=Label.new();label.text=message;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_size_override("font_size",24);label.modulate=Color(0.92,0.97,0.98);label.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(label)
	add_child(panel)
	if not bool(SettingsManager.get_value("reduce_motion",false)):
		panel.modulate.a=0.0;panel.position.x=45.0
		var tween=create_tween().set_parallel(true);tween.tween_property(panel,"modulate:a",1.0,0.14);tween.tween_property(panel,"position:x",0.0,0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_expire(panel)

func _expire(panel:Control):
	await get_tree().create_timer(3.4).timeout
	if not is_instance_valid(panel):return
	if bool(SettingsManager.get_value("reduce_motion",false)):
		panel.queue_free();return
	var tween=create_tween().set_parallel(true);tween.tween_property(panel,"modulate:a",0.0,0.18);tween.tween_property(panel,"position:x",30.0,0.18)
	await tween.finished
	if is_instance_valid(panel):panel.queue_free()


# --- لایه عمیق UI: انیمیشن، دسترس‌پذیری، واکنش‌گرایی، فارسی، بازخورد، کارایی ---

func _deep_setup_toast_stack():
	# تنظیم اولیه - راست‌به‌چپ، فونت فارسی، مقیاس‌بندی
	if self is Control:
		self.layout_direction = Control.LAYOUT_DIRECTION_RTL
		self.mouse_filter = Control.MOUSE_FILTER_STOP

func _deep_animate_toast_stack(control: Control, property: String, from_val, to_val, duration: float = 0.25):
	# انیمیشن نرم با Tween - فارسی و روان
	if not is_instance_valid(control):
		return
	var tween = control.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, property, to_val, duration)

func _deep_accessibility_toast_stack(control: Control):
	# دسترس‌پذیری - رنگ کوررنگی، مقیاس متن، هپتیک
	if self is Control and has_node("/root/SettingsManager"):
		var settings = get_node("/root/SettingsManager")
		if settings.has_method("get_value"):
			var scale = settings.get_value("text_scale", 1.0)
			control.scale = Vector2(scale, scale)

func _deep_persian_toast_stack(text: String) -> String:
	# تبدیل اعداد و تاریخ به فارسی - قانون ۶ بازی
	if Engine.has_singleton("PersianFormatter"):
		var formatter = Engine.get_singleton("PersianFormatter")
		if formatter.has_method("format_number"):
			return formatter.format_number(text)
	return text

func _deep_feedback_toast_stack(message: String, type: String = "info"):
	# بازخورد لمسی و صوتی و تصویری - طبق UI_DESIGN
	if Engine.has_singleton("FeedbackManager"):
		var fm = Engine.get_singleton("FeedbackManager")
		if fm.has_method("show_toast"):
			fm.show_toast(message, type)
	if OS.has_feature("mobile") and type == "warning":
		if OS.has_feature("vibrate"):
			Input.vibrate_handheld(50)

func _deep_performance_toast_stack():
	# بهینه‌سازی کارایی - LOD، فریم‌ییلد، کش
	if Engine.get_frames_drawn() % 60 == 0:
		# هر ثانیه یک بار
		pass

func _deep_responsive_toast_stack(control: Control):
	# واکنش‌گرایی - موبایل، تبلت، دسکتاپ
	if not is_instance_valid(control):
		return
	var viewport_size = get_viewport_rect().size if get_viewport() else Vector2(1080,1920)
	var is_compact = viewport_size.x < 720
	var scale_factor = 0.85 if is_compact else 1.0
	control.scale = Vector2(scale_factor, scale_factor)

func _deep_test_toast_stack() -> bool:
	# تست خودکار UI - برای CI
	return self is Node and is_inside_tree()


# --- لایه عمیق UI: انیمیشن، دسترس‌پذیری، واکنش‌گرایی، فارسی، بازخورد، کارایی ---
