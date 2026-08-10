extends BaseSystem
# ۳.۷۰ حمل‌ونقل عمومی
func compute(state: Dictionary, tick: int) -> Dictionary:
    var pt=state.get("public_transport",{})
    pt["buses"]=pt.get("buses",5000)
    pt["metro_lines"]=pt.get("metro_lines",4)
    pt["metro_stations"]=pt.get("metro_stations",200)
    pt["ridership"]=pt.get("ridership",2000000.0)
    pt["coverage"]=pt.get("coverage",0.60)
    pt["affordability"]=pt.get("affordability",0.70)
    pt["punctuality"]=pt.get("punctuality",0.75)
    var events=[]
    var pop=state.get("population",{}).get("total",85_000_000)
    pt["ridership"]=pop * 0.02 * pt["coverage"]
    pt["coverage"]=clamp(pt["coverage"]+state.get("infrastructure",{}).get("quality",0.55)*0.0002,0.2,0.95)
    if pt["coverage"]<0.4 and Deterministic.chance(0.01):
        events.append({"type":"pt_coverage_crisis","message":"پوشش پایین حمل‌ونقل عمومی"})
    state["public_transport"]=pt
    return {"success":true,"state":state,"events":events}
