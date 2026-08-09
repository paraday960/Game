extends BaseAI
# هوش فرهنگ - ۳.۲۲.۷
func decide(state: Dictionary, tick: int) -> Array:
    var culture = state.get("culture", {})
    # مدیریت بحران اطلاعات، پیشنهاد سیاست رسانه
    if culture.get("misinformation_risk",0.3) > 0.6:
        pass
    return []
