extends BaseAI
# هوش اطلاعات - ۳.۲۳.۷
func decide(state: Dictionary, tick: int) -> Array:
    var intel = state.get("intelligence", {})
    if intel.get("infiltration_risk",0.2) > 0.6:
        pass # پیشنهاد افزایش ضدجاسوسی
    if intel.get("cyber_readiness",0.5) < 0.4:
        pass # پیشنهاد بودجه سایبری
    return []
