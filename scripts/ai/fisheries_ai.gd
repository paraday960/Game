extends BaseAI
func decide(state: Dictionary, tick: int) -> Array:
    var fish = state.get("fisheries", {})
    if fish.get("stock_health",0.65) < 0.3:
        pass
    if fish.get("illegal_fishing",0.15) > 0.3:
        pass
    return []
