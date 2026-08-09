extends BaseAI
func decide(state: Dictionary, tick: int) -> Array:
    var stats = state.get("statistics", {})
    if stats.get("accuracy",0.75) < 0.5:
        pass
    return []
