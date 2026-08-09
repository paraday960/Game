extends BaseAI
func decide(state: Dictionary, tick: int) -> Array:
    var s = state.get("sports_youth", {})
    if s.get("youth_unemployment",0.15) > 0.25:
        pass
    return []
