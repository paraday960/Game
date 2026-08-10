extends BaseSystem
# ۳.۶۱ رهبران مذهبی و اجتماعی
func compute(state: Dictionary, tick: int) -> Dictionary:
    var rel=state.get("religious_leaders",{})
    rel["count"]=rel.get("count",30000)
    rel["influence"]=rel.get("influence",0.60)
    rel["trust"]=rel.get("trust",0.65)
    rel["moderation"]=rel.get("moderation",0.60)
    rel["charity"]=rel.get("charity",0.55)
    var events=[]
    var culture=state.get("culture",{})
    rel["influence"]=clamp(rel["influence"]+culture.get("cohesion",0.65)*0.0003,0.2,0.90)
    rel["trust"]=clamp(rel["trust"]+Deterministic.next_range(-0.001,0.002),0.2,0.90)
    if rel["moderation"]<0.4 and Deterministic.chance(0.01):
        events.append({"type":"religious_extremism","message":"گرایش افراطی در برخی رهبران مذهبی"})
    state["religious_leaders"]=rel
    return {"success":true,"state":state,"events":events}
