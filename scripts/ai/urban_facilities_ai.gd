extends BaseAI
func decide(state: Dictionary, tick: int) -> Array:
    var u = state.get("urban_facilities", {})
    if u.get("waste_collection",0.7) < 0.5:
        pass
    return []
