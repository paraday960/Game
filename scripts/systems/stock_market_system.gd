extends BaseSystem
func compute(state: Dictionary, tick: int) -> Dictionary:
    var sm = state["stock_market"]
    sm["index"] *= (1.0 + state["economy"]["growth_rate"]*0.5/365.0 + Deterministic.next_range(-0.001,0.001))
    state["stock_market"]=sm
    return {"success":true,"state":state,"events":[]}
