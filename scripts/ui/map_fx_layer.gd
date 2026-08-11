extends Control
# لایه افکت‌های زنده «نقشه راهبردی» — موج اقیانوس، پالس جنگ، جریان تجارت،
# ابر آب‌وهوا و چراغ پایتخت. خود نقشه ثابت می‌ماند و فقط این لایه سبک با نرخ
# محدود (~۱۲ فریم) بازترسیم می‌شود تا باتری و پردازش حفظ شود.
# همه افکت‌ها نمایشی‌اند و هیچ اثری روی State یا دترمینیسم موتور ندارند.

const PersianFont = preload("res://assets/fonts/Vazirmatn-Regular.ttf")
const FX_FPS := 12.0

var map: Control
var fx_time := 0.0
var _accum := 0.0

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)

func _process(delta: float):
	if not is_instance_valid(map):
		set_process(false)
		return
	# هنگام حرکت دوربین به‌صورت فریم‌به‌فریم هم‌تراز می‌مانیم.
	if map._motion_active():
		queue_redraw()
		return
	if not map._fx_active():
		return
	_accum += delta
	if _accum < 1.0 / FX_FPS:
		return
	fx_time += _accum
	_accum = 0.0
	queue_redraw()

func _draw():
	if not is_instance_valid(map) or not map.visible:
		return
	if bool(SettingsManager.get_value("reduce_motion", false)):
		return
	_draw_ocean_shimmer()
	_draw_trade_flow()
	_draw_war_pulses()
	_draw_capital_beacon()
	_draw_weather_clouds()

# موج‌های نوری آرام روی اقیانوس در نمای جهان/منطقه — حس نقشه زنده HOI4.
func _draw_ocean_shimmer():
	if float(map.zoom_level) > 2.3:
		return
	var fade: float = clamp((2.3 - float(map.zoom_level)) / 1.3, 0.0, 1.0)
	for band in range(4):
		var y_base = size.y * (0.16 + 0.21 * band)
		var points := PackedVector2Array()
		var steps = 30
		for i in range(steps + 1):
			var x = size.x * float(i) / steps
			var y = y_base + sin(float(i) * 0.45 + fx_time * 0.8 + float(band) * 1.7) * 9.0
			points.append(Vector2(x, y))
		var alpha: float = (0.032 + 0.014 * band) * fade * (0.7 + 0.3 * sin(fx_time * 0.5 + band))
		draw_polyline(points, Color(0.34, 0.78, 0.86, alpha), 1.4, true)

# جریان متحرک تجارت روی مسیرهای ثبت‌شده نقشه + نقطه حمل‌ونقل در حرکت.
func _draw_trade_flow():
	if not map.overlays.get("trade", false):
		return
	var phase = fx_time * 46.0
	for route in map._drawn_routes:
		if str(route.get("type", "")) != "trade":
			continue
		var pts: PackedVector2Array = route.get("points", PackedVector2Array())
		if pts.size() < 2:
			continue
		_dash_flow(pts, Color(1.0, 0.83, 0.35, 0.50), 2.2, phase)
		var label_key = str(route.get("label", ""))
		var offset = float(abs(hash(label_key)) % 100) / 100.0
		var p = _point_at_ratio(pts, fposmod(fx_time * 0.10 + offset, 1.0))
		draw_circle(p, 8.0, Color(1.0, 0.80, 0.30, 0.22))
		draw_circle(p, 4.0, Color(1.0, 0.86, 0.40, 0.90))

