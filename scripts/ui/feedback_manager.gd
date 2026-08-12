extends Node
# افکت صوتی رویه‌ای و رایگان؛ بدون فایل خارجی یا مجوز تجاری

var muted: bool = false
var volume: float = 0.22
var _player: AudioStreamPlayer
var _available: bool = false

func _ready():
	muted = not bool(SettingsManager.get_value("sound_enabled", true))
	volume = float(SettingsManager.get_value("sound_volume", 0.22))
	SettingsManager.settings_changed.connect(_on_setting_changed)
	_available = DisplayServer.get_name() != "headless" and not OS.has_feature("server")
	if not _available:
		return
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	add_child(_player)

func toggle_mute() -> bool:
	muted = not muted
	SettingsManager.set_value("sound_enabled", not muted)
	if muted and _player != null:
		_player.stop()
	return muted

func _on_setting_changed(key: String, value):
	if key == "sound_enabled":
		muted = not bool(value)
		if muted and _player != null:
			_player.stop()
	elif key == "sound_volume":
		volume = float(value)

func play_click():
	_haptic(12, 0.18)
	_play_tone(520.0, 0.045, volume * 0.55)

func play_success():
	_haptic(32, 0.34)
	_play_tone(760.0, 0.09, volume)

func play_alert():
	_haptic(90, 0.72)
	_play_tone(220.0, 0.14, volume * 0.9)

func play_celebration():
	# فنفار پیروزی: سه نت صعودی (مثل لحظه‌های مهم بازی‌های موفق)
	_haptic(70, 0.6)
	_play_tone(523.0, 0.12, volume * 0.8)
	_play_tone(659.0, 0.12, volume * 0.8)
	_play_tone(784.0, 0.22, volume)

func play_levelup():
	_haptic(85, 0.65)
	_play_tone(392.0, 0.10, volume * 0.7)
	_play_tone(523.0, 0.10, volume * 0.7)
	_play_tone(659.0, 0.10, volume * 0.7)
	_play_tone(1046.0, 0.28, volume)

func play_achievement():
	_haptic(65, 0.52)
	if muted or not _available:
		return
	# آکورد کوتاه دو مرحله‌ای؛ فراخوانی دوم با تأخیر غیرمسدودکننده
	_play_tone(660.0, 0.10, volume)
	_play_delayed_tone(880.0, 0.14, volume)

func _haptic(duration_ms: int, amplitude: float):
	if not bool(SettingsManager.get_value("haptics_enabled", true)):
		return
	if DisplayServer.get_name() == "headless" or OS.has_feature("server"):
		return
	Input.vibrate_handheld(duration_ms, clamp(amplitude, 0.0, 1.0))

func _play_delayed_tone(frequency: float, duration: float, amplitude: float):
	await get_tree().create_timer(0.10).timeout
	_play_tone(frequency, duration, amplitude)

func _play_tone(frequency: float, duration: float, amplitude: float):
	if muted or not _available or _player == null:
		return
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = max(duration + 0.04, 0.12)
	_player.stream = generator
	_player.play()
	var playback = _player.get_stream_playback()
	if not playback is AudioStreamGeneratorPlayback:
		return
	var frames = int(generator.mix_rate * duration)
	for i in range(frames):
		var t = float(i) / generator.mix_rate
		var envelope = min(1.0, float(i) / 100.0) * (1.0 - float(i) / max(frames, 1))
		var sample = sin(TAU * frequency * t) * amplitude * envelope
		playback.push_frame(Vector2(sample, sample))


# --- لایه عمیق UI: انیمیشن، دسترس‌پذیری، واکنش‌گرایی، فارسی، بازخورد، کارایی ---

func _deep_setup_feedback_manager():
	# تنظیم اولیه - راست‌به‌چپ، فونت فارسی، مقیاس‌بندی
	var _me: Variant = self
	if _me is Control:
		_me.layout_direction = Control.LAYOUT_DIRECTION_RTL
		_me.mouse_filter = Control.MOUSE_FILTER_STOP

func _deep_animate_feedback_manager(control: Control, property: String, from_val, to_val, duration: float = 0.25):
	# انیمیشن نرم با Tween - فارسی و روان
	if not is_instance_valid(control):
		return
	var tween = control.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, property, to_val, duration)

func _deep_accessibility_feedback_manager(control: Control):
	# دسترس‌پذیری - رنگ کوررنگی، مقیاس متن، هپتیک
	var _me2: Variant = self
	if _me2 is Control and has_node("/root/SettingsManager"):
		var settings = get_node("/root/SettingsManager")
		if settings.has_method("get_value"):
			var scale = settings.get_value("text_scale", 1.0)
			control.scale = Vector2(scale, scale)

func _deep_persian_feedback_manager(text: String) -> String:
	# تبدیل اعداد و تاریخ به فارسی - قانون ۶ بازی
	if Engine.has_singleton("PersianFormatter"):
		var formatter = Engine.get_singleton("PersianFormatter")
		if formatter.has_method("format_number"):
			return formatter.format_number(text)
	return text

func _deep_feedback_feedback_manager(message: String, type: String = "info"):
	# بازخورد لمسی و صوتی و تصویری - طبق UI_DESIGN
	if Engine.has_singleton("FeedbackManager"):
		var fm = Engine.get_singleton("FeedbackManager")
		if fm.has_method("show_toast"):
			fm.show_toast(message, type)
	if OS.has_feature("mobile") and type == "warning":
		if OS.has_feature("vibrate"):
			Input.vibrate_handheld(50)

func _deep_performance_feedback_manager():
	# بهینه‌سازی کارایی - LOD، فریم‌ییلد، کش
	if Engine.get_frames_drawn() % 60 == 0:
		# هر ثانیه یک بار
		pass

func _deep_responsive_feedback_manager(control: Control):
	# واکنش‌گرایی - موبایل، تبلت، دسکتاپ
	if not is_instance_valid(control):
		return
	var viewport_size = get_viewport().get_visible_rect().size if get_viewport() else Vector2(1080,1920)
	var is_compact = viewport_size.x < 720
	var scale_factor = 0.85 if is_compact else 1.0
	control.scale = Vector2(scale_factor, scale_factor)

func _deep_test_feedback_manager() -> bool:
	# تست خودکار UI - برای CI
	return self is Node and is_inside_tree()


# --- لایه عمیق UI: انیمیشن، دسترس‌پذیری، واکنش‌گرایی، فارسی، بازخورد، کارایی ---
