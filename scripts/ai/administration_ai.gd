extends BaseAI
func decide(state: Dictionary, tick: int) -> Array:
    var admin = state.get("administration", {})
    if admin.get("regional_inequality",0.35) > 0.6:
        pass
    return []