# پالس حلقه‌ای قرمز روی کشورهای درگیر جنگ + نشان ⚔ تپنده.
func _draw_war_pulses():
	var active_wars: Dictionary = map.world_state.get("wars", {})
	var npc_wars: Dictionary = map.world_state.get("npc_wars", {})
	if active_wars.is_empty() and npc_wars.is_empty():
		return
	var participants: Array = []
	for code in active_wars.keys():
		participants.append(str(code))
	for npc_war in npc_wars.values():
		participants.append(str(npc_war.get("a", "")))
		participants.append(str(npc_war.get("b", "")))
	var seen := {}
	for code in participants:
		if code == "" or seen.has(code):
			continue
		seen[code] = true
		var profile: Dictionary = map.countries.get(code, {})
		if profile.is_empty():
			continue
		var p = map._geo_point(float(profile.get("lon", 0.0)), float(profile.get("lat", 0.0)))
		if not get_rect().grow(60).has_point(p):
			continue
		var cycle = fposmod(fx_time, 1.2) / 1.2
		for ring in range(2):
			var radius = 10.0 + (cycle + ring * 0.5) * 26.0
			var alpha = clamp(0.55 * (1.0 - cycle), 0.0, 0.55)
			draw_arc(p, radius, 0.0, TAU, 36, Color(1.0, 0.34, 0.28, alpha), 2.4, true)
		draw_circle(p, 5.0 + sin(fx_time * 6.0) * 1.3, Color(1.0, 0.36, 0.30, 0.95))
		draw_string(PersianFont, p + Vector2(0, -18), "⚔", HORIZONTAL_ALIGNMENT_CENTER, -1, 26, Color(1.0, 0.58, 0.48))

# چراغ راهنمای طلایی بالای پایتخت کشور بازیکن.
func _draw_capital_beacon():
	if map.player_country == "":
		return
	var profile: Dictionary = map.countries.get(map.player_country, {})
	if profile.is_empty():
		return
	var p = map._geo_point(float(profile.get("lon", 0.0)), float(profile.get("lat", 0.0)))
	if not get_rect().grow(40).has_point(p):
		return
	var pulse = 0.5 + 0.5 * sin(fx_time * 2.0)
	draw_arc(p, 13.0 + pulse * 8.0, 0.0, TAU, 40, Color(0.95, 0.78, 0.35, 0.42 - pulse * 0.18), 2.0, true)
	draw_string(PersianFont, p + Vector2(0, -27), "★", HORIZONTAL_ALIGNMENT_CENTER, -1, 30, Color(1.0, 0.85, 0.42, 0.80 + 0.20 * sin(fx_time * 2.0)))

# ابرهای شناور آرام در لنز اقلیم.
func _draw_weather_clouds():
	if map.base_layer != "weather":
		return
	for i in range(7):
		var cx = (fposmod(float(i) * 0.37 + fx_time * 0.008, 1.2) - 0.1) * size.x
		var cy = size.y * (0.16 + 0.115 * (i % 6)) + sin(fx_time * 0.4 + i) * 8.0
		var r = 44.0 + float(i % 3) * 22.0
		for puff in range(3):
			var off = Vector2(float(puff - 1) * r * 0.55, float((puff + i) % 2) * r * 0.16)
			draw_circle(Vector2(cx, cy) + off, r * (0.5 + float(puff % 2) * 0.2), Color(0.86, 0.93, 0.99, 0.045))

func _dash_flow(points: PackedVector2Array, color: Color, width: float, phase: float):
	var dash := 10.0
	var period := 22.0
	var s := 0.0
	var prev := points[0]
	for i in range(1, points.size()):
		var cur := points[i]
		var seg := prev.distance_to(cur)
		if seg < 0.5:
			continue
		var walked := 0.0
		while walked < seg:
			var local = fposmod(s + walked + phase, period)
			if local < dash:
				var span = min(dash - local, seg - walked)
				draw_line(prev.lerp(cur, walked / seg), prev.lerp(cur, (walked + span) / seg), color, width, true)
				walked += span
			else:
				walked += period - local
		s += seg
		prev = cur

func _point_at_ratio(points: PackedVector2Array, ratio: float) -> Vector2:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	if total <= 0.0:
		return points[0]
	var target = total * ratio
	var walked := 0.0
	for i in range(1, points.size()):
		var seg = points[i - 1].distance_to(points[i])
		if walked + seg >= target:
			return points[i - 1].lerp(points[i], (target - walked) / max(seg, 0.001))
		walked += seg
	return points[points.size() - 1]
