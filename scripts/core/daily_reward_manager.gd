extends Node
# ============================================================
# 🎁 پاداش روزانه + استریک ورود (مثل بازی‌های موبایل موفق)
# ۷ روز چرخه با پاداش‌های صعودی؛ اگر یک روز جا بماند، از روز ۱ شروع می‌شود.
# ذخیره در user://meta.json (خارج از state بازی) تا دترمینیسم حفظ شود.
# ============================================================

const META_PATH = "user://meta.json"
const REWARDS = [
	{"reserves": 5_000_000_000.0, "capital": 0.0, "prestige": 0.0, "label": "۵ میلیارد ذخیره ارزی"},
	{"reserves": 0.0, "capital": 0.1, "prestige": 0.0, "label": "۰٫۱ سرمایه سیاسی"},
	{"reserves": 0.0, "capital": 0.0, "prestige": 5.0, "label": "۵ اعتبار بین‌المللی"},
	{"reserves": 10_000_000_000.0, "capital": 0.0, "prestige": 0.0, "label": "۱۰ میلیارد ذخیره ارزی"},
	{"reserves": 0.0, "capital": 0.15, "prestige": 0.0, "label": "۰٫۱۵ سرمایه سیاسی"},
	{"reserves": 0.0, "capital": 0.0, "prestige": 10.0, "label": "۱۰ اعتبار بین‌المللی"},
	{"reserves": 20_000_000_000.0, "capital": 0.3, "prestige": 20.0, "label": "جک‌پات: ۲۰ میلیارد + ۲۰ اعتبار + ۰٫۳ سرمایه"}
]
const DAY_MS = 86400000

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

# وضعیت فعلی پاداش روزانه
func get_status() -> Dictionary:
	var now: int = Time.get_unix_time_from_system()
	var last_day: int = int(meta.get("daily_last_day", 0))
	var streak: int = int(meta.get("daily_streak", 0))
	var today: int = now / 86400
	var can_claim := true
	if last_day == today:
		can_claim = false
	elif last_day == today - 1:
		streak = streak  # ادامه استریک
	else:
		streak = 0
	var day_index: int = streak % 7
	return {
		"can_claim": can_claim,
		"streak": streak,
		"day_index": day_index,
		"reward": REWARDS[day_index],
		"today": today,
		"last_day": last_day
	}

# دریافت پاداش — state بازی را تغییر می‌دهد (UI صدا می‌زند؛ دترمینیسم موتور امن است)
func claim(state: Dictionary) -> Dictionary:
	var status: Dictionary = get_status()
	if not bool(status.get("can_claim", false)):
		return {"success": false, "reason": "پاداش امروز قبلاً دریافت شده است"}
	var today: int = int(status.get("today", 0))
	var last_day: int = int(meta.get("daily_last_day", 0))
	var streak: int = int(meta.get("daily_streak", 0))
	if last_day != today - 1:
		streak = 0
	streak += 1
	meta["daily_last_day"] = today
	meta["daily_streak"] = streak
	save_meta()
	var reward: Dictionary = REWARDS[(streak - 1) % 7]
	# اعمال پاداش به state
	var econ: Dictionary = state.get("economy", {})
	econ["foreign_reserves"] = float(econ.get("foreign_reserves", 0.0)) + float(reward.get("reserves", 0.0))
	state["economy"] = econ
	var diplomacy: Dictionary = state.get("diplomacy", {})
	diplomacy["prestige"] = float(diplomacy.get("prestige", 0.0)) + float(reward.get("prestige", 0.0))
	state["diplomacy"] = diplomacy
	var policies: Dictionary = state.get("policies", {})
	policies["political_capital"] = float(policies.get("political_capital", 0.0)) + float(reward.get("capital", 0.0))
	state["policies"] = policies
	return {"success": true, "streak": streak, "day_index": (streak - 1) % 7, "reward": reward, "state": state}
