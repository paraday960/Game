extends RefCounted
class_name ProgressionManager
# پیشرفت واقعی: استریک، شتاب، دستاورد، رکورد و مرحله توسعه

const ACHIEVEMENTS = {
	"first_step": {"title":"نخستین ماه", "description":"نخستین ماه مدیریت کشور را کامل کنید.", "xp":25},
	"first_week": {"title":"شش ماه در قدرت", "description":"شش ماه کشور را اداره کنید.", "xp":40},
	"first_year": {"title":"یک سال پایداری", "description":"یک سال کامل شبیه‌سازی را پشت سر بگذارید.", "xp":150},
	"stable_30": {"title":"سال طلایی", "description":"دوازده ماه پیاپی شادی و ثبات بالای پنجاه درصد داشته باشید.", "xp":100},
	"happy_nation": {"title":"ملت خشنود", "description":"شادی جمعیت را به هفتاد و پنج درصد برسانید.", "xp":120},
	"economic_power": {"title":"قدرت اقتصادی", "description":"تولید ناخالص داخلی را از ششصد میلیارد عبور دهید.", "xp":140},
	"low_debt": {"title":"خزانه منضبط", "description":"نسبت بدهی به تولید داخلی را زیر سی درصد نگه دارید.", "xp":90},
	"global_voice": {"title":"صدای جهانی", "description":"نفوذ دیپلماتیک را به شصت برسانید.", "xp":110},
	"green_transition": {"title":"گذار سبز", "description":"سهم انرژی سبز را به سی‌وپنج درصد برسانید.", "xp":110},
	"crisis_master": {"title":"مدیر بحران", "description":"سه تصمیم راهبردی را با موفقیت اجرا کنید.", "xp":130}
}

static func update(state: Dictionary, tick: int) -> Dictionary:
	var progression: Dictionary = state.get("progression", {}).duplicate(true)
	progression["streak"] = int(progression.get("streak", 0))
	progression["best_streak"] = int(progression.get("best_streak", 0))
	progression["combo"] = int(progression.get("combo", 1))
	progression["previous_score"] = float(progression.get("previous_score", 0.0))
	progression["high_score"] = float(progression.get("high_score", 0.0))
	progression["legacy_score"] = int(progression.get("legacy_score", 0))
	progression["achievements"] = progression.get("achievements", [])
	progression["last_unlocks"] = []

	var happiness = float(state.get("indicators", {}).get("happiness", 0.0))
	var stability = float(state.get("indicators", {}).get("stability", 0.0))
	var streak_happiness = float(BalanceConfig.get_value("progression.stable_streak_happiness", 0.5))
	var streak_stability = float(BalanceConfig.get_value("progression.stable_streak_stability", 0.5))
	if happiness >= streak_happiness and stability >= streak_stability:
		progression["streak"] += 1
	else:
		progression["streak"] = 0
	progression["best_streak"] = max(progression["best_streak"], progression["streak"])

	var score = float(state.get("score", 0.0))
	var combo_threshold = float(BalanceConfig.get_value("progression.combo_threshold", 0.002))
	var max_combo = int(BalanceConfig.get_value("progression.max_combo", 5))
	if progression["previous_score"] > 0.0 and score > progression["previous_score"] * (1.0 + combo_threshold):
		progression["combo"] = min(progression["combo"] + 1, max_combo)
	elif score < progression["previous_score"]:
		progression["combo"] = 1
	progression["previous_score"] = score
	progression["high_score"] = max(progression["high_score"], score)

	var xp_rate = float(BalanceConfig.get_value("progression.xp_per_score", 0.01))
	state["xp"] = float(state.get("xp", 0.0)) + score * xp_rate * progression["combo"]
	var unlocked: Array = []
	var owned: Dictionary = {}
	for achievement in progression["achievements"]:
		owned[str(achievement.get("id", ""))] = true
	for id in ACHIEVEMENTS.keys():
		if owned.has(id) or not _condition_met(id, state, tick, progression):
			continue
		var definition: Dictionary = ACHIEVEMENTS[id]
		var record = {
			"id": id,
			"title": definition["title"],
			"description": definition["description"],
			"unlocked_tick": tick,
			"unlocked_day": TimeManager.get_total_days(state),
			"xp": definition["xp"]
		}
		progression["achievements"].append(record)
		progression["last_unlocks"].append(record)
		progression["legacy_score"] += int(definition["xp"] / 10)
		state["xp"] += float(definition["xp"])
		unlocked.append(record)

	var level_xp = max(float(BalanceConfig.get_value("progression.level_xp", 100.0)), 1.0)
	state["level"] = int(float(state["xp"]) / level_xp) + 1
	progression["stage"] = _development_stage(state)
	state["progression"] = progression
	return {"state": state, "unlocked": unlocked}

static func _condition_met(id: String, state: Dictionary, tick: int, progression: Dictionary) -> bool:
	var total_days = TimeManager.get_total_days(state)
	match id:
		"first_step": return tick >= 1
		"first_week": return total_days >= 180
		"first_year": return total_days >= 360
		"stable_30": return int(progression.get("best_streak", 0)) >= 12
		"happy_nation": return float(state.get("population", {}).get("happiness", 0.0)) >= 0.75
		"economic_power": return float(state.get("economy", {}).get("gdp", 0.0)) >= 600_000_000_000.0
		"low_debt": return float(state.get("economy", {}).get("debt_to_gdp", 1.0)) <= 0.30
		"global_voice": return float(state.get("diplomacy", {}).get("influence", 0.0)) >= 60.0
		"green_transition": return float(state.get("environment", {}).get("green_energy_share", 0.0)) >= 0.35
		"crisis_master": return state.get("decision_history", []).size() >= 3
	return false

static func _development_stage(state: Dictionary) -> String:
	var score = float(state.get("score", 0.0))
	var power = float(state.get("indicators", {}).get("power_score", 0.0))
	if score >= 90.0 and power >= 80.0:
		return "ابرقدرت"
	if score >= 72.0 and power >= 60.0:
		return "قدرت جهانی"
	if score >= 58.0 and power >= 42.0:
		return "قدرت منطقه‌ای"
	if score >= 42.0:
		return "در حال توسعه"
	return "دولت نوپا"


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_progression_manager(data) -> Dictionary:
	if not data is Dictionary:
		return {"valid": false, "reason": "داده دیکشنری نیست"}
	if data.is_empty():
		return {"valid": false, "reason": "داده خالی"}
	# بررسی NaN/Inf
	for k in data.keys():
		var v = data[k]
		if v is float and (is_nan(v) or is_inf(v)):
			return {"valid": false, "reason": "عدد نامتناهی در %s" % str(k)}
	return {"valid": true, "reason": ""}

func _deep_cache_progression_manager_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_progression_manager"):
		set_meta("cache_progression_manager", {})
	var cache = get_meta("cache_progression_manager")
	return cache.get(key, null)

func _deep_cache_progression_manager_set(key: String, value):
	if not has_meta("cache_progression_manager"):
		set_meta("cache_progression_manager", {})
	var cache = get_meta("cache_progression_manager")
	cache[key] = value
	set_meta("cache_progression_manager", cache)

func _deep_log_progression_manager(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_progression_manager(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_progression_manager(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("progression_manager"):
		state["progression_manager"] = {}
	return state

func _deep_deterministic_progression_manager_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_progression_manager(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("progression_manager_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_progression_manager(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("progression_manager", {}).duplicate(true) if state.has("progression_manager") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---
