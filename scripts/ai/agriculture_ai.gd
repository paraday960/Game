extends BaseAI
func decide(state: Dictionary, tick: int) -> Array:
    var agri = state.get("agriculture", {})
    if agri.get("food_security",0.85) < 0.5:
        pass
    if agri.get("waste",0.2) > 0.35:
        pass
    return []
