extends BaseAI
func decide(state: Dictionary, tick: int) -> Array:
    var h = state.get("heritage", {})
    if h.get("preservation",0.65) < 0.4:
        pass
    return []
