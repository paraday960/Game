extends BaseAI
func decide(state: Dictionary, tick: int) -> Array:
    var trade = state.get("trade", {})
    if trade.get("balance",0) < -20000000000.0:
        pass
    return []
