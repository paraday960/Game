extends BaseAI
func decide(state: Dictionary, tick: int) -> Array:
    var h = state.get("hospitality", {})
    if h.get("hotels_capacity",0.65) > 1.0:
        pass
    return []
