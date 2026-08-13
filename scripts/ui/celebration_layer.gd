extends Control
# ============================================================
# 🎉 لایه جشن — بنر متحرک + کاغذرنگی (Confetti)
# برای لحظه‌های مهم: دستاورد، ارتقای مرحله، رکورد، مرز جمعیت/GDP.
# بدون تصویر خارجی؛ همه‌چیز با رسم برداری (خودکفا و رایگان).
# ============================================================

const PersianFont = preload("res://assets/fonts/Vazirmatn-Regular.ttf")
const GOLD := Color(1.0, 0.83, 0.30)
const TEAL := Color(0.30, 0.88, 0.86)
const BLUE := Color(0.42, 0.68, 1.0)
const GREEN := Color(0.42, 0.95, 0.60)

var _banner_alpha := 0.0
var _banner_title := ""
var _banner_subtitle := ""
var _banner_severity := GOLD
var _banner_scale := 1.2
var _banner_show_frames := 0
var _confetti: Array = []
var _confetti_active := false
var _frames := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func celebrate(celebration: Dictionary) -> void:
	set_process(true)
	var sev: String = str(celebration.get("severity", "gold"))
	match sev:
		"gold": _banner_severity = GOLD
		"teal": _banner_severity = TEAL
		"blue": _banner_severity = BLUE
		"green": _banner_severity = GREEN
		_: _banner_severity = GOLD
	_banner_title = str(celebration.get("title", ""))
	_banner_subtitle = str(celebration.get("subtitle", ""))
	_banner_alpha = 1.0
	_banner_scale = 1.25
	_banner_show_frames = 220
	_confetti_active = true
	# تولید کاغذرنگی
	_confetti.clear()
	for i in range(46):
		_confetti.append({
			"x": randf_range(0.0, size.x),
			"y": randf_range(-size.y * 0.5, -20.0),
			"vx": randf_range(-0.6, 0.6),
			"vy": randf_range(2.2, 5.2),
			"rot": randf_range(0.0, TAU),
			"vr": randf_range(-0.15, 0.15),
			"w": randf_range(5.0, 11.0),
			"h": randf_range(3.0, 7.0),
			"color": [GOLD, TEAL, BLUE, GREEN, Color(1.0, 0.55, 0.55), Color(0.9, 0.75, 1.0)].pick_random()
		})
	queue_redraw()
	# صدا و لرزش
	FeedbackManager.play_celebration()

# متن را با فونت و عرض واقعی به چند خط می‌شکند تا هرگز از کادر بیرون نزند
func _wrap_text(font: Font, text: String, max_width: float, font_size: int) -> Array:
	var lines: Array = []
	if text.is_empty():
		return lines
	var words := text.split(" ")
	var current := ""
	for word in words:
		var test := current + (" " if current != "" else "") + word
		if font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width:
			current = test
		else:
			if current != "":
				lines.append(current)
			current = word
	if current != "":
		lines.append(current)
	return lines

func _process(delta: float) -> void:
	_frames += 1
	var changed := false
	if _banner_alpha > 0.0:
		_banner_show_frames -= 1
		_banner_scale = lerpf(_banner_scale, 1.0, 0.08)
		if _banner_show_frames <= 0:
			_banner_alpha = maxf(0.0, _banner_alpha - 0.02)
		changed = true
	if _confetti_active:
		var alive := false
		for p in _confetti:
			p["x"] = float(p["x"]) + float(p["vx"])
			p["y"] = float(p["y"]) + float(p["vy"])
			p["vy"] = float(p["vy"]) + 0.08
			p["rot"] = float(p["rot"]) + float(p["vr"])
			if float(p["y"]) < size.y + 30.0:
				alive = true
		_confetti_active = alive
		changed = true
	if changed:
		queue_redraw()
	elif _banner_alpha <= 0.0 and not _confetti_active:
		# باتری: وقتی هیچ جشنی فعال نیست، پردازش فریم‌به‌فریم کاملاً می‌ایستد
		# و با فراخوانی بعدی celebrate دوباره روشن می‌شود.
		set_process(false)

