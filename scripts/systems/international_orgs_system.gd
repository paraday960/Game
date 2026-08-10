extends BaseSystem
# ۳.۶۸ سازمان‌های بین‌المللی
func compute(state: Dictionary, tick: int) -> Dictionary:
    var intl=state.get("international_orgs",{})
    intl["un_membership"]=intl.get("un_membership",1.0)
    intl["influence_un"]=intl.get("influence_un",state.get("diplomacy",{}).get("influence",40.0)/100.0)
    intl["world_bank"]=intl.get("world_bank",0.50)
    intl["imf"]=intl.get("imf",0.50)
    intl["treaties_intl"]=intl.get("treaties_intl",10)
    intl["compliance"]=intl.get("compliance",0.60)
    var events=[]
    var diplomacy=state.get("diplomacy",{})
    intl["influence_un"]=clamp(diplomacy.get("influence",40.0)/100.0,0.05,0.95)
    intl["compliance"]=clamp(intl["compliance"]+Deterministic.next_range(-0.001,0.002),0.2,0.95)
    if Deterministic.chance(0.005):
        events.append({"type":"un_resolution","message":"قطعنامه سازمان ملل"})
    state["international_orgs"]=intl
    return {"success":true,"state":state,"events":events}
