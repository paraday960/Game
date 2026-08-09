extends BaseAI
func decide(state: Dictionary, tick: int) -> Array:
    var f = state.get("family", {})
    if f.get("fertility",1.8) < 1.5:
        pass
    if f.get("domestic_violence",0.15) > 0.25:
        pass
    return []
