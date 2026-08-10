extends BaseSystem
# ۳.۵۶ سیاست‌مداران - احزاب، جناح‌ها، ایدئولوژی
func compute(state: Dictionary, tick: int) -> Dictionary:
    var pols=state.get("politicians_detail",{})
    pols["parties"]=pols.get("parties",5)
    pols["factions"]=pols.get("factions",8)
    pols["ideology_diversity"]=pols.get("ideology_diversity",0.60)
    pols["polarization"]=pols.get("polarization",0.40)
    pols["populism"]=pols.get("populism",0.30)
    pols["trust_politicians"]=pols.get("trust_politicians",0.40)
    var events=[]
    var politics=state.get("politics",{})
    pols["polarization"]=clamp(pols["polarization"] + politics.get("tension",0.35)*0.001 - state.get("culture",{}).get("cohesion",0.65)*0.0005,0.1,0.90)
    pols["trust_politicians"]=clamp(pols["trust_politicians"]*0.99 + politics.get("trust",0.55)*0.01,0.1,0.85)
    pols["populism"]=clamp(pols["populism"] + (1.0-state.get("population",{}).get("happiness",0.6))*0.001,0.05,0.80)
    if pols["polarization"]>0.7 and Deterministic.chance(0.012):
        events.append({"type":"polarization_crisis","message":"قطبی‌شدن شدید سیاسی - بن‌بست در پارلمان"})
    state["politicians_detail"]=pols
    return {"success":true,"state":state,"events":events}
