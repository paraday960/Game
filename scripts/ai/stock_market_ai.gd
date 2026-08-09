extends BaseAI
func decide(state: Dictionary, tick: int) -> Array:
    var stock = state.get("stock_market", {})
    if stock.get("volatility",0.15) > 0.4:
        pass
    return []
