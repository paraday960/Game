extends BaseAI
func decide(state: Dictionary, tick: int) -> Array:
    var t = state.get("transport_detail", {})
    if t.get("traffic_congestion",0.4) > 0.7:
        pass
    if t.get("logistics_efficiency",0.65) < 0.4:
        pass
    return []
