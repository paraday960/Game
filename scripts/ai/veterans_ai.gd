extends BaseAI
func decide(state: Dictionary, tick: int) -> Array:
    var v = state.get("veterans", {})
    if v.get("fund_balance",500_000_000.0) < 100_000_000.0:
        pass
    return []
