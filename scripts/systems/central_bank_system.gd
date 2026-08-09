extends BaseSystem
func compute(state: Dictionary, tick: int) -> Dictionary:
    var cb = state["central_bank"]
    # تورم هدف
    if state["economy"]["inflation"] > 0.12:
        cb["interest_rate"] += 0.001
    elif state["economy"]["inflation"] < 0.03:
        cb["interest_rate"] -= 0.001
    cb["interest_rate"]=clamp(cb["interest_rate"],0.01,0.30)
    state["central_bank"]=cb
    return {"success":true,"state":state,"events":[]}
