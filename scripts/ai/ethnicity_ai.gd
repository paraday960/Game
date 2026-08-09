extends BaseAI
func decide(state: Dictionary, tick: int) -> Array:
    var eth = state.get("ethnicity", {})
    if eth.get("tension",0.3) > 0.6:
        pass
    return []
