extends RefCounted
class_name ProgressionManager
# پیشرفت واقعی: استریک، شتاب، دستاورد، رکورد و مرحله توسعه

const ACHIEVEMENTS = {
	"first_step": {"title":"نخستین فرمان", "description":"نخستین روز مدیریت کشور را کامل کنید.", "xp":25},
	"first_week": {"title":"یک هفته در قدرت", "description":"هفت روز کشور را اداره کنید.", "xp":40},
	"first_year": {"title":"یک سال پایداری", "description":"یک سال کامل شبیه‌سازی را پشت سر بگذارید.", "xp":150},
	"stable_30": {"title":"ماه طلایی", "description":"سی روز پیاپی شادی و ثبات بالای پنجاه درصد داشته باشید.", "xp":100},
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
	match id:
		"first_step": return tick >= 1
		"first_week": return tick >= 7
		"first_year": return tick >= 360
		"stable_30": return int(progression.get("best_streak", 0)) >= 30
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
