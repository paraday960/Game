extends BaseSystem
func compute(state: Dictionary, tick: int) -> Dictionary:
    var env = state["environment"]
    env["air_quality"] = clamp(env["air_quality"] - state["industry"]["output"]*0.000001 + 0.0001, 0.1, 1.0)
    state["environment"]=env
    return {"success":true,"state":state,"events":[]}
