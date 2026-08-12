extends Control
# ============================================================
# 🎉 لایه جشن — بنر متحرک + کاغذرنگی (Confetti)
# برای لحظه‌های مهم: دستاورد، ارتقای مرحله، رکورد، مرز جمعیت/GDP.
# بدون تصویر خارجی؛ همه‌چیز با رسم برداری (خودکفا و رایگان).
# ============================================================

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

func _draw() -> void:
	# کاغذرنگی
	if _confetti_active:
		for p in _confetti:
			draw_set_transform(Vector2(float(p["x"]), float(p["y"])), float(p["rot"]), Vector2.ONE)
			draw_rect(Rect2(-float(p["w"]) * 0.5, -float(p["h"]) * 0.5, float(p["w"]), float(p["h"])), p["color"], true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# بنر مرکزی
	if _banner_alpha > 0.0:
		var cw := size.x
		var banner_w := minf(cw - 40.0, 760.0)
		var banner_h := 150.0
		var center := Vector2(cw * 0.5, size.y * 0.24)
		var rect := Rect2(center - Vector2(banner_w * 0.5, banner_h * 0.5) * _banner_scale, Vector2(banner_w, banner_h) * _banner_scale)
		# پس‌زمینه
		draw_rect(rect, Color(0.01, 0.03, 0.05, 0.94 * _banner_alpha), true)
		draw_rect(rect, Color(_banner_severity.r, _banner_severity.g, _banner_severity.b, 0.9 * _banner_alpha), false, 3.0)
		# تیتر
		var font := ThemeDB.fallback_font
		var font_size := int(30.0 * _banner_scale)
		var title_pos := Vector2(center.x, rect.position.y + 52.0 * _banner_scale)
		draw_string(font, title_pos, _banner_title, HORIZONTAL_ALIGNMENT_CENTER, banner_w * _banner_scale - 20.0, font_size, Color(1, 1, 1, _banner_alpha))
		# زیرتیتر
		if _banner_subtitle != "":
			var sub_pos := Vector2(center.x, rect.position.y + 96.0 * _banner_scale)
			draw_string(font, sub_pos, _banner_subtitle, HORIZONTAL_ALIGNMENT_CENTER, banner_w * _banner_scale - 20.0, 21, Color(0.85, 0.9, 0.95, _banner_alpha * 0.9))
