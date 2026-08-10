extends BaseSystem
# ۳.۵۵ دولتمردان و مدیران
func compute(state: Dictionary, tick: int) -> Dictionary:
    var officials=state.get("officials",{})
    officials["ministers"]=officials.get("ministers",20)
    officials["governors"]=officials.get("governors",31)
    officials["mayors"]=officials.get("mayors",1200)
    officials["senior_managers"]=officials.get("senior_managers",5000)
    officials["competence"]=officials.get("competence",0.60)
    officials["corruption"]=officials.get("corruption",state.get("politics",{}).get("corruption",0.30))
    officials["turnover"]=officials.get("turnover",0.15)
    var events=[]
    var corruption=state.get("politics",{}).get("corruption",0.30)
    var stability=state.get("politics",{}).get("stability",0.60)
    officials["competence"]=clamp(officials["competence"]+state.get("education",{}).get("quality",0.55)*0.0005 - corruption*0.0005,0.2,0.95)
    officials["corruption"]=corruption
    officials["turnover"]=clamp(0.15 + (1.0-stability)*0.2,0.05,0.50)
    if corruption>0.6 and Deterministic.chance(0.01):
        events.append({"type":"manager_corruption","message":"افشای فساد مدیران ارشد"})
    state["officials"]=officials
    return {"success":true,"state":state,"events":events}
