extends RefCounted
const GameCommandClass = preload("res://scripts/core/command.gd")
# مدیریت هاست مرجع - بخش ۳.۸

var authoritative_state: Dictionary = {}
var version: int = 0

func validate_and_authorize(commands: Array, current_state: Dictionary) -> Dictionary:
    # هاست اختلاف‌ها را قضاوت می‌کند بر اساس شبیه‌سازی دترمینستیک
    for cmd in commands:
        # اعتبارسنجی ساده
        if cmd is GameCommandClass:
            if cmd.version != current_state.get("version",0)+1 and cmd.version != 0:
                return {"valid": false, "reason": "نسخه ناسازگار"}
    return {"valid": true}

func resolve_conflict(state_a: Dictionary, state_b: Dictionary) -> Dictionary:
    # انتخاب وضعیت مرجع - ساده: هاست همیشه مرجع است
    return state_a
