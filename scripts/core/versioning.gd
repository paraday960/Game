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
# کلید یکتا = نوع + تیک + بازیکن + «هش محتوای payload» تا دو فرمان از یک
# نوع با اهداف مختلف (مثلاً دو اقدام دیپلماتیک به دو کشور، دو قانون، دو
# پروژه) در یک نوبت «تکراری» تلقی نشوند — فقط فرمان‌های واقعاً یکسان
# (payload یکسان) رد می‌شوند. (بازرسی ۱۴۰۵ — رفع «فرمان تکراری دریافت شد»)
static func make_idempotent_key(command_type: String, tick: int, player_id: String, payload: Dictionary = {}) -> String:
	var content_hash := 0
	if not payload.is_empty():
		content_hash = JSON.stringify(payload).hash()
	return "%s:%d:%s:%d" % [command_type, tick, player_id, content_hash]
