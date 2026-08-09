extends BaseAI
func decide(state: Dictionary, tick: int) -> Array:
    var s = state.get("space", {})
    if s.get("level",0.1) < 0.2:
        pass
    if s.get("satellites",2) == 0:
        pass
    return []
