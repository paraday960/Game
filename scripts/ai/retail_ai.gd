extends BaseAI
func decide(state: Dictionary, tick: int) -> Array:
    var r = state.get("retail", {})
    if r.get("coverage",0.85) < 0.6:
        pass
    if r.get("competition",0.6) < 0.3:
        pass
    return []
