extends BaseAI
func decide(state: Dictionary, tick: int) -> Array:
    var e = state.get("elections", {})
    if e.get("participation",0.6) < 0.35:
        pass
    if e.get("fraud_risk",0.15) > 0.4:
        pass
    return []
