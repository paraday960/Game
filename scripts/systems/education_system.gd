extends BaseSystem
func compute(state: Dictionary, tick: int) -> Dictionary:
    var e = state["education"]
    e["quality"] = clamp(e["quality"] + 0.0001, 0.1, 1.0)
    e["literacy"] = clamp(e["literacy"] + 0.00005, 0.1, 1.0)
    state["education"]=e
    return {"success":true,"state":state,"events":[]}
