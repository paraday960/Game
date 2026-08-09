extends BaseAI
# هوش بهداشت - ۳.۱۹.۷
func decide(state: Dictionary, tick: int) -> Array:
    var health = state.get("health", {})
    # اگر پوشش کم، اولویت پیشگیری یا درمان
    if health.get("coverage",0.75) < 0.6:
        pass
    if health.get("epidemic_readiness",0.5) < 0.4:
        # پیشنهاد افزایش آمادگی
        pass
    return []
