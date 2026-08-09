extends BaseAI
# هوش بانک مرکزی - ۳.۲۵.۷
func decide(state: Dictionary, tick: int) -> Array:
    var cb = state.get("central_bank", {})
    var econ = state.get("economy", {})
    # استقلال، هدف‌گذاری تورم، مدیریت ارز
    if econ.get("inflation",0.08) > cb.get("inflation_target",0.05) + 0.05:
        pass # افزایش نرخ بهره
    return []
