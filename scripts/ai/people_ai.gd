extends BaseAI
func decide(state: Dictionary, tick: int) -> Array:
    var pe = state.get("people", {})
    var emotions = pe.get("emotions", {})
    if emotions.get("خشم",0.2) > 0.6:
        pass
    return []
