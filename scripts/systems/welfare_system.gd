extends BaseSystem
func compute(state: Dictionary, tick: int) -> Dictionary:
    var w = state["welfare"]
    w["poverty"] = clamp(w["poverty"] + (state["economy"]["unemployment"]-0.08)*0.001, 0.02, 0.50)
    state["welfare"]=w
    return {"success":true,"state":state,"events":[]}
