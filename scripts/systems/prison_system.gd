extends BaseSystem
# ۳.۶۷ زندان و نظام زندان
func compute(state: Dictionary, tick: int) -> Dictionary:
    var prison=state.get("prison",{})
    prison["population"]=prison.get("population",80000)
    prison["capacity"]=prison.get("capacity",100000)
    prison["overcrowding"]=prison.get("overcrowding",0.80)
    prison["rehabilitation"]=prison.get("rehabilitation",0.40)
    prison["recidivism"]=prison.get("recidivism",0.35)
    prison["conditions"]=prison.get("conditions",0.55)
    var events=[]
    var judicial=state.get("judicial",{})
    prison["population"]=int(judicial.get("crime_rate",50.0)*1000.0)
    prison["overcrowding"]=clamp(float(prison["population"])/float(prison["capacity"]),0.3,2.0)
    prison["conditions"]=clamp(prison["conditions"]+ (0.6-prison["overcrowding"])*0.001,0.1,0.90)
    prison["rehabilitation"]=clamp(prison["rehabilitation"]+0.0002,0.1,0.85)
    prison["recidivism"]=clamp(0.5 - prison["rehabilitation"]*0.3,0.1,0.70)
    if prison["overcrowding"]>1.0 and Deterministic.chance(0.012):
        events.append({"type":"prison_overcrowding","message":"تراکم جمعیت زندان - ظرفیت تکمیل"})
    state["prison"]=prison
    return {"success":true,"state":state,"events":events}
