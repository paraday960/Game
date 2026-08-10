extends BaseSystem
# ۳.۶۰ نیروهای امنیتی و نظامی
func compute(state: Dictionary, tick: int) -> Dictionary:
    var sf=state.get("security_forces_detail",{})
    sf["army"]=sf.get("army",500000)
    sf["police"]=sf.get("police",200000)
    sf["intel"]=sf.get("intel",30000)
    sf["border"]=sf.get("border",50000)
    sf["morale"]=sf.get("morale",0.70)
    sf["training"]=sf.get("training",0.65)
    sf["equipment"]=sf.get("equipment",0.65)
    var events=[]
    var mil=state.get("military",{})
    sf["morale"]=clamp(sf["morale"] + (mil.get("readiness",0.70)-0.5)*0.001,0.2,0.95)
    sf["training"]=clamp(sf["training"]+0.0002,0.2,0.95)
    if sf["morale"]<0.4 and Deterministic.chance(0.01):
        events.append({"type":"force_low_morale","message":"روحیه پایین نیروهای امنیتی"})
    state["security_forces_detail"]=sf
    return {"success":true,"state":state,"events":events}
