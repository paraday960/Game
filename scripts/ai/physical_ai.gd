extends BaseAI
func decide(state: Dictionary, tick: int) -> Array:
    var p = state.get("physical", {})
    if p.get("housing_shortage",0.1) > 0.2:
        pass
    return []
