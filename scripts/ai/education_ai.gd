extends BaseAI
# هوش آموزش - ۳.۲۰.۷
func decide(state: Dictionary, tick: int) -> Array:
    var edu = state.get("education", {})
    # اگر نسبت شاگرد/معلم بالا، پیشنهاد جذب معلم
    # اگر مهارت کم، پیشنهاد فنی‌حرفه‌ای
    if edu.get("student_teacher_ratio",25.0) > 35.0:
        pass
    return []
