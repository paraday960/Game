extends BaseAI
func decide(state: Dictionary, tick: int) -> Array:
    var emerg = state.get("emergency", {})
    if emerg.get("preparedness",0.5) < 0.3:
        pass
    if emerg.get("response_time",10.0) > 20.0:
        pass
    return []
