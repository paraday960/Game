extends Node
# تست بلندمدت: ۳۶ نوبت ماهانه (سه سال و بیش از هزار روز داخلی)

func _ready():
	print("=== LONG RUN: 36 MONTHLY TURNS ===")
	var s = GameState.state
	var v = GameState.version
	var t = GameState.tick
	var bad := []

	for i in range(36):
		var result = GameEngine.tick(s, v, t, [])
		if not result.success:
			bad.append("month %d failed: %s" % [i + 1, result.reason])
			break
		s = result.state; v = result.version; t = result.tick
		if i == 8 and s["clock"]["season"] != "زمستان":
			bad.append("پس از نه نوبت باید وارد زمستان شویم")
			break
		if i % 6 == 0 or i == 35:
			var g = s["economy"]["gdp"]
			if is_nan(g) or is_inf(g):
				bad.append("NaN at month %d" % (i + 1))
				break
			print("turn %2d | %s %d %s | days=%d | GDP=%.2fT | pop=%.1fM | happy=%.2f | stab=%.2f" % [
				t, TimeManager.month_name(s["clock"]["month"]), s["clock"]["year"], s["clock"]["season"],
				TimeManager.get_total_days(s), g/1e12, s["population"]["total"]/1e6,
				s["population"]["happiness"], s["politics"]["stability"]])

	if s["clock"]["year"] != 2030 or s["clock"]["month"] != 1:
		bad.append("۳۶ نوبت ماهانه باید تقویم را به ابتدای ۲۰۳۰ برساند")
	if TimeManager.get_total_days(s) < 1090:
		bad.append("روزهای داخلی سه سال کامل اجرا نشد")
	print("Events: %d" % EventLog.count())
	var analytics_count = s.get("analytics", {}).get("history", []).size()
	if analytics_count < 36 or analytics_count > 120:
		bad.append("تعداد نمونه‌های تحلیل ماهانه نامعتبر است: %d" % analytics_count)
	var weather_history: Array = s.get("weather", {}).get("history", [])
	var winter_months = 0
	for weather in weather_history:
		if weather.get("season", "") == "زمستان": winter_months += 1
	if weather_history.size() != 36 or winter_months < 9:
		bad.append("تاریخچه اقلیم و فصل‌های سه سال کامل نیست")
	var achievement_ids: Array = []
	for achievement in s.get("progression", {}).get("achievements", []):
		achievement_ids.append(achievement.get("id", ""))
	if not achievement_ids.has("first_year"):
		bad.append("دستاورد یک سال پایداری باز نشد")
	if bad.size() == 0:
		print("=== ✅ LONG RUN PASSED ===")
	else:
		print("=== ❌ %s ===" % str(bad))
	get_tree().quit(0 if bad.size() == 0 else 1)
