extends BaseSystem
func compute(state: Dictionary, tick: int) -> Dictionary:
    var h = state["health"]
    h["quality"] = clamp(h["quality"] + (state["economy"]["budget_allocations"].get("بهداشت",0.10)-0.08)*0.01, 0.1, 1.0)
    state["health"]=h
    return {"success":true,"state":state,"events":[]}
