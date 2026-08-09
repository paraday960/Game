extends BaseSystem
func compute(state: Dictionary, tick: int) -> Dictionary:
    var ind = state["industry"]
    ind["output"] *= (1.0 + state["economy"]["growth_rate"]*0.3/365.0)
    state["industry"]=ind
    return {"success":true,"state":state,"events":[]}
