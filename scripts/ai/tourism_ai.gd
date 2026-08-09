extends BaseAI
func decide(state: Dictionary, tick: int) -> Array:
    var tourism = state.get("tourism", {})
    if tourism.get("safety",0.7) < 0.4:
        pass
    return []
