extends BaseAI
func decide(state: Dictionary, tick: int) -> Array:
    var ind = state.get("industry", {})
    if ind.get("supply_chain",0.65) < 0.4:
        pass
    if ind.get("capacity_usage",0.75) > 1.0:
        pass
    return []