func _draw() -> void:
	# کاغذرنگی
	if _confetti_active:
		for p in _confetti:
			draw_set_transform(Vector2(float(p["x"]), float(p["y"])), float(p["rot"]), Vector2.ONE)
			draw_rect(Rect2(-float(p["w"]) * 0.5, -float(p["h"]) * 0.5, float(p["w"]), float(p["h"])), p["color"], true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# بنر مرکزی — متن فارسی با شکستن خودکار خط داخل کادر
	if _banner_alpha > 0.0:
		var cw := size.x
		var banner_w := minf(cw - 40.0, 760.0)
		# بنر و متن هر دو با مقیاس یکسان؛ متن همیشه داخل بنر و بنر داخل صفحه
		var banner_w_scaled := banner_w * _banner_scale
		var text_w := banner_w_scaled - 28.0
		var font := PersianFont
		# محاسبه ارتفاع واقعی متن (چندخطی) تا بنر دقیقاً اندازه متن باشد
		var title_size := int(30.0 * _banner_scale)
		var title_lines: int = _wrap_text(font, _banner_title, text_w, title_size).size()
		var sub_lines: int = 0
		var sub_size := 21
		if _banner_subtitle != "":
			sub_lines = _wrap_text(font, _banner_subtitle, text_w, sub_size).size()
		# ارتفاع دینامیک بنر: تیتر + زیرتیتر + فاصله‌ها
		var banner_h := 80.0 + float(title_lines) * 36.0 + float(sub_lines) * 26.0
		banner_h = maxf(banner_h, 120.0)
		var center := Vector2(cw * 0.5, size.y * 0.24)
		var rect := Rect2(center - Vector2(banner_w_scaled * 0.5, banner_h * 0.5 * _banner_scale), Vector2(banner_w_scaled, banner_h * _banner_scale))
		# پس‌زمینه
		draw_rect(rect, Color(0.01, 0.03, 0.05, 0.94 * _banner_alpha), true)
		draw_rect(rect, Color(_banner_severity.r, _banner_severity.g, _banner_severity.b, 0.9 * _banner_alpha), false, 3.0)
		# تیتر و زیرتیتر — وسط‌چین عمودی با فاصله‌گذاری واقعی فونت
		# draw_string با width فقط برای align است و متن را محدود نمی‌کند؛
		# بنابراین هر خط را با عرض واقعی اندازه می‌گیریم و دستی مرکز می‌کنیم.
		var title_lines_arr := _wrap_text(font, _banner_title, text_w, title_size)
		var sub_lines_arr: Array = []
		if _banner_subtitle != "":
			sub_lines_arr = _wrap_text(font, _banner_subtitle, text_w, sub_size)
		var title_ascent: float = font.get_ascent(title_size)
		var title_descent: float = font.get_descent(title_size)
		var sub_ascent := 0.0
		var sub_descent := 0.0
		if sub_lines_arr.size() > 0:
			sub_ascent = font.get_ascent(sub_size)
			sub_descent = font.get_descent(sub_size)
		# فاصله بین خطوط هم‌خانواده (بدون همپوشانی حروف)
		var title_line_gap := title_ascent + title_descent + 5.0
		var sub_line_gap := sub_ascent + sub_descent + 4.0
		# فاصله بین تیتر و زیرتیتر: descent تیتر + تنفس + ascent زیرتیتر
		var title_sub_gap := title_descent + 7.0 + sub_ascent
		# بلوک واقعی متن از بالای ascent تیتر تا پایین descent آخرین خط
		var total_text_h := float(maxi(0, title_lines_arr.size() - 1)) * title_line_gap + title_ascent
		if sub_lines_arr.size() > 0:
			total_text_h += title_sub_gap + float(maxi(0, sub_lines_arr.size() - 1)) * sub_line_gap + sub_descent
		else:
			total_text_h += title_descent
		# نقطه شروع عمودی: وسط بنر منهای نصف بلوک متن (فاصله بالا و پایین یکسان)
		var text_top := rect.position.y + (rect.size.y - total_text_h) * 0.5
		var title_y := text_top + title_ascent
		for line in title_lines_arr:
			var line_w: float = font.get_string_size(str(line), HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
			var line_x: float = center.x - line_w * 0.5
			draw_string(font, Vector2(line_x, title_y), str(line), HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(1, 1, 1, _banner_alpha))
			title_y += title_line_gap
		# زیرتیتر (title_y بعد از حلقه یک فاصله خط جلوتر است؛ آن را برمی‌گردانیم)
		if sub_lines_arr.size() > 0:
			var sub_y := title_y - title_line_gap + title_sub_gap
			for line in sub_lines_arr:
				var line_w2: float = font.get_string_size(str(line), HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size).x
				var line_x2: float = center.x - line_w2 * 0.5
				draw_string(font, Vector2(line_x2, sub_y), str(line), HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, Color(0.85, 0.9, 0.95, _banner_alpha * 0.9))
				sub_y += sub_line_gap
