extends Node
# ============================================================
# ⏰ پیشرفت آفلاین — وقتی بازیکن برمی‌گردد، پاداش غیبت می‌گیرد
# (مثل بازی‌های موبایل: بازدهی که در نبودت تولید شده)
# فقط یک بار در هر بازگشت؛ ذخیره در user://meta.json
# ============================================================

const META_PATH = "user://meta.json"
const MIN_AWAY_HOURS = 2.0
const MAX_AWAY_HOURS = 12.0

var meta: Dictionary = {}

func _ready() -> void:
	load_meta()

func load_meta() -> bool:
	meta = {}
	if not FileAccess.file_exists(META_PATH):
		return true
	var file = FileAccess.open(META_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		meta = parsed
	return true

func save_meta() -> void:
	var file = FileAccess.open(META_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(meta, "\t"))
	file.flush()
	file.close()

# ثبت لحظه خروج (موقع بستن بازی صدا زده می‌شود)
func note_exit() -> void:
	meta["last_exit_unix"] = Time.get_unix_time_from_system()
	save_meta()

# محاسبه پاداش بازگشت — فقط یک بار
func claim_offline(state: Dictionary) -> Dictionary:
	var now: int = Time.get_unix_time_from_system()
	var last_exit: int = int(meta.get("last_exit_unix", 0))
	if last_exit <= 0:
		meta["last_exit_unix"] = now
		save_meta()
		return {"success": false, "reason": "اولین اجرا"}
	if bool(meta.get("offline_claimed", false)):
		return {"success": false, "reason": "پاداش بازگشت قبلاً گرفته شده"}
	var hours: float = (now - last_exit) / 3600.0
	if hours < MIN_AWAY_HOURS:
		meta["last_exit_unix"] = now
		save_meta()
		return {"success": false, "reason": "غیبت کوتاه"}
	hours = minf(hours, MAX_AWAY_HOURS)
	meta["offline_claimed"] = true
	meta["last_exit_unix"] = now
	save_meta()
	# پاداش: درصدی از تولید سالانه بر اساس ساعات غیبت (حداکثر ۱۲ ساعت = ~۲٪ GDP)
	var gdp: float = float(state.get("economy", {}).get("gdp", 0.0))
	var bonus: float = gdp * hours * 0.00002
	var econ: Dictionary = state.get("economy", {})
	econ["foreign_reserves"] = float(econ.get("foreign_reserves", 0.0)) + bonus
	state["economy"] = econ
	# رشد جزئی جمعیت/رضایت هم
	var pop: Dictionary = state.get("population", {})
	pop["happiness"] = clampf(float(pop.get("happiness", 0.6)) + hours * 0.0003, 0.05, 0.95)
	state["population"] = pop
	return {"success": true, "hours": hours, "bonus": bonus, "state": state}

# ریست پس از ذخیره/بارگذاری جدید (پاداش فقط یک بار در نشست)