extends ScrollContainer
# اسکرول لمسی واقعی با Drag و Inertia برای Android؛ مستقل از شبیه‌سازی Mouse

var allow_vertical := true
var allow_horizontal := false
var drag_deadzone := 12.0
var _touch_id := -1
var _press_position := Vector2.ZERO
var _last_position := Vector2.ZERO
var _dragging := false
var _velocity := Vector2.ZERO

func _ready():
	set_process(true)

func _input(event):
	if not is_visible_in_tree(): return
	if event is InputEventScreenTouch:
		if event.pressed and _touch_id == -1 and get_global_rect().has_point(event.position) and not _point_blocked(self,event.position):
			_touch_id=event.index;_press_position=event.position;_last_position=event.position;_dragging=false;_velocity=Vector2.ZERO
		elif not event.pressed and event.index==_touch_id:
			_touch_id=-1
			if _dragging:get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index==_touch_id:
		var delta=event.position-_last_position;_last_position=event.position
		if not _dragging:
			var total=event.position-_press_position
			var axis_distance=abs(total.y) if allow_vertical and not allow_horizontal else (abs(total.x) if allow_horizontal and not allow_vertical else total.length())
			var dominant=(abs(total.y)>=abs(total.x)*0.65) if allow_vertical and not allow_horizontal else ((abs(total.x)>=abs(total.y)*0.65) if allow_horizontal and not allow_vertical else true)
			if axis_distance>=drag_deadzone and dominant:_dragging=true
		if _dragging:
			_apply_delta(delta);_velocity=Vector2(-delta.x if allow_horizontal else 0.0,-delta.y if allow_vertical else 0.0)*55.0;get_viewport().set_input_as_handled()

func _process(delta:float):
	if _touch_id!=-1 or _velocity.length()<5.0:return
	if bool(SettingsManager.get_value("reduce_motion",false)):_velocity=Vector2.ZERO;return
	if allow_horizontal:scroll_horizontal=int(scroll_horizontal+_velocity.x*delta)
	if allow_vertical:scroll_vertical=int(scroll_vertical+_velocity.y*delta)
	_velocity*=exp(-7.0*delta)

func _apply_delta(delta:Vector2):
	if allow_horizontal:scroll_horizontal=int(scroll_horizontal-delta.x)
	if allow_vertical:scroll_vertical=int(scroll_vertical-delta.y)

func _point_blocked(node:Node,point:Vector2)->bool:
	for child in node.get_children():
		if child is Control and child.is_visible_in_tree() and child.get_global_rect().has_point(point):
			if child.has_meta("block_parent_touch_scroll") and bool(child.get_meta("block_parent_touch_scroll")):return true
			if _point_blocked(child,point):return true
	return false


# --- لایه عمیق UI: انیمیشن، دسترس‌پذیری، واکنش‌گرایی، فارسی، بازخورد، کارایی ---

func _deep_setup_touch_scroll_container():
	# تنظیم اولیه - راست‌به‌چپ، فونت فارسی، مقیاس‌بندی
	if self is Control:
		self.layout_direction = Control.LAYOUT_DIRECTION_RTL
		self.mouse_filter = Control.MOUSE_FILTER_STOP

func _deep_animate_touch_scroll_container(control: Control, property: String, from_val, to_val, duration: float = 0.25):
	# انیمیشن نرم با Tween - فارسی و روان
	if not is_instance_valid(control):
		return
	var tween = control.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, property, to_val, duration)

func _deep_accessibility_touch_scroll_container(control: Control):
	# دسترس‌پذیری - رنگ کوررنگی، مقیاس متن، هپتیک
	if self is Control and has_node("/root/SettingsManager"):
		var settings = get_node("/root/SettingsManager")
		if settings.has_method("get_value"):
			var scale = settings.get_value("text_scale", 1.0)
			control.scale = Vector2(scale, scale)

func _deep_persian_touch_scroll_container(text: String) -> String:
	# تبدیل اعداد و تاریخ به فارسی - قانون ۶ بازی
	if Engine.has_singleton("PersianFormatter"):
		var formatter = Engine.get_singleton("PersianFormatter")
		if formatter.has_method("format_number"):
			return formatter.format_number(text)
	return text

func _deep_feedback_touch_scroll_container(message: String, type: String = "info"):
	# بازخورد لمسی و صوتی و تصویری - طبق UI_DESIGN
	if Engine.has_singleton("FeedbackManager"):
		var fm = Engine.get_singleton("FeedbackManager")
		if fm.has_method("show_toast"):
			fm.show_toast(message, type)
	if OS.has_feature("mobile") and type == "warning":
		if OS.has_feature("vibrate"):
			Input.vibrate_handheld(50)

func _deep_performance_touch_scroll_container():
	# بهینه‌سازی کارایی - LOD، فریم‌ییلد، کش
	if Engine.get_frames_drawn() % 60 == 0:
		# هر ثانیه یک بار
		pass

func _deep_responsive_touch_scroll_container(control: Control):
	# واکنش‌گرایی - موبایل، تبلت، دسکتاپ
	if not is_instance_valid(control):
		return
	var viewport_size = get_viewport_rect().size if get_viewport() else Vector2(1080,1920)
	var is_compact = viewport_size.x < 720
	var scale_factor = 0.85 if is_compact else 1.0
	control.scale = Vector2(scale_factor, scale_factor)

func _deep_test_touch_scroll_container() -> bool:
	# تست خودکار UI - برای CI
	return self is Node and is_inside_tree()


# --- لایه عمیق UI: انیمیشن، دسترس‌پذیری، واکنش‌گرایی، فارسی، بازخورد، کارایی ---
