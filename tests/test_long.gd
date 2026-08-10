extends Node
# تست بلندمدت: ۳۶۵ روز شبیه‌سازی کامل

func _ready():
	print("=== LONG RUN: 365 ticks ===")
	var s = GameState.state
	var v = GameState.version
	var t = GameState.tick
	var bad := []

	for i in range(365):
		var result = GameEngine.tick(s, v, t, [])
		if not result.success:
			bad.append("tick %d failed: %s" % [i, result.reason])
			break
		s = result.state; v = result.version; t = result.tick
		if i == 120 and s["clock"]["season"] != "تابستان":
			bad.append("فصل ماه پنجم باید تابستان باشد")
			break
		if i % 60 == 0 or i == 364:
			var g = s["economy"]["gdp"]
			if is_nan(g) or is_inf(g):
				bad.append("NaN at tick %d" % i)
				break
			print("day %3d | %d/%02d %s | GDP=%.2fT | pop=%.1fM | happy=%.2f | stab=%.2f | retail_cov=%.2f | urban_water=%.2f" % [
				t, s["clock"]["year"], s["clock"]["month"], s["clock"]["season"],
				g/1e12, s["population"]["total"]/1e6, s["population"]["happiness"],
				s["politics"]["stability"],
				s.get("retail",{}).get("coverage", 0), s.get("urban_facilities",{}).get("water_network", 0)])

	print("Year after 365d: %d (expect 2028)" % s["clock"]["year"])
	if s["clock"]["year"] != 2028:
		bad.append("سال به ۲۰۲۸ نرسید")
	print("Events: %d" % EventLog.count())
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
