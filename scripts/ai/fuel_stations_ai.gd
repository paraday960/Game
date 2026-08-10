extends BaseAI
func decide(state: Dictionary, tick: int) -> Array:
    var f = state.get("fuel_stations", {})
    if f.get("smuggling",0.15) > 0.4:
        pass
    if f.get("storage_days",15.0) < 7.0:
        pass
    return []
