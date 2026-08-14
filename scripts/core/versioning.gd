extends RefCounted
class_name Versioning
# نسخه‌بندی خوش‌بینانه - بخش ۳.۷ لایه ۳

static func is_next_version(current: int, incoming: int) -> bool:
	return incoming == current + 1

static func check_conflict(current_version: int, incoming_version: int) -> Dictionary:
	if incoming_version == current_version + 1:
		return {"conflict": false, "reason": ""}
	elif incoming_version <= current_version:
		return {"conflict": true, "reason": "نسخه قدیمی - قبلا اعمال شده"}
	else:
		return {"conflict": true, "reason": "پرش نسخه - نسخه‌های میانی گم شده"}

# ایدمپوتنسی - بخش ۳.۷ لایه ۲
# هر عملیات قابل تکرار امن باشد
static func make_idempotent_key(command_type: String, tick: int, player_id: String) -> String:
	return "%s:%d:%s" % [command_type, tick, player_id]
