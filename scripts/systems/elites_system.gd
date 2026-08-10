extends BaseSystem
# ۳.۵۹ نخبگان
func compute(state: Dictionary, tick: int) -> Dictionary:
    var elites=state.get("elites_detail",{})
    elites["scientific"]=elites.get("scientific",10000)
    elites["economic"]=elites.get("economic",50000)
    elites["cultural"]=elites.get("cultural",20000)
    elites["influence"]=elites.get("influence",0.60)
    elites["brain_drain"]=elites.get("brain_drain",0.15)
    elites["return_rate"]=elites.get("return_rate",0.10)
    var events=[]
    var pop_hap=state.get("population",{}).get("happiness",0.6)
    var gdp_pc=state.get("economy",{}).get("gdp_per_capita",5000.0)
    elites["brain_drain"]=clamp(elites["brain_drain"] + (0.6-pop_hap)*0.001 + (5000.0-gdp_pc)/10000.0*0.0005,0.02,0.50)
    elites["influence"]=clamp(elites["influence"]+elites["scientific"]/10000.0*0.0001,0.2,0.90)
    if elites["brain_drain"]>0.3 and Deterministic.chance(0.01):
        events.append({"type":"brain_drain_elites","message":"مهاجرت نخبگان علمی"})
        elites["scientific"]-=50
    state["elites_detail"]=elites
    return {"success":true,"state":state,"events":events}
