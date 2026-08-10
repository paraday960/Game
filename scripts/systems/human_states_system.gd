extends BaseSystem
# ۳.۶۶ حالات انسانی
func compute(state: Dictionary, tick: int) -> Dictionary:
    var human=state.get("human_states",{})
    human["happiness_avg"]=human.get("happiness_avg",state.get("population",{}).get("happiness",0.60))
    human["stress"]=human.get("stress",0.35)
    human["hope"]=human.get("hope",0.60)
    human["fear"]=human.get("fear",state.get("politics",{}).get("tension",0.35))
    human["anger"]=human.get("anger",0.20)
    human["trust"]=human.get("trust",state.get("politics",{}).get("trust",0.55))
    human["national_pride"]=human.get("national_pride",state.get("culture",{}).get("cohesion",0.65))
    human["mental_health"]=human.get("mental_health",state.get("health",{}).get("mental_health",0.60))
    var events=[]
    var happiness=state.get("population",{}).get("happiness",0.60)
    var tension=state.get("politics",{}).get("tension",0.35)
    human["happiness_avg"]=happiness
    human["stress"]=clamp(tension*0.6 + (1.0-happiness)*0.4,0.05,0.90)
    human["hope"]=clamp(0.5 + happiness*0.3 + state.get("economy",{}).get("growth_rate",0.02)*10.0*0.2,0.1,0.95)
    human["fear"]=clamp(tension*0.7 + (1.0-state.get("security",{}).get("feeling_security",0.70))*0.3,0.05,0.90)
    human["anger"]=clamp((1.0-happiness)*0.5 + tension*0.3,0.05,0.85)
    human["trust"]=state.get("politics",{}).get("trust",0.55)
    human["national_pride"]=clamp(state.get("culture",{}).get("cohesion",0.65)*0.5 + state.get("indicators",{}).get("power_score",55.0)/100.0*0.5,0.1,0.95)
    human["mental_health"]=clamp(human["mental_health"]+ (happiness-0.5)*0.001 - human["stress"]*0.0005,0.1,0.95)
    if human["stress"]>0.7 and Deterministic.chance(0.015):
        events.append({"type":"stress_crisis","message":"استرس اجتماعی بالا"})
    state["human_states"]=human
    return {"success":true,"state":state,"events":events}
