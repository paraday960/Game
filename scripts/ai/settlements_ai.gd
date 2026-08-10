extends BaseAI
func decide(state: Dictionary, tick: int) -> Array:
    var s = state.get("settlements_detail", {})
    if s.get("sprawl",0.3) > 0.6:
        pass
    if state.get("physical",{}).get("housing_shortage",0.1) > 0.3:
        pass
    return []
