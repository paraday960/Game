extends Node
# ============================================================
# 🎉 مدیر جشن‌ها و لحظه‌های هیجان‌انگیز (Game Feel)
# در پایان هر ماه، تغییرات وضعیت را رصد می‌کند و «لحظه‌های مهم» را
# تشخیص می‌دهد: دستاورد جدید، ارتقای مرحله توسعه، رکورد امتیاز،
# مرز جمعیت/GDP و پیروزی جنگ. این لحظه‌ها به UI اعلام می‌شوند تا
# با بنر، جلوه و صدا جشن گرفته شوند (مثل بازی‌های موفق این سبک).
# ============================================================

# هماهنگ‌سازی tracking با وضعیت فعلی (بعد از انتخاب کشور یا شروع بازی)
func reset_tracking(state: Dictionary) -> void:
	var progression: Dictionary = state.get("progression", {})
	var tracking: Dictionary = {
		"last_stage": str(progression.get("stage", "دولت نوپا")),
		"last_achievement_count": int(progression.get("achievements", []).size()),
		"last_high_score": float(progression.get("high_score", 0.0)),
		"last_pop_mark": _mark(float(state.get("population", {}).get("total", 0.0))),
		"last_gdp_mark": _mark(float(state.get("economy", {}).get("gdp", 0.0)))
	}
	state["celebration_tracking"] = tracking

func _mark(value: float) -> int:
	if value <= 0.0:
		return 0
	return int(log(value) / log(10.0))

# در پایان هر ماه صدا زده می‌شود؛ لیست جشن‌های فعال را برمی‌گرداند.
# نکته دترمینیسم: تمام tracking در خود state ذخیره می‌شود (نه حافظه مدیر)
# تا دو اجرای یکسان تیک، خروجی یکسان بدهند.
func detect_celebrations(state: Dictionary) -> Array:
	var celebrations: Array = []
	var tracking: Dictionary = state.get("celebration_tracking", {})
	var progression: Dictionary = state.get("progression", {})
	var stage: String = str(progression.get("stage", "دولت نوپا"))

	# ۱) ارتقای مرحله توسعه
	var last_stage: String = str(tracking.get("last_stage", ""))
	if last_stage != "" and stage != last_stage:
		celebrations.append({
			"type": "stage_up",
			"title": "🏛 دوره جدید تمدن شما آغاز شد!",
			"subtitle": "مرحله کشور: «%s»" % stage,
			"severity": "gold"
		})
	tracking["last_stage"] = stage

	# ۲) دستاورد جدید
	var achievements: Array = progression.get("achievements", [])
	var last_ach_count: int = int(tracking.get("last_achievement_count", 0))
	if achievements.size() > last_ach_count:
		var new_one: Dictionary = achievements[achievements.size() - 1]
		celebrations.append({
			"type": "achievement",
			"title": "🏅 دستاورد: %s" % str(new_one.get("title", "جدید")),
			"subtitle": str(new_one.get("description", "")),
			"severity": "gold"
		})
	tracking["last_achievement_count"] = achievements.size()

	# ۳) رکورد امتیاز — فقط برای جهش‌های بزرگ (≥ ۳ امتیاز)
	var high_score = float(progression.get("high_score", 0.0))
	var last_high: float = float(tracking.get("last_high_score", 0.0))
	if high_score > last_high and last_high > 0.0 and high_score - last_high >= 3.0:
		celebrations.append({
			"type": "record",
			"title": "📈 رکورد تازه!",
			"subtitle": "بالاترین امتیاز تاریخ کشور شما: %s" % PersianFormatter.to_persian_digits("%.0f" % high_score),
			"severity": "blue"
		})
	tracking["last_high_score"] = high_score

	# ۴) عبور از مرز جمعیت (هر ۱۰ برابر)
	var pop = float(state.get("population", {}).get("total", 0.0))
	var pop_mark = _mark(pop)
	var last_pop_mark: int = int(tracking.get("last_pop_mark", 0))
	if pop_mark > last_pop_mark and last_pop_mark > 0:
		celebrations.append({
			"type": "population",
			"title": "👥 جمعیت کشور به %s نفر رسید!" % PersianFormatter.format_large(pop),
			"subtitle": "مرز جمعیتی جدیدی ثبت شد",
			"severity": "teal"
		})
	tracking["last_pop_mark"] = pop_mark

	# ۵) عبور از مرز GDP (هر ۱۰ برابر)
	var gdp = float(state.get("economy", {}).get("gdp", 0.0))
	var gdp_mark = _mark(gdp)
	var last_gdp_mark: int = int(tracking.get("last_gdp_mark", 0))
	if gdp_mark > last_gdp_mark and last_gdp_mark > 0:
		celebrations.append({
			"type": "economy",
			"title": "💰 اقتصاد کشور از مرز %s گذشت!" % PersianFormatter.format_money(gdp),
			"subtitle": "دوران تازه‌ای برای توسعه اقتصادی",
			"severity": "green"
		})
	tracking["last_gdp_mark"] = gdp_mark

	state["celebration_tracking"] = tracking
	return celebrations
